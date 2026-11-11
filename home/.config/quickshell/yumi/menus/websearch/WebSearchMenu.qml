import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services

// Меню «Веб-поиск» на QML. Содержимое и подписи — как у ~/.local/bin/yumi-menu-websearch (GTK-меню остаётся рабочим):
// запрос и Enter — поиск в выбранном поисковике (↑/↓ — сменить); «имя:запрос» — сразу в нужный (yt:lofi, aur:paru);
// адрес открывается как адрес; пустая строка + Enter — главная поисковика; щелчок по поисковику при запросе ищет сразу,
// щелчок по истории повторяет запрос. Открывает `uwsm app -- xdg-open <адрес>`.
// Логика (поисковики из websearch.lst, разбор строки, история) — бэкенд ~/.local/lib/yumi/qs/websearch: берёт функции
// из самого GTK-скрипта (часть без GTK). Открыть по бинду (по центру): qs -c yumi ipc call menu center websearch (SUPER+SHIFT+/).
// Поле держит фокус только пока меню открыто — перед закрытием фокус снимается (иначе segfault в Qt).
// Проверка: YP_DRYRUN=1 (адрес только печатается, окно не закрывается); qs … ipc call websearch search <текст>
Scope {
    id: menu
    readonly property bool open: Menus.current === "websearch"
    readonly property string home: Quickshell.env("HOME")
    readonly property int gridH: 188       // высота сетки поисковиков (постоянная — карточка не меняет размер)
    readonly property int histH: 110       // высота списка истории

    // ---- данные из бэкенда ----
    property bool ready: false
    property bool dry: false
    property var engines: []               // [{key, icon, name, alias, tip}]
    property string current: ""
    property string shown: ""
    property var plan: ({ icon: "󰖟", text: "", url: "" })
    property var hist: []                  // [{q, meta}]
    property string histEmpty: ""
    property string histTitle: "НЕДАВНИЕ ЗАПРОСЫ"
    property string sub: ""
    property bool cascade: false
    property string toastText: ""
    property bool toastError: false

    function toast(text, error) { toastText = text; toastError = !!error; toastTimer.restart() }
    Timer { id: toastTimer; interval: 4000; onTriggered: menu.toastText = "" }
    Timer { id: cascadeEnd; interval: 900; onTriggered: menu.cascade = false }

    // ---- бэкенд ----
    property bool echo: false              // текст поставил бэкенд — не отсылать обратно
    function send(obj) { if (proc.running && ready) proc.write(JSON.stringify(obj) + "\n") }
    function apply(line) {
        let j
        try { j = JSON.parse(line) } catch (e) { console.log("websearch: не JSON:", line); return }
        switch (j.type) {
        case "engines": engines = j.engines; dry = j.dry; ready = true; break
        case "state":
            if (j.text !== undefined && j.text !== field.text) { echo = true; field.text = j.text; field.cursorPosition = field.text.length; echo = false }
            current = j.current; plan = j.plan; hist = j.hist; histEmpty = j.empty; histTitle = j.histTitle; sub = j.sub
            if (shown !== j.shown) { shown = j.shown; const i = engines.findIndex(e => e.key === shown); if (i >= 0) grid.positionViewAtIndex(i, GridView.Contain) }
            break
        case "toast": toast(j.text, j.error); break
        case "done": closeLater.restart(); break
        }
    }
    onReadyChanged: if (ready && open && field.text) send({ cmd: "text", text: field.text })
    Timer { id: closeLater; interval: 150; onTriggered: menu.close() }
    Process {
        id: proc
        command: ["python3", "-I", menu.home + "/.local/lib/yumi/qs/websearch"]
        running: menu.open || grace.running
        stdout: SplitParser { onRead: line => menu.apply(line) }
        stderr: SplitParser { onRead: line => console.log("websearch:", line) }
        onExited: menu.ready = false
    }
    Timer { id: grace; interval: 90000 }   // после закрытия бэкенд живёт ещё 90 с — повторное открытие мгновенное
    onOpenChanged: {
        if (open) {
            grace.stop(); cascade = true; cascadeEnd.restart()
            if (ready) send({ cmd: "reload" })
            field.forceActiveFocus()
        } else {
            field.focus = false; grace.restart(); toastText = ""; echo = true; field.text = ""; echo = false
        }
    }

    function close() { field.focus = false; Menus.close("websearch") }

    IpcHandler {
        target: "websearch"
        function toggle(): void { Menus.toggleCenter("websearch") }
        function search(text: string): void { field.text = text }
        function go(): void { menu.send({ cmd: "go" }) }
    }

    Popup {
        id: pop
        name: "websearch"
        open: menu.open
        screen: Menus.screen
        contentW: 520
        pad: 18
        vcenter: true                             // меню по бинду: по центру экрана
        closeOnLeave: false
        contentH: body.implicitHeight + 36
        fixedH: contentH

        FocusScope {
            id: scope
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: menu.close()

            ColumnLayout {
                id: body
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                spacing: 12

                // ---- шапка ----
                CardHead {
                    title: "Веб-поиск"; dry: menu.dry
                    status: menu.toastText || menu.sub || " "
                    statusColor: menu.toastText ? (menu.toastError ? Colors.bad : Colors.acc) : Colors.fgDim
                }

                // ---- поле (как IField), справа — очистить ----
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 40; radius: 20
                    color: Colors.isl2
                    border.width: field.activeFocus ? 1.5 : 0; border.color: Colors.acc
                    Glyph { id: lens; anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: "󰍉"; font.pixelSize: 16; color: Colors.fgDim }
                    TextInput {
                        id: field
                        anchors { left: lens.right; right: clear.left; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 8 }
                        font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fg
                        selectByMouse: true; selectionColor: Colors.alpha(Colors.acc, 0.4); selectedTextColor: Colors.fg
                        clip: true
                        onTextChanged: if (!menu.echo) menu.send({ cmd: "text", text: text })
                        Keys.onDownPressed: menu.send({ cmd: "cycle", dir: 1 })
                        Keys.onUpPressed: menu.send({ cmd: "cycle", dir: -1 })
                        Keys.onReturnPressed: menu.send({ cmd: "go" })
                        Keys.onEnterPressed: menu.send({ cmd: "go" })
                        Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; visible: !field.text; font.family: Theme.fontUi; font.pixelSize: 13
                               color: Colors.fgDim; text: "Запрос, адрес или имя:запрос" }
                    }
                    Glyph {
                        id: clear
                        anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                        text: "󰅖"; font.pixelSize: 14; color: Colors.fgDim
                        opacity: field.text ? 1 : 0; Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                        MouseArea { anchors.fill: parent; anchors.margins: -6; enabled: field.text.length > 0; onClicked: { field.text = ""; field.forceActiveFocus() } }
                    }
                }

                // ---- что сделает Enter — выбранная строка (как IRow sel) ----
                IRow {
                    sel: true; hoverable: false
                    icon: menu.plan.icon || "󰖟"
                    title: menu.plan.text || " "
                    sub: menu.plan.url || " "
                    onClicked: menu.send({ cmd: "go" })
                }

                // ---- поисковики — капсулы, выбранный — акцент ----
                ISection { text: "Поисковики · ↑↓ выбрать · всего " + menu.engines.length }
                GridView {
                    id: grid
                    Layout.fillWidth: true
                    Layout.preferredHeight: menu.gridH - 36
                    implicitHeight: menu.gridH - 36
                    clip: true; boundsBehavior: Flickable.StopAtBounds
                    cellWidth: Math.floor(width / 3); cellHeight: 38
                    model: menu.engines
                    delegate: Item {
                        id: cell
                        required property var modelData
                        required property int index
                        readonly property bool active: modelData.key === menu.shown
                        width: grid.cellWidth; height: grid.cellHeight
                        opacity: 0
                        Component.onCompleted: { if (menu.cascade) appear.start(); else opacity = 1 }
                        SequentialAnimation {
                            id: appear
                            PauseAnimation { duration: 60 + Math.min(cell.index, 12) * 40 }
                            NumberAnimation { target: cell; property: "opacity"; to: 1; duration: Theme.normal }
                        }
                        Rectangle {
                            anchors { fill: parent; margins: 3 }
                            radius: height / 2
                            color: cell.active ? Colors.acc : (eArea.containsMouse ? Colors.hover : Colors.isl2)
                            Behavior on color { ColorAnimation { duration: 220 } }
                            scale: eArea.pressed ? 0.95 : 1
                            Behavior on scale { NumberAnimation { duration: Theme.fast } }
                            RowLayout {
                                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                                spacing: 6
                                Text { Layout.fillWidth: true; text: cell.modelData.name; elide: Text.ElideRight; font.family: Theme.fontUi; font.pixelSize: 12
                                       font.weight: Font.Medium; color: cell.active ? Colors.onAcc : Colors.fg }
                                Text { visible: !!cell.modelData.alias; text: cell.modelData.alias; font.family: Theme.fontUi; font.pixelSize: 11
                                       color: cell.active ? Colors.alpha(Colors.onAcc, 0.7) : Colors.fgDim }
                            }
                            MouseArea { id: eArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { menu.send({ cmd: "pick", key: cell.modelData.key }); field.forceActiveFocus() } }
                        }
                    }
                }

                // ---- история ----
                ISection { text: menu.histTitle }
                ListView {
                    id: hlist
                    Layout.fillWidth: true
                    Layout.preferredHeight: menu.histH
                    implicitHeight: menu.histH
                    clip: true; boundsBehavior: Flickable.StopAtBounds
                    spacing: 2
                    model: menu.hist
                    delegate: Rectangle {
                        id: hrow
                        required property var modelData
                        required property int index
                        width: ListView.view.width; height: 34; radius: Theme.radius
                        color: hArea.containsMouse ? Colors.isl2 : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.fast } }
                        scale: hArea.pressed ? 0.985 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.fast } }
                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            spacing: 10
                            Glyph { text: "󰋚"; font.pixelSize: 14; color: Colors.fgDim }
                            Text { Layout.fillWidth: true; text: hrow.modelData.q; elide: Text.ElideRight; font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fg }
                            Text { text: hrow.modelData.meta; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim }
                        }
                        MouseArea { id: hArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: menu.send({ cmd: "hist", i: hrow.index }) }
                    }
                    Text {
                        visible: menu.hist.length === 0 && menu.histEmpty.length > 0
                        width: parent.width; text: menu.histEmpty; wrapMode: Text.Wrap
                        font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fgDim; leftPadding: 8; topPadding: 8
                    }
                }
                CardHints {
                    items: [["↑↓", "поисковик"], ["Enter", "открыть"], ["Esc", "закрыть"]]
                    note: menu.dry ? "проверка: браузер не открывается" : ""
                }
            }
        }
    }
}
