import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services

// Меню «Обои» на QML. Содержимое и подписи — как у ~/.local/bin/yumi-menu-wallpaper (GTK-меню остаётся рабочим):
// сетка миниатюр 4 в ряд из ~/Pictures/Wallpapers, коллекции (папки) кнопками, поиск по имени и коллекции,
// текущие обои отмечены, «Случайные», «Открыть папку». Применение — `yumi-wallpaper set ФАЙЛ` (через бэкенд).
// Бэкенд ~/.local/lib/yumi/qs/wallpaper (список + sha1 → миниатюры ~/.cache/yumi/theme/thumbs/<sha1>.thmb; применение).
// Сетка — GridView с переиспользованием делегатов: на экране только видимые плитки, без каскада.
// Клавиши: печать — поиск, ↓/↑ (и ←/→ при пустом поиске) — выбор, Enter — применить, Esc — очистить поиск / закрыть.
// Открыть: qs -c yumi ipc call menu center wallpaper (бинд SUPER+SHIFT+W: по центру в фокусе) · menu toggle wallpaper.
// Проверка: YP_DRYRUN=1 (обои не меняются, папка не открывается, окно не закрывается);
//   qs … ipc call wallpaper search <текст> · wallpaper apply <N> · wallpaper random · wallpaper hover <N>
Scope {
    id: menu
    readonly property bool open: Menus.current === "wallpaper"
    readonly property string home: Quickshell.env("HOME")
    readonly property string backend: home + "/.local/lib/yumi/qs/wallpaper"
    readonly property int cols: 4
    readonly property int gap: 10

    // ---- данные ----
    property bool loaded: false
    property bool dry: false
    property string dir: ""
    property string current: ""
    property var walls: []                 // [{path, name, file, key, coll, thumb}]
    property string listSig: ""
    property var colls: []                 // [{key, label, n}] — пусто, если подпапок нет
    property string coll: "*"              // выбранная коллекция ("*" — все)
    property string query: ""
    property var shown: []                 // видимые плитки (объекты из walls)
    property int sel: 0
    property bool nav: false               // клавиатура в сетке (стрелки двигают выбор)
    property string applying: ""           // путь применяемых обоев
    property string hoverName: ""
    property string toastText: ""
    property bool toastError: false

    function toast(text, error, hold) { toastText = text; toastError = !!error; toastTimer.interval = (hold || 3) * 1000; toastTimer.restart() }
    Timer { id: toastTimer; interval: 3000; onTriggered: menu.toastText = "" }
    function curName() { const w = walls.find(x => x.path === current); return w ? w.name : "" }
    function subtitle() {
        if (toastText) return toastText
        if (hoverName) return "󰋩  " + hoverName
        if (nav && shown[sel]) return "󰋩  " + shown[sel].name
        if (!loaded) return "Читаю папку…"
        const n = walls.length
        const count = shown.length === n ? n + " обоев" : "найдено " + shown.length + " из " + n
        const cur = curName()
        return cur ? count + "  ·  󰄬 " + cur : count
    }

    function visibleWall(w) { return (coll === "*" || w.coll === coll) && (!query || w.key.indexOf(query) >= 0) }
    // как on_search(): фильтр, выбор (прежний, если виден, иначе первый), прокрутка
    function refilter(keepScroll) {
        const prev = shown[sel]
        const v = walls.filter(visibleWall)
        shown = v
        let i = prev ? v.indexOf(prev) : -1
        if (i < 0) i = 0
        sel = i
        if (!keepScroll) grid.positionViewAtBeginning()
        if (prev && v.indexOf(prev) >= 0) Qt.callLater(() => grid.positionViewAtIndex(menu.sel, GridView.Contain))
    }
    function buildColls() {
        const names = [...new Set(walls.map(w => w.coll).filter(c => c))].sort()
        if (!names.length) { colls = []; return }
        const out = [{ key: "*", label: "Все", n: walls.length }]
        for (const c of names) out.push({ key: c, label: /^\d\d/.test(c) && c.indexOf(" ") > 0 ? c.slice(c.indexOf(" ") + 1) : c, n: walls.filter(w => w.coll === c).length })
        colls = out
    }
    function pickColl(key) { coll = key; refilter(false); field.forceActiveFocus() }
    onQueryChanged: { nav = false; refilter(false) }

    // ---- бэкенд ----
    Process {
        id: lister
        command: [menu.backend, "list"]
        stdout: StdioCollector { onStreamFinished: menu.takeList(text) }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) console.log("wallpaper:", text.trim()) }
    }
    function takeList(text) {
        let j
        try { j = JSON.parse(text) } catch (e) { console.log("wallpaper: не JSON"); return }
        dry = j.dry; dir = j.dir; current = j.current
        const sig = JSON.stringify(j.items)
        if (sig !== listSig || !shown.length) {   // список не изменился — сетку не трогаем (прокрутка и выбор остаются)
            listSig = sig; walls = j.items; buildColls(); refilter(true)
            const ci = shown.findIndex(w => w.path === current)
            if (ci >= 0) { sel = ci; Qt.callLater(() => grid.positionViewAtIndex(ci, GridView.Center)) }
        }
        loaded = true
    }
    Process {
        id: setter
        property string target: ""
        property string name: ""
        stdout: StdioCollector { onStreamFinished: menu.applied(setter.name, text) }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) console.log("wallpaper:", text.trim()) }
    }

    // ---- действия (как apply / applied / random / open_folder) ----
    function apply(w) {
        if (!w) return
        if (applying) { toast("Подождите — обои ещё применяются…", false, 2); return }
        if (w.path === current) { toast("Уже стоят: " + w.name, false, 2); return }
        applying = w.path
        toast("Применяю: " + w.name + "…", false, 60)
        setter.target = w.path; setter.name = w.name
        setter.command = [backend, "set", w.path]
        setter.running = true
    }
    function applied(name, text) {
        applying = ""
        let j = null
        try { j = JSON.parse(text) } catch (e) {}
        if (j && j.ok) {
            current = j.current
            toast((j.dry ? "[проверка] " : "") + "󰄬 Обои: " + name, false, 3)
            if (!j.dry) closeLater.restart()      // обои сменились — меню закрывается само (галочку видно ~0,6 с)
        } else {
            const lines = ((j && j.out) || "").trim().split("\n")
            toast("Не удалось: " + ((lines[lines.length - 1] || "ошибка").slice(0, 80)), true, 6)
        }
    }
    Timer { id: closeLater; interval: 600; onTriggered: menu.close() }
    function random() {
        const pool = shown.filter(w => w.path !== current)
        if (!pool.length) { toast("Нет других обоев", false, 2); return }
        const w = pool[Math.floor(Math.random() * pool.length)]
        sel = shown.indexOf(w); grid.positionViewAtIndex(sel, GridView.Contain)
        apply(w)
    }
    function openFolder() {
        if (dry) { console.log("[dry-run] xdg-open", dir); toast("[проверка] открыть папку", false, 2); return }
        Quickshell.execDetached(["xdg-open", dir])
        close()
    }
    function close() { field.focus = false; Menus.close("wallpaper") }
    function move(step) {
        if (!shown.length) return
        sel = Math.max(0, Math.min(shown.length - 1, sel + step))
        grid.positionViewAtIndex(sel, GridView.Contain)
    }

    onOpenChanged: {
        if (open) {
            closeLater.stop(); dropRows.stop()
            nav = false; hoverName = ""
            if (walls.length && !shown.length) { refilter(true); const ci = shown.findIndex(w => w.path === current); if (ci >= 0) { sel = ci; Qt.callLater(() => grid.positionViewAtIndex(ci, GridView.Center)) } }
            lister.running = true
            field.forceActiveFocus()
        } else {
            field.focus = false
            toastText = ""; hoverName = ""
            if (field.text) field.text = ""
            dropRows.restart()
        }
    }
    // после закрытия плитки (и картинки в памяти) освобождаются; список путей остаётся — повторное открытие мгновенное
    Timer { id: dropRows; interval: 600; onTriggered: if (!menu.open) { menu.shown = []; menu.coll = "*" } }

    IpcHandler {
        target: "wallpaper"
        function search(text: string): void { field.text = text }
        function apply(n: int): void { menu.apply(menu.shown[n]) }
        function random(): void { menu.random() }
        function folder(): void { menu.openFolder() }
        function hover(n: int): void { menu.hoverName = menu.shown[n] ? menu.shown[n].name : "" }
        function select(n: int): void { menu.nav = true; menu.sel = n; grid.positionViewAtIndex(n, GridView.Contain) }
    }

    Popup {
        id: pop
        name: "wallpaper"
        open: menu.open
        screen: Menus.screen
        contentW: 720                              // шире обычного меню: сетка 4 в ряд (как WIDTH в GTK)
        marginTop: Theme.barH * (Theme.dev ? 2 : 1) + 6
        fixedH: body.implicitHeight + 36
        contentH: body.implicitHeight + 36
        pad: 18
        closeOnLeave: false                        // меню по бинду: только Esc, повтор бинда, клик вне, выбор

        // общая маска скругления для всех плиток (одна текстура вместо сотни)
        Item {
            id: tileMask
            width: grid.cellWidth - menu.gap; height: grid.cellHeight - menu.gap
            layer.enabled: true; visible: false
            Rectangle { anchors.fill: parent; radius: 16; color: "black" }
        }

        FocusScope {
            anchors.fill: parent
            focus: true

            ColumnLayout {
                id: body
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                spacing: 12

                // ---- шапка ----
                CardHead {
                    title: "Обои"; dry: menu.dry
                    status: menu.subtitle()
                    statusColor: menu.toastText ? (menu.toastError ? Colors.bad : Colors.acc) : Colors.fgDim
                }

                // ---- поиск ----
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 40; radius: 20      // «Остров»: как IField
                    color: Colors.isl2
                    border.width: field.activeFocus && !menu.nav ? 1.5 : 0; border.color: Colors.acc
                    Glyph { id: lens; anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: "󰍉"; font.pixelSize: 16; color: Colors.fgDim }
                    TextInput {
                        id: field
                        anchors { left: lens.right; right: clear.left; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 8 }
                        font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fg
                        selectByMouse: true; selectionColor: Colors.alpha(Colors.acc, 0.35); selectedTextColor: Colors.fg
                        clip: true
                        onTextChanged: menu.query = text.trim().toLowerCase()
                        Keys.onPressed: (e) => {
                            const k = e.key
                            if (k === Qt.Key_Escape) { if (field.text) field.text = ""; else menu.close(); e.accepted = true }
                            else if (k === Qt.Key_Return || k === Qt.Key_Enter) { menu.apply(menu.shown[menu.sel]); e.accepted = true }
                            else if (k === Qt.Key_Down || k === Qt.Key_Up || k === Qt.Key_PageDown || k === Qt.Key_PageUp) {
                                const step = { [Qt.Key_Down]: menu.cols, [Qt.Key_Up]: -menu.cols, [Qt.Key_PageDown]: menu.cols * 3, [Qt.Key_PageUp]: -menu.cols * 3 }[k]
                                if (!menu.nav) { menu.nav = true; grid.positionViewAtIndex(menu.sel, GridView.Contain) } else menu.move(step)
                                e.accepted = true
                            } else if ((k === Qt.Key_Left || k === Qt.Key_Right) && (menu.nav || !field.text)) {
                                if (!menu.nav) menu.nav = true; else menu.move(k === Qt.Key_Right ? 1 : -1)
                                e.accepted = true
                            }
                        }
                        Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; visible: !field.text; text: "Поиск по имени"; font: field.font; color: Colors.fgDim }
                    }
                    Glyph {
                        id: clear
                        anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                        text: "󰅖"; font.pixelSize: 14; color: Colors.fgDim
                        opacity: field.text ? 1 : 0; Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                        MouseArea { anchors.fill: parent; enabled: field.text.length > 0; onClicked: { field.text = ""; field.forceActiveFocus() } }
                    }
                }

                // ---- коллекции (папки) ----
                Flow {
                    Layout.fillWidth: true
                    visible: menu.colls.length > 0
                    spacing: 6
                    Repeater {
                        model: menu.colls
                        delegate: IChip {
                            required property var modelData
                            text: modelData.label + "  " + modelData.n
                            on: menu.coll === modelData.key
                            onClicked: menu.pickColl(modelData.key)
                        }
                    }
                }

                // ---- сетка миниатюр ----
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 3 * grid.cellHeight + Math.round(grid.cellHeight / 2)   // видно 3,5 ряда — понятно, что есть ещё
                    GridView {
                        id: grid
                        anchors.fill: parent
                        anchors.rightMargin: -menu.gap          // последний столбец без лишнего зазора справа
                        cellWidth: Math.floor((parent.width + menu.gap) / menu.cols)
                        cellHeight: Math.round((cellWidth - menu.gap) * 9 / 16) + menu.gap
                        clip: true
                        reuseItems: true
                        cacheBuffer: cellHeight * 2
                        boundsBehavior: Flickable.StopAtBounds
                        model: menu.shown
                        delegate: Item {
                            id: cell
                            required property var modelData
                            required property int index
                            width: grid.cellWidth; height: grid.cellHeight
                            WallTile {
                                width: grid.cellWidth - menu.gap; height: grid.cellHeight - menu.gap
                                source: cell.modelData.thumb || cell.modelData.path
                                name: cell.modelData.name
                                current: cell.modelData.path === menu.current
                                selected: menu.nav && cell.index === menu.sel
                                applying: cell.modelData.path === menu.applying
                                hovered: area.containsMouse
                                mask: tileMask
                                dpr: pop.screen ? pop.screen.devicePixelRatio : 1
                                scale: area.pressed ? 0.94 : (area.containsMouse ? 1.03 : 1)
                                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
                                MouseArea {
                                    id: area; anchors.fill: parent; hoverEnabled: true
                                    onContainsMouseChanged: { if (containsMouse) menu.hoverName = cell.modelData.name; else if (menu.hoverName === cell.modelData.name) menu.hoverName = "" }
                                    onClicked: { menu.sel = cell.index; menu.apply(cell.modelData) }
                                }
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent; font.family: Theme.fontUi
                        visible: menu.loaded && !menu.shown.length
                        horizontalAlignment: Text.AlignHCenter
                        text: menu.walls.length ? "Ничего не найдено" : "В папке нет обоев\n" + menu.dir
                        color: Colors.fgDim; font.pixelSize: 14
                    }
                }

                // ---- кнопки ----
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    IButton { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰒝"; text: "Случайные"; primary: true; onClicked: menu.random() }
                    IButton { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰉋"; text: "Открыть папку"; onClicked: menu.openFolder() }
                }
            }
        }
    }
}
