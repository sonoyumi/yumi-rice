import QtQuick
import QtQuick.Layouts
import qs

// «Остров» (29.10): подвал — подсказки клавиш по центру: клавиша в капсуле isl2, подпись приглушённо (Onest 11).
// items: [["↑↓", "строка"], ["Esc", "закрыть"]]; note — приглушённая приписка в конце строки (необязательно).
ColumnLayout {
    id: root
    property var items: []
    property string note: ""
    Layout.fillWidth: true
    spacing: 6
    Item {                                   // по центру карточки (Flow прижимал бы влево)
        Layout.fillWidth: true
        implicitHeight: hintRow.implicitHeight
        Row {
            id: hintRow
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14
            Repeater {
                model: root.items
                Row {
                    required property var modelData
                    spacing: 6
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: kt.implicitWidth + 12; implicitHeight: 18; radius: 7
                        color: Colors.isl2; border.width: 1; border.color: Colors.edge
                        Text { id: kt; anchors.centerIn: parent; text: modelData[0]; font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.Medium; color: Colors.fg }
                    }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: modelData[1]; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim }
                }
            }
            Text { visible: root.note.length > 0; anchors.verticalCenter: parent.verticalCenter; text: root.note; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim; opacity: 0.8 }
        }
    }
}
