import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// «Остров»: ползунок-капсула 26 px — заливка акцентом, значок внутри слева (onAcc), справа процент.
// value 0..1; moved(v) — при перетаскивании и колесе; showValue — подпись справа.
RowLayout {
    id: s
    property real value: 0.5
    property string icon: ""
    property bool showValue: true
    property string valueText: Math.round(value * 100) + "%"
    property int trackH: 26
    signal moved(real v)
    Layout.fillWidth: true
    spacing: 12
    Rectangle {
        id: track
        Layout.fillWidth: true
        implicitHeight: s.trackH; radius: s.trackH / 2
        color: Colors.isl2
        clip: true
        Rectangle {
            width: Math.max(track.height, track.width * Math.max(0, Math.min(1, s.value)))
            height: parent.height; radius: parent.radius
            color: Colors.acc
            Behavior on width { enabled: !ma.pressed; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Theme.normal } }
        }
        Glyph { visible: s.icon.length > 0; anchors.verticalCenter: parent.verticalCenter; x: 9; text: s.icon; font.pixelSize: 15; color: Colors.onAcc }
        MouseArea {
            id: ma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; preventStealing: true
            function upd(m) { s.moved(Math.max(0, Math.min(1, m.x / width))) }
            onPressed: (m) => upd(m)
            onPositionChanged: (m) => { if (pressed) upd(m) }
            onWheel: (w) => s.moved(Math.max(0, Math.min(1, s.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
        }
    }
    Text { visible: s.showValue; text: s.valueText; Layout.minimumWidth: 38; horizontalAlignment: Text.AlignRight
           font.family: Theme.fontUi; font.pixelSize: 12; font.features: ({ "tnum": 1 }); color: Colors.fgDim }
}
