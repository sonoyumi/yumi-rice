import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// «Остров» (29.10): строка списка — значок в квадрате 34 (isl2; выбранная — акцент), название, подпись, справа trailing.
// sel — выбрана (подложка акцентом 16 %), kb — фокус клавиатуры (кромка акцентом). Нажатие 0.985.
Rectangle {
    id: row
    property string icon: ""
    property bool yumiIcon: false
    property string title: ""
    property string sub: ""
    property bool sel: false
    property bool kb: false
    property bool dim: false
    property bool hoverable: true
    default property alias trailing: tr.data
    signal clicked()
    signal rightClicked()
    Layout.fillWidth: true
    implicitHeight: Math.max(52, col.implicitHeight + 18)
    radius: Theme.radius
    color: sel ? Colors.alpha(Colors.acc, 0.16) : (ma.containsMouse && hoverable ? Colors.isl2 : "transparent")
    border.width: kb ? 1 : 0; border.color: Colors.alpha(Colors.acc, 0.7)
    // 29.10: без ColorAnimation — при движении выбора стрелками прежняя строка гасла хвостом
    scale: ma.pressed ? 0.985 : 1
    Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
    opacity: dim ? 0.55 : 1

    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 9; anchors.rightMargin: 10
        spacing: 12
        Rectangle {
            visible: row.icon.length > 0
            implicitWidth: 34; implicitHeight: 34; radius: 12
            color: row.sel ? Colors.acc : Colors.isl2
            Behavior on color { ColorAnimation { duration: Theme.normal } }
            Glyph { anchors.centerIn: parent; text: row.icon; yumi: row.yumiIcon; font.pixelSize: 16; color: row.sel ? Colors.onAcc : Colors.fg }
        }
        ColumnLayout {
            id: col
            Layout.fillWidth: true
            spacing: 1
            Text { Layout.fillWidth: true; text: row.title; elide: Text.ElideRight; font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium; color: Colors.fg }
            Text { Layout.fillWidth: true; visible: text.length > 0; text: row.sub; elide: Text.ElideRight; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim }
        }
        RowLayout { id: tr; spacing: 8 }
    }
    MouseArea {
        id: ma; anchors.fill: parent; z: -1; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (e) => e.button === Qt.RightButton ? row.rightClicked() : row.clicked()
    }
}
