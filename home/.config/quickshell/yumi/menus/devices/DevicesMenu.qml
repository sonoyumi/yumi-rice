import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services
import qs.menus.wifi
import qs.menus.mouse

// Меню «Устройства» на QML — как ~/.local/bin/yumi-menu-devices (GTK-меню остаётся рабочим): мышь и клавиатура,
// у каждой своя страница. Мышь — то же содержимое, что меню «Мышь» (MousePanel + бэкенд ~/.local/lib/yumi/qs/mouse),
// клавиатура — подсветка через yumi-kb-light (KbData). Esc — назад / закрыть.
//   qs -c yumi ipc call menu toggle devices · menu center devices · devices page mouse|keyboard (сразу страница)
// YP_DRYRUN=1 — ничего не меняется (команды пишутся в журнал).
Popup {
    id: pop
    name: "devices"
    open: Menus.current === "devices"
    screen: Menus.screen
    marginRight: Theme.screenPad
    marginTop: Theme.barH * (Theme.dev ? 2 : 1) + 6
    contentW: 400                          // «Остров»: карточка с раскрывашками, отступ 18
    pad: 18
    contentH: col.implicitHeight + pad * 2
    holdOpen: mouse.busy > 0

    property string page: ""               // "" | mouse | keyboard
    property string toastText: ""
    property bool toastError: false
    function toast(t, e, h) { toastText = t; toastError = e; toastTimer.interval = (h || 3) * 1000; toastTimer.restart() }
    Timer { id: toastTimer; onTriggered: pop.toastText = "" }
    onOpenChanged: {
        if (open) { scope.forceActiveFocus(); kb.reload() }
        else { scope.focus = false; toastText = ""; resetPage.restart() }
    }
    Timer { id: resetPage; interval: Theme.slow; onTriggered: if (!pop.open) pop.page = "" }   // после анимации закрытия

    MouseData { id: mouse; active: pop.open; onToast: (t, e, h) => pop.toast(t, e, h) }
    KbData { id: kb; onDone: (ok, text) => pop.toast(text || (ok ? "" : "ошибка"), !ok, 3) }

    readonly property string kbMeta: kb.state.on ? kb.state.brightness + "%" : "выкл"
    readonly property string sub: toastText ? toastText
        : page === "mouse" ? mouse.summary
        : page === "keyboard" ? "PRO Gaming Keyboard · OpenRGB" : "Мышь · клавиатура"

    IpcHandler {
        target: "devices"
        function page(name: string): void { pop.page = name === "mouse" || name === "keyboard" ? name : "" }
    }

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: { if (pop.page) pop.page = ""; else Menus.close("devices") }

        // одна карточка — две строки-раскрывашки; мышь и клавиатура раскрываются на месте
        // (page = "mouse" | "keyboard" — то же состояние, что раньше страницы; Esc — свернуть / закрыть)
        ColumnLayout {
            id: col
            width: parent.width
            spacing: 8

            MenuHeader {
                Layout.bottomMargin: 4
                icon: "󰍽"; iconOn: true
                title: "Устройства"
                subtitle: pop.sub; error: pop.toastError && pop.toastText.length > 0
                showToggle: false; dry: mouse.dry
            }

            DevRow { index: 0; icon: "󰍽"; text: "Мышь · PRO X 2"; meta: mouse.meta; on: pop.page === "mouse"
                     sub: pop.page === "mouse" ? "" : "Logitech · Solaar"
                     onClicked: pop.page = pop.page === "mouse" ? "" : "mouse" }
            Fold {
                on: pop.page === "mouse"
                MousePanel {
                    id: mousePage
                    width: parent.width
                    md: mouse
                    shown: pop.page === "mouse"
                    onSolaarOpened: Menus.close("devices")
                }
            }
            DevRow { index: 1; icon: "󰌌"; text: "Клавиатура · PRO Gaming"; meta: pop.kbMeta; on: pop.page === "keyboard"
                     sub: "подсветка · " + (kb.state.source === "fixed" ? "свой цвет" : "по обоям")
                     onClicked: pop.page = pop.page === "keyboard" ? "" : "keyboard" }
            Fold {
                on: pop.page === "keyboard"
                KbPanel {
                    id: kbPage
                    width: parent.width
                    kb: kb
                }
            }
            MFooter { Layout.topMargin: 4; hints: [["клик", "раскрыть"], ["Esc", pop.page ? "свернуть" : "закрыть"]] }
        }
    }

    // раскрывашка: высота плавно 0 ↔ содержимое, отступ слева под строкой
    component Fold: Item {
        id: fd
        property bool on: false
        default property alias content: holder.data
        Layout.fillWidth: true
        Layout.leftMargin: 4; Layout.rightMargin: 4
        implicitHeight: on ? holder.childrenRect.height + 10 : 0
        Behavior on implicitHeight { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
        clip: true
        opacity: on ? 1 : 0
        visible: implicitHeight > 0
        enabled: on
        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
        Item { id: holder; width: parent.width; y: 4 }
    }

    // строка устройства (yp.row_button с пометкой): значок, название, пометка, стрелка; каскад 40 мс
    component DevRow: Rectangle {
        id: rb
        property int index: 0
        property string icon: ""
        property string text: ""
        property string meta: ""
        property string sub: ""
        property bool on: false               // раскрыта — подложка акцентом 0.16, значок в акцентном квадрате («Остров»)
        signal clicked()
        Layout.fillWidth: true
        implicitHeight: 52; radius: Theme.radius
        color: on ? Colors.alpha(Colors.acc, 0.16) : (rbm.containsMouse ? Colors.isl2 : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        scale: rbm.pressed ? 0.985 : 1
        Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
        opacity: pop.open ? 1 : 0
        property real slide: pop.open ? 0 : 8
        transform: Translate { y: rb.slide }
        Behavior on opacity { SequentialAnimation { PauseAnimation { duration: pop.open ? 110 + rb.index * 40 : 0 } NumberAnimation { duration: 280; easing.type: Easing.OutCubic } } }
        Behavior on slide { SequentialAnimation { PauseAnimation { duration: pop.open ? 110 + rb.index * 40 : 0 } NumberAnimation { duration: 280; easing.type: Easing.OutCubic } } }
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 9; anchors.rightMargin: 10; spacing: 12
            MIconSq { icon: rb.icon; on: rb.on }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                MText { text: rb.text; Layout.fillWidth: true; elide: Text.ElideRight; font.weight: Font.Medium }
                MText { visible: rb.sub.length > 0; text: rb.sub; Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 12; color: Colors.fgDim }
            }
            Text { visible: rb.meta.length > 0; text: rb.meta; font.family: Theme.fontUi; font.pixelSize: 12; font.features: ({ "tnum": 1 }); color: Colors.fgDim; Layout.minimumWidth: 40; horizontalAlignment: Text.AlignRight }
            Glyph { text: "󰅂"; color: Colors.fgDim; font.pixelSize: 14; rotation: rb.on ? 90 : 0
                    Behavior on rotation { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutBack } } }
        }
        MouseArea { id: rbm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rb.clicked() }
    }
}
