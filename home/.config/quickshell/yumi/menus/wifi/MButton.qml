import QtQuick
import qs

// Кнопка действия: primary (акцент), plain (isl2), danger (красноватая).
// «Остров» (29.10): капсула radius 16 как components/IButton, Onest Medium; нажатие 0.96. API прежний.
Rectangle {
    id: root
    property string text: ""
    property string kind: "plain"
    property int fontSize: Theme.fontSize
    signal clicked()
    implicitHeight: 36
    implicitWidth: label.implicitWidth + 32
    radius: 16
    color: kind === "primary" ? (mouse.containsMouse ? Colors.mix(Colors.acc, Colors.fg, 0.15) : Colors.acc)
         : kind === "danger"  ? Colors.mix(Colors.isl2, Colors.bad, mouse.containsMouse ? 0.35 : 0.2)
         : (mouse.containsMouse ? Colors.hover : Colors.isl2)
    opacity: enabled ? 1 : 0.45
    scale: mouse.pressed ? 0.96 : 1
    Behavior on color { ColorAnimation { duration: Theme.fast } }
    Behavior on opacity { NumberAnimation { duration: Theme.fast } }
    Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.family: Theme.fontUi; font.pixelSize: root.fontSize; font.weight: Font.Medium
        color: root.kind === "primary" ? Colors.onAcc : Colors.fg
        Behavior on color { ColorAnimation { duration: Theme.normal } }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
