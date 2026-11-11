import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// «Остров»: кнопка-капсула radius 16 — обычная isl2, primary — акцент, danger — красноватая. icon и/или text.
Rectangle {
    id: b
    property string icon: ""
    property string text: ""
    property bool primary: false
    property bool danger: false
    property bool kb: false
    property bool enabledLook: true
    signal clicked()
    implicitHeight: 38
    implicitWidth: row.implicitWidth + (text.length ? 32 : 22)
    radius: 16
    color: primary ? (ma.containsMouse ? Colors.mix(Colors.acc, Colors.fg, 0.15) : Colors.acc)
         : danger ? Colors.mix(Colors.isl2, Colors.bad, ma.containsMouse ? 0.35 : 0.2)
         : (ma.containsMouse ? Colors.hover : Colors.isl2)
    border.width: kb ? 1.5 : 0; border.color: Colors.acc
    opacity: enabledLook ? 1 : 0.45
    Behavior on color { ColorAnimation { duration: Theme.fast } }
    scale: ma.pressed ? 0.95 : 1
    Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
    RowLayout {
        id: row; anchors.centerIn: parent; spacing: 8
        Glyph { visible: b.icon.length > 0; text: b.icon; font.pixelSize: 16; color: b.primary ? Colors.onAcc : Colors.fg }
        Text { visible: b.text.length > 0; text: b.text; font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium
               color: b.primary ? Colors.onAcc : Colors.fg }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: b.enabledLook; onClicked: b.clicked() }
}
