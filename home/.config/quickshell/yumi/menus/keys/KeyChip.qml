import QtQuick
import qs

// Клавиша-капсула — «Остров» (29.10), как в CardHints: isl2, тонкая кромка, Onest 11 Medium.
Rectangle {
    id: root
    property string text: ""
    property bool key: false
    implicitWidth: Math.max(22, label.implicitWidth + 14)
    implicitHeight: 20
    radius: 7
    color: Colors.isl2
    border.width: 1
    border.color: key ? Colors.alpha(Colors.fg, 0.16) : Colors.edge
    Behavior on color { ColorAnimation { duration: Theme.normal } }
    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.Medium
        color: Colors.fg
        Behavior on color { ColorAnimation { duration: Theme.normal } }
    }
}
