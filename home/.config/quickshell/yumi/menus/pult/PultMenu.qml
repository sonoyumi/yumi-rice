import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.components
import qs.services
import qs.menus.launcher

// «Пульт» — остров-строка; «Остров» (29.10): карточка-остров 680 — поле 48 px, фишки режимов (IChip), строки как IRow
// (значок в квадрате 34, выбранная — акцент 16 %), подсказки CardHints. Прежнее описание: одна пилюля над столом: строка ввода, под ней результаты — пилюля растёт вниз с пружиной, строки въезжают
// каскадом по 40 мс. Снизу в той же пилюле — что сделают Enter / Ctrl+Enter у выбранного (кнопки из предпросмотра) и итог
// счёта/проверки. Ищет программы, команды Yumi, файлы (fd в фоне), счёт «2+2*3», эмодзи «:кот», веб «?запрос»; пустой
// ввод — недавние. Логика прежняя — бэкенд ~/.local/lib/yumi/qs/pult (функции самого yumi-pult и yumiapps.py).
// → (курсор в конце ввода) — раскрыть под выбранной строкой карточку подробностей (картинка, итог, «доктор», таблица
// сведений, текст — бывший правый предпросмотр; с пружиной), ← — свернуть.
// Клавиши: ↑/↓ PgUp/PgDn — выбор, Enter — действие, Ctrl+Enter (или Shift+Enter) — второе действие,
// Tab / Shift+Tab — режим (Всё/Программы/Команды/Файлы/Эмодзи/Веб), Esc — очистить, повторно — закрыть.
// Открыть по бинду (SUPER+Space, по центру): qs -c yumi ipc call menu center pult
// Проверка: YP_DRYRUN=1 (команды только печатаются, окно не закрывается); qs … ipc call pult search <текст> | pult mode <режим> |
//   pult enter false|true | pult select <n> | pult details true|false | pult state
Scope {
    id: menu
    readonly property bool open: Menus.current === "pult"
    readonly property string home: Quickshell.env("HOME")
    readonly property var modes: [{ key: "all", icon: "󰍉", text: "Всё" }, { key: "apps", icon: "󰀻", text: "Программы" },
                                  { key: "cmds", icon: "󰘳", text: "Команды" }, { key: "files", icon: "󰈞", text: "Файлы" },
                                  { key: "emoji", icon: "󰞅", text: "Эмодзи" }, { key: "web", icon: "󰖟", text: "Веб" }]
    property string mode: "all"
    readonly property int islandW: 680
    readonly property int rowH: 54
    readonly property int maxListH: 8 * rowH

    // ---- данные из бэкенда ----
    property bool ready: false
    property bool dry: false
    property var rows: []                  // [{section} | {hint} | {i, kind, title, sub, glyph|icons|path|emoji, on, badge}]
    property int sel: -1
    property var pv: ({})
    property string sub: ""
    property string ph: "Программы, команды, файлы, счёт…"
    property int wave: 0                   // номер выдачи — каскад строк при каждой новой
    property string toastText: ""
    property bool toastError: false

    function toast(text, error) { toastText = text; toastError = !!error; toastTimer.restart() }
    Timer { id: toastTimer; interval: 3000; onTriggered: menu.toastText = "" }

    function rowHeight(r) { return r.i !== undefined ? (r.kind === "calc" ? 76 : rowH) : (r.section !== undefined ? 30 : 46) }
    property int openI: -1                 // раскрытая карточка подробностей (→ / ←)
    property real detailH: 0
    readonly property bool opened: openI >= 0 && openI === sel && rows.some(r => r.i === openI)
    readonly property int listH: { let h = 0; for (const r of rows) h += rowHeight(r); if (opened) h += detailH + 10; return Math.min(maxListH + (opened ? 330 : 0), h) }
    onSelChanged: openI = -1
    function expand(on) {
        if (on && sel < 0) return false
        openI = on ? sel : -1
        if (on) { send({ cmd: "sel", i: sel }); revealT.restart() }
        return true
    }
    Timer { id: revealT; interval: 360; onTriggered: { const r = menu.rowOf(menu.sel); if (r >= 0) list.positionViewAtIndex(r, ListView.Contain) } }

    // ---- бэкенд ----
    function send(obj) { if (proc.running && ready) proc.write(JSON.stringify(obj) + "\n") }
    function query() { send({ cmd: "query", mode: mode, text: field.text }) }
    function rowOf(i) { return rows.findIndex(r => r.i === i) }
    function apply(line) {
        let j
        try { j = JSON.parse(line) } catch (e) { console.log("pult: не JSON:", line); return }
        switch (j.type) {
        case "hello": dry = j.dry; ready = true; if (open) query(); break
        case "rows":
            if (!j.keep) { wave++; openI = -1 }
            rows = j.rows; sub = j.sub; ph = j.ph; sel = j.sel
            if (!j.keep) list.positionViewAtBeginning()
            else { const r = rowOf(sel); if (r >= 0) list.positionViewAtIndex(r, ListView.Contain) }
            break
        case "preview": if (j.i === sel) pv = j.p; break
        case "toast": toast(j.text, j.error); break
        case "done": closeLater.restart(); break
        }
    }
    Timer { id: closeLater; interval: 80; onTriggered: menu.close() }
    Process {
        id: proc
        command: ["python3", "-I", menu.home + "/.local/lib/yumi/qs/pult"]
        running: menu.open || grace.running
        stdout: SplitParser { onRead: line => menu.apply(line) }
        stderr: SplitParser { onRead: line => console.log("pult:", line) }
        onExited: menu.ready = false
    }
    Timer { id: grace; interval: 90000 }   // после закрытия бэкенд живёт ещё 90 с — повторное открытие мгновенное
    onOpenChanged: {
        if (open) {
            grace.stop(); closer.stop(); mode = "all"
            if (ready) { send({ cmd: "reload" }); query() }
            field.forceActiveFocus()
        } else {
            field.focus = false; grace.restart(); closer.restart(); toastText = ""; field.text = ""; dropRows.restart()
        }
    }
    onModeChanged: if (open) query()
    Timer { id: closer; interval: Theme.normal }
    Timer { id: dropRows; interval: 600; onTriggered: if (!menu.open) { menu.rows = []; menu.pv = {} } }

    // ---- действия ----
    function close() { field.focus = false; Menus.close("pult") }
    function act(i, alt) { if (i >= 0) send({ cmd: "act", i: i, alt: !!alt }) }
    function move(d) {
        let n = 0
        for (const r of rows) if (r.i !== undefined) n++
        if (!n) return
        const i = Math.max(0, Math.min(n - 1, sel + d))
        if (i === sel) return
        sel = i
        send({ cmd: "sel", i: i })
        const r = rowOf(i)
        if (r >= 0) list.positionViewAtIndex(Math.max(0, d < 0 && r > 0 && rows[r - 1].section !== undefined ? r - 1 : r), ListView.Contain)
    }
    function docColor(st) { return st === "fail" ? Colors.bad : st === "warn" ? Colors.warn : st === "ok" ? Colors.alpha(Colors.fg, 0.7) : Colors.alpha(Colors.fg, 0.9) }
    function cycleMode(d) {
        const keys = modes.map(m => m.key)
        mode = keys[(keys.indexOf(mode) + d + keys.length) % keys.length]
    }

    IpcHandler {
        target: "pult"
        function toggle(): void { Menus.toggleCenter("pult") }
        function search(text: string): void { field.text = text }
        function mode(key: string): void { menu.mode = key }
        function select(n: int): void { menu.move(n - menu.sel) }
        function enter(alt: bool): void { menu.act(menu.sel, alt) }
        function details(on: bool): void { menu.expand(on) }
        function state(): string {
            const r = menu.rows[menu.rowOf(menu.sel)]
            return JSON.stringify({ open: menu.open, mode: menu.mode, q: field.text, rows: menu.rows.length, listH: menu.listH,
                                    sel: r ? r.title : "", btns: (menu.pv.btns || []).map(b => b.text) })
        }
    }

    // ---- окно ----
    PanelWindow {
        id: win
        screen: Menus.screen
        visible: menu.open || closer.running
        color: "transparent"
        WlrLayershell.namespace: "yumi-qs-pult"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        // YUMI_QS_NOKB=1 — проверка без захвата клавиатуры
        WlrLayershell.keyboardFocus: menu.open && Quickshell.env("YUMI_QS_NOKB") !== "1" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: true; right: true }

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: menu.close() }   // клик мимо острова — закрыть

        FocusScope {
            anchors.fill: parent

            // ---- остров: растёт вниз пружиной по мере выдачи ----
            Rectangle {
                id: island
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(parent.height * 0.16)
                width: Math.min(menu.islandW, parent.width - 40)
                height: hints.y + hints.height + 18
                Behavior on height { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.05 } }
                radius: Theme.radiusBig
                clip: true
                color: Colors.isl
                border.width: 1; border.color: Colors.edge
                Behavior on color { ColorAnimation { duration: Theme.normal } }
                property real grow: menu.open ? 1 : 0
                Behavior on grow { NumberAnimation { duration: menu.open ? Theme.menuOpen : Theme.fast
                                                     easing.type: menu.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.15 } }
                transform: Scale { origin.x: island.width / 2; origin.y: 24
                                   xScale: 0.9 + 0.1 * island.grow; yScale: 0.85 + 0.15 * island.grow }
                opacity: Math.min(1, grow * 3)
                MouseArea { anchors.fill: parent; onClicked: field.forceActiveFocus() }   // клики по острову — не «мимо»

                ColumnLayout {
                    id: head
                    x: 18; y: 18; width: parent.width - 36
                    spacing: 12
                    opacity: menu.open ? 1 : 0
                    Behavior on opacity { SequentialAnimation {
                        PauseAnimation { duration: menu.open ? Theme.contentDelay : 0 }
                        NumberAnimation { duration: menu.open ? 260 : 120; easing.type: Easing.OutCubic } } }

                    // поле 48 px (как IField, крупное); значок — режим
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 48; radius: 24
                        color: Colors.isl2
                        border.width: field.activeFocus ? 1.5 : 0; border.color: Colors.acc
                        Behavior on color { ColorAnimation { duration: Theme.normal } }
                        Glyph { id: lens; x: 16; anchors.verticalCenter: parent.verticalCenter
                                text: menu.modes.find(m => m.key === menu.mode).icon; font.pixelSize: 18; color: Colors.fgDim }
                        TextInput {
                            id: field
                            anchors { left: lens.right; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: dryT.visible ? dryT.implicitWidth + 30 : 16 }
                            font.family: Theme.fontUi; font.pixelSize: 15; color: Colors.fg
                            selectByMouse: true; selectionColor: Colors.alpha(Colors.acc, 0.4); selectedTextColor: Colors.fg
                            clip: true
                            onTextChanged: if (menu.open) menu.query()
                            Keys.onPressed: (e) => {
                                const k = e.key
                                if (k === Qt.Key_Right && field.cursorPosition === field.text.length && !menu.opened && menu.sel >= 0) menu.expand(true)
                                else if (k === Qt.Key_Left && menu.opened) menu.expand(false)
                                else if (k === Qt.Key_Down) menu.move(1)
                                else if (k === Qt.Key_Up) menu.move(-1)
                                else if (k === Qt.Key_PageDown) menu.move(8)
                                else if (k === Qt.Key_PageUp) menu.move(-8)
                                else if (k === Qt.Key_Tab) menu.cycleMode(1)
                                else if (k === Qt.Key_Backtab) menu.cycleMode(-1)
                                else if (k === Qt.Key_Return || k === Qt.Key_Enter) menu.act(menu.sel, e.modifiers & (Qt.ControlModifier | Qt.ShiftModifier))
                                else if (k === Qt.Key_Escape) { if (field.text) field.text = ""; else menu.close() }
                                else return
                                e.accepted = true
                            }
                            Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; visible: !field.text; elide: Text.ElideRight
                                   font.family: Theme.fontUi; font.pixelSize: 15; color: Colors.fgDim; text: menu.ph }
                        }
                        Text { id: dryT; anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter
                               visible: menu.dry
                               text: "DRY-RUN"; font.family: Theme.fontUi; font.pixelSize: 9; font.weight: Font.DemiBold; font.letterSpacing: 1; color: Colors.acc }
                    }
                    // режимы — фишки (клик = то же, что Tab до нужного)
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: menu.modes
                            IChip {
                                required property var modelData
                                text: modelData.text
                                on: menu.mode === modelData.key
                                onClicked: { menu.mode = modelData.key; field.forceActiveFocus() }
                            }
                        }
                    }
                }

                // результаты
                ListView {
                    id: list
                    anchors.top: head.bottom; anchors.topMargin: 8
                    x: 18; width: parent.width - 36; height: menu.listH
                    clip: true; boundsBehavior: Flickable.StopAtBounds
                    cacheBuffer: 200
                    model: menu.rows
                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool isRow: modelData.i !== undefined
                        readonly property bool isCalc: modelData.kind === "calc"
                        readonly property bool selected: isRow && modelData.i === menu.sel
                        readonly property bool expanded: isRow && modelData.i === menu.openI && menu.openI === menu.sel
                        width: ListView.view.width
                        height: menu.rowHeight(modelData) + (expanded ? menu.detailH + 10 : 0)
                        Behavior on height { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.0 } }
                        // каскад: каждая новая выдача въезжает по 40 мс на строку
                        property int myWave: -1
                        opacity: 1
                        Component.onCompleted: start()
                        function start() { if (myWave === menu.wave) return; myWave = menu.wave; if (index < 9) { opacity = 0; shift.y = 8; appear.restart() } }
                        Connections { target: menu; function onWaveChanged() { row.start() } }
                        transform: Translate { id: shift; y: 0 }
                        ParallelAnimation {
                            id: appear
                            SequentialAnimation { PauseAnimation { duration: Math.min(row.index, 8) * Theme.cascade }
                                NumberAnimation { target: row; property: "opacity"; to: 1; duration: 220 } }
                            SequentialAnimation { PauseAnimation { duration: Math.min(row.index, 8) * Theme.cascade }
                                NumberAnimation { target: shift; property: "y"; to: 0; duration: 280; easing.type: Easing.OutCubic } }
                        }

                        // подпись раздела — как ISection (11 заглавными)
                        Text { visible: row.modelData.section !== undefined
                               text: row.modelData.section || ""
                               x: 10; anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                               font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.Medium
                               font.capitalization: Font.AllUppercase; font.letterSpacing: 1; color: Colors.fgDim }
                        Text { visible: row.modelData.hint !== undefined; text: row.modelData.hint || ""; x: 12; width: parent.width - 24
                               anchors.verticalCenter: parent.verticalCenter; wrapMode: Text.Wrap
                               font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim }

                        Rectangle {
                            visible: row.isRow
                            anchors.fill: parent; anchors.topMargin: 1; anchors.bottomMargin: 1
                            radius: Theme.radius                         // как IRow: выбранная — акцент 16 %, наведение isl2
                            clip: true
                            color: row.selected ? Colors.alpha(Colors.acc, 0.16)
                                                : (area.containsMouse ? Colors.isl2 : "transparent")
                            /* выбор — без затухания (29.10) */
                            scale: area.pressed ? 0.985 : 1
                            Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
                            Item {
                                id: base
                                width: parent.width; height: menu.rowHeight(row.modelData) - 2
                                MouseArea {
                                    id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: (m) => { menu.act(row.modelData.i, m.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)); field.forceActiveFocus() }
                                }
                                // счёт — крупно
                                Row {
                                    visible: row.isCalc
                                    anchors.left: parent.left; anchors.leftMargin: 9; anchors.verticalCenter: parent.verticalCenter
                                    spacing: 12
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 34; height: 34; radius: 12
                                        color: row.selected ? Colors.acc : Colors.isl2
                                        Text { anchors.centerIn: parent; text: "="; font.family: Theme.fontUi; font.pixelSize: 18; font.weight: Font.DemiBold
                                               color: row.selected ? Colors.onAcc : Colors.fg }
                                    }
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text { text: row.isCalc ? row.modelData.title : ""; font.family: Theme.fontUi; font.pixelSize: 26; font.weight: Font.DemiBold
                                               color: Colors.fg; font.features: ({ "tnum": 1 }) }
                                        Text { text: (row.modelData.sub || "") + "   ·   Enter — скопировать"; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim }
                                    }
                                }
                                // обычная строка — как IRow
                                Item {
                                    visible: !row.isCalc
                                    anchors.fill: parent; anchors.leftMargin: 9; anchors.rightMargin: 12
                                    Rectangle {
                                        id: ico
                                        width: 34; height: 34; radius: 12; anchors.verticalCenter: parent.verticalCenter
                                        color: row.selected && !row.modelData.icons && !row.modelData.emoji ? Colors.acc : Colors.isl2
                                        /* выбор — без затухания (29.10) */
                                        LIcon { anchors.centerIn: parent; visible: !!row.modelData.icons; size: row.modelData.kind === "file" ? 20 : 22
                                                names: row.modelData.icons || []; path: row.modelData.path || "" }
                                        Glyph { anchors.centerIn: parent; visible: !!row.modelData.glyph; text: row.modelData.glyph || ""; font.pixelSize: 16
                                                color: row.selected ? Colors.onAcc : Colors.fg }
                                        Text { anchors.centerIn: parent; visible: !!row.modelData.emoji; text: row.modelData.emoji || ""; font.pixelSize: 18 }
                                    }
                                    Column {
                                        anchors.left: ico.right; anchors.leftMargin: 12; anchors.right: tail.left; anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 1
                                        Text { width: parent.width; text: row.modelData.title || ""; elide: Text.ElideRight
                                               font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium; color: Colors.fg }
                                        Text { width: parent.width; visible: !!row.modelData.sub; text: row.modelData.sub || ""; elide: Text.ElideMiddle
                                               font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim }
                                    }
                                    Row {
                                        id: tail
                                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                        spacing: 8
                                        Rectangle {
                                            visible: !!row.modelData.on
                                            width: onT.implicitWidth + 14; height: 20; radius: 10
                                            color: Colors.acc
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text { id: onT; anchors.centerIn: parent; text: "вкл"; font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.Medium; color: Colors.onAcc }
                                        }
                                        Text { visible: !!row.modelData.badge; text: row.modelData.badge || ""; anchors.verticalCenter: parent.verticalCenter
                                               font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim }
                                        Glyph { visible: row.selected; text: "󰅂"; rotation: row.expanded ? 90 : 0; anchors.verticalCenter: parent.verticalCenter
                                                font.pixelSize: 16; color: Colors.fgDim
                                                Behavior on rotation { NumberAnimation { duration: 340; easing.type: Easing.OutBack } }
                                                MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: { menu.openI = row.expanded ? -1 : row.modelData.i; field.forceActiveFocus() } } }
                                    }
                                }
                            }

                            // ---- подробности (→ раскрыть, ← свернуть) — бывший правый предпросмотр ----
                            Flickable {
                                id: dflick
                                anchors.top: base.bottom; x: 14; width: parent.width - 28
                                height: Math.max(0, parent.height - base.height - 8)
                                visible: row.expanded
                                opacity: row.expanded ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                                contentHeight: det.implicitHeight
                                clip: true; boundsBehavior: Flickable.StopAtBounds
                                interactive: contentHeight > height
                                Binding { target: menu; property: "detailH"; value: Math.min(320, det.implicitHeight); when: row.expanded; restoreMode: Binding.RestoreNone }
                                Column {
                                    id: det
                                    width: dflick.width
                                    spacing: 8
                                    readonly property var p: row.expanded ? menu.pv : ({})
                                    Item { width: 1; height: 2 }
                                    ClippingRectangle {
                                        visible: det.p.head === "img"
                                        width: parent.width; height: visible ? 170 : 0
                                        radius: Theme.radiusTile; color: Colors.isl2
                                        Image {
                                            anchors.fill: parent
                                            source: det.p.head === "img" && det.p.img ? "file://" + det.p.img : ""
                                            sourceSize.width: Math.ceil(width * Screen.devicePixelRatio); sourceSize.height: Math.ceil(height * Screen.devicePixelRatio)
                                            fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true
                                            opacity: status === Image.Ready ? 1 : 0
                                            Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                                        }
                                    }
                                    Row {
                                        spacing: 12
                                        visible: det.p.head === "glyph" || det.p.head === "icon" || det.p.head === "emoji"
                                        Glyph { visible: det.p.head === "glyph"; text: det.p.glyph || ""; color: Colors.fg; font.pixelSize: 24 }
                                        LIcon { visible: det.p.head === "icon"; size: 32; names: det.p.icons || []; path: det.p.path || "" }
                                        Text { visible: det.p.head === "emoji"; text: det.p.emoji || ""; font.pixelSize: 26 }
                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text { visible: !!det.p.title; text: det.p.title || ""; font.family: Theme.fontUi; font.pixelSize: 16; font.weight: Font.DemiBold; color: Colors.fg }
                                        }
                                    }
                                    Text { width: parent.width; visible: det.p.head === "img" && !!det.p.title; text: det.p.title || ""; wrapMode: Text.WrapAnywhere
                                           font.family: Theme.fontUi; font.pixelSize: 16; font.weight: Font.DemiBold; color: Colors.fg }
                                    Text { width: parent.width; visible: !!det.p.sub; text: det.p.sub || ""; wrapMode: Text.Wrap
                                           font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim }
                                    Text { width: parent.width; visible: !!det.p.res; text: det.p.res || ""; wrapMode: Text.WrapAnywhere
                                           font.family: Theme.fontUi; font.pixelSize: 26; font.weight: Font.DemiBold; color: Colors.fg; font.features: ({ "tnum": 1 }) }
                                    // доктор
                                    Column {
                                        visible: !!det.p.doctor
                                        width: parent.width; spacing: 4
                                        readonly property var d: det.p.doctor || ({})
                                        Row {
                                            spacing: 8
                                            Glyph { text: parent.parent.d.icon || ""; font.pixelSize: 16; color: menu.docColor(parent.parent.d.status) }
                                            Text { width: det.width - 30; text: parent.parent.d.summary || ""; wrapMode: Text.Wrap
                                                   font.family: Theme.fontUi; font.pixelSize: 14; font.weight: Font.Medium; color: Colors.fg }
                                        }
                                        Text { width: parent.width; text: parent.d.bits || ""; wrapMode: Text.Wrap; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.alpha(Colors.fg, 0.8) }
                                        Repeater {
                                            model: parent.d.checks || []
                                            delegate: Row {
                                                required property var modelData
                                                spacing: 8
                                                Glyph { text: modelData.icon; font.pixelSize: 12; color: menu.docColor(modelData.status) }
                                                Text { width: det.width - 24; text: modelData.text; wrapMode: Text.Wrap; font.family: Theme.fontUi; font.pixelSize: 12
                                                       color: modelData.status === "ok" ? Colors.alpha(Colors.fg, 0.7) : Colors.alpha(Colors.fg, 0.9) }
                                            }
                                        }
                                    }
                                    // подробности «ключ — значение»
                                    Grid {
                                        visible: (det.p.details || []).length > 0
                                        columns: 2; columnSpacing: 12; rowSpacing: 5
                                        Repeater {
                                            model: (det.p.details || []).length * 2
                                            delegate: Text {
                                                required property int index
                                                readonly property var kv: det.p.details[Math.floor(index / 2)] || ["", ""]
                                                readonly property bool isKey: index % 2 === 0
                                                width: isKey ? 120 : det.width - 132
                                                text: isKey ? kv[0] : (kv[1] || "—")
                                                wrapMode: isKey ? Text.NoWrap : Text.WrapAnywhere; elide: isKey ? Text.ElideRight : Text.ElideNone
                                                font.family: Theme.fontUi; font.pixelSize: 12
                                                color: isKey ? Colors.fgDim : Colors.fg
                                            }
                                        }
                                    }
                                    Text { width: parent.width; visible: !!det.p.list; text: det.p.list || ""; wrapMode: Text.WrapAnywhere
                                           font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.alpha(Colors.fg, 0.8) }
                                    Rectangle {
                                        visible: !!det.p.text
                                        width: parent.width; height: ptext.implicitHeight + 20; radius: Theme.radiusTile
                                        color: Colors.isl2
                                        Text { id: ptext; anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10; leftMargin: 12 }
                                               text: det.p.text || ""; wrapMode: Text.WrapAnywhere; textFormat: Text.PlainText
                                               font.family: Theme.fontMono; font.pixelSize: 11; color: Colors.alpha(Colors.fg, 0.85) }
                                    }
                                    Item { width: 1; height: 2 }
                                }
                            }
                        }
                    }
                }

                // низ острова: итог / уведомление, справа — что сделают Enter / Ctrl+Enter
                Item {
                    id: foot
                    anchors.top: list.bottom; anchors.topMargin: 8
                    x: 18; width: parent.width - 36; height: menu.rows.length || menu.toastText ? 34 : 0
                    visible: height > 0
                    Text {
                        anchors.left: parent.left; anchors.right: keys.left; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: menu.toastText || menu.pv.res || (menu.pv.doctor ? menu.pv.doctor.summary : "") || menu.sub || ""
                        font.family: Theme.fontUi; font.pixelSize: 12
                        color: menu.toastText ? (menu.toastError ? Colors.bad : Colors.acc) : Colors.fgDim
                    }
                    Row {
                        id: keys
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Repeater {
                            model: menu.pv.btns || []
                            IButton {
                                required property var modelData
                                implicitHeight: 30
                                width: Math.min(240, implicitWidth)
                                text: modelData.text
                                primary: !!modelData.primary
                                onClicked: { menu.act(menu.sel, modelData.alt); field.forceActiveFocus() }
                            }
                        }
                    }
                }

                CardHints {
                    id: hints
                    y: foot.visible ? foot.y + foot.height + 10 : head.y + head.height + 12
                    x: 18; width: parent.width - 36
                    items: [["↑↓", "выбрать"], ["Enter", "выполнить"], ["→ ←", "подробности"], ["Tab", "раздел"], [": ? =", "эмодзи, веб, счёт"], ["Esc", "закрыть"]]
                    note: menu.dry ? "проверка: команды только печатаются" : ""
                }
            }
        }
    }
}
