import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// «Остров»: поле ввода-капсула 40 px (isl2) со значком слева; фокус — кромка акцентом. input — сам TextInput.
Rectangle {
    id: f
    property string icon: String.fromCodePoint(0xf0349)      // 󰍉 поиск
    property alias text: inp.text
    property alias input: inp
    property string placeholder: ""
    property bool password: false
    signal accepted()
    Layout.fillWidth: true
    implicitHeight: 40; radius: 20
    color: Colors.isl2
    border.width: inp.activeFocus ? 1.5 : 0; border.color: Colors.acc
    RowLayout {
        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 10
        Glyph { visible: f.icon.length > 0; text: f.icon; font.pixelSize: 16; color: Colors.fgDim }
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            TextInput {
                id: inp; anchors.fill: parent; verticalAlignment: TextInput.AlignVCenter
                font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fg; selectionColor: Colors.alpha(Colors.acc, 0.4)
                echoMode: f.password ? TextInput.Password : TextInput.Normal; clip: true
                onAccepted: f.accepted()
            }
            Text { anchors.verticalCenter: parent.verticalCenter; visible: inp.text.length === 0; text: f.placeholder
                   font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fgDim }
        }
    }
}
