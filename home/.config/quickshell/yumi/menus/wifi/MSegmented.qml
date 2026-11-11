import QtQuick
import QtQuick.Layouts
import qs

// Сегменты (как yp.Segmented): items = [{key, icon, text}], current — активный ключ, enabledKeys — доступные (null = все).
// «Остров» (29.10): капсула isl2 radius 16, выбранный — акцентная плашка, переезжает пружиной (как components/ISeg).
Rectangle {
    id: root
    property var items: []
    property var current: null
    property var enabledKeys: null
    signal picked(var key)
    implicitHeight: 36
    radius: 16
    color: Colors.isl2
    Behavior on color { ColorAnimation { duration: Theme.normal } }
    readonly property int curIndex: { for (let i = 0; i < items.length; i++) if (items[i].key === current) return i; return -1 }
    readonly property real cw: (width - 8 - (items.length - 1) * 4) / Math.max(1, items.length)

    Rectangle {
        visible: root.curIndex >= 0
        y: 4; height: parent.height - 8; width: root.cw; radius: 12
        x: 4 + Math.max(0, root.curIndex) * (root.cw + 4)
        color: Colors.acc
        Behavior on x { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }
        Behavior on color { ColorAnimation { duration: Theme.normal } }
    }
    Row {
        x: 4; y: 4; spacing: 4
        Repeater {
            model: root.items
            delegate: Item {
                id: seg
                required property var modelData
                readonly property bool on: root.current === modelData.key
                readonly property bool can: !root.enabledKeys || root.enabledKeys.indexOf(modelData.key) >= 0
                width: root.cw; height: root.height - 8
                opacity: can ? 1 : 0.35
                Rectangle { anchors.fill: parent; radius: 12; color: Colors.hover; opacity: m.containsMouse && seg.can && !seg.on ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.fast } } }
                Row {
                    anchors.centerIn: parent; spacing: 5
                    Text { id: segIcon; text: seg.modelData.icon || ""; visible: text.length > 0; font.family: Theme.fontIcon; font.pixelSize: 14
                           color: seg.on ? Colors.onAcc : Colors.fg; anchors.verticalCenter: parent.verticalCenter
                           /* выбор — без затухания (29.10) */ }
                    Text { text: seg.modelData.text; font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium
                           width: Math.min(implicitWidth, seg.width - 8 - (segIcon.visible ? segIcon.implicitWidth + 5 : 0))
                           fontSizeMode: Text.HorizontalFit; minimumPixelSize: 10; elide: Text.ElideRight
                           color: seg.on ? Colors.onAcc : Colors.fgDim; anchors.verticalCenter: parent.verticalCenter
                           /* выбор — без затухания (29.10) */ }
                }
                MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; enabled: seg.can; cursorShape: Qt.PointingHandCursor; onClicked: root.picked(seg.modelData.key) }
            }
        }
    }
}
