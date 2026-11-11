import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// Ползунок-капсула (как yp.slider_row): значок, капсула с заливкой, подпись справа постоянной ширины.
// value — внешнее значение (from..to); пока тянут и blockMs после — внешние обновления не дёргают ползунок.
// moved(v) — на каждое движение (v округлено до step), released(v) — когда отпустили/прокрутили.
// marks — отметки под капсулой (значения, напр. 400/800/1600/3200).
Item {
    id: root
    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 1
    property string icon: ""
    property string label: ""
    property int labelWidth: 48
    property var marks: []
    property int blockMs: 1500
    signal moved(real v)
    signal released(real v)
    Layout.fillWidth: true

    property real shown: value
    property bool blocked: false
    onValueChanged: if (!drag.pressed && !blocked) shown = value
    Timer { id: block; interval: root.blockMs; onTriggered: { root.blocked = false; root.shown = root.value } }
    function snap(v) { v = Math.max(from, Math.min(to, v)); return Math.round(v / step) * step }
    function frac(v) { return (v - from) / (to - from) }
    function push(v, done) {
        v = snap(v); shown = v; blocked = true; block.restart(); moved(v)
        if (done) released(v)
    }

    // «Остров» (29.10): капсула 26 px как components/ISlider — заливка акцентом, значок внутри слева (onAcc),
    // подпись справа постоянной ширины; marks — точки-отметки под капсулой. Доля = x / ширина капсулы.
    implicitHeight: marks.length ? 40 : 30
    RowLayout {
        anchors.fill: parent
        spacing: 12
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            Rectangle {
                id: trackBg
                anchors.left: parent.left; anchors.right: parent.right
                y: root.marks.length ? 2 : (parent.height - height) / 2
                height: 26; radius: 13
                color: Colors.isl2
                clip: true
                Rectangle {
                    id: fill
                    height: parent.height; radius: parent.radius
                    width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, root.frac(root.shown))))
                    color: Colors.acc
                    Behavior on width { enabled: !drag.pressed; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: Theme.normal } }
                }
                Glyph { visible: root.icon.length > 0; anchors.verticalCenter: parent.verticalCenter; x: 9; text: root.icon; font.pixelSize: 15; color: Colors.onAcc }
            }
            Repeater {
                model: root.marks
                Rectangle {
                    required property real modelData
                    x: trackBg.width * root.frac(modelData) - 2
                    y: trackBg.y + trackBg.height + 5
                    width: 4; height: 4; radius: 2
                    color: root.shown >= modelData ? Colors.acc : Colors.alpha(Colors.fg, 0.3)
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                }
            }
            MouseArea {
                id: drag
                anchors.fill: trackBg
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor; preventStealing: true
                function at(x) { return root.from + (root.to - root.from) * Math.max(0, Math.min(1, x / width)) }
                onPressed: (e) => root.push(at(e.x), false)
                onPositionChanged: (e) => { if (pressed) root.push(at(e.x), false) }
                onReleased: (e) => root.push(at(e.x), true)
                onWheel: (w) => root.push(root.shown + (w.angleDelta.y > 0 ? root.step : -root.step), true)
            }
        }
        Text {
            Layout.alignment: root.marks.length ? Qt.AlignTop : Qt.AlignVCenter
            Layout.topMargin: root.marks.length ? 7 : 0
            text: root.label
            font.family: Theme.fontUi; font.pixelSize: 12; font.features: ({ "tnum": 1 })
            color: Colors.fgDim
            horizontalAlignment: Text.AlignRight
            Layout.minimumWidth: root.labelWidth
            Behavior on color { ColorAnimation { duration: Theme.normal } }
        }
    }
}
