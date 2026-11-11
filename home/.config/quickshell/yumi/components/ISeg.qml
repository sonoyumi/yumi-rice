import QtQuick
import QtQuick.Layouts
import qs

// «Остров»: сегменты в капсуле isl2 — выбранный подсвечивается акцентной плашкой, которая переезжает пружиной.
// model: ["Экономия", "Баланс", "Игры"], current — индекс; picked(i).
Rectangle {
    id: seg
    property var model: []
    property int current: 0
    property int fontPx: 12
    signal picked(int i)
    Layout.fillWidth: true
    implicitHeight: 36; radius: 16
    color: Colors.isl2
    readonly property real cw: (width - 8 - (model.length - 1) * 4) / Math.max(1, model.length)
    Rectangle {
        visible: seg.current >= 0 && seg.current < seg.model.length
        y: 4; height: parent.height - 8; width: seg.cw; radius: 12
        x: 4 + seg.current * (seg.cw + 4)
        color: Colors.acc
        Behavior on x { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }
        Behavior on color { ColorAnimation { duration: Theme.normal } }
    }
    Row {
        x: 4; y: 4; spacing: 4
        Repeater {
            model: seg.model
            Item {
                required property var modelData
                required property int index
                width: seg.cw; height: seg.height - 8
                Text { anchors.centerIn: parent; width: parent.width - 6; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                       text: modelData; font.family: Theme.fontUi; font.pixelSize: seg.fontPx; font.weight: Font.Medium
                       color: index === seg.current ? Colors.onAcc : Colors.fgDim
                       Behavior on color { ColorAnimation { duration: 200 } } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: seg.picked(index) }
            }
        }
    }
}
