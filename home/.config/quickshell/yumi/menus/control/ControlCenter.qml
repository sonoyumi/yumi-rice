import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower
import qs
import qs.components
import qs.services
import qs.osd
import qs.menus.wifi

// Центр управления — «Плитки с удержанием» (вариант 02 страницы статичных меню, 16.10) и ГЛАВНЫЙ УЗЕЛ оболочки.
// «Остров» (29.10): шапка «Центр управления» + дата и печать 弓 справа, плитки ITile в 2 колонки (вкл = акцент,
// морфинг радиуса), ползунки-капсулы, мини-плеер в подложке, профиль сегментами, меню — капсулы-значки, уведомления.
// Прежние версии: шторка — ControlCenter.qml.bak-v2-20261016, исходные плитки — ControlCenter.qml.bak-widget-20261016.
// Карточка под правым краем бара: плитки Wi-Fi / Bluetooth / VPN / Микрофон / Экономия / Кофеин (клик / Enter — вкл/выкл
// через yumi-cc; удержание / правый клик / Shift+Enter / «.» — меню раздела), ползунки яркости и громкости, плеер,
// профиль питания, плитки-ссылки на ВСЕ меню (Menus.open(имя, true) — как по бинду, по центру), последние уведомления.
// Клавиши: стрелки — по плиткам (↑↓ между рядами — к ближайшей по горизонтали), Enter / Пробел — нажать,
// Shift+Enter / «.» — подробности; на ползунке Enter — регулировать (↑↓ ←→ ±5 %, Enter/Esc — готово); Esc — закрыть.
// Закрытие — Esc, клик вне карточки, уход курсора далеко (как раньше).
//   qs -c yumi ipc call control toggle|open|close (= menu toggle control) · control key up|down|left|right|enter|alt|space|esc · control state
//   YP_DRYRUN=1 — только печать команд. YUMI_QS_NOKB=1 — без захвата клавиатуры (проверка).
Scope {
    id: root
    readonly property string home: Quickshell.env("HOME")
    readonly property string bin: home + "/.local/bin/"
    readonly property bool dry: Quickshell.env("YP_DRYRUN") === "1"
    property var st: ({})                       // состояния от бэкенда: {wifi:{on,sub}, bt, vpn, saver, caffeine, ppd}
    property var busy: ({})                     // ключ → момент, до которого держим мгновенный отклик (мс)
    readonly property bool open: Menus.current === "control"

    IpcHandler {
        target: "control"
        function toggle(): void { Menus.toggle("control") }
        function open(): void { Menus.open("control") }
        function close(): void { Menus.close("control") }
        function key(name: string): void { root.key(name) }
        function state(): string { return JSON.stringify({ open: root.open, focus: root.fid, row: root.fr, col: root.fc, editing: root.editing }) }
    }

    // --- бэкенд состояний (без изменений) ---
    Process {
        id: backend
        command: [root.home + "/.local/lib/yumi/qs/control-state"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: (line) => {
                let j; try { j = JSON.parse(line) } catch (e) { return }
                const now = Date.now(), s = Object.assign({}, root.st)
                for (const k in j) { if (!(root.busy[k] > now)) s[k] = j[k] }
                root.st = s
            }
        }
        onExited: restart.start()
    }
    Timer { id: restart; interval: 3000; onTriggered: backend.running = true }
    Connections {
        target: Signals
        function onRefresh(n) { if (["wifi", "bt", "vpn", "ppd", "caffeine"].indexOf(n) >= 0) root.refresh(n) }
    }
    function refresh(key) { if (backend.running) backend.write("refresh " + key + "\n") }

    function run(cmd) {
        if (dry) { console.log("[dry]", cmd.join(" ")); return }
        Quickshell.execDetached(cmd)
    }
    function state(key) { return key === "mic" ? !Audio.micMuted : (st[key] && st[key].on) === true }
    function sub(key) { return key === "mic" ? (Audio.micMuted ? "Выключен" : "Включён") : (st[key] ? st[key].sub : "…") }
    // переключить плитку: yumi-cc <key> toggle, мгновенный отклик, потом настоящее состояние (VPN подключается дольше)
    function toggle(key) {
        run([bin + "yumi-cc", key, "toggle"])
        if (key === "mic") return
        const s = Object.assign({}, st); s[key] = { on: !state(key), sub: "…" }; st = s
        const b = Object.assign({}, busy); b[key] = Date.now() + 600; if (key === "saver") b.ppd = b[key]; busy = b
        later1.key = key; later1.restart(); later2.key = key; later2.restart(); later3.key = key; later3.restart()
    }
    Timer { id: later1; property string key; interval: 700;  onTriggered: root.refresh(key) }
    Timer { id: later2; property string key; interval: 1800; onTriggered: root.refresh(key) }
    Timer { id: later3; property string key; interval: 4000; onTriggered: root.refresh(key) }
    function menu(name) { if (name) Menus.open(name, true) }   // любое меню — по центру, как по бинду; Menus сам закрывает центр
    function setProfile(name) {
        if (name === (st.ppd || "balanced")) return
        run([Quickshell.env("HOME") + "/.local/bin/yumi-power-profile", "set", name])   // 29.10: частота ЦП вместо powerprofilesctl
        const s = Object.assign({}, st); s.ppd = name; s.saver = { on: name === "power-saver", sub: name === "power-saver" ? "Включена" : "Выключена" }; st = s
        const b = Object.assign({}, busy); b.ppd = b.saver = Date.now() + 600; busy = b
        later1.key = "ppd"; later1.restart()
    }

    // --- шапка: дата, время, батарея ---
    readonly property var days: ["Воскресенье", "Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота"]
    readonly property var months: ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"]
    property string subtitle: ""
    function tick() { const d = new Date(); subtitle = days[d.getDay()] + ", " + d.getDate() + " " + months[d.getMonth()] + " · " + Qt.formatTime(d, "HH:mm") }
    Timer { interval: 15000; repeat: true; running: root.open; triggeredOnStart: true; onTriggered: root.tick() }
    readonly property var bat: UPower.displayDevice
    readonly property bool charging: bat && (bat.state === UPowerDeviceState.Charging || bat.state === UPowerDeviceState.FullyCharged || bat.state === UPowerDeviceState.PendingCharge)

    // --- содержимое ---
    readonly property var tiles: [
        { key: "wifi",     on: "󰖩", off: "󰖪", title: "Wi-Fi",     menu: "wifi" },
        { key: "bt",       on: "󰂯", off: "󰂲", title: "Bluetooth", menu: "bluetooth" },
        { key: "vpn",      on: "󰖂", off: "󰖂", title: "VPN",       menu: "vpn" },
        { key: "mic",      on: "󰍬", off: "󰍭", title: "Микрофон",  menu: "sound" },
        { key: "saver",    on: "󰌪", off: "󰌪", title: "Экономия",  menu: "power" },
        { key: "caffeine", on: "󰅶", off: "󰾪", title: "Кофеин",    menu: "" }
    ]
    // плитки-ссылки: все меню оболочки (имя — как в Menus и биндах «menu center …»)
    readonly property var links: [
        { name: "wifi", icon: "󰖩", text: "Wi-Fi" },        { name: "bluetooth", icon: "󰂯", text: "Bluetooth" },
        { name: "vpn", icon: "󰖂", text: "VPN" },           { name: "sound", icon: "󰕾", text: "Звук" },
        { name: "power", icon: "󰁹", text: "Батарея" },     { name: "devices", icon: "󰍽", text: "Устройства" },
        { name: "top", icon: "󰍛", text: "Процессы" },      { name: "tray", icon: "󰀻", text: "Трей" },
        { name: "calendar", icon: "󰃭", text: "Календарь" },
        { name: "keys", icon: "󰌌", text: "Клавиши" },      { name: "system", icon: "yumi", text: "Система" },
        { name: "wallpaper", icon: "󰸉", text: "Обои" },    { name: "music", icon: "󰝚", text: "Музыка" },
        { name: "launcher", icon: "󰏗", text: "Программы" }, { name: "clipboard", icon: "󰅍", text: "Буфер" },
        { name: "workspaces", icon: "󰕰", text: "Столы" },  { name: "session", icon: "󰐥", text: "Сеанс" }
    ]
    readonly property int linkCols: 6
    property string hoverLink: ""
    readonly property string linkHint: {
        if (fid.startsWith("l:")) { const l = links.find(x => x.name === fid.slice(2)); if (l) return "· " + l.text }
        return hoverLink ? "· " + hoverLink : ""
    }
    readonly property var profiles: ["power-saver", "balanced"]   // 29.10: без PowerProfiles (yumi-power-profile)
    readonly property int notifCount: notifList.items.length

    // --- фокус клавиатуры: ряды фокусируемых элементов, f — положение по горизонтали (0..1) для ↑↓ ---
    readonly property var rows: {
        const r = [
            // «Остров»: плитки 2×3, затем громкость, яркость, плеер
            tiles.slice(0, 2).map((t, i) => ({ id: "t:" + t.key, f: (i + 0.5) / 2 })),
            tiles.slice(2, 4).map((t, i) => ({ id: "t:" + t.key, f: (i + 0.5) / 2 })),
            tiles.slice(4, 6).map((t, i) => ({ id: "t:" + t.key, f: (i + 0.5) / 2 })),
            [{ id: "vol", f: 0.5 }], [{ id: "bri", f: 0.5 }], [{ id: "kbd", f: 0.4 }, { id: "kbd-auto", f: 0.95 }],
            [{ id: "previous", f: 0.8 }, { id: "toggle", f: 0.88 }, { id: "next", f: 0.96 }],
            profiles.map((p, i) => ({ id: "p:" + p, f: (i + 0.5) / profiles.length }))
        ]
        for (let i = 0; i < links.length; i += linkCols)
            r.push(links.slice(i, i + linkCols).map((l, j) => ({ id: "l:" + l.name, f: (j + 0.5) / linkCols })))
        if (notifCount > 0) r.push([{ id: "n:clear", f: 0.75 }, { id: "n:all", f: 0.92 }])
        return r
    }
    property int fr: 0
    property int fc: 0
    property bool editing: false
    // автояркость клавиш MacBook (служба yumi-light): состояние читаем при открытии, клик по «авто» переключает
    property bool kbdAuto: false
    function kbdAutoCmd(args) {
        if (dry && args[0] !== "status") { console.log("[dry] yumi-light", args.join(" ")); return }
        kbdAutoProc.command = [Quickshell.env("HOME") + "/.local/bin/yumi-light"].concat(args)
        kbdAutoProc.running = true
    }
    Process {
        id: kbdAutoProc
        stdout: SplitParser { onRead: (line) => { try { root.kbdAuto = JSON.parse(line).auto === true } catch (e) {} } }
        onExited: Brightness.refresh()
    }
    readonly property string fid: rows[fr] && rows[fr][fc] ? rows[fr][fc].id : ""
    function is(id) { return root.open && fid === id }
    function focusOn(id) { for (let r = 0; r < rows.length; r++) for (let c = 0; c < rows[r].length; c++) if (rows[r][c].id === id) { fr = r; fc = c; return } }
    function vmove(d) {
        const r2 = fr + d
        if (r2 < 0 || r2 >= rows.length) return
        const f = rows[fr][fc].f
        let best = 0, dist = 9
        rows[r2].forEach((x, i) => { const dd = Math.abs(x.f - f); if (dd < dist) { dist = dd; best = i } })
        fr = r2; fc = best
    }
    function adjust(id, d) {
        if (id === "vol") Audio.setVolume(Math.max(0, Math.min(1, Audio.vol + d)))
        else if (id === "bri") Brightness.setScreen(Math.max(1, Math.min(100, (Brightness.screen >= 0 ? Brightness.screen : 50) + d * 100)))
        else if (id === "kbd") Brightness.setKbd(Math.max(0, Math.min(100, (Brightness.kbd >= 0 ? Brightness.kbd : 50) + d * 100)))
    }
    function act(id, alt) {
        const k = id.slice(2)
        if (id.startsWith("t:")) {
            const t = tiles.find(x => x.key === k)
            if (alt && t.menu) menu(t.menu); else toggle(k)
        }
        else if (id === "kbd") editing = !editing
        else if (id === "kbd-auto") kbdAutoCmd(["auto", "toggle"])
        else if (id === "bri" || id === "vol") { if (alt) menu(id === "vol" ? "sound" : "power"); else editing = !editing }
        else if (id === "previous" || id === "next" || id === "toggle") {
            if (dry) { console.log("[dry] плеер:", id); return }        // сервис Player YP_DRYRUN не соблюдает — здесь сами
            if (id === "previous") Player.previous(); else if (id === "next") Player.next(); else Player.togglePlaying()
        }
        else if (id.startsWith("p:")) setProfile(k)
        else if (id.startsWith("l:")) menu(k)
        else if (id === "n:clear") Notifs.closeAll()
        else if (id === "n:all") { Menus.close("control"); Quickshell.execDetached(["qs", "-c", "yumi", "ipc", "call", "notif", "toggle"]) }
    }
    function key(k) {
        if (!rows.length) return
        fr = Math.min(fr, rows.length - 1); fc = Math.min(fc, rows[fr].length - 1)
        if (editing) {
            if (k === "up" || k === "right") adjust(fid, 0.05)
            else if (k === "down" || k === "left") adjust(fid, -0.05)
            else if (k === "enter" || k === "esc" || k === "space") editing = false
            return
        }
        if (k === "left") fc = Math.max(0, fc - 1)
        else if (k === "right") fc = Math.min(rows[fr].length - 1, fc + 1)
        else if (k === "up") vmove(-1)
        else if (k === "down") vmove(1)
        else if (k === "enter" || k === "space") act(fid, false)
        else if (k === "alt") act(fid, true)
        else if (k === "esc") Menus.close("control")
    }
    onFidChanged: editing = false

    // ---- окно ----
    PanelWindow {
        id: win
        screen: Menus.screen
        visible: root.open || closer.running
        color: "transparent"
        WlrLayershell.namespace: "yumi-qs-control"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: root.open && Quickshell.env("YUMI_QS_NOKB") !== "1" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: true; right: true }

        readonly property int topY: Theme.barH + 6 + (Theme.dev ? Theme.barH : 0)
        Timer { id: closer; interval: Theme.slow }
        // 29.10: обновление яркости и состояний плиток — когда карточка уже выросла (запуск процесса в потоке GUI
        // во время роста давал кадры по 50–90 мс)
        Timer { id: afterOpen; interval: Theme.menuOpen + 40; onTriggered: if (root.open) { Brightness.refresh(); root.kbdAutoCmd(["status"]); root.refresh("all") } }
        Timer { id: grace; interval: 400 }                 // первые 0,4 с мышь не закрывает (окно только встало на экран)
        readonly property bool settled: root.open && !grace.running

        Connections {
            target: root
            function onOpenChanged() {
                OsdState.suppressed = root.open
                far.reset()
                if (root.open) {
                    grace.restart(); closer.stop()
                    root.fr = 0; root.fc = 0; root.editing = false
                    afterOpen.restart()                 // процессы (fork большого qs) — после роста, не во время анимации
                    scope.forceActiveFocus()
                } else { scope.focus = false; closer.restart() }
            }
        }
        FarWatch { id: far; enabled: win.settled; onFar: Menus.close("control") }
        // проба плавности (YUMI_QS_PROBE=1): интервалы показанных кадров окна центра >25 мс — в журнал
        property real probeT0: 0
        property real probeLast: 0
        Connections {
            target: Quickshell.env("YUMI_QS_PROBE") === "1" ? win : null
            function onVisibleChanged() { win.probeLast = 0; win.probeT0 = Date.now() }
        }
        Connections {
            target: Quickshell.env("YUMI_QS_PROBE") === "1" ? scope.Window.window : null
            ignoreUnknownSignals: true
            function onFrameSwapped() { const n = Date.now(); if (win.probeLast && n - win.probeLast > 25) console.log("probe: swap gap " + (n - win.probeLast) + " ms at t=" + (n - win.probeT0)); win.probeLast = n }
        }

        FocusScope {
            id: scope
            anchors.fill: parent
            focus: root.open
            Keys.onPressed: (e) => {
                const shift = e.modifiers & Qt.ShiftModifier
                const m = { [Qt.Key_Up]: "up", [Qt.Key_Down]: "down", [Qt.Key_Left]: "left", [Qt.Key_Right]: "right",
                            [Qt.Key_Return]: shift ? "alt" : "enter", [Qt.Key_Enter]: shift ? "alt" : "enter",
                            [Qt.Key_Period]: "alt", [Qt.Key_Menu]: "alt", [Qt.Key_Space]: "space", [Qt.Key_Escape]: "esc" }[e.key]
                if (m) { root.key(m); e.accepted = true }
            }

            // поле вокруг карточки: клик — закрыть, движение — правило «курсор ушёл далеко»
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                hoverEnabled: true
                onPressed: if (win.settled) Menus.close("control")
                onPositionChanged: (m) => { far.rect = Qt.rect(card.x, card.y, card.width, card.height); far.track(m.x, m.y) }
                onExited: far.reset()
            }

            Rectangle {
                id: card
                readonly property int pad: 18
                width: 400
                x: win.width - width - Theme.screenPad - 20
                y: win.topY + 20
                height: Math.min(col.implicitHeight + pad * 2, win.height - y - Theme.screenPad)
                radius: Theme.radiusBig
                color: Colors.isl                                  // «Остров»: сплошной остров в оттенке обоев
                border.width: 1; border.color: Colors.edge
                Behavior on color { ColorAnimation { duration: Theme.normal } }
                transformOrigin: Item.TopRight
                // «Остров»: вырастает из правого верхнего угла пружиной (OutBack 480 мс), закрытие — быстро внутрь
                property real grow: root.open ? 1 : 0
                Behavior on grow { NumberAnimation { duration: root.open ? Theme.menuOpen : Theme.fast
                                                     easing.type: root.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 0.8 } }
                opacity: Math.min(1, grow * 2.5)
                scale: 0.6 + 0.4 * grow
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; hoverEnabled: true; onEntered: far.reset() }

                Flickable {
                    id: flick
                    anchors.fill: parent; anchors.margins: card.pad
                    contentHeight: col.implicitHeight
                    opacity: root.open ? 1 : 0                 // содержимое проявляется после начала роста
                    Behavior on opacity { SequentialAnimation {
                        PauseAnimation { duration: root.open ? Theme.contentDelay : 0 }
                        NumberAnimation { duration: root.open ? 260 : 120; easing.type: Easing.OutCubic } } }
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: col
                        width: flick.width
                        spacing: 12

                        // шапка: «Центр управления», дата · время · заряд, справа печать 弓
                        CardHead {
                            title: "Центр управления"
                            status: root.subtitle + (root.bat !== null ? " · " + (root.charging ? "󰂄 " : "") + Math.round(root.bat.percentage * 100) + "%" : "")
                            YumiMark { size: 28 }
                        }

                        // плитки 2×3: клик — вкл/выкл, удержание / правый клик — меню раздела
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2; columnSpacing: 8; rowSpacing: 8
                            Repeater {
                                model: root.tiles
                                delegate: ITile {
                                    id: tl
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    icon: modelData.on; iconOff: modelData.off; title: modelData.title
                                    hasMenu: modelData.menu.length > 0
                                    on: root.state(modelData.key)
                                    sub: root.sub(modelData.key)
                                    kb: root.is("t:" + modelData.key)
                                    onToggled: { root.focusOn("t:" + modelData.key); root.toggle(modelData.key) }
                                    onMenuRequested: root.menu(modelData.menu)
                                    // каскад: opacity + y 8 px по 40 мс
                                    opacity: root.open ? 1 : 0
                                    property real dy: root.open ? 0 : 8
                                    transform: Translate { y: tl.dy }
                                    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: root.open ? index * 30 : 0 } NumberAnimation { duration: 200; easing.type: Easing.OutCubic } } }
                                    Behavior on dy { SequentialAnimation { PauseAnimation { duration: root.open ? index * 30 : 0 } NumberAnimation { duration: 200; easing.type: Easing.OutCubic } } }
                                }
                            }
                        }

                        // ползунки-капсулы (значок внутри) + мини-плеер
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            HSlider {
                                Layout.fillWidth: true
                                icon: Audio.muted ? "󰝟" : "󰕾"
                                kb: root.is("vol"); editing: root.editing && root.is("vol")
                                value: Audio.vol
                                onMoved: (v) => Audio.setVolume(v)
                            }
                            HSlider {
                                Layout.fillWidth: true
                                icon: "󰃠"; minimum: 0.01
                                kb: root.is("bri"); editing: root.editing && root.is("bri")
                                value: Brightness.screen >= 0 ? Brightness.screen / 100 : 0
                                onMoved: (v) => Brightness.setScreen(v * 100)
                            }
                            RowLayout {   // подсветка клавиш MacBook (kbd_backlight); 0 = выключена; «авто» — по датчику света (yumi-light)
                                Layout.fillWidth: true
                                spacing: 8
                                HSlider {
                                    Layout.fillWidth: true
                                    icon: "󰌌"
                                    kb: root.is("kbd"); editing: root.editing && root.is("kbd")
                                    value: Brightness.kbd >= 0 ? Brightness.kbd / 100 : 0
                                    onMoved: (v) => Brightness.setKbd(v * 100)
                                }
                                Chip {
                                    label: "авто"
                                    ink: root.kbdAuto ? Colors.acc : Qt.alpha(Colors.fg, 0.45)
                                    kb: root.is("kbd-auto")
                                    onClicked: root.kbdAutoCmd(["auto", "toggle"])
                                }
                            }
                        }
                        PlayerCard {
                            Layout.fillWidth: true
                            kb: ["previous", "toggle", "next"].indexOf(root.fid) >= 0 && root.open ? root.fid : ""
                        }

                        // профиль питания
                        ProfileSeg {
                            Layout.fillWidth: true
                            current: root.st.ppd || "balanced"
                            kb: root.fid.startsWith("p:") && root.open ? root.fid.slice(2) : ""
                            onPicked: (name) => root.setProfile(name)
                        }

                        // все меню — капсулы-значки 6 в ряд (как ряд кнопок превью); имя — в подписи раздела при наведении/фокусе
                        RowLayout {
                            Layout.fillWidth: true; Layout.topMargin: 2
                            ISection { Layout.topMargin: 0; Layout.fillWidth: false; text: "Меню" }
                            Text {
                                Layout.fillWidth: true
                                text: root.linkHint; elide: Text.ElideRight
                                font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.Medium
                                font.capitalization: Font.AllUppercase; font.letterSpacing: 1; color: Colors.acc
                            }
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: root.linkCols; columnSpacing: 6; rowSpacing: 6
                            Repeater {
                                model: root.links
                                delegate: Rectangle {
                                    id: lk
                                    required property var modelData
                                    required property int index
                                    readonly property bool focused: root.is("l:" + modelData.name)
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    implicitHeight: 40
                                    radius: Theme.radius
                                    color: lma.containsMouse ? Colors.hover : Colors.isl2
                                    border.width: focused ? 1.5 : 0; border.color: Colors.acc
                                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                                    scale: lma.pressed ? 0.94 : 1
                                    Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
                                    Glyph { visible: lk.modelData.icon !== "yumi"; anchors.centerIn: parent; text: lk.modelData.icon; font.pixelSize: 17
                                            color: lk.focused ? Colors.acc : Colors.fg }
                                    YumiMark { visible: lk.modelData.icon === "yumi"; anchors.centerIn: parent; size: 18 }
                                    MouseArea { id: lma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.menu(lk.modelData.name)
                                                onContainsMouseChanged: root.hoverLink = containsMouse ? lk.modelData.text : (root.hoverLink === lk.modelData.text ? "" : root.hoverLink) }
                                }
                            }
                        }

                        // уведомления
                        NotifList {
                            id: notifList
                            Layout.fillWidth: true; Layout.topMargin: 2
                            max: 2
                            shown: root.open
                            kb: root.fid.startsWith("n:") && root.open ? root.fid.slice(2) : ""
                            onOpenAll: { Menus.close("control"); Quickshell.execDetached(["qs", "-c", "yumi", "ipc", "call", "notif", "toggle"]) }
                        }

                        // подвал — подсказки клавиш капсулами
                        MFooter {
                            hints: root.editing ? [["↑↓", "значение"], ["Enter / Esc", "готово"]]
                                 : [["←→↑↓", "плитки"], ["Enter", "нажать"], ["⇧ Enter", "подробно"], ["Esc", ""]]
                        }
                    }
                }
            }
        }
    }
}
