import QtQuick
import qs

// «Остров»: чип-фильтр — капсула isl2, выбранный — акцент.
Rectangle {
    id: c
    property string text: ""
    property bool on: false
    signal clicked()
    implicitWidth: t.implicitWidth + 24; implicitHeight: 30; radius: 14
    color: on ? Colors.acc : (ma.containsMouse ? Colors.hover : Colors.isl2)
    Behavior on color { ColorAnimation { duration: 220 } }
    scale: ma.pressed ? 0.95 : 1
    Behavior on scale { NumberAnimation { duration: Theme.fast } }
    Text { id: t; anchors.centerIn: parent; text: c.text; font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium
           color: c.on ? Colors.onAcc : Colors.fgDim }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: c.clicked() }
}
