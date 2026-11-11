import QtQuick
import QtQuick.Layouts
import qs

// Подвал карточки. «Остров» (29.10): как components/CardHints — подсказки клавиш по центру, клавиша в капсуле isl2,
// подпись приглушённо. hints = [["↑↓", "сеть"], ["Esc", "закрыть"]]; rule и center оставлены для совместимости
// (черты нет, всегда по центру). Не влезает в одну строку — переносится на вторую (тоже по центру).
ColumnLayout {
    id: root
    property var hints: []
    property bool rule: false
    property bool center: true
    Layout.fillWidth: true
    spacing: 6
    Item {
        id: box
        Layout.fillWidth: true
        implicitHeight: flow.implicitHeight
        // невидимый замер одной строкой: его ширина задаёт ширину Flow (центр), шире карточки — перенос
        Row { id: probe; opacity: 0; spacing: flow.spacing; Repeater { model: root.hints; delegate: chipC } }
        Flow {
            id: flow
            width: Math.min(box.width, probe.implicitWidth)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            Repeater { model: root.hints; delegate: chipC }
        }
    }
    Component {
        id: chipC
        Row {
            id: chip
            required property var modelData
            spacing: 6
            height: 20
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: kt.implicitWidth + 12; height: 18; radius: 7
                color: Colors.isl2; border.width: 1; border.color: Colors.edge
                Text { id: kt; anchors.centerIn: parent; text: chip.modelData[0]; font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.Medium; color: Colors.fg }
            }
            Text { anchors.verticalCenter: parent.verticalCenter; visible: text.length > 0; text: chip.modelData[1] || ""
                   font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim }
        }
    }
}
