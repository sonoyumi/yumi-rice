import QtQuick
import QtQuick.Layouts
import qs

// Подпись раздела («Доступные сети»). «Остров» (29.10): как components/ISection — Onest 11 Medium ЗАГЛАВНЫМИ
// с разрядкой, приглушённо. jp и rule оставлены для совместимости и не показываются (иероглифов и черт нет).
// trail — число/состояние справа (11 px, табличные цифры). Корень — Item: text, leftPadding, topPadding, color, font сохранены.
Item {
    id: root
    property string text: ""
    property string jp: ""                 // устарело — не показывается
    property real leftPadding: 0
    property real rightPadding: 0
    property real topPadding: 6
    property real bottomPadding: 0
    property color color: Colors.fgDim
    property alias font: label.font
    property string trail: ""
    property bool rule: false              // устарело — черт нет
    readonly property real rightW: trailText.visible ? trailText.implicitWidth + 10 : 0
    implicitWidth: leftPadding + label.implicitWidth + rightW + rightPadding
    implicitHeight: topPadding + label.implicitHeight + bottomPadding

    Text {
        id: label
        x: root.leftPadding; y: root.topPadding
        width: Math.max(0, root.width - root.leftPadding - root.rightPadding - root.rightW)
        text: root.text
        elide: Text.ElideRight
        font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.Medium
        font.capitalization: Font.AllUppercase; font.letterSpacing: 1
        color: root.color
        Behavior on color { ColorAnimation { duration: Theme.normal } }
    }
    Text {
        id: trailText
        visible: root.trail.length > 0
        anchors.right: parent.right; anchors.rightMargin: root.rightPadding
        anchors.baseline: label.baseline
        text: root.trail
        font.family: Theme.fontUi; font.pixelSize: 11; font.features: ({ "tnum": 1 })
        color: Colors.fgDim
        Behavior on color { ColorAnimation { duration: Theme.normal } }
    }
}
