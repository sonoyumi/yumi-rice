import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// Ползунок центра управления (яркость/громкость). «Остров» (29.10): капсула 26 px как components/ISlider — заливка
// акцентом, значок внутри слева (onAcc), процент справа (табличные цифры). Тянется мышью, колесо ±5 %.
// Снаружи задают value (0..1) и слушают moved(v); kb — фокус клавиатуры (кромка), editing — регулировка стрелками
// (капсула чуть выше, заливка светлее).
Item {
    id: sl
    property real value: 0
    property string icon: ""
    property real minimum: 0
    property bool kb: false
    property bool editing: false
    signal moved(real v)
    implicitHeight: 30

    Rectangle {
        id: track
        anchors.left: parent.left; anchors.right: pct.left; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: sl.editing ? 30 : 26; radius: height / 2
        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
        color: Colors.isl2
        border.width: sl.kb ? 1.5 : 0; border.color: Colors.acc
        clip: true
        Rectangle {
            id: fill
            width: Math.max(track.height, track.width * Math.max(0, Math.min(1, sl.value)))
            height: parent.height; radius: parent.radius
            color: sl.editing ? Colors.mix(Colors.acc, Colors.fg, 0.15) : Colors.acc
            Behavior on width { enabled: !mouse.pressed; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Theme.normal } }
        }
        Glyph { anchors.verticalCenter: parent.verticalCenter; x: 9; text: sl.icon; font.pixelSize: 15; color: Colors.onAcc }
        MouseArea {
            id: mouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor; preventStealing: true
            function at(x) { const v = Math.max(sl.minimum, Math.min(1, x / width)); sl.value = v; sl.moved(v) }
            onPressed: (e) => at(e.x)
            onPositionChanged: (e) => { if (pressed) at(e.x) }
            onWheel: (w) => { const v = Math.max(sl.minimum, Math.min(1, sl.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))); sl.value = v; sl.moved(v) }
        }
    }
    Text {
        id: pct
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        width: 38; horizontalAlignment: Text.AlignRight
        text: Math.round(sl.value * 100) + "%"
        font.family: Theme.fontUi; font.pixelSize: 12; font.features: ({ "tnum": 1 }); color: Colors.fgDim
    }
}
