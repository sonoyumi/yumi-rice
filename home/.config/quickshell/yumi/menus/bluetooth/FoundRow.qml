import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services
import qs.menus.wifi

// Найденное (несопряжённое) устройство: клик → сопряжение прямо под строкой: шаги, запросы агента (код, PIN), итог
ColumnLayout {
    id: row
    required property var model
    required property int index
    required property var menu
    readonly property string mac: model.mac || ""
    readonly property bool pairing: Bt.pairMac === mac
    readonly property var agent: pairing ? Bt.pairAgent : null
    readonly property var result: pairing ? Bt.pairResult : null
    Layout.fillWidth: true
    implicitWidth: parent ? parent.width : 0     // 19.10: иначе строка бывала нулевой ширины — стрелки и мышь её не видели
    spacing: 0
    opacity: 0
    Component.onCompleted: appear.start()
    SequentialAnimation {
        id: appear
        PauseAnimation { duration: Math.max(0, Math.min(row.index, 12)) * 40 }
        ParallelAnimation {
            NumberAnimation { target: row; property: "opacity"; to: 1; duration: 280; easing.type: Easing.OutCubic }
            NumberAnimation { target: row; property: "dy"; to: 0; duration: 280; easing.type: Easing.OutCubic }
        }
    }
    property real dy: 8
    transform: Translate { y: row.dy }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 52
        radius: Theme.radius                          // «Остров»: вид IRow; сопряжение — подложка акцентом
        color: row.pairing ? Colors.alpha(Colors.acc, 0.16) : hm.containsMouse ? Colors.isl2 : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        scale: hm.pressed ? 0.985 : 1
        Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 9; anchors.rightMargin: 10; spacing: 12
            MIconSq { icon: row.model.icon || ""; on: row.pairing }
            MText { Layout.fillWidth: true; text: row.model.name || ""; elide: Text.ElideRight; font.weight: Font.Medium }
            MText { text: (row.model.rssi !== null && row.model.rssi !== undefined) ? row.model.rssi + " dBm" : ""; font.pixelSize: 12; font.features: ({ "tnum": 1 }); color: Colors.fgDim; Layout.minimumWidth: 56; horizontalAlignment: Text.AlignRight }
        }
        MouseArea { id: hm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: !Bt.pairMac; onClicked: Bt.pair(row.mac) }
    }

    Reveal {
        shown: row.pairing
        spacing: 8
        Rectangle {
            Layout.fillWidth: true; Layout.topMargin: 4
            implicitHeight: steps.implicitHeight + 24; radius: Theme.radiusTile
            color: Colors.isl2
            ColumnLayout {
                id: steps
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 4
                Repeater {
                    model: 3
                    delegate: RowLayout {
                        required property int index
                        readonly property string st: Bt.pairSteps[index] || "wait"
                        spacing: 8
                        Item {
                            Layout.preferredWidth: 18; Layout.preferredHeight: 18
                            MSpinner { anchors.centerIn: parent; visible: parent.parent.st === "run" }
                            Glyph { anchors.centerIn: parent; visible: parent.parent.st !== "run"; font.pixelSize: 14
                                    text: parent.parent.st === "ok" ? "󰄬" : parent.parent.st === "err" ? "󰅖" : "󰇘"
                                    color: parent.parent.st === "ok" ? Colors.ok : parent.parent.st === "err" ? Colors.bad : Colors.fgDim }
                        }
                        MText { text: Bt.pairTitles[index]; font.pixelSize: 12; color: parent.st === "wait" ? Colors.fgDim : Colors.fg }
                    }
                }
            }
        }
        // запрос агента bluetoothctl: сверить код / ввести PIN / набрать код на устройстве
        Rectangle {
            visible: row.agent !== null
            Layout.fillWidth: true
            implicitHeight: ask.implicitHeight + 24; radius: Theme.radiusTile
            color: Colors.alpha(Colors.acc, 0.16)                 // «Остров»: активный запрос — подложка акцентом
            ColumnLayout {
                id: ask
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 8
                MText {
                    Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12
                    text: !row.agent ? "" : row.agent.kind === "confirm" ? "Проверьте, что на устройстве показан такой же код:"
                        : row.agent.kind === "pin" ? "Введите PIN-код устройства (часто 0000 или 1234):"
                        : row.agent.kind === "passkey" ? "Введите код, показанный на устройстве:"
                        : "Наберите этот код на устройстве и нажмите Enter:"
                }
                MText { visible: row.agent && (row.agent.kind === "confirm" || row.agent.kind === "display"); Layout.alignment: Qt.AlignHCenter
                        text: row.agent ? row.agent.code : ""; font.pixelSize: 24; font.weight: Font.DemiBold; font.letterSpacing: 4; font.features: ({ "tnum": 1 }); color: Colors.acc }
                Rectangle {
                    visible: row.agent && (row.agent.kind === "pin" || row.agent.kind === "passkey")
                    Layout.fillWidth: true; implicitHeight: 40; radius: 20      // «Остров»: поле-капсула
                    color: Colors.isl2; border.width: codeField.activeFocus ? 1.5 : 0; border.color: Colors.acc
                    TextInput {
                        id: codeField
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 16 }
                        font.family: Theme.fontUi; font.pixelSize: Theme.fontSize; color: Colors.fg; clip: true
                        onAccepted: Bt.pairReply(text.trim() || "0000")
                        Connections { target: row; function onAgentChanged() { if (!row.agent) codeField.focus = false; else if (row.agent.kind === "pin" || row.agent.kind === "passkey") codeField.forceActiveFocus() } }
                        Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; visible: !codeField.text; text: "Код"; font: codeField.font; color: Colors.fgDim }
                    }
                }
                RowLayout {
                    visible: row.agent && row.agent.kind === "confirm"
                    Layout.fillWidth: true; spacing: 8
                    MButton { Layout.fillWidth: true; text: "Отклонить"; onClicked: Bt.pairReply("no") }
                    MButton { Layout.fillWidth: true; text: "Подтвердить"; kind: "primary"; onClicked: Bt.pairReply("yes") }
                }
                MButton { visible: row.agent && (row.agent.kind === "pin" || row.agent.kind === "passkey"); Layout.fillWidth: true
                          text: "Отправить"; kind: "primary"; onClicked: Bt.pairReply(codeField.text.trim() || "0000") }
            }
        }
        // итог
        ColumnLayout {
            visible: row.result !== null
            Layout.fillWidth: true; spacing: 8
            MText { visible: row.result && row.result.ok; Layout.fillWidth: true; wrapMode: Text.Wrap
                    text: "󰄬  «" + (row.model.name || "") + "» подключено"; color: Colors.acc; font.weight: Font.DemiBold }
            MText { visible: row.result && !row.result.ok; Layout.fillWidth: true; wrapMode: Text.Wrap
                    text: row.result ? (row.result.msg || "Не получилось") : ""; color: Colors.bad; font.pixelSize: 12 }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                MButton { visible: row.result && !row.result.ok; Layout.fillWidth: true; text: "Повторить"; kind: "primary"; onClicked: Bt.pair(row.mac) }
                MButton { Layout.fillWidth: true; text: row.result && row.result.ok ? "К устройствам" : "Закрыть"; onClicked: Bt.pairCancel() }
            }
        }
        Item { implicitHeight: 4 }
    }
}
