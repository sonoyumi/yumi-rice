import QtQuick
import QtQuick.Effects
import qs

// Свечение, как text-shadow: 0 0 <radius>px alpha(<color>, <strength>) в user-style.css.
// Лежит ПОД источником (z −1) в том же родителе: размытая копия, окрашенная в цвет. Выключено — не создаётся.
Item {
    id: root
    required property Item source
    property color color: Colors.acc
    property real radius: 3
    property real strength: 0.75
    property bool on: true
    anchors.fill: source
    z: -1
    visible: on && source.visible
    Loader {
        active: root.on
        anchors.fill: parent
        sourceComponent: MultiEffect {
            source: root.source
            autoPaddingEnabled: true
            blurEnabled: true
            blurMax: Math.max(4, Math.round(root.radius * 2.5))
            blur: 1
            colorization: 1
            colorizationColor: root.color
            opacity: root.strength
            Behavior on opacity { NumberAnimation { duration: 200 } }
            Behavior on colorizationColor { ColorAnimation { duration: 100 } }
        }
    }
}
