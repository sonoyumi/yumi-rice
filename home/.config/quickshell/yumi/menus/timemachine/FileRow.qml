import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// Строка «Машины времени»: значок, имя, справа — размер / отметка (badge) / «›» у папки. on — выбрана (акцент 16 % + кромка).
// cascade — номер строки: проявляется каскадом при появлении (не больше 12 × Theme.cascade).
Rectangle {
    id: row
    property string icon: ""
    property string name: ""
    property string meta: ""
    property string badge: ""
    property color badgeColor: Colors.ok
    property bool on: false
    property bool dim: false
    property bool chevron: false
    property int cascade: 0
    signal clicked()
    signal doubleClicked()
    implicitHeight: 34
    radius: 12
    color: on ? Colors.alpha(Colors.acc, 0.16) : ma.containsMouse ? Colors.alpha(Colors.fg, 0.05) : "transparent"
    border.width: on ? 1 : 0; border.color: Colors.alpha(Colors.acc, 0.45)
    scale: ma.pressed ? 0.985 : 1
    Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }

    opacity: 0
    property real dy: 6
    transform: Translate { y: row.dy }
    Component.onCompleted: appear.start()
    SequentialAnimation {
        id: appear
        PauseAnimation { duration: Math.min(12, row.cascade) * Theme.cascade }
        ParallelAnimation {
            NumberAnimation { target: row; property: "opacity"; to: row.dim ? 0.6 : 1; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: row; property: "dy"; to: 0; duration: 280; easing.type: Easing.OutCubic }
        }
    }

    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
        spacing: 10
        Glyph {
            text: row.icon; font.pixelSize: 16
            color: row.on ? Colors.acc : Colors.alpha(Colors.fg, 0.8)
            Layout.preferredWidth: 18
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            Layout.fillWidth: true
            text: row.name; elide: Text.ElideMiddle
            textFormat: Text.PlainText
            font.family: Theme.fontUi; font.pixelSize: 13; font.weight: row.on ? Font.Medium : Font.Normal
            color: Colors.fg
        }
        Rectangle {
            visible: row.badge.length > 0
            implicitWidth: bt.implicitWidth + 14; implicitHeight: 20; radius: 10
            color: Colors.alpha(row.badgeColor, 0.16)
            Text { id: bt; anchors.centerIn: parent; text: row.badge; font.family: Theme.fontUi; font.pixelSize: 10; font.weight: Font.Medium; color: row.badgeColor }
        }
        Text {
            visible: row.meta.length > 0
            text: row.meta
            font.family: Theme.fontUi; font.pixelSize: 11; font.features: { "tnum": 1 }
            color: Colors.fgDim
        }
        Glyph {
            visible: row.chevron
            text: String.fromCodePoint(0xf0142); font.pixelSize: 14; color: Colors.alpha(Colors.fg, 0.4)
        }
    }
    MouseArea {
        id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: row.clicked()
        onDoubleClicked: row.doubleClicked()
    }
}
