import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// «Остров»: плитка центра управления — значок, название, состояние; вкл = акцентная заливка, углы круглее (морфинг).
// Клик — toggled(); правый клик / удержание — menuRequested(). kb — фокус клавиатуры.
Rectangle {
    id: tile
    property string icon: ""
    property string iconOff: icon
    property bool yumiIcon: false
    property string title: ""
    property string sub: ""
    property bool on: false
    property bool kb: false
    property bool hasMenu: true
    signal toggled()
    signal menuRequested()
    Layout.fillWidth: true
    implicitHeight: 56
    radius: on ? 24 : Theme.radiusTile
    color: on ? Colors.acc : (ma.containsMouse ? Colors.hover : Colors.isl2)
    border.width: kb ? 1.5 : 0; border.color: on ? Colors.fg : Colors.acc
    Behavior on radius { NumberAnimation { duration: 380; easing.type: Easing.OutBack } }
    Behavior on color { ColorAnimation { duration: 250 } }
    scale: ma.pressed ? 0.96 : 1
    Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10
        spacing: 10
        Glyph { text: tile.on ? tile.icon : tile.iconOff; yumi: tile.yumiIcon; font.pixelSize: 17; color: tile.on ? Colors.onAcc : Colors.fg }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 0
            Text { Layout.fillWidth: true; text: tile.title; elide: Text.ElideRight; font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium
                   color: tile.on ? Colors.onAcc : Colors.fg }
            Text { Layout.fillWidth: true; text: tile.sub; elide: Text.ElideRight; font.family: Theme.fontUi; font.pixelSize: 11
                   color: tile.on ? Colors.alpha(Colors.onAcc, 0.72) : Colors.fgDim }
        }
    }
    MouseArea {
        id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        property bool held: false
        onPressed: held = false
        onPressAndHold: (e) => { if (tile.hasMenu && e.button === Qt.LeftButton) { held = true; tile.menuRequested() } }
        onClicked: (e) => { if (e.button === Qt.RightButton) { if (tile.hasMenu) tile.menuRequested() } else if (!held) tile.toggled() }
    }
}
