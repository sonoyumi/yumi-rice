import QtQuick
import QtQuick.Layouts
import qs
import qs.services

// Профили звуковой карты: список строк, активный с галочкой. «Выкл.» — с подтверждением (как в GTK).
ColumnLayout {
    id: root
    property var card            // запись бэкенда (Sound.state.cards[i])
    property bool confirming: false
    spacing: 4

    Repeater {
        model: root.card ? root.card.profiles : []
        delegate: RowButton {
            required property var modelData
            icon: modelData.icon; text: modelData.ru; active: modelData.active
            onClicked: {
                if (modelData.active) return
                if (modelData.key === "off") { root.confirming = true; return }
                Sound.setProfile(root.card.name, modelData.key)
            }
        }
    }
    // подтверждение выключения карты
    Rectangle {
        Layout.fillWidth: true
        visible: height > 0
        implicitHeight: root.confirming ? confirmCol.implicitHeight + 20 : 0
        clip: true
        radius: Theme.radiusTile       // «Остров»: блок isl2 с красноватым оттенком
        color: Colors.mix(Colors.isl2, Colors.bad, 0.12)
        Behavior on implicitHeight { NumberAnimation { duration: Theme.normal; easing.type: Theme.easeSoft } }
        ColumnLayout {
            id: confirmCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 8
            Text { Layout.fillWidth: true; wrapMode: Text.Wrap; font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fg
                   text: "Выключить звуковую карту? Её выходы и входы пропадут, пока не выберете профиль снова." }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 8
                Chip { text: "Отмена"; onClicked: root.confirming = false }
                Chip { text: "Выключить"; live: true; onClicked: { root.confirming = false; Sound.setProfile(root.card.name, "off") } }
            }
        }
    }
}
