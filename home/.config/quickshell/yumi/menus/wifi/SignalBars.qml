import QtQuick
import qs

// «Остров» (29.10): уровень Wi-Fi четырьмя полосками (3 px, высота 5/8/11/14) — горящие цветом color, остальные hover.
// level — 0..100 %; порог полоски: 1 — всегда, 2 — от 30, 3 — от 55, 4 — от 75.
Row {
    id: b
    property int level: 0
    property color color: Colors.fg
    spacing: 2
    height: 14
    readonly property int n: level <= 0 ? 0 : level < 30 ? 1 : level < 55 ? 2 : level < 75 ? 3 : 4
    Repeater {
        model: 4
        Rectangle {
            required property int index
            anchors.bottom: parent.bottom
            width: 3; height: index * 3 + 5; radius: 1
            color: index < b.n ? b.color : Colors.hover
            Behavior on color { ColorAnimation { duration: Theme.normal } }
        }
    }
}
