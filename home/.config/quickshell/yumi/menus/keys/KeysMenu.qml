import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services

// Меню «Горячие клавиши» на QML — содержимое и подписи как у ~/.local/bin/yumi-menu-keys (GTK-меню остаётся рабочим):
// живые бинды Hyprland (`hyprctl binds -j`), группы из описаний «[Группа|Подгруппа] текст» (названия по-русски),
// одинаковые описания собраны в одну строку («или»). Поиск на лету по описанию, группе, клавише.
// Бинды — Lua-функции Hyprland, запустить их отсюда нельзя: Enter / щелчок копирует сочетание (запись binds.lua).
// Клавиши: набор — поиск; ↑/↓ — выбор; Enter — скопировать выбранное (первое найденное); Esc — очистить поиск / закрыть.
// Разбор — бэкенд ~/.local/lib/yumi/qs/keys (разовый запуск при открытии; YP_KEYS_JSON=файл — бинды из файла).
//   qs -c yumi ipc call menu center keys (по центру — бинд, меню «Система») · menu toggle keys · keys search <текст>
// YP_DRYRUN=1 — копирование только пишется в журнал, буфер не меняется.
Scope {
    id: menu
    readonly property bool open: Menus.current === "keys"
    readonly property bool dry: Quickshell.env("YP_DRYRUN") === "1"
    property var groups: []
    property int nBinds: 0
    property int total: 0
    property bool loaded: false
    property string query: ""
    property var rows: []                  // [{head:true,name,n} | {e: запись}]
    property int shown: 0
    property int sel: -1                   // индекс выбранной строки в rows
    property string toastText: ""
    property bool toastError: false
    function toast(t, err) { toastText = t; toastError = !!err; toastTimer.restart() }
    Timer { id: toastTimer; interval: 4000; onTriggered: menu.toastText = "" }

    readonly property string sub: toastText ? toastText
        : !loaded ? "Читаю бинды…"
        : query.trim() ? "Найдено: " + shown + " из " + total
        : nBinds + " биндов · " + groups.length + " групп · из hyprctl binds"

    Process {
        id: backend
        command: [Quickshell.env("HOME") + "/.local/lib/yumi/qs/keys"]
        stdout: StdioCollector {
            onStreamFinished: {
                let j; try { j = JSON.parse(text) } catch (e) { j = { groups: [], n_binds: 0, total: 0 } }
                menu.groups = j.groups; menu.nBinds = j.n_binds; menu.total = j.total; menu.loaded = true; menu.render()
            }
        }
    }
    onOpenChanged: {
        if (open) { backend.running = true; if (loaded) render(); field.forceActiveFocus() }
        else { field.focus = false; field.text = ""; toastText = ""; dropRows.restart() }
    }
    Timer { id: dropRows; interval: 600; onTriggered: if (!menu.open) menu.rows = [] }   // после закрытия делегаты освобождаются
    onQueryChanged: render()

    function render() {
        const words = query.toLowerCase().split(/\s+/).filter(w => w)
        const out = []
        let n = 0, first = -1
        for (const g of groups) {
            const hits = g.items.filter(e => words.every(w => e.hay.indexOf(w) >= 0))
            if (!hits.length) continue
            out.push({ head: true, name: g.name, n: hits.length })
            for (const e of hits) { if (first < 0) first = out.length; out.push({ e: e }); n++ }
        }
        rows = out; shown = n; sel = first
        list.positionViewAtBeginning()
    }
    function move(d) {
        let i = sel
        for (let k = 0; k < rows.length; k++) { i = Math.max(0, Math.min(rows.length - 1, i + d)); if (!rows[i].head) break }
        if (i >= 0 && rows[i] && !rows[i].head) { sel = i; list.positionViewAtIndex(i, ListView.Contain); if (i <= 1) list.positionViewAtBeginning() }
    }
    function copy(e) {
        if (!e) return
        if (dry) { console.log("[dry-run] wl-copy «" + e.conf + "»"); toast("Имитация: скопировано " + e.conf); return }
        Quickshell.execDetached(["wl-copy", "--", e.conf])
        toast("Скопировано: " + e.conf)
    }
    function groupOf(i) { for (let k = i; k >= 0; k--) if (rows[k] && rows[k].head) return rows[k].name; return "" }   // группа строки (для колонки слева)
    function copySelected() { if (sel >= 0 && rows[sel] && !rows[sel].head) copy(rows[sel].e) }
    function close() { field.focus = false; Menus.close("keys") }

    IpcHandler {
        target: "keys"
        function search(text: string): void { field.text = text }
        function enter(): void { menu.copySelected() }
    }

    Popup {
        id: pop
        name: "keys"
        open: menu.open
        screen: Menus.screen
        contentW: 700                          // «Карточка B»: две колонки (было 560, как yp.WIDTH)
        marginTop: Theme.barH * (Theme.dev ? 2 : 1) + 6
        contentH: body.implicitHeight + 36
        pad: 18

        FocusScope {
            id: scope
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: { if (field.text) field.text = ""; else menu.close() }
            Keys.onDownPressed: menu.move(1)
            Keys.onUpPressed: menu.move(-1)
            Keys.onReturnPressed: menu.copySelected()
            Keys.onEnterPressed: menu.copySelected()

            ColumnLayout {
                id: body
                width: parent.width
                spacing: 12

                // ---- шапка («Карточка B», 19.10); пояснение про Lua-функции ушло в подвал ----
                CardHead {
                    title: "Горячие клавиши"; dry: menu.dry
                    status: menu.sub
                    statusColor: menu.toastText ? (menu.toastError ? Colors.bad : Colors.acc) : Colors.fgDim
                }

                // ---- поиск ----
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 40; radius: 20     // «Остров»: как IField
                    color: Colors.isl2
                    border.width: field.activeFocus ? 1.5 : 0; border.color: Colors.acc
                    Glyph { id: lens; anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: "󰍉"; font.pixelSize: 16; color: Colors.fgDim }
                    TextInput {
                        id: field
                        anchors { left: lens.right; right: clr.left; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 8 }
                        font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fg
                        selectByMouse: true; selectionColor: Colors.alpha(Colors.acc, 0.4); selectedTextColor: Colors.fg
                        clip: true
                        onTextChanged: menu.query = text
                        onAccepted: menu.copySelected()
                        Keys.onDownPressed: menu.move(1)
                        Keys.onUpPressed: menu.move(-1)
                        Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; visible: !field.text; text: "Поиск: описание, группа или клавиша…"; font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fgDim }
                    }
                    Glyph {
                        id: clr
                        anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                        text: "󰅖"; font.pixelSize: 14; color: Colors.fgDim
                        opacity: field.text ? 1 : 0; Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                        MouseArea { anchors.fill: parent; enabled: field.text.length > 0; onClicked: { field.text = ""; field.forceActiveFocus() } }
                    }
                }

                // ---- слева группы с числом биндов (подсвечена группа выбранной строки), справа список постоянной высоты ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14
                    ListView {
                        id: groupList
                        Layout.preferredWidth: 170
                        Layout.preferredHeight: 470
                        clip: true
                        interactive: contentHeight > height
                        boundsBehavior: Flickable.StopAtBounds
                        spacing: 2
                        readonly property string cur: menu.groupOf(menu.sel)
                        model: menu.rows.filter(x => x.head)
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool on: groupList.cur === modelData.name
                            width: groupList.width; height: 34; radius: Theme.radius
                            color: on ? Colors.alpha(Colors.acc, 0.16) : "transparent"
                            /* выбор — без затухания (29.10) */
                            onOnChanged: if (on) groupList.positionViewAtIndex(groupList.model.indexOf(modelData), ListView.Contain)
                            Text { anchors { left: parent.left; leftMargin: 12; right: gn.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                                   text: parent.modelData.name; elide: Text.ElideRight; font.family: Theme.fontUi; font.pixelSize: 13
                                   font.weight: parent.on ? Font.Medium : Font.Normal; color: parent.on ? Colors.fg : Colors.fgDim }
                            Text { id: gn; anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                                   text: String(parent.modelData.n); font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim; font.features: ({ "tnum": 1 }) }
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 470
                        ListView {
                            id: list
                            anchors.fill: parent
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            model: menu.rows
                            spacing: 1
                            cacheBuffer: 200
                            delegate: Loader {
                                id: dl
                                required property var modelData
                                required property int index
                                width: list.width
                                sourceComponent: modelData.head ? headC : rowC
                            }
                        }
                        Text {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                            anchors.margins: 6; anchors.topMargin: 18
                            visible: menu.loaded && menu.shown === 0
                            wrapMode: Text.Wrap
                            text: menu.query.trim() ? "Ничего не найдено" : "Бинды не получены — Hyprland не ответил на `hyprctl binds -j`"
                            font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fgDim
                        }
                    }
                }
                CardHints {
                    items: [["↑↓", "бинд"], ["Enter", "скопировать"], ["Esc", "очистить / закрыть"]]
                    note: "бинды — Lua-функции Hyprland, отсюда только копируются"
                }
                Text { visible: menu.dry; Layout.alignment: Qt.AlignHCenter; text: "проверка: буфер обмена не меняется"; font.family: Theme.fontUi; font.pixelSize: 11
                       color: Colors.acc }
            }
        }
    }

    // заголовок группы: «ОКНА  29»
    Component {
        id: headC
        Row {
            readonly property var m: parent ? parent.modelData : null
            spacing: 6
            topPadding: 12; bottomPadding: 4; leftPadding: 10
            // «Остров»: подпись группы как ISection — 11 заглавными, разрядка
            Text { text: m ? m.name : ""; font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.Medium
                   font.capitalization: Font.AllUppercase; font.letterSpacing: 1; color: Colors.fgDim }
            Text { text: m ? String(m.n) : ""; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.alpha(Colors.fgDim, 0.8); anchors.baseline: parent.children[0].baseline }
        }
    }
    // строка бинда («Остров»): описание слева, сочетание клавишами-капсулами справа
    Component {
        id: rowC
        Rectangle {
            id: r
            readonly property var e: parent ? parent.modelData.e : null
            readonly property bool selected: parent ? parent.index === menu.sel : false
            implicitHeight: Math.max(40, Math.max(chips.implicitHeight, txt.implicitHeight) + 14)
            radius: Theme.radius
            color: selected ? Colors.alpha(Colors.acc, 0.16) : (rm.containsMouse ? Colors.isl2 : "transparent")
            /* выбор — без затухания (29.10) */
            scale: rm.pressed ? 0.985 : 1
            Behavior on scale { NumberAnimation { duration: Theme.fast } }
            MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; onClicked: { menu.sel = r.parent.index; menu.copy(r.e) } }
            Column {
                id: txt
                anchors { left: parent.left; right: chips.left; leftMargin: 12; rightMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 1
                Text { width: parent.width; wrapMode: Text.Wrap; text: r.e ? r.e.text : ""; font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium; color: Colors.fg }
                Text {
                    readonly property string meta: r.e ? [r.e.sub].concat(r.e.flags).filter(x => x).join(" · ") : ""
                    visible: meta.length > 0; width: parent.width; elide: Text.ElideRight
                    text: meta; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim
                }
            }
            Column {
                id: chips
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                spacing: 4
                Repeater {
                    model: r.e ? r.e.combos : []
                    Row {
                        required property var modelData
                        required property int index
                        anchors.right: parent ? parent.right : undefined
                        spacing: 4
                        Text { visible: index > 0; text: "или"; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim
                               anchors.verticalCenter: parent.verticalCenter; rightPadding: 3 }
                        Repeater { model: modelData.mods; KeyChip { required property string modelData; text: modelData } }
                        KeyChip { text: modelData.key; key: true }
                    }
                }
            }
        }
    }
}
