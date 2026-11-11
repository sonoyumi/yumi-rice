import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// Плитка стола (как .yp-ws-tile): номер, число окон, до 3 значков приложений (+N). Активный — акцент, на экране — кромка.
// Клик — перейти, правый клик (или долгое нажатие) — окна стола.
Rectangle {
    id: root
    property int num: 0
    property var info: null                // ws[N] от бэкенда
    property bool active: false
    readonly property var wins: info ? info.wins : []
    readonly property var classes: info ? info.classes : []
    readonly property bool empty: wins.length === 0
    readonly property bool shownOnScreen: info ? info.visible : false
    signal go()
    signal openPage()
    signal hovered(string tip)

    Layout.fillWidth: true
    Layout.preferredWidth: 1
    implicitHeight: 62
    radius: 16
    color: active ? Colors.alpha(Colors.acc, 0.25)
         : Colors.alpha(mouse.containsMouse ? Colors.hover : Colors.bg, mouse.containsMouse ? 0.7 : (empty ? 0.28 : 0.55))
    border.width: active || shownOnScreen ? 1 : 0
    border.color: Colors.alpha(Colors.acc, active ? 0.8 : 0.45)
    Behavior on color { ColorAnimation { duration: Theme.fast } }
    scale: mouse.pressed ? 0.96 : 1
    Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Theme.easeSpring } }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 4
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 4
            Text {
                text: String(root.num)
                font.family: Theme.fontUi; font.pixelSize: 17; font.weight: Font.ExtraBold
                color: root.active ? Colors.acc : Colors.alpha(Colors.fg, root.empty ? 0.45 : 1)
                Behavior on color { ColorAnimation { duration: Theme.normal } }
            }
            Rectangle {
                visible: !root.empty
                implicitWidth: Math.max(16, cnt.implicitWidth + 10); implicitHeight: 15; radius: 8
                color: Colors.alpha(Colors.acc, 0.85)
                Text { id: cnt; anchors.centerIn: parent; text: String(root.wins.length); font.family: Theme.fontUi; font.pixelSize: 10; font.bold: true; color: Colors.deep }
            }
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.minimumHeight: 16
            spacing: 3
            Repeater {
                model: root.classes.slice(0, 3)
                WsIcon { required property var modelData; cls: modelData.class; icon: modelData.icon; size: 15 }
            }
            Text { visible: root.classes.length > 3; text: "+" + (root.classes.length - 3); font.family: Theme.fontUi; font.pixelSize: 10; color: Colors.fgDim }
            Text { visible: root.classes.length === 0; text: "·"; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.alpha(Colors.fgDim, 0.5) }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (e) => { if (e.button === Qt.RightButton) root.openPage(); else root.go() }
        onPressAndHold: root.openPage()
        onEntered: root.hovered("Стол " + root.num + ": " + (root.classes.map(c => c.short).join(", ") || "пусто"))
        onExited: root.hovered("")
    }
}
