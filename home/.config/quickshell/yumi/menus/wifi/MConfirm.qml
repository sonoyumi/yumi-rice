import QtQuick
import QtQuick.Layouts
import qs

// Вопрос с двумя кнопками (как yp.confirm_box). «Остров» (29.10): блок radius 18, isl2 с красноватым оттенком, без кромки.
Rectangle {
    id: root
    property string text: ""
    property string yesText: "Удалить"
    signal yes()
    signal no()
    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 24
    radius: Theme.radiusTile
    color: Colors.mix(Colors.isl2, Colors.bad, 0.12)
    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 10
        Text { Layout.fillWidth: true; text: root.text; wrapMode: Text.Wrap; font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fg }
        RowLayout {
            spacing: 8
            MButton { Layout.fillWidth: true; text: root.yesText; kind: "danger"; onClicked: root.yes() }
            MButton { Layout.fillWidth: true; text: "Отмена"; onClicked: root.no() }
        }
    }
}
