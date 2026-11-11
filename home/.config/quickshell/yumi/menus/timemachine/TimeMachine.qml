import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// «Машина времени» (30.10): снимки snapper (btrfs) в стиле «Остров». Карточка-остров 1160×680 по центру экрана в фокусе
// (Menus.screen, как LauncherMenu): слева — обозреватель текущей папки, посередине — выбранное «как было» в выбранный момент
// (картинка, текст с подсветкой отличий от текущего, список папки с отметками «нет сейчас / изменён / новый»), справа —
// вертикальная шкала времени: «Сейчас» и версии (одинаковые снимки склеены), сгруппированные «Сегодня / Вчера / дата».
// Кнопки: «Восстановить» (текущее сначала переименовывается в «<имя>.before-restore-<дата>»), «Восстановить рядом»
// («<имя> (из снимка <дата>)»), «Показать в Dolphin» (xdg-open папки в снимке). Корневые снимки (/etc…) — только просмотр.
// Логика — бэкенд ~/.local/lib/yumi/qs/timemachine (python3 -I, JSON-строки; YP_DRYRUN=1 — восстановление только печатается).
// Клавиши: ↑↓ — время, Tab / Shift+Tab — файл в папке, Enter — войти в папку, ⌫ — вверх, Esc — отмена / закрыть.
// Открыть: qs -c yumi ipc call timemachine open <путь> | timemachine toggle | timemachine state
// Проверка: qs … ipc call timemachine key up|down|tab|enter|back · timemachine pick <индекс точки> · timemachine select <имя>
Scope {
    id: tm
    readonly property bool open: Menus.current === "timemachine"
    readonly property string home: Quickshell.env("HOME")

    // ---- данные ----
    property bool ready: false
    property bool dry: false
    property var configs: ({})
    property string folder: home           // папка обозревателя
    property string target: home           // что смотрим во времени (папка или файл в ней)
    property var items: []                 // текущая папка
    property string lsError: ""
    property bool hidden: false
    property int fsel: -1                  // -1 — сама папка, иначе строка items
    property var vres: null                // ответ versions для target
    property var peek: null                // ответ peek для выбранной точки
    property int tsel: 0                   // точка шкалы: 0 — «Сейчас»
    property int wantN: -1                 // номер снимка, на котором остаться после смены target
    property string view: "diff"           // текст: diff | full
    property bool confirm: false           // «Восстановить» ждёт подтверждения
    property bool busy: false
    property string toastText: ""
    property bool toastError: false
    property string pendingPath: ""

    readonly property var versions: vres && vres.path === target ? vres.versions : []
    readonly property bool writable: !!(vres && vres.path === target && vres.writable)
    readonly property var points: {
        const out = [{ now: true, n: 0, ts: Date.now() / 1000, exists: !!(vres && vres.current), same: true, snaps: [] }]
        for (const v of versions) out.push(v)
        let prev = ""
        for (let i = 0; i < out.length; i++) {
            const d = i === 0 ? "" : dayLabel(out[i].to)
            out[i].head = i > 0 && d !== prev ? d : ""
            if (i > 0) prev = d
        }
        return out
    }
    readonly property var point: tsel >= 0 && tsel < points.length ? points[tsel] : null
    readonly property string targetName: target === home ? "Домашняя папка" : baseName(target)
    readonly property int snapCount: { const c = configs[(vres && vres.config) || "home"]; return c ? c.snaps.length : 0 }
    readonly property bool canRestore: !busy && writable && point && !point.now && point.exists
    readonly property bool targetIsDir: {
        if (vres && vres.path === target) {
            if (vres.current) return vres.current.dir
            const v = vres.versions.find(x => x.exists)
            if (v) return v.dir
        }
        return peek && peek.path === target ? peek.kind === "dir" : true
    }
    readonly property var selItem: fsel >= 0 && fsel < items.length ? items[fsel] : null

    // ---- помощники ----
    readonly property var months: ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"]
    readonly property var monthsShort: ["янв", "фев", "мар", "апр", "мая", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"]
    function baseName(p) { const s = String(p); return s === "/" ? "/" : s.substring(s.lastIndexOf("/") + 1) }
    function dirName(p) { const s = String(p); const i = s.lastIndexOf("/"); return i <= 0 ? "/" : s.substring(0, i) }
    function tilde(p) { return p === home ? "~" : String(p).startsWith(home + "/") ? "~" + String(p).substring(home.length) : String(p) }
    function pad2(n) { return n < 10 ? "0" + n : "" + n }
    function dayKey(d) { return d.getFullYear() * 10000 + d.getMonth() * 100 + d.getDate() }
    function dayLabel(ts) {
        const d = new Date(ts * 1000), now = new Date()
        const y = new Date(now.getTime() - 86400000)
        if (dayKey(d) === dayKey(now)) return "Сегодня"
        if (dayKey(d) === dayKey(y)) return "Вчера"
        return d.getDate() + " " + months[d.getMonth()] + (d.getFullYear() !== now.getFullYear() ? " " + d.getFullYear() : "")
    }
    function hm(ts) { const d = new Date(ts * 1000); return pad2(d.getHours()) + ":" + pad2(d.getMinutes()) }
    function shortDate(ts) {
        const d = new Date(ts * 1000), now = new Date()
        const day = dayKey(d) === dayKey(now) ? "сегодня" : dayKey(d) === dayKey(new Date(now.getTime() - 86400000)) ? "вчера"
                  : d.getDate() + " " + monthsShort[d.getMonth()]
        return day + ", " + hm(ts)
    }
    function longDate(ts) { const d = new Date(ts * 1000); return d.getDate() + " " + months[d.getMonth()] + ", " + hm(ts) }
    function plural(n, one, few, many) {
        const a = n % 10, b = n % 100
        return a === 1 && b !== 11 ? one : (a >= 2 && a <= 4 && (b < 12 || b > 14)) ? few : many
    }
    function size(b) {
        if (b < 1024) return b + " Б"
        const u = ["КБ", "МБ", "ГБ", "ТБ"]; let v = b / 1024, i = 0
        while (v >= 1024 && i < u.length - 1) { v /= 1024; i++ }
        return (v < 10 ? v.toFixed(1) : Math.round(v)).toString().replace(".", ",") + " " + u[i]
    }
    function fileUrl(p) { return "file://" + String(p).split("/").map(encodeURIComponent).join("/") }
    readonly property var imageExt: ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "tif", "tiff", "ico", "avif", "jxl"]
    function iconFor(name, dir) {
        if (dir) return String.fromCodePoint(0xf024b)                       // папка
        const e = String(name).toLowerCase().split(".").pop()
        if (imageExt.indexOf(e) >= 0) return String.fromCodePoint(0xf021f)   // картинка
        if (["mp3", "flac", "ogg", "opus", "wav", "m4a"].indexOf(e) >= 0) return String.fromCodePoint(0xf0223)
        if (["mp4", "mkv", "webm", "mov", "avi"].indexOf(e) >= 0) return String.fromCodePoint(0xf022b)
        if (["zip", "tar", "gz", "xz", "zst", "7z", "rar"].indexOf(e) >= 0) return String.fromCodePoint(0xf05c4)
        if (["pdf"].indexOf(e) >= 0) return String.fromCodePoint(0xf0226)
        if (["qml", "py", "js", "lua", "sh", "c", "h", "cpp", "rs", "go", "json", "toml", "yaml", "yml", "css", "html", "conf", "ini"].indexOf(e) >= 0)
            return String.fromCodePoint(0xf022e)                             // код
        return String.fromCodePoint(0xf0214)                                 // файл
    }
    function toast(t, e) { toastText = t; toastError = !!e; toastTimer.restart() }
    Timer { id: toastTimer; interval: 4500; onTriggered: tm.toastText = "" }

    // ---- бэкенд ----
    function send(o) { if (proc.running && ready) proc.write(JSON.stringify(o) + "\n") }
    function take(line) {
        let j
        try { j = JSON.parse(line) } catch (e) { console.log("timemachine: не JSON:", line); return }
        switch (j.type) {
        case "hello":
            dry = j.dry; ready = true
            if (open) { reloadAll() }
            break
        case "snaps": configs = j.configs; break
        case "ls":
            if (j.path !== folder) break
            if (probe === j.path) {
                probe = ""
                // стартовый путь не открылся как папка — это файл (или его уже нет): родитель с выбором
                if (j.error) { goFolder(dirName(j.path), j.path); break }
            }
            items = j.items; lsError = j.error || ""
            if (pendingPath) {
                const i = items.findIndex(x => x.path === pendingPath)
                fsel = i; pendingPath = ""
            }
            if (fsel >= items.length) fsel = items.length - 1
            if (fsel >= 0) fileList.positionViewAtIndex(fsel, ListView.Contain)
            break
        case "versions":
            if (j.path !== target) break
            vres = j
            {
                // остаться на том же моменте (снимок с тем же номером), иначе — на новейшей версии
                let k = -1
                if (wantN > 0) k = j.versions.findIndex(v => v.snaps.indexOf(wantN) >= 0)
                else if (wantN === 0) k = -1
                // по умолчанию — новейшая версия, где это есть (удалённое — момент до удаления)
                const firstHave = j.versions.findIndex(v => v.exists)
                tsel = wantN === 0 ? 0 : k >= 0 ? k + 1 : firstHave >= 0 ? firstHave + 1 : (j.versions.length ? 1 : 0)
                wantN = -1
            }
            requestPeek(true)
            break
        case "peek":
            if (point && j.path === target && j.n === point.n) { peek = j; peekGen++ }
            break
        case "restored":
            busy = false; confirm = false
            toast(j.msg, !j.ok)
            if (j.ok && !j.dry) {
                if (j.mode === "beside") pendingPath = j.target
                send({ cmd: "ls", path: folder, hidden: hidden })
                wantN = point ? point.n : -1
                send({ cmd: "versions", path: target })
            }
            break
        case "toast": toast(j.text, j.error); break
        }
    }
    property int peekGen: 0
    function reloadAll() {
        send({ cmd: "snaps" })
        send({ cmd: "ls", path: folder, hidden: hidden })
        send({ cmd: "versions", path: target })
    }
    function requestPeek(now) { if (now) { peekTimer.stop(); doPeek() } else peekTimer.restart() }
    function doPeek() { if (point) send({ cmd: "peek", path: target, n: point.n, hidden: hidden }) }
    Timer { id: peekTimer; interval: 70; onTriggered: tm.doPeek() }
    Process {
        id: proc
        command: ["python3", "-I", tm.home + "/.local/lib/yumi/qs/timemachine"]
        running: tm.open || grace.running
        stdout: SplitParser { onRead: line => tm.take(line) }
        stderr: SplitParser { onRead: line => console.log(line) }
        onExited: tm.ready = false
    }
    Timer { id: grace; interval: 60000 }   // после закрытия бэкенд живёт ещё минуту — повторное открытие мгновенное

    // ---- навигация ----
    function setTarget(p) {
        if (p === target) return
        wantN = point ? point.n : -1
        target = p; confirm = false; vres = null
        send({ cmd: "versions", path: p })
    }
    function goFolder(p, selectPath) {
        folder = p; items = []; lsError = ""; fsel = -1
        pendingPath = selectPath || ""
        send({ cmd: "ls", path: p, hidden: hidden })
        setTarget(selectPath || p)
    }
    function up() { if (folder !== "/") goFolder(dirName(folder), folder) }
    function selectRow(i) {
        fsel = i
        if (i >= 0) fileList.positionViewAtIndex(i, ListView.Contain)
        setTarget(i < 0 ? folder : items[i].path)
    }
    function enter() {
        const it = selItem
        if (it && it.dir) goFolder(it.path, "")
    }
    function stepFile(d) {
        const n = items.length
        if (!n) return
        let i = fsel + d
        if (i < -1) i = n - 1
        if (i >= n) i = -1
        selectRow(i)
    }
    function stepTime(d) {
        const i = Math.max(0, Math.min(points.length - 1, tsel + d))
        if (i === tsel) return
        tsel = i; confirm = false
        requestPeek(false)
    }
    function pick(i) { if (i >= 0 && i < points.length) { tsel = i; confirm = false; requestPeek(true) } }
    // в снимке папки щёлкнули по строке: папка — войти (даже если её больше нет), файл — смотреть его во времени
    function openSnapItem(it) {
        const p = (target === "/" ? "" : target) + "/" + it.name
        if (it.dir) goFolder(p, "")
        else if (dirName(p) === folder) { const i = items.findIndex(x => x.path === p); if (i >= 0) selectRow(i); else { fsel = -1; setTarget(p) } }
        else { goFolder(dirName(p), p) }
    }
    function restore(mode) {
        if (!canRestore || (mode === "replace" && point.same)) return
        if (mode === "replace" && vres.current && !confirm) { confirm = true; return }
        busy = true
        send({ cmd: "restore", path: target, n: point.n, mode: mode })
    }
    function showInFm() { if (point && !point.now) send({ cmd: "open", path: target, n: point.n }) }

    function show(path) {
        let p = String(path || "").trim()
        if (p.startsWith("file://")) p = decodeURIComponent(p.substring(7))
        if (p === "" || p === "-") p = folder || home
        if (p.startsWith("~")) p = home + p.substring(1)
        if (!p.startsWith("/")) p = home + "/" + p
        p = p.replace(/\/+$/, "") || "/"
        startPath = p
        if (open) applyStart(); else Menus.toggleCenter("timemachine")
    }
    property string startPath: ""
    function applyStart() {
        const p = startPath || folder || home
        startPath = ""
        // папка или файл — узнаем по ответу ls: если папки нет, смотрим её как файл в родителе
        probe = p
        send({ cmd: "ls", path: p, hidden: hidden })
        folder = p; target = ""; vres = null; peek = null; items = []; fsel = -1; tsel = 0; wantN = -1
        setTarget(p)
        wantN = -1                           // при открытии — новейшая версия из снимков
    }
    property string probe: ""
    onOpenChanged: {
        if (open) {
            grace.stop(); closer.stop(); confirm = false; busy = false; toastText = ""
            if (ready) { send({ cmd: "snaps" }); applyStart() }
            keys.forceActiveFocus()
        } else {
            keys.focus = false; grace.restart(); closer.restart()
        }
    }
    onReadyChanged: if (ready && open) applyStart()
    onHiddenChanged: if (ready) { send({ cmd: "ls", path: folder, hidden: hidden }); requestPeek(true) }
    Timer { id: closer; interval: Theme.normal }

    IpcHandler {
        target: "timemachine"
        function open(path: string): void { tm.show(path) }
        function toggle(): void { if (tm.open) Menus.close("timemachine"); else tm.show("") }
        function close(): void { Menus.close("timemachine") }
        function key(name: string): void {
            if (name === "up") tm.stepTime(-1); else if (name === "down") tm.stepTime(1)
            else if (name === "tab") tm.stepFile(1); else if (name === "backtab") tm.stepFile(-1)
            else if (name === "enter") tm.enter(); else if (name === "back") tm.up()
            else if (name === "view") tm.view = tm.view === "diff" ? "full" : "diff"
            else if (name === "hidden") tm.hidden = !tm.hidden
        }
        function pick(i: int): void { tm.pick(i) }
        function select(name: string): void { const i = tm.items.findIndex(x => x.name === name); if (i >= 0) tm.selectRow(i) }
        function restore(mode: string): void { tm.restore(mode) }
        function state(): string {
            return JSON.stringify({ open: tm.open, ready: tm.ready, dry: tm.dry, folder: tm.folder, target: tm.target,
                                    items: tm.items.length, fsel: tm.fsel, points: tm.points.length, tsel: tm.tsel,
                                    n: tm.point ? tm.point.n : -1, kind: tm.peek ? tm.peek.kind : "", writable: tm.writable,
                                    confirm: tm.confirm, toast: tm.toastText })
        }
    }

    // ---- окно ----
    PanelWindow {
        id: win
        screen: Menus.screen
        visible: tm.open || closer.running
        color: "transparent"
        WlrLayershell.namespace: "yumi-qs-timemachine"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: tm.open && Quickshell.env("YUMI_QS_NOKB") !== "1" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: true; right: true }

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: Menus.close("timemachine") }   // клик мимо — закрыть

        FocusScope {
            anchors.fill: parent

            Item {
                id: keys
                focus: true
                Keys.onPressed: (e) => {
                    const k = e.key
                    if (k === Qt.Key_Escape) { if (tm.confirm) tm.confirm = false; else Menus.close("timemachine") }
                    else if (k === Qt.Key_Up) tm.stepTime(-1)
                    else if (k === Qt.Key_Down) tm.stepTime(1)
                    else if (k === Qt.Key_Home) tm.pick(0)
                    else if (k === Qt.Key_End) tm.pick(tm.points.length - 1)
                    else if (k === Qt.Key_Tab) tm.stepFile(1)
                    else if (k === Qt.Key_Backtab) tm.stepFile(-1)
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter) { if (tm.confirm) tm.restore("replace"); else tm.enter() }
                    else if (k === Qt.Key_Backspace || k === Qt.Key_Left) tm.up()
                    else if (k === Qt.Key_Right) tm.enter()
                    else return
                    e.accepted = true
                }
            }

            Rectangle {
                id: card
                width: Math.min(1160, win.width - 48)
                height: Math.min(680, win.height - 96)
                x: Math.round((parent.width - width) / 2)
                y: Math.round((parent.height - height) / 2)
                radius: Theme.radiusBig
                color: Colors.isl
                border.width: 1; border.color: Colors.edge
                Behavior on color { ColorAnimation { duration: Theme.normal } }
                property real grow: tm.open ? 1 : 0
                Behavior on grow { NumberAnimation { duration: tm.open ? Theme.menuOpen + 60 : Theme.fast
                                                     easing.type: tm.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 0.9 } }
                transform: Scale { origin.x: card.width / 2; origin.y: card.height / 2
                                   xScale: 0.9 + 0.1 * card.grow; yScale: 0.88 + 0.12 * card.grow }
                opacity: Math.min(1, card.grow * 2.5)
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: keys.forceActiveFocus() }

                ColumnLayout {
                    id: body
                    anchors.fill: parent; anchors.margins: 18
                    spacing: 14
                    opacity: tm.open ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: tm.open ? 220 : 100; easing.type: Easing.OutCubic } }

                    // ---- шапка ----
                    CardHead {
                        title: "Машина времени"
                        dry: tm.dry
                        status: !tm.ready ? "Читаю снимки…"
                              : tm.snapCount + " " + tm.plural(tm.snapCount, "снимок", "снимка", "снимков")
                                + ((tm.vres && tm.vres.config === "root") ? " системы · только просмотр" : " домашней папки")
                        IChip { text: "Скрытые"; on: tm.hidden; onClicked: { tm.hidden = !tm.hidden; keys.forceActiveFocus() } }
                        Rectangle {
                            implicitWidth: 30; implicitHeight: 30; radius: 15
                            color: xMa.containsMouse ? Colors.isl2 : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.fast } }
                            Glyph { anchors.centerIn: parent; text: String.fromCodePoint(0xf0156); font.pixelSize: 16; color: Colors.fgDim }
                            MouseArea { id: xMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Menus.close("timemachine") }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        spacing: 14

                        // ================= слева: обозреватель =================
                        Rectangle {
                            Layout.preferredWidth: 290; Layout.fillHeight: true
                            radius: Theme.radiusTile; color: Colors.isl2
                            Behavior on color { ColorAnimation { duration: Theme.normal } }
                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: 8
                                spacing: 6
                                // путь: «‹» вверх и папка
                                RowLayout {
                                    Layout.fillWidth: true; Layout.leftMargin: 2; Layout.rightMargin: 4
                                    spacing: 6
                                    Rectangle {
                                        implicitWidth: 30; implicitHeight: 30; radius: 12
                                        opacity: tm.folder === "/" ? 0.35 : 1
                                        color: upMa.containsMouse ? Colors.hover : "transparent"
                                        Behavior on color { ColorAnimation { duration: Theme.fast } }
                                        scale: upMa.pressed ? 0.92 : 1
                                        Behavior on scale { NumberAnimation { duration: Theme.fast } }
                                        Glyph { anchors.centerIn: parent; text: String.fromCodePoint(0xf0141); font.pixelSize: 18; color: Colors.fg }
                                        MouseArea { id: upMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { tm.up(); keys.forceActiveFocus() } }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: tm.tilde(tm.folder)
                                        elide: Text.ElideLeft
                                        font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium; color: Colors.fg
                                    }
                                }
                                // сама папка — тоже можно смотреть во времени
                                FileRow {
                                    Layout.fillWidth: true
                                    icon: String.fromCodePoint(0xf0770)
                                    name: tm.folder === tm.home ? "Вся домашняя папка" : "Вся папка «" + tm.baseName(tm.folder) + "»"
                                    meta: ""
                                    on: tm.fsel < 0
                                    onClicked: { tm.selectRow(-1); keys.forceActiveFocus() }
                                }
                                Rectangle { Layout.fillWidth: true; Layout.leftMargin: 10; Layout.rightMargin: 10; implicitHeight: 1; color: Colors.edge }
                                ListView {
                                    id: fileList
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds
                                    model: tm.items
                                    spacing: 1
                                    delegate: FileRow {
                                        required property var modelData
                                        required property int index
                                        width: fileList.width
                                        icon: tm.iconFor(modelData.name, modelData.dir)
                                        name: modelData.name
                                        meta: modelData.dir ? "" : tm.size(modelData.size)
                                        on: index === tm.fsel
                                        chevron: modelData.dir
                                        cascade: index
                                        onClicked: { tm.selectRow(index); keys.forceActiveFocus() }
                                        onDoubleClicked: { if (modelData.dir) tm.goFolder(modelData.path, "") }
                                    }
                                    Text {
                                        anchors.centerIn: parent; width: parent.width - 30
                                        visible: tm.ready && !tm.items.length
                                        horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                                        text: tm.lsError ? "Этой папки сейчас нет — она есть только в снимках" : "Пусто"
                                        font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim
                                    }
                                }
                            }
                        }

                        // ================= посередине: как было =================
                        ColumnLayout {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            spacing: 12

                            // заголовок: значок, имя, «версия от …»
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                Rectangle {
                                    implicitWidth: 44; implicitHeight: 44; radius: 14
                                    gradient: Gradient {
                                        GradientStop { position: 0; color: Colors.mix(Colors.isl2, Colors.acc, 0.34) }
                                        GradientStop { position: 1; color: Colors.isl2 }
                                    }
                                    Glyph { anchors.centerIn: parent; font.pixelSize: 22; color: Colors.fg
                                            text: tm.iconFor(tm.target, tm.targetIsDir) }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { Layout.fillWidth: true; text: tm.targetName; elide: Text.ElideMiddle
                                           font.family: Theme.fontUi; font.pixelSize: 16; font.weight: Font.DemiBold; color: Colors.fg }
                                    Text {
                                        Layout.fillWidth: true; elide: Text.ElideRight
                                        font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim
                                        text: {
                                            const p = tm.point
                                            if (!p) return " "
                                            const inf = tm.peek && tm.peek.info
                                            const sz = inf && !inf.dir ? " · " + tm.size(inf.size) : ""
                                            if (p.now) return (tm.vres && !tm.vres.current ? "Сейчас этого нет" : "Как сейчас" + sz)
                                            if (!p.exists) return "В снимке от " + tm.longDate(p.to) + " этого нет"
                                            return "Как было " + tm.longDate(p.to) + sz + (p.same ? " · совпадает с текущим" : "")
                                        }
                                    }
                                }
                                ISeg {
                                    Layout.fillWidth: false; Layout.preferredWidth: 190
                                    visible: !!(tm.peek && tm.peek.kind === "text" && tm.point && !tm.point.now && !tm.peek.nocur && !tm.peek.same)
                                    model: ["Отличия", "Целиком"]
                                    current: tm.view === "diff" ? 0 : 1
                                    onPicked: (i) => { tm.view = i === 0 ? "diff" : "full"; keys.forceActiveFocus() }
                                }
                            }

                            // содержимое
                            Rectangle {
                                id: pane
                                Layout.fillWidth: true; Layout.fillHeight: true
                                radius: Theme.radiusTile; color: Colors.isl2
                                clip: true
                                Behavior on color { ColorAnimation { duration: Theme.normal } }
                                readonly property string kind: tm.peek ? tm.peek.kind : ""
                                readonly property bool textFull: kind === "text" && (tm.view === "full" || !tm.point || tm.point.now || tm.peek.nocur || tm.peek.same)

                                // смена момента — содержимое мягко проявляется, чуть съезжая
                                Item {
                                    id: paneBody
                                    anchors.fill: parent
                                    property real dy: 0
                                    transform: Translate { y: paneBody.dy }
                                    Connections {
                                        target: tm
                                        function onPeekGenChanged() { fade.restart() }
                                    }
                                    ParallelAnimation {
                                        id: fade
                                        NumberAnimation { target: paneBody; property: "opacity"; from: 0.25; to: 1; duration: 220; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: paneBody; property: "dy"; from: 6; to: 0; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                                    }

                                    // ---- картинка ----
                                    Image {
                                        anchors.fill: parent; anchors.margins: 14
                                        visible: pane.kind === "image"
                                        source: visible ? tm.fileUrl(tm.peek.src) : ""
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true; cache: false
                                        sourceSize.width: 1200; sourceSize.height: 900
                                        smooth: true; mipmap: true
                                    }

                                    // ---- текст: отличия или целиком ----
                                    ListView {
                                        id: textView
                                        anchors.fill: parent; anchors.margins: 6
                                        visible: pane.kind === "text"
                                        clip: true
                                        boundsBehavior: Flickable.StopAtBounds
                                        model: !visible ? [] : pane.textFull ? tm.peek.lines : tm.peek.diff
                                        delegate: Rectangle {
                                            required property var modelData
                                            required property int index
                                            readonly property string t: pane.textFull ? " " : modelData.t
                                            width: textView.width; height: 19
                                            radius: 6
                                            color: t === "-" ? Colors.alpha(Colors.bad, 0.16) : t === "+" ? Colors.alpha(Colors.ok, 0.14)
                                                 : t === "@" ? Colors.alpha(Colors.acc, 0.10) : "transparent"
                                            Text {
                                                x: 6; width: 34; anchors.verticalCenter: parent.verticalCenter
                                                horizontalAlignment: Text.AlignRight
                                                text: pane.textFull ? (index + 1) : (parent.t === "@" ? "" : parent.t === "-" ? "−" : parent.t === "+" ? "+" : "")
                                                font.family: Theme.fontMono; font.pixelSize: 11
                                                color: parent.t === "-" ? Colors.bad : parent.t === "+" ? Colors.ok : Colors.alpha(Colors.fg, 0.35)
                                            }
                                            Text {
                                                x: 48; width: parent.width - 54; anchors.verticalCenter: parent.verticalCenter
                                                text: (pane.textFull ? modelData : modelData.s).replace(/\t/g, "    ")
                                                textFormat: Text.PlainText
                                                elide: Text.ElideRight
                                                font.family: Theme.fontMono; font.pixelSize: 12
                                                color: parent.t === "@" ? Colors.acc : parent.t === " " && !pane.textFull ? Colors.fgDim : Colors.fg
                                            }
                                        }
                                    }

                                    // ---- папка ----
                                    ListView {
                                        id: dirView
                                        anchors.fill: parent; anchors.margins: 6
                                        visible: pane.kind === "dir"
                                        clip: true
                                        boundsBehavior: Flickable.StopAtBounds
                                        spacing: 1
                                        model: visible ? tm.peek.items : []
                                        delegate: FileRow {
                                            required property var modelData
                                            required property int index
                                            width: dirView.width
                                            icon: tm.iconFor(modelData.name, modelData.dir)
                                            name: modelData.name
                                            meta: modelData.dir ? "" : tm.size(modelData.size)
                                            badge: modelData.state === "gone" ? "нет сейчас" : modelData.state === "changed" ? "изменён"
                                                 : modelData.state === "new" ? "появился позже" : ""
                                            badgeColor: modelData.state === "gone" ? Colors.bad : modelData.state === "changed" ? Colors.warn : Colors.ok
                                            dim: modelData.state === "new"
                                            chevron: modelData.dir
                                            cascade: index
                                            onClicked: { tm.openSnapItem(modelData); keys.forceActiveFocus() }
                                        }
                                    }

                                    // ---- нет / двоичный / пусто ----
                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        width: parent.width - 60
                                        visible: pane.kind === "missing" || pane.kind === "binary" || (pane.kind === "text" && textView.count === 0)
                                                 || (pane.kind === "dir" && dirView.count === 0) || !tm.peek
                                        spacing: 10
                                        Glyph {
                                            Layout.alignment: Qt.AlignHCenter
                                            font.pixelSize: 40; color: Colors.alpha(Colors.fg, 0.35)
                                            text: String.fromCodePoint(pane.kind === "missing" ? 0xf0b98 : pane.kind === "binary" ? 0xf0214 : 0xf02da)
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                                            font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fgDim
                                            text: !tm.peek ? (tm.ready ? "Загружаю…" : "Читаю снимки…")
                                                : pane.kind === "missing" ? (tm.point && tm.point.now ? "Сейчас «" + tm.targetName + "» нет — выберите момент на шкале справа"
                                                                                              : "В этом снимке «" + tm.targetName + "» нет")
                                                : pane.kind === "binary" ? "Двоичный файл, " + tm.size(tm.peek.info.size) + " — предпросмотра нет"
                                                : pane.kind === "dir" ? "Папка пуста"
                                                : "Пустой файл"
                                        }
                                    }
                                }

                                // подпись снизу: что за отличия
                                Rectangle {
                                    visible: pane.kind === "text" && !pane.textFull
                                    anchors { right: parent.right; bottom: parent.bottom; margins: 10 }
                                    implicitWidth: legend.implicitWidth + 20; implicitHeight: 24; radius: 12
                                    color: Colors.alpha(Colors.isl, 0.92)
                                    Row {
                                        id: legend; anchors.centerIn: parent; spacing: 12
                                        Text { text: "− было в снимке"; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.bad }
                                        Text { text: "+ сейчас"; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.ok }
                                    }
                                }
                                Rectangle {
                                    visible: pane.kind === "text" && pane.textFull && !!tm.peek.same && !!tm.point && !tm.point.now
                                    anchors { right: parent.right; bottom: parent.bottom; margins: 10 }
                                    implicitWidth: sameT.implicitWidth + 20; implicitHeight: 24; radius: 12
                                    color: Colors.alpha(Colors.isl, 0.92)
                                    Text { id: sameT; anchors.centerIn: parent; text: "Не отличается от текущего"; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim }
                                }
                            }

                            // действия / подтверждение / сообщение
                            Item {
                                Layout.fillWidth: true
                                implicitHeight: 38
                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 8
                                    opacity: tm.confirm ? 0 : 1
                                    visible: opacity > 0
                                    Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                                    IButton {
                                        icon: String.fromCodePoint(0xf02da); text: "Восстановить"; primary: true
                                        enabledLook: tm.canRestore && !(tm.point && tm.point.same)
                                        onClicked: tm.restore("replace")
                                    }
                                    IButton {
                                        icon: String.fromCodePoint(0xf018f); text: "Восстановить рядом"
                                        enabledLook: tm.canRestore
                                        onClicked: tm.restore("beside")
                                    }
                                    IButton {
                                        icon: String.fromCodePoint(0xf0770); text: "Показать в Dolphin"
                                        enabledLook: !!(tm.point && !tm.point.now && tm.point.exists)
                                        onClicked: tm.showInFm()
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        Layout.maximumWidth: 260
                                        visible: tm.toastText.length > 0 || (tm.vres && !tm.writable)
                                        text: tm.toastText || "Только просмотр"
                                        elide: Text.ElideMiddle
                                        font.family: Theme.fontUi; font.pixelSize: 12
                                        color: tm.toastError ? Colors.bad : tm.toastText ? Colors.ok : Colors.fgDim
                                    }
                                }
                                // «Восстановить» — подтверждение на месте кнопок
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 16
                                    color: Colors.alpha(Colors.acc, 0.14)
                                    border.width: 1; border.color: Colors.alpha(Colors.acc, 0.4)
                                    opacity: tm.confirm ? 1 : 0
                                    visible: opacity > 0
                                    scale: tm.confirm ? 1 : 0.96
                                    Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                                    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 4
                                        spacing: 8
                                        Text {
                                            Layout.fillWidth: true
                                            wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                                            lineHeight: 0.95
                                            font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fg
                                            text: tm.point && !tm.point.now ? "Вернуть версию от " + tm.shortDate(tm.point.to) + "? Текущая останется рядом как «" + tm.targetName + ".before-restore-…»" : ""
                                        }
                                        IButton { implicitHeight: 30; text: "Отмена"; onClicked: { tm.confirm = false; keys.forceActiveFocus() } }
                                        IButton { implicitHeight: 30; text: "Восстановить"; primary: true; onClicked: tm.restore("replace") }
                                    }
                                }
                            }
                        }

                        // ================= справа: шкала времени =================
                        Rectangle {
                            Layout.preferredWidth: 250; Layout.fillHeight: true
                            radius: Theme.radiusTile; color: Colors.isl2
                            Behavior on color { ColorAnimation { duration: Theme.normal } }
                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: 8
                                spacing: 4
                                RowLayout {
                                    Layout.fillWidth: true; Layout.leftMargin: 8; Layout.rightMargin: 8; Layout.topMargin: 4
                                    Text { text: "Время"; font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium; color: Colors.fg }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: tm.versions.filter(v => v.exists).length + " " + tm.plural(tm.versions.filter(v => v.exists).length, "версия", "версии", "версий")
                                        font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim
                                    }
                                }
                                ListView {
                                    id: timeline
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds
                                    model: tm.points
                                    // currentIndex — не привязкой: новая модель сбрасывает его в 0, и привязка больше не срабатывает
                                    Connections {
                                        target: tm
                                        function onTselChanged() { timeline.currentIndex = tm.tsel }
                                        function onPointsChanged() { Qt.callLater(() => { timeline.currentIndex = tm.tsel }) }
                                    }
                                    highlightMoveDuration: 320
                                    highlightMoveVelocity: -1
                                    highlightResizeDuration: 200
                                    highlightRangeMode: ListView.ApplyRange
                                    preferredHighlightBegin: 60; preferredHighlightEnd: height - 60
                                    highlight: Item {
                                        z: 0
                                        Rectangle {
                                            x: 0; width: timeline.width; radius: 14
                                            y: timeline.currentItem ? timeline.currentItem.headH : 0
                                            height: 46
                                            color: Colors.alpha(Colors.acc, 0.16)
                                            border.width: 1; border.color: Colors.alpha(Colors.acc, 0.45)
                                        }
                                    }
                                    // линия времени — сквозь все точки
                                    Rectangle {
                                        x: 21; width: 2; y: 23; height: Math.max(0, timeline.contentHeight - 46)
                                        z: 0.5
                                        color: Colors.alpha(Colors.fg, 0.18)
                                    }
                                    delegate: Item {
                                        id: tp
                                        required property var modelData
                                        required property int index
                                        readonly property bool on: index === tm.tsel
                                        readonly property int headH: modelData.head ? 30 : 0
                                        width: timeline.width
                                        height: headH + 46
                                        z: 1
                                        opacity: 0
                                        property real dx: 10
                                        transform: Translate { x: tp.dx }
                                        Component.onCompleted: appear.start()
                                        SequentialAnimation {
                                            id: appear
                                            PauseAnimation { duration: Math.min(10, tp.index) * Theme.cascade }
                                            ParallelAnimation {
                                                NumberAnimation { target: tp; property: "opacity"; to: 1; duration: 240; easing.type: Easing.OutCubic }
                                                NumberAnimation { target: tp; property: "dx"; to: 0; duration: 320; easing.type: Easing.OutCubic }
                                            }
                                        }
                                        Text {
                                            visible: tp.headH > 0
                                            x: 10; y: 10
                                            text: tp.modelData.head || ""
                                            font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.DemiBold
                                            font.letterSpacing: 0.4
                                            color: Colors.fgDim
                                        }
                                        Item {
                                            y: tp.headH; width: parent.width; height: 46
                                            // точка на шкале
                                            Rectangle {
                                                x: 22 - width / 2; anchors.verticalCenter: parent.verticalCenter
                                                width: tp.on ? 14 : tp.modelData.now ? 12 : 9; height: width; radius: width / 2
                                                color: tp.on ? Colors.acc : !tp.modelData.exists && !tp.modelData.now ? "transparent"
                                                     : tp.modelData.same ? Colors.alpha(Colors.fg, 0.35) : Colors.fg
                                                border.width: !tp.modelData.exists && !tp.modelData.now && !tp.on ? 1.5 : 0
                                                border.color: Colors.alpha(Colors.fg, 0.4)
                                                Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                                                Behavior on color { ColorAnimation { duration: Theme.fast } }
                                            }
                                            Column {
                                                x: 40; anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - 48
                                                spacing: 1
                                                Text {
                                                    width: parent.width; elide: Text.ElideRight
                                                    text: tp.modelData.now ? "Сейчас" : tm.hm(tp.modelData.to)
                                                    font.family: tp.modelData.now ? Theme.fontUi : Theme.fontUi
                                                    font.features: { "tnum": 1 }
                                                    font.pixelSize: 13; font.weight: tp.on ? Font.DemiBold : Font.Medium
                                                    color: Colors.fg
                                                }
                                                Text {
                                                    width: parent.width; elide: Text.ElideRight
                                                    font.family: Theme.fontUi; font.pixelSize: 11
                                                    color: tp.on ? Colors.alpha(Colors.fg, 0.8) : Colors.fgDim
                                                    text: {
                                                        const v = tp.modelData
                                                        if (v.now) return tm.vres && !tm.vres.current ? "нет" : "текущая версия"
                                                        let s = !v.exists ? "нет в снимке" : v.same ? "как сейчас" : "другая версия"
                                                        if (v.snaps.length > 1) s += " · " + v.snaps.length + " " + tm.plural(v.snaps.length, "снимок", "снимка", "снимков")
                                                        const st = (tm.configs[tm.vres ? tm.vres.config : "home"] || { snaps: [] }).snaps.find(x => x.n === v.n)
                                                        if (st && st.desc && st.desc !== "timeline") s = st.desc + (v.exists ? "" : " · нет")
                                                        return s
                                                    }
                                                }
                                            }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: { tm.pick(tp.index); keys.forceActiveFocus() }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    CardHints {
                        items: [["↑↓", "время"], ["Tab", "файл"], ["Enter", "в папку"], ["⌫", "вверх"], ["Esc", "закрыть"]]
                    }
                }
            }
        }
    }
}
