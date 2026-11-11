import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services
import "Search.js" as Search

// Меню «Эмодзи / Символы» на QML. Содержимое и подписи — как у ~/.local/bin/yumi-menu-picker (GTK-меню остаётся рабочим):
// вкладки Эмодзи / Символы Nerd Font, поиск (рус/англ: русские слова переводятся по словарю — Search.js), недавние,
// сетка 9 в ряд (GridView: из 10 тыс. глифов на экране только видимые ячейки, делегаты переиспользуются).
// Выбор: символ копируется (wl-copy), меню закрывается, через 120 мс `wtype -- СИМВОЛ` печатает его в окно с фокусом.
// Shift+Enter / Shift+щелчок — только скопировать. YUMI_PICKER_PASTE=0 — всегда только копировать.
// Данные и недавние — бэкенд ~/.local/lib/yumi/qs/picker (базы ~/.local/share/yumi-panel/data, недавние ~/.cache/yumi-panel).
// Клавиши: печать — поиск, ↓ — к сетке, стрелки/PgUp/PgDn/Home/End — выбор, ↑ с первого ряда — назад к поиску,
// Enter — вставить, Shift+Enter — копия, Ctrl+Tab — вкладка, Esc — очистить поиск / закрыть.
// Открыть (по центру в фокусе): qs -c yumi ipc call picker emoji (бинд SUPER+,) · picker glyph (бинд SUPER+.);
// повторный вызов любого из двух закрывает меню (как один id у GTK).
// Проверка: YP_DRYRUN=1 — ничего не копируется и не вставляется (печатается в журнал), недавние не пишутся;
//   qs … ipc call picker search <текст> · picker select <N> · picker pick <N> · picker copy <N> · picker hover <N>
Scope {
    id: menu
    readonly property bool open: Menus.current === "picker"
    readonly property string home: Quickshell.env("HOME")
    readonly property string backend: home + "/.local/lib/yumi/qs/picker"
    readonly property bool dry: Quickshell.env("YP_DRYRUN") === "1"
    readonly property bool pasteOn: Quickshell.env("YUMI_PICKER_PASTE") !== "0"
    readonly property int cols: 9                 // «Остров»: 9 в ряд, как превью
    readonly property int rowsVisible: 6
    readonly property int cell: 46
    readonly property int recentMax: 27

    readonly property var kinds: ({
        emoji: { title: "Эмодзи", icon: "󰇵", hint: "Поиск: smile, сердце, огонь…", unit: "эмодзи" },
        glyph: { title: "Символы", icon: "󰬴", hint: "Поиск: arrow, git, папка, linux…", unit: "символов" }
    })
    property string kind: "emoji"
    property var data: ({})                // вид → {items, recent, path, file, dir}
    readonly property var cur: data[kind] || null
    readonly property var items: cur ? cur.items : []
    property var byChar: ({})
    property var shown: null               // индексы выдачи; null — вся база по порядку
    readonly property int count: shown ? shown.length : items.length
    property string query: ""
    property int sel: 0
    property bool nav: false               // клавиатура в сетке
    property string hoverText: ""
    readonly property var recentShown: cur ? cur.recent.filter(c => byChar[c] !== undefined).slice(0, cols) : []

    function idx(i) { return shown ? shown[i] : i }
    function itemAt(i) { return i >= 0 && i < count ? items[idx(i)] : null }
    function subtitle() {
        if (hoverText) return hoverText
        if (nav && itemAt(sel)) return itemAt(sel)[0] + "  " + itemAt(sel)[1]
        if (!cur) return "Загружаю…"
        return query ? "найдено " + count + " из " + items.length : items.length + " " + kinds[kind].unit
    }

    function refilter() {
        shown = query ? Search.filter(items, query) : null
        sel = 0
        grid.positionViewAtBeginning()
    }
    Timer { id: searchLater; interval: 60; onTriggered: menu.refilter() }    // не пересчитывать 10 тыс. на каждую букву
    onQueryChanged: { nav = false; searchLater.restart() }
    function rebuild() {
        const m = {}
        for (let i = 0; i < items.length; i++) m[items[i][0]] = i
        byChar = m
        refilter()
    }
    function setKind(k) {
        if (kind === k && cur) return
        kind = k; nav = false; hoverText = ""
        if (!data[k]) load(k); else rebuild()
    }

    // ---- бэкенд ----
    Process {
        id: loader
        property string what: ""
        stdout: StdioCollector { onStreamFinished: menu.take(loader.what, text) }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) console.log("picker:", text.trim()) }
    }
    function load(k) { if (loader.running) return; loader.what = k; loader.command = [backend, "load", k]; loader.running = true }
    function take(k, text) {
        let j
        try { j = JSON.parse(text) } catch (e) { console.log("picker: не JSON"); return }
        const d = Object.assign({}, data); d[k] = { items: j.items, recent: j.recent, path: j.path, file: j.file, dir: j.dir }; data = d
        if (k === kind) rebuild()
        else if (!data[kind]) load(kind)
    }
    // закрыто 2 минуты — базы (10 тыс. строк) отпускаются, открытие снова читает их (~30 мс)
    Timer { id: afterOpen; interval: Theme.menuOpen + 60; onTriggered: if (menu.open && !menu.data[menu.kind]) menu.load(menu.kind) }
    Timer { id: dropData; interval: 120000; onTriggered: if (!menu.open) { menu.data = {}; menu.shown = null; menu.byChar = {} } }

    // ---- выбор (как choose_item) ----
    function choose(it, paste) {
        if (!it) return
        const ch = it[0]
        const rec = [ch].concat(cur.recent.filter(c => c !== ch)).slice(0, recentMax)
        const d = Object.assign({}, data); d[kind] = Object.assign({}, cur, { recent: rec }); data = d
        Quickshell.execDetached([backend, "recent", kind, JSON.stringify(rec)])
        paste = paste && pasteOn
        if (dry) {
            const cps = Array.from(ch).map(c => "U+" + c.codePointAt(0).toString(16).toUpperCase().padStart(4, "0")).join(" ")
            console.log("[dry-run] wl-copy --", ch, "  (" + cps + ")")
            console.log(paste ? "[dry-run] закрыть меню; через 120 мс: wtype -- " + ch : "[dry-run] закрыть меню (только копия)")
            close()
            return
        }
        Quickshell.execDetached(["wl-copy", "--", ch])
        // отдельный процесс: меню закрывается сразу, фокус возвращается окну, потом печатаем строку целиком (эмодзи с ZWJ тоже)
        if (paste) Quickshell.execDetached(["sh", "-c", "sleep 0.12; exec wtype -- \"$1\"", "yumi-picker-paste", ch])
        close()
    }
    function close() { field.focus = false; Menus.close("picker") }
    function move(step) {
        if (!count) return
        if (step < 0 && sel < cols && -step <= cols) { nav = false; return }    // ↑ с первого ряда — к поиску
        sel = Math.max(0, Math.min(count - 1, sel + step))
        grid.positionViewAtIndex(sel, GridView.Contain)
    }
    function openAs(k) {
        if (open) { Menus.close("picker"); return }          // повторный бинд закрывает (любой вид)
        setKind(k)
        Menus.toggleCenter("picker")
    }

    onOpenChanged: {
        if (open) {
            dropData.stop(); nav = false; hoverText = ""
            if (!data[kind]) afterOpen.restart()     // 30.10: загрузка — после роста карточки
            field.forceActiveFocus()
        } else {
            field.focus = false
            hoverText = ""
            if (field.text) field.text = ""
            dropData.restart()
        }
    }

    IpcHandler {
        target: "picker"
        function emoji(): void { menu.openAs("emoji") }
        function glyph(): void { menu.openAs("glyph") }
        function search(text: string): void { field.text = text }
        function select(n: int): void { menu.nav = true; menu.sel = n; grid.positionViewAtIndex(n, GridView.Contain) }
        function hover(n: int): void { const it = menu.itemAt(n); menu.hoverText = it ? it[0] + "  " + it[1] : "" }
        function pick(n: int): void { menu.choose(menu.itemAt(n), true) }
        function copy(n: int): void { menu.choose(menu.itemAt(n), false) }
    }

    Popup {
        id: pop
        name: "picker"
        open: menu.open
        screen: Menus.screen
        contentW: 460                              // «Остров»: как превью
        pad: 18
        marginTop: Theme.barH * (Theme.dev ? 2 : 1) + 6
        fixedH: body.implicitHeight + 36
        contentH: body.implicitHeight + 36
        closeOnLeave: false

        FocusScope {
            anchors.fill: parent
            focus: true

            ColumnLayout {
                id: body
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                spacing: 12

                CardHead {
                    title: menu.kinds[menu.kind].title; dry: menu.dry
                    status: !menu.cur ? "Загружаю…" : menu.query ? "найдено " + menu.count + " из " + menu.items.length : menu.items.length + " " + menu.kinds[menu.kind].unit
                }

                // ---- вкладки — ISeg ----
                ISeg {
                    model: ["Эмодзи", "Символы Nerd Font"]
                    current: menu.kind === "emoji" ? 0 : 1
                    onPicked: (i) => { menu.setKind(i === 0 ? "emoji" : "glyph"); field.forceActiveFocus() }
                }

                // ---- поиск (как IField) ----
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 40; radius: 20
                    color: Colors.isl2
                    border.width: field.activeFocus && !menu.nav ? 1.5 : 0; border.color: Colors.acc
                    Glyph { id: lens; anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: "󰍉"; font.pixelSize: 16; color: Colors.fgDim }
                    TextInput {
                        id: field
                        anchors { left: lens.right; right: clear.left; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 8 }
                        font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fg
                        selectByMouse: true; selectionColor: Colors.alpha(Colors.acc, 0.4); selectedTextColor: Colors.fg
                        clip: true
                        onTextChanged: menu.query = text.trim()
                        Keys.onPressed: (e) => {
                            const k = e.key, ctrl = e.modifiers & Qt.ControlModifier, shift = e.modifiers & Qt.ShiftModifier
                            if (ctrl && (k === Qt.Key_Tab || k === Qt.Key_Backtab || k === Qt.Key_PageDown || k === Qt.Key_PageUp)) {
                                menu.setKind(menu.kind === "emoji" ? "glyph" : "emoji"); e.accepted = true
                            } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                                menu.choose(menu.itemAt(menu.sel), !shift); e.accepted = true
                            } else if (k === Qt.Key_Escape) {
                                if (field.text) field.text = ""; else menu.close(); e.accepted = true
                            } else if (!menu.nav && (k === Qt.Key_Down || k === Qt.Key_PageDown)) {
                                if (menu.count) { menu.nav = true; grid.positionViewAtIndex(menu.sel, GridView.Contain) }
                                e.accepted = true
                            } else if (menu.nav) {
                                const page = menu.cols * menu.rowsVisible
                                const step = { [Qt.Key_Right]: 1, [Qt.Key_Left]: -1, [Qt.Key_Down]: menu.cols, [Qt.Key_Up]: -menu.cols,
                                               [Qt.Key_PageDown]: page, [Qt.Key_PageUp]: -page, [Qt.Key_Home]: -menu.count, [Qt.Key_End]: menu.count }[k]
                                if (step !== undefined) { if (k === Qt.Key_Home || k === Qt.Key_End) { menu.sel = k === Qt.Key_Home ? 0 : menu.count - 1; grid.positionViewAtIndex(menu.sel, GridView.Contain) } else menu.move(step); e.accepted = true }
                            }
                        }
                        Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; visible: !field.text; text: menu.kinds[menu.kind].hint; font.family: Theme.fontUi; font.pixelSize: 13
                               color: Colors.fgDim; elide: Text.ElideRight }
                    }
                    Glyph {
                        id: clear
                        anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                        text: "󰅖"; font.pixelSize: 14; color: Colors.fgDim
                        opacity: field.text ? 1 : 0; Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                        MouseArea { anchors.fill: parent; anchors.margins: -6; enabled: field.text.length > 0; onClicked: { field.text = ""; field.forceActiveFocus() } }
                    }
                }

                // ---- недавние: один ряд постоянной высоты ----
                ISection { text: "Недавние" }
                Item {
                    Layout.fillWidth: true
                    implicitHeight: menu.cell
                    Text { anchors.verticalCenter: parent.verticalCenter; leftPadding: 4; visible: !menu.recentShown.length
                           text: "Здесь появятся выбранные символы"; font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fgDim }
                    Row {
                        Repeater {
                            model: menu.recentShown
                            delegate: Item {
                                id: rb
                                required property string modelData
                                readonly property var item: menu.items[menu.byChar[modelData]]
                                width: Math.floor(body.width / menu.cols); height: menu.cell
                                Rectangle {
                                    anchors.fill: parent; anchors.margins: 2; radius: 10
                                    color: rbArea.containsMouse ? Colors.isl2 : "transparent"
                                    scale: rbArea.pressed ? 0.94 : rbArea.containsMouse ? 1.18 : 1
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
                                    Text {
                                        anchors.centerIn: parent; text: rb.modelData; color: Colors.fg
                                        font.family: menu.kind === "emoji" ? "Apple Color Emoji" : Theme.fontIcon
                                        font.pixelSize: menu.kind === "emoji" ? 26 : 19
                                    }
                                }
                                MouseArea {
                                    id: rbArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onContainsMouseChanged: menu.hoverText = containsMouse && rb.item ? rb.item[0] + "  " + rb.item[1] : ""
                                    onClicked: (m) => menu.choose(rb.item, !(m.modifiers & Qt.ShiftModifier))
                                }
                            }
                        }
                    }
                }

                // ---- сетка 9 в ряд: наведение — подложка и пружинное увеличение ----
                ISection { text: menu.query ? "Найдено: " + menu.count : "Все" }
                Item {
                    Layout.fillWidth: true
                    implicitHeight: menu.cell * menu.rowsVisible
                    GridView {
                        id: grid
                        anchors.fill: parent
                        cellWidth: Math.floor(width / menu.cols); cellHeight: menu.cell
                        clip: true
                        reuseItems: true
                        cacheBuffer: cellHeight * 2
                        boundsBehavior: Flickable.StopAtBounds
                        model: menu.count
                        delegate: Item {
                            id: gcell
                            required property int index
                            readonly property var item: menu.itemAt(index)
                            readonly property bool picked: index === menu.sel
                            width: grid.cellWidth; height: grid.cellHeight
                            z: gcArea.containsMouse ? 2 : 1
                            Rectangle {
                                anchors.fill: parent; anchors.margins: 2; radius: 10
                                color: gcell.picked && menu.nav ? Colors.alpha(Colors.acc, 0.16) : (gcArea.containsMouse ? Colors.isl2 : "transparent")
                                border.width: gcell.picked && menu.nav ? 1.5 : 0
                                border.color: Colors.alpha(Colors.acc, 0.8)
                                Behavior on color { ColorAnimation { duration: 160 } }
                                scale: gcArea.pressed ? 0.94 : (gcArea.containsMouse || (gcell.picked && menu.nav)) ? 1.18 : 1
                                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
                                Text {
                                    anchors.centerIn: parent; text: gcell.item ? gcell.item[0] : ""; color: Colors.fg
                                    font.family: menu.kind === "emoji" ? "Apple Color Emoji" : Theme.fontIcon
                                    font.pixelSize: menu.kind === "emoji" ? 26 : 20
                                }
                            }
                            MouseArea {
                                id: gcArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onContainsMouseChanged: { if (containsMouse && gcell.item) menu.hoverText = gcell.item[0] + "  " + gcell.item[1]; else if (!containsMouse) menu.hoverText = "" }
                                onClicked: (m) => { menu.sel = gcell.index; menu.choose(gcell.item, !(m.modifiers & Qt.ShiftModifier)) }
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent; width: parent.width - 40
                        visible: !!menu.cur && !menu.count
                        horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                        text: menu.cur && !menu.items.length ? "Нет базы " + menu.cur.file + "\n(ищется в " + menu.cur.dir + ")" : "Ничего не найдено"
                        color: Colors.fgDim; font.family: Theme.fontUi; font.pixelSize: 13
                    }
                }

                // ---- выбранный символ строкой: что вставится (имя и код) ----
                Rectangle {
                    id: infoBox
                    Layout.fillWidth: true; implicitHeight: 40; radius: Theme.radius
                    readonly property string info: menu.hoverText || (menu.itemAt(menu.sel) ? menu.itemAt(menu.sel)[0] + "  " + menu.itemAt(menu.sel)[1] : "")
                    readonly property string ch: info.split("  ")[0] || ""
                    color: Colors.isl2
                    opacity: info.length > 0 ? 1 : 0
                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        spacing: 10
                        Text { text: infoBox.ch; color: Colors.fg
                               font.family: menu.kind === "emoji" ? "Apple Color Emoji" : Theme.fontIcon; font.pixelSize: 18 }
                        Text { Layout.fillWidth: true; elide: Text.ElideRight; font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fg
                               text: infoBox.info.split("  ").slice(1).join("  ") }
                        Text { font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim; font.features: ({ "tnum": 1 })
                               text: { const s = infoBox.ch, out = []
                                      for (let i = 0; i < s.length;) { const cp = s.codePointAt(i); out.push("U+" + cp.toString(16).toUpperCase().padStart(4, "0")); i += cp > 0xffff ? 2 : 1 }
                                      return out.join(" ") } }
                    }
                }
                CardHints {
                    items: [["Enter", menu.pasteOn ? "вставить" : "скопировать"], ["Shift Enter", "копия"], ["Ctrl Tab", "вкладка"], ["Esc", "закрыть"]]
                    note: menu.dry ? "проверка: без копирования и вставки" : ""
                }
            }
        }
    }
}
