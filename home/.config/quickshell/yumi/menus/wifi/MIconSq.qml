import QtQuick
import qs
import qs.components

// «Остров» (29.10): значок в квадрате 34 (radius 12) — как .ri превью; on — акцент (значок onAcc), иначе isl2.
// base — цвет невыбранного квадрата (на подложке isl2 ставят Colors.hover).
Rectangle {
    id: sq
    property string icon: ""
    property bool on: false
    property bool yumi: false
    property color base: Colors.isl2
    property color iconColor: on ? Colors.onAcc : Colors.fg
    property int size: 34
    implicitWidth: size; implicitHeight: size; radius: Math.round(size * 0.35)
    color: on ? Colors.acc : base
    Behavior on color { ColorAnimation { duration: Theme.normal } }
    Glyph { anchors.centerIn: parent; text: sq.icon; yumi: sq.yumi; font.pixelSize: Math.round(sq.size * 0.47); color: sq.iconColor
            Behavior on color { ColorAnimation { duration: Theme.normal } } }
}
