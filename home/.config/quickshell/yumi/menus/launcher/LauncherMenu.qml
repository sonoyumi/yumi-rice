import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// «Остров» (29.10): карточка-остров 700 по центру — поле поиска 48 px, фишки разделов (IChip), сетка плиток 52 px
// (градиент акцент 34 % → isl2), выбранная — кромка акцентом и линза (соседи чуть крупнее); логика та же.
// «Программы и файлы» — сетка-линза (вариант 2 со страницы стилей меню, 16.10; прежнее меню-список —
// LauncherMenu.qml.bak-lens-20261016). Слой поверх размытого стола, как виджет обоев: строка поиска, фишки разделов,
// сетка значков. Выбранный значок крупнее, соседи чуть крупнее (линза); при поиске программы не перестраиваются —
// неподходящие гаснут на своих местах, выбор прыгает на лучшее совпадение. Файлы — та же сетка из найденного.
// Логика прежняя — бэкенд ~/.local/lib/yumi/qs/launcher (поиск, «часто», запуск `uwsm app`, файлы через fd/find);
// у программы есть раздел cat (по Categories .desktop: Интернет / Разработка / Медиа / Офис / Система / Другое).
// Клавиши: печать — поиск, ←→↑↓ — выбор (↑ с верхнего ряда — к фишкам разделов, там ←→ раздел, ↓ назад),
// Enter — запустить/открыть, Shift+Enter — папка файла, Tab — Программы ⇄ Файлы, Esc — очистить поиск / закрыть.
// Открыть: qs -c yumi ipc call launcher apps (SUPER+A) · launcher files (SUPER+SHIFT+E) · menu center launcher.
// Проверка: YP_DRYRUN=1 (запуск только печатается); qs … ipc call launcher search <текст> | launcher enter false|true | launcher state
Scope {
    id: menu
    readonly property bool open: Menus.current === "launcher"
    readonly property string home: Quickshell.env("HOME")
    property string mode: "apps"           // apps | files
    property bool modeSet: false
    readonly property bool apps: mode === "apps"
    readonly property int cols: 6          // «Остров»: 6 в ряд, как превью
    readonly property int cellW: 110
    readonly property int cellH: 104
    readonly property int maxRows: 4

    // ---- данные ----
    property bool ready: false
    property bool dry: false
    property var cur: []                   // последние строки бэкенда (номер действия i — по ним)
    property var base: []                  // программы: все, постоянный порядок (из пустого запроса)
    property var freq: []                  // ключи «часто»
    property var match: null               // поиск программ: {ключ: место}; null — поиска нет
    property string sent: ""               // запрос, на который ждём ответ
    property string sub: ""
    property string chip: "*"              // "*" все · "freq" часто · раздел
    property bool inChips: false
    property int sel: 0
    property string launching: ""          // ключ запускаемой — значок улетает
    property string toastText: ""
    property bool toastError: false
    readonly property var tiles: apps ? base : cur.filter(r => r.i !== undefined)
    readonly property var groups: {
        const order = ["Интернет", "Разработка", "Медиа", "Офис", "Система", "Другое"]
        const have = new Set(base.map(t => t.cat))
        const out = [{ key: "*", text: "Все" }]
        if (freq.length) out.push({ key: "freq", text: "Часто" })
        for (const g of order) if (have.has(g)) out.push({ key: g, text: g })
        return out
    }
    readonly property var selTile: tiles.length && sel >= 0 && sel < tiles.length ? tiles[sel] : null

    function toast(text, error) { toastText = text; toastError = !!error; toastTimer.restart() }
    Timer { id: toastTimer; interval: 3000; onTriggered: menu.toastText = "" }

    function isVis(t) {
        if (!apps) return true
        if (match !== null && match[t.key] === undefined) return false
        if (chip === "*") return true
        if (chip === "freq") return freq.indexOf(t.key) >= 0
        return t.cat === chip
    }
    function firstVis() { for (let i = 0; i < tiles.length; i++) if (isVis(tiles[i])) return i; return -1 }
    function fixSel() { if (!selTile || !isVis(selTile)) { const f = firstVis(); sel = f < 0 ? 0 : f } show(sel) }
    function show(i) { if (i >= 0) grid.positionViewAtIndex(i, GridView.Contain) }

    // ---- бэкенд ----
    function send(obj) { if (proc.running && ready) proc.write(JSON.stringify(obj) + "\n") }
    function query() { sent = field.text; send({ cmd: "query", mode: mode, q: field.text }) }
    function take(line) {
        let j
        try { j = JSON.parse(line) } catch (e) { console.log("launcher: не JSON:", line); return }
        switch (j.type) {
        case "hello": dry = j.dry; ready = true; if (open) { send({ cmd: "reload" }); query() } break
        case "rows":
            if (j.mode !== mode) break
            cur = j.rows; sub = j.sub
            if (apps) {
                if (!sent.trim()) {
                    let section = "", all = [], fr = []
                    for (const r of j.rows) {
                        if (r.section !== undefined) { section = r.section; continue }
                        if (r.i === undefined) continue
                        if (section === "ЧАСТО") fr.push(r.key); else all.push(r)
                    }
                    if (!all.length) all = j.rows.filter(r => r.i !== undefined)
                    if (JSON.stringify(all.map(r => r.key)) !== JSON.stringify(base.map(r => r.key))) base = all
                    freq = fr; match = null
                    fixSel()
                } else {
                    const m = {}; let best = ""
                    j.rows.forEach((r, n) => { if (r.i !== undefined) { m[r.key] = n; if (!best) best = r.key } })
                    match = m
                    const b = base.findIndex(t => t.key === best)
                    if (b >= 0 && isVis(base[b])) { sel = b; show(b) } else fixSel()
                }
            } else { sel = 0; show(0) }
            break
        case "toast": toast(j.text, j.error); launching = ""; break
        case "done": closeLater.restart(); break
        }
    }
    Timer { id: closeLater; interval: 160; onTriggered: menu.close() }
    Process {
        id: proc
        command: ["python3", "-I", menu.home + "/.local/lib/yumi/qs/launcher"]
        running: menu.open || grace.running
        stdout: SplitParser { onRead: line => menu.take(line) }
        stderr: SplitParser { onRead: line => console.log("launcher:", line) }
        onExited: menu.ready = false
    }
    Timer { id: grace; interval: 90000 }   // после закрытия бэкенд живёт ещё 90 с — повторное открытие мгновенное
    Timer { id: typing; interval: 40; onTriggered: menu.query() }
    onOpenChanged: {
        if (open) {
            if (!modeSet) mode = "apps"
            modeSet = false
            grace.stop(); closer.stop(); launching = ""; inChips = false; chip = "*"; match = null
            afterOpen.restart()                 // 30.10: перечитать список — после роста карточки (иначе рост терял кадры)
            fixSel()
            field.forceActiveFocus()
        } else {
            field.focus = false; grace.restart(); closer.restart(); toastText = ""; field.text = ""
        }
    }
    onModeChanged: { inChips = false; sel = 0; match = null; if (open) { query(); field.forceActiveFocus() } }
    onChipChanged: fixSel()
    Timer { id: closer; interval: Theme.normal; onTriggered: if (!menu.open && menu.ready) menu.query() }   // 30.10: полный список к следующему открытию
    Timer { id: afterOpen; interval: Theme.menuOpen + 60; onTriggered: if (menu.open && menu.ready) { menu.send({ cmd: "reload" }); menu.query() } }

    // ---- действия ----
    function close() { field.focus = false; Menus.close("launcher") }
    function activate(shift) {
        const t = selTile
        if (!t || !isVis(t)) return
        const r = cur.find(x => x.key === t.key && x.i !== undefined)
        if (!r) return
        launching = t.key
        send({ cmd: "act", i: r.i, shift: !!shift })
    }
    // ←→ — соседняя видимая плитка; ↑↓ — ближайшая видимая в другом ряду (погасшие пропускаются)
    function move(dx, dy) {
        if (!tiles.length) return
        if (dx) {
            for (let i = sel + dx; i >= 0 && i < tiles.length; i += dx) if (isVis(tiles[i])) { sel = i; show(i); return }
            return
        }
        const r = Math.floor(sel / cols), c = sel % cols
        let best = -1, score = 1e9
        for (let i = 0; i < tiles.length; i++) {
            if (!isVis(tiles[i])) continue
            const ri = Math.floor(i / cols)
            if (dy > 0 ? ri <= r : ri >= r) continue
            const s = Math.abs(ri - r) * 100 + Math.abs(i % cols - c)
            if (s < score) { score = s; best = i }
        }
        if (best >= 0) { sel = best; show(best) }
        else if (dy < 0 && apps) inChips = true
    }
    function chipStep(d) { const i = groups.findIndex(g => g.key === chip); chip = groups[(i + d + groups.length) % groups.length].key }
    function toggleMode(m) {
        if (open && mode === m) { close(); return }
        if (open) { mode = m; return }
        mode = m; modeSet = true; Menus.toggleCenter("launcher")
    }

    IpcHandler {
        target: "launcher"
        function apps(): void { menu.toggleMode("apps") }
        function files(): void { menu.toggleMode("files") }
        function search(text: string): void { field.text = text }
        function enter(shift: bool): void { menu.activate(shift) }
        function key(name: string): void {       // проверка навигации: left|right|up|down|tab
            if (name === "tab") menu.mode = menu.apps ? "files" : "apps"
            else if (menu.inChips) { if (name === "left") menu.chipStep(-1); else if (name === "right") menu.chipStep(1); else if (name === "down") menu.inChips = false }
            else menu.move(name === "left" ? -1 : name === "right" ? 1 : 0, name === "up" ? -1 : name === "down" ? 1 : 0)
        }
        function state(): string {
            return JSON.stringify({ open: menu.open, mode: menu.mode, chip: menu.chip, inChips: menu.inChips, q: field.text,
                                    sel: menu.selTile ? menu.selTile.name : "", tiles: menu.tiles.length,
                                    visible: menu.tiles.filter(t => menu.isVis(t)).length })
        }
    }

    // ---- окно: «Остров» (29.10) — карточка-остров по центру (как Popup: isl, radius 26, кромка, растёт пружиной) ----
    PanelWindow {
        id: win
        screen: Menus.screen
        visible: menu.open || closer.running
        color: "transparent"
        WlrLayershell.namespace: "yumi-qs-launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        // YUMI_QS_NOKB=1 — проверка без захвата клавиатуры (иначе тестовое окно на eDP-1 забирает ввод пользователя)
        WlrLayershell.keyboardFocus: menu.open && Quickshell.env("YUMI_QS_NOKB") !== "1" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: true; right: true }

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: menu.close() }   // клик мимо карточки — закрыть

        FocusScope {
            anchors.fill: parent

            Rectangle {
                id: card
                width: 700
                height: body.implicitHeight + 36
                x: Math.round((parent.width - width) / 2)
                y: Math.round(Math.max(Theme.barH + 24, (parent.height - (36 + 48 + 30 + menu.maxRows * menu.cellH + 110 + 48)) * 0.42))
                radius: Theme.radiusBig
                color: Colors.isl
                border.width: 1; border.color: Colors.edge
                Behavior on color { ColorAnimation { duration: Theme.normal } }
                Behavior on height { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                property real grow: menu.open ? 1 : 0
                Behavior on grow { NumberAnimation { duration: menu.open ? Theme.menuOpen : Theme.fast
                                                     easing.type: menu.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.15 } }
                transform: Scale { origin.x: card.width / 2; origin.y: 24
                                   xScale: 0.9 + 0.1 * card.grow; yScale: 0.85 + 0.15 * card.grow }
                opacity: Math.min(1, grow * 3)
                MouseArea { anchors.fill: parent; onClicked: field.forceActiveFocus() }   // клик по карточке не закрывает меню

                ColumnLayout {
                    id: body
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
                    spacing: 12
                    opacity: menu.open ? 1 : 0
                    Behavior on opacity { SequentialAnimation {
                        PauseAnimation { duration: menu.open ? Theme.contentDelay : 0 }
                        NumberAnimation { duration: menu.open ? 260 : 120; easing.type: Easing.OutCubic } } }

                    // ---- поиск 48 px (как IField, крупный) + режим Программы / Файлы ----
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 48; radius: 24
                            color: Colors.isl2
                            border.width: field.activeFocus && !menu.inChips ? 1.5 : 0; border.color: Colors.acc
                            Behavior on color { ColorAnimation { duration: Theme.normal } }
                            Glyph { id: lens; x: 16; anchors.verticalCenter: parent.verticalCenter; text: "󰍉"; font.pixelSize: 18; color: Colors.fgDim }
                            TextInput {
                                id: field
                                anchors { left: lens.right; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 16 }
                                font.family: Theme.fontUi; font.pixelSize: 15; color: Colors.fg
                                selectByMouse: true; selectionColor: Colors.alpha(Colors.acc, 0.4); selectedTextColor: Colors.fg
                                clip: true
                                onTextChanged: { if (menu.open) typing.restart(); if (!text) menu.match = null }
                                Keys.onPressed: (e) => {
                                    const k = e.key
                                    if (menu.inChips) {
                                        if (k === Qt.Key_Left) menu.chipStep(-1)
                                        else if (k === Qt.Key_Right) menu.chipStep(1)
                                        else if (k === Qt.Key_Down || k === Qt.Key_Return || k === Qt.Key_Enter) menu.inChips = false
                                        else if (k === Qt.Key_Escape) menu.inChips = false
                                        else return
                                        e.accepted = true; return
                                    }
                                    // раздел — прямо из сетки: Ctrl+↑↓ или PageUp/PageDown (Fn+↑↓)
                                    if (menu.apps && (k === Qt.Key_PageUp || k === Qt.Key_PageDown
                                                      || ((e.modifiers & Qt.ControlModifier) && (k === Qt.Key_Up || k === Qt.Key_Down)))) {
                                        menu.chipStep(k === Qt.Key_PageUp || k === Qt.Key_Up ? -1 : 1); e.accepted = true; return
                                    }
                                    if (k === Qt.Key_Left) menu.move(-1, 0)
                                    else if (k === Qt.Key_Right) menu.move(1, 0)
                                    else if (k === Qt.Key_Up) menu.move(0, -1)
                                    else if (k === Qt.Key_Down) menu.move(0, 1)
                                    else if (k === Qt.Key_Return || k === Qt.Key_Enter) menu.activate(e.modifiers & Qt.ShiftModifier)
                                    else if (k === Qt.Key_Tab || k === Qt.Key_Backtab) menu.mode = menu.apps ? "files" : "apps"
                                    else if (k === Qt.Key_Escape) { if (field.text) field.text = ""; else menu.close() }
                                    else return
                                    e.accepted = true
                                }
                                Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; visible: !field.text
                                       font.family: Theme.fontUi; font.pixelSize: 15; color: Colors.fgDim
                                       text: menu.apps ? "Найти программу" : "Имя файла или папки" }
                            }
                        }
                        ISeg {
                            Layout.fillWidth: false; Layout.preferredWidth: 200
                            model: ["Программы", "Файлы"]
                            current: menu.apps ? 0 : 1
                            onPicked: (i) => { menu.mode = i === 0 ? "apps" : "files"; field.forceActiveFocus() }
                        }
                    }

                    // ---- фишки разделов (в «Файлах» — строка состояния бэкенда) ----
                    Flow {
                        Layout.fillWidth: true
                        visible: menu.apps
                        spacing: 6
                        Repeater {
                            model: menu.apps ? menu.groups : []
                            IChip {
                                required property var modelData
                                text: modelData.text
                                on: menu.chip === modelData.key
                                border.width: on && menu.inChips ? 1.5 : 0; border.color: Colors.fg
                                onClicked: { menu.chip = modelData.key; menu.inChips = false; field.forceActiveFocus() }
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: !menu.apps
                        text: menu.sub || " "
                        elide: Text.ElideRight
                        font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim
                    }

                    // ---- сетка плиток ----
                    Item {
                        id: gridBox
                        Layout.fillWidth: true
                        implicitHeight: menu.maxRows * menu.cellH
                        GridView {
                            id: grid
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: menu.cols * menu.cellW
                            height: parent.height
                            cellWidth: menu.cellW; cellHeight: menu.cellH
                            interactive: true; clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            model: menu.tiles
                            highlightFollowsCurrentItem: false
                            Behavior on contentY { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 0.9 } }
                            delegate: Item {
                                id: tile
                                required property var modelData
                                required property int index
                                width: menu.cellW; height: menu.cellH
                                readonly property bool vis: menu.isVis(modelData)
                                readonly property bool on: !menu.inChips && index === menu.sel
                                // линза: соседи выбранной (в ряду и колонке) чуть крупнее
                                readonly property bool near: !menu.inChips && !on && vis
                                    && Math.abs(Math.floor(index / menu.cols) - Math.floor(menu.sel / menu.cols)) + Math.abs(index % menu.cols - menu.sel % menu.cols) === 1
                                readonly property bool flying: menu.launching !== "" && menu.launching === modelData.key
                                z: on ? 2 : 1
                                // каскад только при открытии и только для первых рядов (не больше 3 × 40 мс); при прокрутке — сразу
                                opacity: 0
                                property real dy: 8
                                transform: Translate { y: tile.dy }
                                states: State { when: menu.open; PropertyChanges { tile.opacity: 1; tile.dy: 0 } }
                                transitions: Transition {
                                    SequentialAnimation {
                                        PauseAnimation { duration: menu.open && tile.index < menu.cols * menu.maxRows ? Theme.contentDelay + 60 + Math.min(3, Math.floor(tile.index / menu.cols)) * Theme.cascade : 0 }
                                        NumberAnimation { properties: "opacity,dy"; duration: 280; easing.type: Easing.OutCubic } } }

                                Rectangle {   // ячейка: наведение isl2, выбранная — isl2 + кромка акцентом
                                    anchors.fill: parent; anchors.margins: 3
                                    radius: Theme.radiusTile
                                    color: tile.on || (area.containsMouse && tile.vis) ? Colors.isl2 : "transparent"
                                    border.width: tile.on ? 1.5 : 0; border.color: Colors.alpha(Colors.acc, 0.8)
                                    // 29.10: без затухания — подсветка уходившей ячейки тянулась «тенью» за выбором
                                    scale: area.pressed ? 0.94 : 1
                                    Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }

                                    Rectangle {   // плитка значка 52 px: градиент акцент 34 % → isl2
                                        id: ai
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: 12
                                        width: 52; height: 52; radius: 16
                                        gradient: Gradient {
                                            orientation: Gradient.Vertical
                                            GradientStop { position: 0; color: Colors.mix(Colors.isl2, Colors.acc, 0.34) }
                                            GradientStop { position: 1; color: Colors.isl2 }
                                        }
                                        scale: tile.flying ? 1.4 : !tile.vis ? 0.86 : tile.on ? 1.12 : tile.near ? 1.04 : 1
                                        opacity: tile.flying ? 0 : tile.vis ? 1 : 0.14
                                        Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
                                        Behavior on opacity { NumberAnimation { duration: tile.flying ? 260 : Theme.normal } }
                                        LIcon {
                                            anchors.centerIn: parent
                                            size: 32
                                            names: tile.modelData.icons || []
                                            path: tile.modelData.path || ""
                                        }
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: ai.y + ai.height + 9
                                        width: parent.width - 10
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        text: tile.modelData.name || ""
                                        font.family: Theme.fontUi; font.pixelSize: 12
                                        font.weight: tile.on ? Font.Medium : Font.Normal
                                        color: tile.on ? Colors.fg : Colors.alpha(Colors.fg, 0.85)
                                        opacity: tile.vis ? 1 : 0.22
                                        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                                    }
                                }
                                MouseArea {
                                    id: area
                                    anchors.fill: parent; hoverEnabled: true; enabled: tile.vis; cursorShape: Qt.PointingHandCursor
                                    onClicked: (m) => { menu.inChips = false; menu.sel = tile.index; menu.activate(m.modifiers & Qt.ShiftModifier); field.forceActiveFocus() }
                                }
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter; y: 60
                            visible: menu.ready && (menu.tiles.length === 0 || menu.firstVis() < 0)
                            text: menu.apps ? "Ничего не найдено" : (field.text ? "Ничего не найдено" : "Недавних файлов нет")
                            font.family: Theme.fontUi; font.pixelSize: 14; color: Colors.fgDim
                        }
                    }

                    // ---- выбранная: название · описание · раздел; справа раздел и число ----
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            Layout.maximumWidth: card.width * 0.4
                            elide: Text.ElideRight
                            text: menu.toastText || (menu.selTile && menu.isVis(menu.selTile) ? menu.selTile.name : " ")
                            font.family: Theme.fontUi; font.pixelSize: 14; font.weight: Font.DemiBold
                            color: menu.toastText ? (menu.toastError ? Colors.bad : Colors.acc) : Colors.fg
                        }
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideMiddle
                            text: {
                                const t = menu.selTile
                                if (!t || menu.toastText || !menu.isVis(t)) return " "
                                return [t.sub, t.badge, t.cat && menu.apps ? t.cat : ""].filter(x => x).join("  ·  ") || " "
                            }
                            font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim
                        }
                        Text {
                            visible: menu.dry
                            text: "DRY-RUN"; font.family: Theme.fontUi; font.pixelSize: 9; font.weight: Font.DemiBold; font.letterSpacing: 1; color: Colors.acc
                        }
                        Text {
                            readonly property var grp: menu.apps ? (menu.groups.find(g => g.key === menu.chip) || menu.groups[0]) : { key: "files", text: "Файлы" }
                            text: grp.text + " · " + (menu.apps ? menu.tiles.filter(t => menu.isVis(t)).length : menu.tiles.length)
                            font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim; font.features: ({ "tnum": 1 })
                        }
                    }

                    CardHints {
                        items: menu.inChips ? [["←→", "раздел"], ["↓", "к программам"], ["Esc", "назад"]]
                             : menu.apps ? [["↑↓←→", "выбрать"], ["Enter", "запустить"], ["Ctrl ↑↓", "категория"], ["Tab", "файлы"], ["Esc", "закрыть"]]
                                         : [["↑↓←→", "выбрать"], ["Enter", "открыть"], ["Shift Enter", "папка"], ["Tab", "программы"], ["Esc", "закрыть"]]
                    }
                }
            }
        }
    }
}
