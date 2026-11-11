import QtQuick
import qs

// Кнопка-значок — «Остров» (29.10): круг, в покое прозрачный (flat) или isl2, наведение — hover, нажатие 0.9.
Rectangle {
    id: root
    property string icon: ""
    property int size: 32
    property int iconPx: 17
    property color tone: Colors.fg
    property bool accent: false
    property bool flat: false              // без подложки в покое
    signal clicked()
    implicitWidth: size; implicitHeight: size; radius: size / 2
    color: mouse.containsMouse ? (flat ? Colors.isl2 : Colors.hover) : (flat ? "transparent" : Colors.isl2)
    opacity: enabled ? 1 : 0.35
    scale: mouse.pressed ? 0.9 : 1
    Behavior on color { ColorAnimation { duration: Theme.fast } }
    Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
    Text {
        anchors.centerIn: parent
        text: root.icon; font.family: Theme.fontIcon; font.pixelSize: root.iconPx
        color: root.accent ? Colors.acc : root.tone
        Behavior on color { ColorAnimation { duration: Theme.normal } }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
