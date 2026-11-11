import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// YumiTube: пункт боковой панели — значок + подпись, выбранный — плашка акцентом 16 % и значок в акцентной капсуле.
Rectangle {
    id: n
    property string icon: ""
    property string text: ""
    property string badge: ""
    property bool sel: false
    property bool compact: false        // узкое окно: только значок
    signal clicked()
    Layout.fillWidth: true
    implicitHeight: 40
    radius: 14
    color: sel ? Colors.alpha(Colors.acc, 0.16) : (ma.containsMouse ? Colors.isl2 : "transparent")
    Behavior on color { ColorAnimation { duration: Theme.fast } }
    scale: ma.pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
    RowLayout {
        anchors.fill: parent; anchors.leftMargin: n.compact ? (n.width - 28) / 2 : 6; anchors.rightMargin: n.compact ? 0 : 12; spacing: 10
        Rectangle {
            visible: n.icon.length > 0
            implicitWidth: 28; implicitHeight: 28; radius: 10
            color: n.sel ? Colors.acc : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.normal } }
            Glyph { anchors.centerIn: parent; text: n.icon; font.pixelSize: 16; color: n.sel ? Colors.onAcc : Colors.fgDim }
        }
        Text {
            visible: !n.compact
            Layout.fillWidth: true
            text: n.text; elide: Text.ElideRight
            font.family: Theme.fontUi; font.pixelSize: 13; font.weight: n.sel ? Font.DemiBold : Font.Medium
            color: n.sel ? Colors.fg : Colors.alpha(Colors.fg, 0.82)
        }
        Text {
            visible: n.badge.length > 0 && !n.compact
            text: n.badge
            font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.Medium; color: Colors.fgDim
        }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: n.clicked() }
}
