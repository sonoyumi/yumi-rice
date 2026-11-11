import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components
import qs.services
import qs.menus.wifi
import qs.menus.power
import qs.menus.top
import "../top/Dash.js" as Dash

// Меню «Система» (печать 弓 в баре, SUPER+`). «Остров» (29.10): во весь экран поверх приглушённых обоев — остров по центру:
// шапка (печать YumiMark 48, «Yumi-Rice», строка ОС/ядра/сети), справа быстрые переходы (оформление O, инструменты I,
// клавиши K, батарея B, btop, Arch Wiki); ниже ряд из семи плиток-показателей (обновления, снимки btrfs, доктор, процессор,
// память, свободно на /, температура), под ним подробности выбранного (списки, графики, кнопки).
// Прежний вид «Сис A» (линейка на черте, засечки) — в git до тега pre-island-20261029.
// Датчики и действия — как раньше: обновления (кеш yumi-update; список пакетов — по Enter), снимки (snapper), доктор
// (yumi-doctor), процессор/память/температура с живыми графиками (данные «Процессов», только пока меню открыто), диск.
// Клавиши: ←→ — показатель (справа его подробности), ↑↓ — прокрутка подробностей, Enter (или клик) — «подробнее»:
//   фокус уходит в подробности — ←→ кнопка (у оформления/инструментов ↑↓ — выбор), ↑↓ прокрутка, Enter — нажать, Esc — назад.
//   Esc в ряду плиток — закрыть. Клик мимо острова — закрыть.
// Логика — бэкенд ~/.local/lib/yumi/qs/system (SysData.qml). Открыть/закрыть: qs -c yumi ipc call menu toggle system.
// Проверка: YP_DRYRUN=1 — команды только пишутся (обновить, снимок, doctor --fix, запуск программ); YP_SYS_PAGE=updates|snapshots|doctor;
//   qs … ipc call sysmenu page <имя> | act <ключ> (update, snapshot, wallpaper, waybar, accent, btop, wiki, keys, doctor-fix, doctor-term)
//   | key left|right|up|down|enter|esc|look|tools|keys|bat | state
Scope {
    id: menu
    readonly property bool open: Menus.current === "system"
    property string toastText: ""
    property bool toastError: false
    property string dryText: ""
    readonly property var mgrName: ({ pacman: "pacman", paru: "AUR", yay: "AUR", flatpak: "flatpak" })
    readonly property var docIcon: ({ ok: "󰗠", info: "󰋼", warn: "󰀪", fail: "󰅙", run: "󰔟" })
    readonly property var docTitle: ({ ok: "Всё хорошо", warn: "Есть предупреждения", fail: "Есть проблемы" })
    function plural(n, one, few, many) { return Dash.plural(n, one, few, many) }
    function clean(s) { return String(s || "").replace(/\u001b\[[0-9;]*[A-Za-z]/g, "").replace(/\[[0-9;]*m/g, "") }   // коды цвета терминала из журнала
    function hhmm(t) { return Qt.formatTime(new Date((t || Date.now() / 1000) * 1000), "HH:mm") }
    function comma(s) { return String(s).replace(".", ",") }
    function chargeTone(p) {
        const k = Math.max(0, Math.min(1, p / 100)), a = Qt.color(Colors.bad), b = Qt.color(Colors.ok)
        return Qt.hsla(k * 120 / 360, a.hslSaturation + (b.hslSaturation - a.hslSaturation) * k, a.hslLightness + (b.hslLightness - a.hslLightness) * k, 1)
    }

    // ---- шапка: «имя · ядро · в сети» из бэкенда ----
    readonly property var subParts: (sys.subtitle || "").split(" · ")
    readonly property string hostName: subParts[0] || "Yumi-Rice"
    readonly property string hostInfo: ["Yumi-Rice"].concat(subParts.slice(1)).join(" · ")
                                       + (sys.stats && sys.stats.bat && sys.stats.bat.text ? " · батарея " + sys.stats.bat.text : "")

    // ---- обновления ----
    readonly property int updTotal: sys.recs ? sys.recs.reduce((a, r) => a + r[1], 0) : 0
    readonly property string updTitle: !sys.recs ? "Нет данных" : updTotal === 0 ? "Система обновлена" : plural(updTotal, "обновление", "обновления", "обновлений") + " доступно"
    readonly property string updSub: !sys.recs ? "нажмите, чтобы проверить" : (sys.recs.map(r => (mgrName[r[0]] || r[0]) + " " + r[1]).join(" · ") || "менеджеров нет")
    readonly property var updSections: {
        if (!sys.updList) return []
        const out = []
        for (const name in sys.updList) { const p = sys.updList[name]; if (p.length) out.push({ title: (mgrName[name] || name) + " · " + p.length, pkgs: p }) }
        return out
    }
    readonly property int updListTotal: sys.updList ? Object.values(sys.updList).reduce((a, v) => a + v.length, 0) : 0

    // ---- снимки ----
    readonly property var snapCfgs: [{ cfg: "root", title: "Система  /" }, { cfg: "home", title: "Домашняя папка  /home" }]
    readonly property int snapTotal: sys.snaps ? Object.values(sys.snaps).reduce((a, v) => a + v.length, 0) : 0
    readonly property string snapWord: plural(snapTotal, "снимок", "снимка", "снимков")
    readonly property string snapTotalText: {
        if (!sys.snaps) return ""
        const cfgs = Object.keys(sys.snaps).sort((a, b) => (a !== "root") - (b !== "root"))
        return cfgs.map(c => (c === "root" ? "/" : c) + " " + sys.snaps[c].length).join(" · ")
    }
    readonly property var snapLast: {
        const s = sys.snaps
        if (!s) return null
        return (s.root && s.root[0]) || (s.home && s.home[0]) || null
    }

    // ---- доктор ----
    readonly property string docStatus: sys.doc ? (sys.doc.status || "fail") : ""
    readonly property string docRowIcon: !sys.doc || sys.docStale ? docIcon.run : (docIcon[docStatus] || docIcon.fail)
    readonly property color docTone: !sys.doc || sys.docStale ? Colors.alpha(Colors.fg, 0.6)
        : docStatus === "ok" ? Colors.ok : docStatus === "warn" ? Colors.warn : docStatus === "fail" ? Colors.bad : Colors.alpha(Colors.fg, 0.6)
    readonly property string docShort: !sys.doc ? "проверяю…" : (sys.doc.summary || docTitle[docStatus] || "?")
    readonly property string docRowSub: {
        if (!sys.doc) return "службы, конфиг, цвета, обои, диск, снимки"
        const checks = sys.doc.checks || []
        const bits = checks.length ? [checks.length + " " + plural(checks.length, "проверка", "проверки", "проверок")] : []
        const bad = checks.filter(c => c.status === "warn" || c.status === "fail").map(c => c.title)
        if (bad.length) bits.push(bad.join(", ")); else if (sys.doc.error) bits.push(sys.doc.error)
        bits.push(sys.docStale ? "проверяю… (прошлая в " + hhmm(sys.doc.time) + ")" : "в " + hhmm(sys.doc.time))
        return bits.join(" · ")
    }
    readonly property var docChecks: {
        const order = { fail: 0, warn: 1, info: 2, ok: 3 }
        return ((sys.doc && sys.doc.checks) || []).slice().sort((a, b) => (a.status in order ? order[a.status] : 9) - (b.status in order ? order[b.status] : 9))
    }
    readonly property int docFixable: (sys.doc && sys.doc.fixable) || 0

    // ---- диск: «47 из 122 ГБ» → 47 / из 122 ГБ ----
    readonly property var diskParts: {
        const t = sys.stats && sys.stats.disk ? String(sys.stats.disk.text || "") : ""
        const m = t.match(/^(\S+)\s+из\s+(.+)$/)
        return m ? [m[1], "из " + m[2]] : [t || "…", ""]
    }

    // ---- горячие клавиши: новая схема (16.10) ----
    readonly property var keyScheme: [
        ["SUPER+Space", "Пульт — поиск всего"], ["SUPER+A", "Программы"], ["SUPER+SHIFT+E", "Файлы"], ["SUPER+V", "Буфер обмена"],
        ["SUPER+TAB", "Рабочие столы (и свайп 3 пальцами вниз)"], ["SUPER+SHIFT+W", "Обои"], ["SUPER+SHIFT+M", "Музыка"], ["SUPER+M", "Плеер"],
        ["SUPER+`", "Система (это меню)"], ["SUPER+Escape", "Питание системы"],
        ["SUPER+C", "Центр управления"],
        ["SUPER+CTRL+W", "Wi-Fi"], ["SUPER+CTRL+B", "Bluetooth"], ["SUPER+CTRL+V", "VPN"], ["SUPER+CTRL+A", "Звук"],
        ["SUPER+CTRL+E", "Батарея и питание"], ["SUPER+CTRL+T", "Процессы"], ["SUPER+CTRL+Y", "Трей"],
        ["SUPER+CTRL+C", "Календарь"], ["SUPER+CTRL+K", "Горячие клавиши"], ["SUPER+CTRL+N", "Центр уведомлений"],
        ["SUPER+P", "Снимок области"], ["SUPER+ALT+P", "Заморозить экран и вырезать"], ["SUPER+SHIFT+P", "Снимок монитора"],
        ["SUPER+CTRL+SHIFT+P", "Пипетка цвета"], ["SUPER+ALT+Space", "Плей / пауза"], ["SUPER+ALT+,  /  .", "Предыдущий / следующий трек"],
        ["SUPER+SHIFT+C", "Текстовый редактор"] ]

    SysData {
        id: sys
        wanted: menu.open
        onToast: (text, error, hold) => { menu.toastText = text; menu.toastError = error; toastTimer.interval = hold * 1000; toastTimer.restart() }
        onDryText: text => menu.dryText = text
        onLaunched: key => Menus.close("system")
    }
    Timer { id: toastTimer; interval: 3000; onTriggered: menu.toastText = "" }

    // живые графики: процессор, память, температура — данные «Процессов» (бэкенд top), точка раз в 2 с, только пока открыто
    TopData { id: td; active: menu.open; maxRows: 0 }

    // ---- память подробно (раскрытие плитки «Память»): /proc/meminfo, zram — раз в 2 с, только пока открыта эта страница ----
    property var mem: ({})                 // кБ: MemTotal, MemAvailable, Buffers, Cached, SReclaimable, Shmem, SwapTotal, SwapFree
    property var zram: null                // {orig, compr, used, disk} байт, alg
    property string earlyoom: ""           // «работает» / «выключен» (systemctl is-active, раз при открытии страницы)
    FileView { id: meminfo; path: "/proc/meminfo"; printErrors: false }
    FileView { id: zramStat; path: "/sys/block/zram0/mm_stat"; printErrors: false }
    FileView { id: zramSize; path: "/sys/block/zram0/disksize"; printErrors: false }
    FileView { id: zramAlg; path: "/sys/block/zram0/comp_algorithm"; printErrors: false }
    function readMem() {
        meminfo.reload(); zramStat.reload(); zramSize.reload()
        const m = {}
        for (const l of String(meminfo.text() || "").split("\n")) { const r = /^(\w+):\s+(\d+)/.exec(l); if (r) m[r[1]] = parseInt(r[2]) }
        mem = m
        const z = String(zramStat.text() || "").trim().split(/\s+/).map(Number)
        if (z.length >= 3 && !isNaN(z[0])) {
            zramAlg.reload()
            const alg = (/\[(\w+)\]/.exec(String(zramAlg.text() || "")) || [])[1] || ""
            zram = { orig: z[0], compr: z[1], used: z[2], disk: parseInt(String(zramSize.text() || "0")) || 0, alg: alg }
        } else zram = null
    }
    readonly property bool memPage: open && skey === "mem"
    Timer { interval: 2000; repeat: true; running: menu.memPage; triggeredOnStart: true; onTriggered: menu.readMem() }
    Process {
        id: oomProc
        command: ["sh", "-c", "systemctl is-active earlyoom 2>/dev/null; systemctl --user is-active earlyoom 2>/dev/null; true"]
        stdout: StdioCollector { onStreamFinished: menu.earlyoom = text.split("\n").some(l => l.trim() === "active") ? "работает" : "выключен" }
    }
    onMemPageChanged: if (memPage && !oomProc.running) oomProc.running = true
    function gb(kb) { return comma((kb / 1048576).toFixed(1)) + " ГБ" }
    function gbB(b) { return comma((b / 1073741824).toFixed(1)) + " ГБ" }
    property var cpuHist: []
    property var ramHist: []
    property var tempHist: []
    function sampleNow() {
        if (!td.ready) return
        cpuHist = Dash.push(cpuHist, td.cpu); ramHist = Dash.push(ramHist, td.ram)
        if (td.temp) tempHist = Dash.push(tempHist, td.temp[0])
    }
    Connections { target: td; function onSample(cpu, ram) { if (!menu.cpuHist.length) menu.sampleNow() } }
    Timer { interval: 2000; repeat: true; running: menu.open; onTriggered: menu.sampleNow() }

    onOpenChanged: {
        if (open) {
            closer.stop()
            if (sys.loaded) sys.refresh()
            cpuHist = []; ramHist = []; tempHist = []
            zoom = -1; sel = 0; lastRuler = 0; zsel = 0
            scope.forceActiveFocus()
            const p = Quickshell.env("YP_SYS_PAGE"); if (p) pageTimer.restart()
        } else {
            scope.focus = false                     // снять фокус до скрытия — иначе Qt падает, уничтожая элемент с фокусом
            zoom = -1; dryText = ""; toastText = ""
            closer.restart()
        }
    }
    Timer { id: pageTimer; interval: 300; onTriggered: menu.openPage(Quickshell.env("YP_SYS_PAGE")) }
    Timer { id: closer; interval: Theme.normal }

    // ---- показатели ----
    // первые семь — линейка на черте; остальные открываются клавишами O / I / K / B и ссылками внизу справа
    readonly property var tiles: [
        { key: "upd",   title: "Обновления" },
        { key: "snap",  title: "Снимки btrfs" },
        { key: "doc",   title: "Доктор" },
        { key: "cpu",   title: "Процессор" },
        { key: "mem",   title: "Память" },
        { key: "disk",  title: "Свободно /" },
        { key: "temp",  title: "Температура" },
        { key: "look",  title: "Оформление" },
        { key: "tools", title: "Инструменты" },
        { key: "keys",  title: "Горячие клавиши" },
        { key: "bat",   title: "Батарея" } ]
    readonly property int rulerN: 7
    property int sel: 0                    // что раскрыто справа
    property int lastRuler: 0              // последний выбранный на линейке (куда вернуться с O/I/K/B)
    property int zoom: -1                  // >=0 — «подробнее»: клавиши у подробностей
    property int zsel: 0                   // кнопка/пункт внутри подробностей
    readonly property string skey: tiles[sel].key
    readonly property string zkey: zoom >= 0 ? tiles[zoom].key : ""
    function tileIdx(k) { return tiles.findIndex(t => t.key === k) }

    // кнопки подробностей: [{t, act, primary, active}]
    readonly property var zbtns: {
        switch (skey) {
        case "upd":   return [{ t: "󰚰  Обновить систему", act: "update", primary: true, active: true }]
        case "snap":  return [{ t: "󰄄  Сделать снимок сейчас", act: "snapshot", primary: true, active: !sys.snapping }]
        case "doc":   return [{ t: "󰁨  Починить", act: "doctor-fix", primary: true, active: docFixable > 0 && !sys.docRunning },
                              { t: "󰆍  В терминале", act: "doctor-term", active: true }]
        case "cpu":   return [{ t: "󰍛  Процессы…", act: "top", primary: true, active: true }, { t: "󰄨  btop", act: "btop", active: true }]
        case "look":  return [{ t: "󰸉  Обои", act: "wallpaper", active: true }, { t: "󰑓  Перезапустить бар", act: "waybar", active: true },
                              { t: "󰏘  Пересчитать цвета", act: "accent", active: true }]
        case "tools": return [{ t: "󰄨  Монитор btop", act: "btop", active: true }, { t: "󰖟  Arch Wiki", act: "wiki", active: true },
                              { t: "󰌌  Горячие клавиши", act: "keys", active: true }]
        case "keys":  return [{ t: "󰌌  Все горячие клавиши…", act: "keys", primary: true, active: true }]
        default:      return []
        }
    }
    readonly property bool vertBtns: skey === "look" || skey === "tools"     // список действий — ↑↓
    readonly property bool scrolls: skey === "upd" || skey === "snap" || skey === "doc" || skey === "keys" || skey === "mem"

    // подпись над подробностями
    readonly property string sideTitle: {
        switch (skey) {
        case "upd":  return "Обновления · " + (sys.updList ? updListTotal + " " + plural(updListTotal, "пакет", "пакета", "пакетов")
                                                            : !sys.recs ? "нет данных" : updTotal ? updTotal + " " + plural(updTotal, "пакет", "пакета", "пакетов") : "всё обновлено")
        case "snap": return "Снимки btrfs · " + (sys.snaps === null ? "загружаю" : snapTotal + " " + snapWord)
        case "doc":  return "Доктор · " + docShort
        case "cpu":  return "Процессор · " + (td.ready ? Math.round(td.cpu) + " % сейчас" : "…")
        case "mem":  return "Память · " + (td.ready ? Math.round(td.ram) + " % занято" : "…")
        case "disk": return "Диск · свободно на /"
        case "temp": return "Температура · " + (td.temp ? td.temp[1] || "датчик" : "нет датчиков")
        default:     return tiles[sel].title
        }
    }

    function openPage(name) {
        if (name === "updates") openZoom(tileIdx("upd"))
        else if (name === "snapshots") openZoom(tileIdx("snap"))
        else if (name === "doctor") openZoom(tileIdx("doc"))
        else back()
    }
    function select(i) {
        if (i < 0) return
        sel = i; zoom = -1; zsel = 0
        if (i < rulerN) lastRuler = i
    }
    function openZoom(i) {
        if (i < 0) return
        select(i); zoom = i
        zsel = Math.max(0, zbtns.findIndex(b => b.active))     // фокус — на первую доступную кнопку («Починить» бывает неактивной)
        if (tiles[i].key === "upd") sys.listUpdates()
    }
    function back() { zoom = -1; if (sel >= rulerN) sel = lastRuler }
    function act(key) {
        if (key === "snapshot") sys.snapshot()
        else if (key === "doctor-fix") sys.doctor(true)
        else if (key === "doctor-term") sys.doctorTerminal()
        else if (key === "keys") Menus.toggleCenter("keys")   // «Горячие клавиши» — меню QML (menus/keys) по центру
        else if (key === "top") Menus.open("top")             // «Процессы» — своя панель (закрывает эту)
        else sys.launch(key)
    }
    function press(b) { if (b && b.active) act(b.act) }
    function scrollBy(d) { const f = scrollFlick; if (f) f.contentY = Math.max(0, Math.min(Math.max(0, f.contentHeight - f.height), f.contentY + d)) }
    property Flickable scrollFlick: null

    function key(k) {
        if (k === "look" || k === "tools" || k === "keys" || k === "bat") { openZoom(tileIdx(k)); return }
        if (zoom < 0) {
            if (k === "esc") { if (sel >= rulerN) back(); else Menus.close("system") }
            else if (k === "enter" || k === "space") openZoom(sel)
            else if (k === "left") select(Math.max(0, (sel < rulerN ? sel : lastRuler) - 1))
            else if (k === "right") select(Math.min(rulerN - 1, (sel < rulerN ? sel : lastRuler) + 1))
            else if (k === "up") scrollBy(-60)
            else if (k === "down") scrollBy(60)
            return
        }
        const n = zbtns.length
        if (k === "esc") { back(); return }
        if (k === "enter" || k === "space") { if (n) press(zbtns[Math.min(zsel, n - 1)]); else back(); return }
        if (vertBtns) {
            if (k === "up" || k === "left") zsel = Math.max(0, zsel - 1)
            else if (k === "down" || k === "right") zsel = Math.min(n - 1, zsel + 1)
            return
        }
        if (k === "left") zsel = Math.max(0, zsel - 1)
        else if (k === "right") zsel = Math.min(Math.max(0, n - 1), zsel + 1)
        else if (k === "up") scrollBy(-60)
        else if (k === "down") scrollBy(60)
    }

    IpcHandler {
        target: "sysmenu"
        function page(name: string): void { menu.openPage(name) }
        // прежде — открыть под значком обновлений с центром x; во весь экран место не нужно — просто открыть/закрыть
        function toggleAt(x: int): void { Menus.toggle("system") }
        function act(key: string): void { menu.act(key) }
        function key(name: string): void { menu.key(name) }
        function state(): string {
            return JSON.stringify({ open: menu.open, sel: menu.skey, zoom: menu.zkey, zsel: menu.zsel,
                                    btns: menu.zbtns.map(b => b.act), upd: menu.updTotal, snaps: menu.snapTotal, doc: menu.docStatus,
                                    cpu: Math.round(td.cpu), hist: menu.cpuHist.length, dry: menu.dryText, toast: menu.toastText })
        }
    }

    // ================= окно во весь экран =================
    PanelWindow {
        id: win
        screen: Menus.screen
        visible: menu.open || closer.running
        color: "transparent"
        WlrLayershell.namespace: "yumi-wall-system"     // как у обоев W2: правило yumi_wall_fade (затухание, без размытия)
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: menu.open && Quickshell.env("YUMI_QS_NOKB") !== "1" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None   // YUMI_QS_NOKB=1 — проверка без захвата клавиатуры
        anchors { top: true; bottom: true; left: true; right: true }
        function cardRect() { return Qt.rect(card.x, card.y, card.width, card.height) }
        Component.onCompleted: Menus.cards["system"] = win                                  // для проверки: qs … ipc call menu rect
        readonly property real dpr: screen ? screen.devicePixelRatio : 1

        FocusScope {
            id: scope
            anchors.fill: parent
            focus: menu.open
            opacity: menu.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: menu.open ? Theme.normal : Theme.fast; easing.type: Easing.OutCubic } }
            Keys.onPressed: (e) => {
                const m = { [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Up]: "up", [Qt.Key_Down]: "down",
                            [Qt.Key_Return]: "enter", [Qt.Key_Enter]: "enter", [Qt.Key_Space]: "space", [Qt.Key_Escape]: "esc",
                            [Qt.Key_O]: "look", [Qt.Key_I]: "tools", [Qt.Key_K]: "keys", [Qt.Key_B]: "bat" }[Latin.key(e)]   // 29.10: Latin.key — O/I/K/B и на русской раскладке
                if (!m) return
                menu.key(m); e.accepted = true
            }

            // ---- фон: текущие обои, размытые и приглушённые ----
            // Дёшево (M1, 8 ГБ): картинка 480 px по ширине размывается ОДИН раз в маленьком слое (шейдер считает ~530×340,
            // а не весь экран), а уже готовый слой растягивается на экран со сглаживанием. Поля по краям — чтобы размытие
            // не темнело к кромке.
            Rectangle { anchors.fill: parent; color: Colors.deep }
            Item {
                id: bgSmall
                readonly property int bw: 480
                readonly property int pad: 24
                readonly property real s: win.width / bw
                width: bw + 2 * pad; height: Math.round(bw * win.height / Math.max(1, win.width)) + 2 * pad
                x: -pad * s; y: -pad * s
                transformOrigin: Item.TopLeft
                scale: s
                visible: wallImg.status === Image.Ready
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                layer.enabled: menu.open || closer.running
                layer.smooth: true
                layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 32; brightness: -0.08; autoPaddingEnabled: false }
                Image {
                    id: wallImg
                    anchors.fill: parent
                    source: menu.open || closer.running ? "file://" + Quickshell.env("HOME") + "/.cache/yumi/theme/wall.set" : ""
                    sourceSize.width: bgSmall.width; sourceSize.height: bgSmall.height
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true; cache: false; smooth: true; mipmap: true
                }
            }
            Rectangle { anchors.fill: parent; color: Colors.alpha(Colors.deep, 0.45) }
            // щелчок мимо — закрыть
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: Menus.close("system") }
            WheelHandler { onWheel: (ev) => menu.scrollBy(-(ev.angleDelta.y) / 2) }

            // ---- остров по центру ----
            Rectangle {
                id: card
                width: Math.min(980, win.width - 64)
                height: cardCol.implicitHeight + 44
                x: Math.round((win.width - width) / 2)
                y: Math.round(win.height * 0.10)
                radius: Theme.radiusBig
                color: Colors.isl
                border.width: 1; border.color: Colors.edge
                Behavior on height { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 0.9 } }
                Behavior on color { ColorAnimation { duration: Theme.normal } }
                scale: menu.open ? 1 : 0.94
                Behavior on scale { NumberAnimation { duration: Theme.menuOpen; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
                transformOrigin: Item.Top
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }     // клики по острову не закрывают меню

                ColumnLayout {
                    id: cardCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 22 }
                    spacing: 14

                    // ---- шапка: печать, Yumi-Rice, строка системы; справа быстрые переходы ----
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        YumiMark { size: 48 }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            RowLayout {
                                spacing: 8
                                Text { text: "Yumi-Rice"; font.family: Theme.fontUi; font.pixelSize: 20; font.weight: Font.DemiBold; color: Colors.fg }
                                Text { visible: sys.dry; text: "DRY-RUN"; font.family: Theme.fontUi; font.pixelSize: 9; font.weight: Font.DemiBold; font.letterSpacing: 1; color: Colors.acc }
                            }
                            Text {
                                Layout.fillWidth: true; elide: Text.ElideRight
                                text: menu.toastText || ((sys.subtitle || menu.hostName) + (sys.stats && sys.stats.bat && sys.stats.bat.text ? " · батарея " + sys.stats.bat.text : ""))
                                font.family: Theme.fontUi; font.pixelSize: 13
                                color: menu.toastText ? (menu.toastError ? Colors.bad : Colors.acc) : Colors.fgDim
                                Behavior on color { ColorAnimation { duration: Theme.fast } }
                            }
                        }
                        Repeater {   // O / I / K / B — подробности, которых нет в ряду плиток
                            model: [["󰏘", "Оформление", "look", "O"], ["󰒓", "Инструменты", "tools", "I"], ["󰌌", "Клавиши", "keys", "K"], ["󰁹", "Батарея", "bat", "B"]]
                            QuickBtn {
                                required property var modelData
                                icon: modelData[0]; label: modelData[1]; hotkey: modelData[3]
                                on: menu.skey === modelData[2]
                                onClicked: { menu.key(modelData[2]); scope.forceActiveFocus() }
                            }
                        }
                    }

                    // ---- ряд показателей ----
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                            model: menu.rulerN
                            StatTile { required property int index; idx: index }
                        }
                    }

                    // ---- подробности выбранного ----
                    ColumnLayout {
                        id: side
                        Layout.fillWidth: true
                        spacing: 10
                        readonly property real maxDetH: Math.round(win.height * 0.46)
                        ISection { text: menu.sideTitle }
                        Loader {
                            id: det
                            Layout.fillWidth: true
                            Layout.preferredHeight: item ? Math.min(item.implicitHeight, side.maxDetH) : 0
                            active: menu.open || closer.running
                            sourceComponent: ({ upd: zUpd, snap: zSnap, doc: zDoc, cpu: zCpu, mem: zMem, disk: zStat, bat: zStat, temp: zTemp,
                                                look: zActs, tools: zActs, keys: zKeys })[menu.skey] || null
                        }
                        // кнопки (кроме списков действий «оформление/инструменты» — они в самом списке)
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            visible: menu.zbtns.length > 0 && !menu.vertBtns
                            Repeater {
                                model: menu.vertBtns ? [] : menu.zbtns
                                SBtn {
                                    required property var modelData
                                    required property int index
                                    t: modelData.t; primary: !!modelData.primary; enabledLook: modelData.active
                                    kb: menu.zoom >= 0 && menu.zsel === index
                                    onClicked: { menu.zoom = menu.sel; menu.zsel = index; menu.press(modelData); scope.forceActiveFocus() }
                                }
                            }
                            Item { Layout.fillWidth: true }
                        }
                        // пробный режим: что было бы запущено
                        IBox {
                            visible: menu.dryText.length > 0
                            Text { Layout.fillWidth: true; text: menu.dryText; wrapMode: Text.Wrap; font.family: Theme.fontMono; font.pixelSize: 12; color: Colors.fgDim }
                        }
                    }

                    CardHints {
                        items: menu.zoom < 0
                            ? [["←→", "показатель"], ["↵", "подробнее"], ["O I K B", "разделы"], ["Esc", "закрыть"]]
                            : menu.vertBtns ? [["↑↓", "выбор"], ["↵", "запустить"], ["Esc", "назад"]]
                            : [menu.scrolls ? ["↑↓", "прокрутка"] : null, menu.zbtns.length > 1 ? ["←→", "кнопка"] : null,
                               menu.zbtns.length ? ["↵", "нажать"] : null, ["Esc", "назад"]].filter(x => x)
                    }
                }
            }
        }
    }

    // ================= части =================
    // быстрый переход в шапке: значок в круге isl2 (выбран — акцент), подсказка-клавиша мелко
    component QuickBtn: Rectangle {
        id: qb
        property string icon: ""
        property string label: ""
        property string hotkey: ""
        property bool on: false
        signal clicked()
        implicitWidth: 40; implicitHeight: 40; radius: 20
        color: on ? Colors.acc : qm.containsMouse ? Colors.hover : Colors.isl2
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        scale: qm.pressed ? 0.92 : 1
        Behavior on scale { NumberAnimation { duration: Theme.fast } }
        Glyph { anchors.centerIn: parent; text: qb.icon; font.pixelSize: 17; color: qb.on ? Colors.onAcc : Colors.fg }
        Rectangle {
            anchors { right: parent.right; bottom: parent.bottom; rightMargin: -3; bottomMargin: -3 }
            implicitWidth: 16; implicitHeight: 16; radius: 8
            color: Colors.isl; border.width: 1; border.color: Colors.edge
            Text { anchors.centerIn: parent; text: qb.hotkey; font.family: Theme.fontUi; font.pixelSize: 9; font.weight: Font.DemiBold; color: Colors.fgDim }
        }
        MouseArea { id: qm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: qb.clicked() }
    }
    // плитка показателя: подпись, крупное значение, подпись под ним; выбранная — акцентная подложка
    component StatTile: Rectangle {
        id: rc
        property int idx: 0
        readonly property string k: menu.tiles[idx].key
        readonly property bool on: menu.sel === idx
        Layout.fillWidth: true; Layout.preferredWidth: 1
        implicitHeight: 84
        radius: Theme.radiusTile
        color: on ? Colors.alpha(Colors.acc, 0.16) : ma.containsMouse ? Colors.hover : Colors.isl2
        border.width: on && menu.zoom < 0 ? 1 : 0; border.color: Colors.alpha(Colors.acc, 0.7)
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        scale: ma.pressed ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: Theme.fast } }
        // каскад при открытии
        opacity: menu.open ? 1 : 0
        property real dy: menu.open ? 0 : 8
        transform: Translate { y: rc.dy }
        Behavior on opacity { SequentialAnimation { PauseAnimation { duration: menu.open ? Theme.contentDelay + rc.idx * Theme.cascade : 0 } NumberAnimation { duration: 280; easing.type: Easing.OutCubic } } }
        Behavior on dy { SequentialAnimation { PauseAnimation { duration: menu.open ? Theme.contentDelay + rc.idx * Theme.cascade : 0 } NumberAnimation { duration: 280; easing.type: Easing.OutCubic } } }
        ColumnLayout {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 10 }
            spacing: 1
            Text { Layout.fillWidth: true; text: menu.tiles[rc.idx].title; elide: Text.ElideRight; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim }
            Item {
                Layout.fillWidth: true
                implicitHeight: 26
                Row {
                    visible: rc.k !== "doc"
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Text {
                        id: bigT
                        text: rc.k === "upd" ? (sys.recs ? String(menu.updTotal) : "?")
                            : rc.k === "snap" ? (sys.snaps === null ? "…" : String(menu.snapTotal))
                            : rc.k === "cpu" ? (td.ready ? String(Math.round(td.cpu)) : "…")
                            : rc.k === "mem" ? (td.ready ? String(Math.round(td.ram)) : "…")
                            : rc.k === "disk" ? menu.diskParts[0]
                            : rc.k === "temp" ? (td.temp ? String(Math.round(td.temp[0])) : "—") : ""
                        font.family: Theme.fontUi; font.pixelSize: 20; font.weight: Font.DemiBold; font.features: ({ "tnum": 1 })
                        color: rc.k === "cpu" ? (td.cpu >= 90 ? Colors.bad : td.cpu >= 70 ? Colors.warn : Colors.fg)
                             : rc.k === "mem" ? (td.ram >= 90 ? Colors.bad : td.ram >= 70 ? Colors.warn : Colors.fg)
                             : rc.k === "temp" ? (td.temp && td.temp[0] >= 85 ? Colors.bad : td.temp && td.temp[0] >= 70 ? Colors.warn : Colors.fg)
                             : rc.k === "disk" ? (sys.stats && sys.stats.disk && sys.stats.disk.level === "crit" ? Colors.bad
                                                 : sys.stats && sys.stats.disk && sys.stats.disk.level === "warn" ? Colors.warn : Colors.fg)
                             : Colors.fg
                    }
                    Text { anchors.baseline: bigT.baseline; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim
                           text: rc.k === "cpu" || rc.k === "mem" ? "%" : rc.k === "disk" && menu.diskParts[1] ? "ГБ" : rc.k === "temp" && td.temp ? "°C" : "" }
                }
                Glyph {
                    id: dg
                    visible: rc.k === "doc"
                    anchors.verticalCenter: parent.verticalCenter
                    text: menu.docRowIcon; font.pixelSize: 22; color: menu.docTone
                    RotationAnimation on rotation { running: rc.k === "doc" && sys.docRunning && menu.open; from: 0; to: 360; duration: 1800; loops: Animation.Infinite }
                    onTextChanged: if (dg.text !== menu.docIcon.run) dg.rotation = 0
                }
            }
            Rectangle {   // полоса загрузки у процессора и памяти
                visible: rc.k === "cpu" || rc.k === "mem"
                Layout.fillWidth: true; Layout.topMargin: 2; Layout.bottomMargin: 2
                implicitHeight: 4; radius: 2; color: Colors.alpha(Colors.fg, 0.14)
                Rectangle {
                    readonly property real v: rc.k === "cpu" ? td.cpu : td.ram
                    height: parent.height; radius: 2
                    width: Math.max(4, parent.width * Math.max(0, Math.min(1, (td.ready ? v : 0) / 100)))
                    color: v >= 90 ? Colors.bad : v >= 70 ? Colors.warn : Colors.acc
                    Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: Theme.normal } }
                }
            }
            Text {
                Layout.fillWidth: true; elide: Text.ElideRight
                text: rc.k === "upd" ? (sys.recs && menu.updTotal === 0 ? "система обновлена" : menu.updSub)
                    : rc.k === "snap" ? (sys.snaps === null ? "загружаю…" : menu.snapLast ? (menu.snapLast.when || "") : "snapper не настроен")
                    : rc.k === "doc" ? menu.docShort.toLowerCase()
                    : rc.k === "cpu" ? td.ncpu + " " + menu.plural(td.ncpu, "ядро", "ядра", "ядер")
                    : rc.k === "mem" ? (td.ready ? menu.comma(td.fmtGb(td.used)) + " из " + menu.comma(td.fmtGb(td.total)) + " ГБ" : "…")
                    : rc.k === "disk" ? menu.diskParts[1]
                    : rc.k === "temp" ? (td.temp ? String(td.temp[1] || "") : "") : ""
                font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim
            }
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { menu.openZoom(rc.idx); scope.forceActiveFocus() } }
    }
    // кнопка подробностей: «󰚰  Обновить систему» → значок + подпись (IButton)
    component SBtn: IButton {
        property string t: ""
        icon: t.split("  ")[0]
        text: t.split("  ").slice(1).join("  ")
    }
    // строка списка: название слева, значение справа (tnum)
    component Li: RowLayout {
        property string name: ""
        property string val: ""
        property color tone: Colors.fg
        Layout.fillWidth: true; Layout.leftMargin: 10; Layout.rightMargin: 10
        spacing: 16
        Text { Layout.fillWidth: true; text: parent.name; elide: Text.ElideRight; font.family: Theme.fontUi; font.pixelSize: 13; color: parent.tone }
        Text { visible: parent.val.length > 0; Layout.maximumWidth: 280; text: parent.val; elide: Text.ElideLeft
               font.family: Theme.fontUi; font.pixelSize: 12; font.features: ({ "tnum": 1 }); color: Colors.fgDim }
    }
    component Note: Text {
        Layout.fillWidth: true; Layout.leftMargin: 10; Layout.rightMargin: 10
        wrapMode: Text.Wrap; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim
    }
    component SecLbl: ISection { Layout.leftMargin: 10; Layout.topMargin: 8 }
    // прокручиваемый список (↑↓ двигают его — menu.scrollFlick); высота — по содержимому, не больше места
    component ScrollList: Flickable {
        id: sl
        default property alias content: slCol.data
        property int spacing: 6
        implicitHeight: contentHeight
        clip: true
        contentHeight: slCol.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        Behavior on contentY { NumberAnimation { duration: Theme.fast; easing.type: Theme.easeSoft } }
        Component.onCompleted: menu.scrollFlick = sl
        Component.onDestruction: if (menu.scrollFlick === sl) menu.scrollFlick = null
        ColumnLayout { id: slCol; width: sl.width; spacing: sl.spacing }
    }
    // показатели плитками IStat в 4 колонки
    component Facts: GridLayout {
        id: facts
        property var rows: []
        columns: 4; columnSpacing: 8; rowSpacing: 8
        Repeater {
            model: facts.rows.filter(r => r[0])
            IStat { required property var modelData; Layout.preferredWidth: 1; label: modelData[0]; value: modelData[1] }
        }
    }
    // график в подложке isl2: заливка акцентом 22 % и линия
    component GBox: Rectangle {
        property alias values: gsp.values
        property alias max: gsp.max
        property alias range: gsp.range
        property alias tone: gsp.tone
        Layout.fillWidth: true; Layout.preferredHeight: 130
        radius: Theme.radius; color: Colors.isl2; clip: true
        PowerMenu.Spark { id: gsp; anchors.fill: parent; anchors.topMargin: 8; grid: true }
    }
    component BigNum: Row {
        id: bg
        property string text: ""
        property string unit: ""
        Layout.leftMargin: 4
        spacing: 4
        Text { id: bt; text: bg.text; font.family: Theme.fontUi; font.pixelSize: 36; font.weight: Font.DemiBold; font.features: ({ "tnum": 1 }); color: Colors.fg }
        Text { anchors.baseline: bt.baseline; text: bg.unit; font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fgDim }
    }

    // ================= подробности =================
    Component {
        id: zUpd
        ScrollList {
            spacing: 2
            RowLayout { visible: sys.listing || (!sys.updList && menu.zoom >= 0); Layout.leftMargin: 10; spacing: 10
                        MSpinner {} Text { text: "Проверяю обновления…"; font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fgDim } }
            // до «подробнее» — счёт по менеджерам из кеша
            Repeater {
                model: !sys.updList && sys.recs ? sys.recs.filter(r => r[1] > 0) : []
                Li { required property var modelData; name: menu.mgrName[modelData[0]] || modelData[0]; val: String(modelData[1]) }
            }
            Note { visible: !sys.updList && !sys.listing && menu.zoom < 0; text: sys.recs ? "↵ — список пакетов" : "↵ — проверить обновления" }
            Note { visible: sys.updList !== null && menu.updListTotal === 0; text: "Новых версий нет. Система обновлена." }
            Repeater {
                model: menu.updSections
                ColumnLayout {
                    id: us
                    required property var modelData
                    Layout.fillWidth: true; spacing: 4
                    SecLbl { text: us.modelData.title; visible: menu.updSections.length > 1 }
                    Repeater {
                        model: us.modelData.pkgs
                        Li { required property var modelData; name: modelData[0]; val: modelData[1] ? modelData[1] + " → " + modelData[2] : modelData[2] }
                    }
                }
            }
            Note { visible: sys.snapNote.length > 0; text: sys.snapNote }
            Note { text: "откат: snapper undochange ДО..ПОСЛЕ"; Layout.topMargin: 4 }
        }
    }
    Component {
        id: zSnap
        ScrollList {
            spacing: 2
            Note { text: sys.snaps === null ? "Загружаю…" : menu.snapTotal ? "Всего " + menu.snapTotal + " " + menu.snapWord + " · " + menu.snapTotalText
                                                         : "snapper не настроен — запустите yumi-setup-snapshots" }
            Repeater {
                model: menu.snapCfgs
                ColumnLayout {
                    id: ss
                    required property var modelData
                    readonly property var items: ((sys.snaps && sys.snaps[modelData.cfg]) || []).slice(0, 6)
                    visible: items.length > 0
                    Layout.fillWidth: true; spacing: 2
                    SecLbl { text: ss.modelData.title }
                    Repeater {
                        model: ss.items
                        IRow {
                            required property var modelData
                            hoverable: false
                            icon: "󰄄"; title: "№" + modelData.num + "  " + (modelData.desc || ""); sub: modelData.sub || ""
                            Text { text: modelData.when || ""; font.family: Theme.fontUi; font.pixelSize: 12; font.features: ({ "tnum": 1 }); color: Colors.fgDim }
                        }
                    }
                }
            }
            Note { Layout.topMargin: 4
                   text: "Откат обновления: sudo snapper -c root undochange ДО..ПОСЛЕ. Корень — снимок до и после каждого pacman; /home — каждый час." }
        }
    }
    Component {
        id: zDoc
        ScrollList {
            spacing: 2
            Note { text: menu.docRowSub }
            RowLayout { visible: sys.docRunning; Layout.leftMargin: 10; spacing: 10
                        MSpinner {} Text { text: "Проверяю…"; font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fgDim } }
            Note { visible: menu.docChecks.length === 0; text: (sys.doc && sys.doc.error) || "Ещё нет результата — проверяю…" }
            Repeater {
                model: menu.docChecks
                Rectangle {
                    id: chk
                    required property var modelData
                    readonly property string st: modelData.status || "info"
                    Layout.fillWidth: true
                    implicitHeight: chkRow.implicitHeight + 16
                    radius: Theme.radius; color: "transparent"
                    RowLayout {
                        id: chkRow
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 9; rightMargin: 10 }
                        spacing: 12
                        Rectangle {
                            implicitWidth: 34; implicitHeight: 34; radius: 12; Layout.alignment: Qt.AlignTop
                            color: Colors.isl2
                            Glyph { anchors.centerIn: parent; text: menu.docIcon[chk.st] || "•"; font.pixelSize: 16
                                    color: chk.st === "ok" ? Colors.ok : chk.st === "warn" ? Colors.warn : chk.st === "fail" ? Colors.bad : Colors.fgDim }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 1
                            Text { Layout.fillWidth: true; text: chk.modelData.title || chk.modelData.id || "?"; elide: Text.ElideRight; font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium; color: Colors.fg }
                            Text { Layout.fillWidth: true; text: menu.clean(chk.modelData.summary); wrapMode: Text.Wrap; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim }
                            Text { visible: (chk.st === "warn" || chk.st === "fail") && !!chk.modelData.hint; Layout.fillWidth: true
                                   text: "→ " + menu.clean(chk.modelData.hint); wrapMode: Text.Wrap; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim }
                        }
                    }
                }
            }
            Note { text: menu.docFixable ? "yumi-doctor --fix: " + menu.docFixable + " " + menu.plural(menu.docFixable, "пункт", "пункта", "пунктов") : "Безопасно чинить нечего" }
        }
    }
    Component {
        id: zCpu
        ColumnLayout {
            spacing: 10
            BigNum { text: td.ready ? String(Math.round(td.cpu)) : "…"; unit: "% сейчас" }
            GBox { values: menu.cpuHist; max: 100; tone: td.cpu >= 90 ? Colors.bad : td.cpu >= 70 ? Colors.warn : Colors.acc }
            Facts { Layout.fillWidth: true
                rows: [["Ядер", String(td.ncpu)], ["Нагрузка 1 / 5 / 15", td.load.map(x => x.toFixed(2)).join(" · ")],
                       ["Работает", td.ready ? td.fmtDuration(td.up) : "…"], ["График", "≈ 1,5 мин, раз в 2 с"]] }
        }
    }
    Component {
        id: zMem
        ScrollList {
            spacing: 10
            readonly property var m: menu.mem
            RowLayout {
                Layout.fillWidth: true
                spacing: 18
                BigNum { text: td.ready ? String(Math.round(td.ram)) : "…"; unit: "% занято" }
                Item { Layout.fillWidth: true }
                IStat { Layout.fillWidth: false; Layout.preferredWidth: 180; label: "earlyoom"; value: menu.earlyoom || "…" }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 4; columnSpacing: 8; rowSpacing: 8
                IStat { Layout.preferredWidth: 1; label: "Занято"; value: m.MemTotal ? menu.gb(m.MemTotal - m.MemAvailable) : menu.comma(td.fmtGb(td.used)) + " ГБ" }
                IStat { Layout.preferredWidth: 1; label: "Доступно"; value: m.MemAvailable ? menu.gb(m.MemAvailable) : "…" }
                IStat { Layout.preferredWidth: 1; label: "Всего"; value: m.MemTotal ? menu.gb(m.MemTotal) : menu.comma(td.fmtGb(td.total)) + " ГБ" }
                IStat { Layout.preferredWidth: 1; label: "Кэш и буферы"; value: m.Cached !== undefined ? menu.gb((m.Cached || 0) + (m.Buffers || 0) + (m.SReclaimable || 0)) : "…" }
            }
            GBox { values: menu.ramHist; max: 100; Layout.preferredHeight: 110
                   tone: td.ram >= 90 ? Colors.bad : td.ram >= 70 ? Colors.warn : Colors.acc }
            GridLayout {
                Layout.fillWidth: true
                columns: 4; columnSpacing: 8; rowSpacing: 8
                IStat { Layout.preferredWidth: 1; label: "Подкачка (zram/swap)"
                        value: m.SwapTotal ? menu.gb(m.SwapTotal - m.SwapFree) + " / " + menu.gb(m.SwapTotal) : "нет" }
                IStat { Layout.preferredWidth: 1; label: "zram: данные → в памяти"
                        value: menu.zram ? menu.gbB(menu.zram.orig) + " → " + menu.gbB(menu.zram.used) : "—" }
                IStat { Layout.preferredWidth: 1; label: "Сжатие" + (menu.zram && menu.zram.alg ? " · " + menu.zram.alg : "")
                        value: menu.zram && menu.zram.compr > 0 ? menu.comma((menu.zram.orig / menu.zram.compr).toFixed(1)) + "×" : "—" }
                IStat { Layout.preferredWidth: 1; label: "Общая (shmem)"; value: m.Shmem !== undefined ? menu.gb(m.Shmem) : "…" }
            }
            ISection { text: "Больше всего памяти" }
            GridLayout {
                Layout.fillWidth: true
                columns: 2; columnSpacing: 8; rowSpacing: 0
                Repeater {
                    model: (td.apps || []).slice(0, 8)
                    IRow {
                        required property var modelData
                        Layout.preferredWidth: 1
                        hoverable: false
                        icon: "󰍛"; title: modelData.name
                        sub: modelData.n + " проц. · ЦП " + menu.comma(Number(modelData.pct || 0).toFixed(1)) + " %"
                        Text { text: td.fmtSize(modelData.mem); font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium
                               font.features: ({ "tnum": 1 }); color: Colors.fg }
                    }
                }
            }
            Note { text: "Память приложений — PSS (как в btop); обновление раз в 2 с, пока открыта эта страница." }
        }
    }
    // диск / батарея: значение, полоса и полная подсказка карточки
    Component {
        id: zStat
        ColumnLayout {
            id: zs
            spacing: 10
            readonly property var d: sys.stats && sys.stats[menu.skey] ? sys.stats[menu.skey] : ({ text: "…", frac: 0, level: "", icon: "", tip: "" })
            // батарея — зелёный (100 %) → красный (0 %) по оттенку HSL, как в меню питания; диск — по уровню
            readonly property color tone: menu.skey === "bat" ? menu.chargeTone(Math.round((d.frac || 0) * 20) * 5)
                                        : d.level === "crit" ? Colors.bad : d.level === "warn" ? Colors.warn : Colors.acc
            RowLayout {
                Layout.leftMargin: 4; spacing: 12
                Rectangle { implicitWidth: 34; implicitHeight: 34; radius: 12; color: Colors.isl2
                            Glyph { anchors.centerIn: parent; text: zs.d.icon || (menu.skey === "disk" ? "󰋊" : "󰁹"); color: zs.tone; font.pixelSize: 17 } }
                Text { text: zs.d.text || "…"; font.family: Theme.fontUi; font.pixelSize: 26; font.weight: Font.DemiBold; font.features: ({ "tnum": 1 }); color: Colors.fg }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 8; radius: 4; color: Colors.alpha(Colors.fg, 0.14)
                Rectangle { width: Math.max(8, parent.width * Math.max(0, Math.min(1, zs.d.frac || 0))); height: parent.height; radius: 4; color: zs.tone
                            Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
                            Behavior on color { ColorAnimation { duration: Theme.normal } } }
            }
            Note { text: zs.d.tip || ""; color: Colors.fg; lineHeight: 1.25 }
            Note { visible: menu.skey === "bat"; text: "Подробно о питании — SUPER+CTRL+E или пилюля батареи" }
        }
    }
    Component {
        id: zTemp
        ColumnLayout {
            spacing: 10
            BigNum { text: td.temp ? String(Math.round(td.temp[0])) : "—"; unit: "°C" }
            GBox { values: menu.tempHist; range: true; tone: td.temp && td.temp[0] >= 85 ? Colors.bad : td.temp && td.temp[0] >= 70 ? Colors.warn : Colors.acc }
            Note { text: sys.stats && sys.stats.temp ? (sys.stats.temp.tip || sys.stats.temp.text || "") : ""; lineHeight: 1.25 }
        }
    }
    // оформление / инструменты: список действий строками IRow, ↑↓ — выбор, Enter — запустить
    Component {
        id: zActs
        ColumnLayout {
            spacing: 2
            Repeater {
                model: menu.zbtns
                IRow {
                    required property var modelData
                    required property int index
                    icon: modelData.t.split("  ")[0]; title: modelData.t.split("  ").slice(1).join("  ")
                    dim: !modelData.active
                    kb: menu.zoom >= 0 && menu.zsel === index
                    onClicked: { menu.zoom = menu.sel; menu.zsel = index; menu.press(modelData); scope.forceActiveFocus() }
                    Glyph { text: "󰅂"; font.pixelSize: 16; color: Colors.fgDim }
                }
            }
        }
    }
    Component {
        id: zKeys
        ScrollList {
            spacing: 2
            Repeater {
                model: menu.keyScheme
                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true; Layout.leftMargin: 10; Layout.rightMargin: 10; spacing: 14
                    Text { Layout.fillWidth: true; text: modelData[1]; elide: Text.ElideRight; font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fg }
                    Row {
                        spacing: 4
                        Repeater {
                            model: modelData[0].split("+")
                            Rectangle {
                                required property string modelData
                                implicitWidth: kt.implicitWidth + 14; implicitHeight: 22; radius: 7
                                color: Colors.isl2; border.width: 1; border.color: Colors.edge
                                Text { id: kt; anchors.centerIn: parent; text: modelData; font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.Medium; color: Colors.fg }
                            }
                        }
                    }
                }
            }
        }
    }
}
