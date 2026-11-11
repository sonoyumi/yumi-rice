import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.components
import qs.services

// OSD: громкость, микрофон, яркость экрана и клавиатуры, раскладка, Caps Lock, «Не засыпать».
// «Остров» (29.10): своего окна нет — состояние уходит в OsdState.post(), показывает центральный остров
// (уровни — полоса 340×48 ~1,6 с, раскладка/Caps/«не спать» — сообщение 270×30 ~1,5 с; повтор продлевает без мигания).
// Источники: 1) PipeWire — громкость/выкл выхода и микрофона (Audio); 2) Hyprland — событие activelayout;
// 3) IPC:  qs -c yumi ipc call osd show <vol|mic|bri|kbd|lang|caps|caffeine> <значение|->
//    значение: проценты (vol/mic/bri/kbd), код раскладки (lang), on/off|true|false (caps/caffeine); «-» = прочитать самим.
Scope {
    id: root
    readonly property string home: Quickshell.env("HOME")

    property string kind: "vol"
    property real level: 0            // 0..1
    property bool hasLevel: true      // есть ползунок
    property bool off: false          // выключено (звук/микрофон) — ползунок тускнеет
    property string icon: "󰕾"
    property bool yumiIcon: false
    property bool pods: false         // AirPods — значок PodsGlyph, как в баре (18.10)
    property string label: ""         // текст справа (проценты или слово)
    property bool armed: false
    readonly property string mainKb: '[.keyboards[] | select(.name | test("avrcp") | not)] | (map(select(.main)) + .)[0]'   // jq: главная без AirPods        // первые секунды после старта PipeWire не считаем событиями

    IpcHandler {
        target: "osd"
        function show(kind: string, value: string): void { if (kind === "vol") btFirst.stop(); root.show(kind, value) }
    }

    Timer { interval: 2500; running: true; onTriggered: { root.armed = true; root.lastSink = Audio.sinkName } }

    // 30.10: смена выхода (подключились AirPods и т. п.) — громкость нового устройства не показываем
    // (было два всплытия подряд поверх пузыря «AirPods» с зарядом); клавиши и yumi-volume идут через IPC — их не глушим
    property string lastSink: ""
    // громкость нового выхода приходит на ~1 мс раньше смены имени — решаем чуть позже (pwPend), когда имя уже новое
    Timer { id: sinkQuiet; interval: 2000 }
    // 30.10: Bluetooth-выход при первом звуке после подключения сам присылает свою громкость (AVRCP) — это не действие
    // пользователя: первое такое изменение в течение 3 мин пропускаем (клавиши/IPC и свайп после него — как обычно)
    Timer { id: btFirst; interval: 180000 }
    Timer { id: pwPend; interval: 120
            onTriggered: {
                if (!root.armed || !Audio.ready) return
                if (Audio.sinkName !== root.lastSink) { root.lastSink = Audio.sinkName; sinkQuiet.restart(); if (Audio.bluetooth) btFirst.restart(); return }
                if (sinkQuiet.running) return
                if (btFirst.running && Audio.bluetooth) { btFirst.stop(); return }
                root.show("vol", "-")
            } }
    function fromPw() { if (root.armed && Audio.ready && !sinkQuiet.running) pwPend.restart() }

    // --- штатные источники ---
    Connections {
        target: Audio
        function onSinkNameChanged() { root.lastSink = Audio.sinkName; pwPend.stop(); sinkQuiet.restart(); if (Audio.bluetooth) btFirst.restart(); else btFirst.stop() }
        function onReadyChanged()    { pwPend.stop(); sinkQuiet.restart() }
        function onVolChanged()      { root.fromPw() }
        function onMutedChanged()    { root.fromPw() }
        // 30.10: громкость микрофона сама по себе не показывается — Discord (автоусиление) двигает её постоянно;
        // клавиши и yumi-volume зовут IPC «osd show mic» сами
        function onMicMutedChanged() { if (root.armed && Audio.micReady) root.show("mic", "-") }
    }
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name !== "activelayout") return
            // 30.10: подключились AirPods — их «клавиатура» (…-(avrcp)) всегда стартует с EN: не показываем,
            // а ставим ей текущую раскладку настоящих клавиатур (иначе казалось, что язык сменился)
            if (ev.data.split(",")[0].indexOf("avrcp") >= 0) {
                const dev = ev.data.split(",")[0]
                Quickshell.execDetached(["sh", "-c", "i=$(hyprctl devices -j | jq -r '" + root.mainKb + ".active_layout_index // 0'); "
                                         + "hyprctl switchxkblayout \"$1\" \"$i\" >/dev/null", "sh", dev])
                return
            }
            // 31.10: язык у каретки рисует yumi-lang-popup (zwp_input_popup_surface_v2);
            // островной индикатор выключен, чтобы при переключении не было двух подсказок.
            // Вернуть прежнее поведение — раскомментировать две строки ниже.
            // const km = ev.data.split(",").pop()
            // root.show("lang", km.indexOf("Russian") >= 0 ? "RU" : (km.indexOf("Ukrain") >= 0 ? "UA" : (km.indexOf("English") >= 0 ? "EN" : km.slice(0, 2).toUpperCase())))
        }
    }
    Connections {
        target: Brightness
        function onUpdated() { if (root.pendingBri) { root.pendingBri = ""; root.show(root.pendingBriKind, "-") } }
    }
    property string pendingBri: ""
    property string pendingBriKind: ""

    function pct(value, fallback) {
        const n = parseFloat(value)
        return isNaN(n) ? fallback : Math.max(0, Math.min(1, n / 100))
    }
    function onoff(value, fallback) {
        if (value === "on" || value === "true" || value === "1") return true
        if (value === "off" || value === "false" || value === "0") return false
        return fallback
    }

    function show(kind, value) {
        if (OsdState.suppressed) return
        value = (value === undefined || value === null) ? "-" : String(value)
        const asked = value !== "-" && value !== ""
        pods = false
        switch (kind) {
        case "vol":
            level = asked ? pct(value, Audio.vol) : Audio.vol
            off = Audio.muted; hasLevel = true
            pods = Audio.airpods; yumiIcon = false   // 19.10: 3,5 мм — значок колонки (MDI), не YumiIcons-наушники
            icon = Audio.airpods ? "" : (Audio.jack ? String.fromCodePoint(0xF04C3) :   // YumiIcons кодами — сами символы теряются при записи файла
                   (off ? "󰝟" : (level < 0.33 ? "󰕿" : (level < 0.66 ? "󰖀" : "󰕾"))))
            label = off ? "Выкл" : Math.round(level * 100) + "%"
            break
        case "player":   // 19.10: громкость ПОТОКА плеера (yumi-player-volume, кнопки тачбара) — своя нота, чтобы не путать с системной
            level = pct(value, Player.volume); off = level <= 0; hasLevel = true; yumiIcon = false
            icon = String.fromCodePoint(off ? 0xF075B : 0xF075A)   // music-off / music (♫ — не путать с динамиком системы)
            label = off ? "Плеер · выкл" : "Плеер · " + Math.round(level * 100) + "%"
            break
        case "mic":
            level = asked ? pct(value, Audio.micVol) : Audio.micVol
            off = Audio.micMuted; hasLevel = true; yumiIcon = false
            icon = off ? "󰍭" : "󰍬"
            label = off ? "Выкл" : Math.round(level * 100) + "%"
            break
        case "bri":
        case "kbd":
            if (!asked) {   // значения нет — прочитать brightnessctl и показать, когда придёт
                pendingBri = kind; pendingBriKind = kind; Brightness.refresh(); return
            }
            level = pct(value, 0); off = false; hasLevel = true; yumiIcon = false
            icon = kind === "bri" ? (level < 0.5 ? "󰃟" : "󰃠") : "󰌌"
            label = Math.round(level * 100) + "%"
            break
        case "lang":
            hasLevel = false; off = false; yumiIcon = false
            icon = "󰌌"
            label = asked ? value.toUpperCase() : "…"
            break
        case "caps": {
            const on = asked ? onoff(value, Brightness.caps) : Brightness.caps
            hasLevel = false; off = !on; yumiIcon = false
            icon = "󰪛"; label = on ? "Caps Lock вкл" : "Caps Lock выкл"
            break
        }
        case "caffeine": {
            const on = onoff(value, false)
            hasLevel = false; off = !on; yumiIcon = false
            icon = on ? "󰅶" : "󰒲"; label = on ? "Не засыпать" : "Обычный сон"
            break
        }
        default:
            console.log("OSD: неизвестный вид", kind); return
        }
        // bri/kbd без значения: когда brightnessctl прочитан, pendingBri уже сброшен — берём свежие значения
        if ((kind === "bri" || kind === "kbd") && !asked) {
            level = (kind === "bri" ? Brightness.screen : Brightness.kbd) / 100
            label = Math.round(level * 100) + "%"
        }
        root.kind = kind
        OsdState.post({ kind: kind, level: level, hasLevel: hasLevel, off: off, icon: icon, yumiIcon: yumiIcon, pods: pods, label: label })
    }
}
