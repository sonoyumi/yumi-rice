import QtQuick
import qs

// Поле ввода меню. «Остров» (29.10): капсула isl2 (как components/IField), в фокусе — кромка акцентом;
// bad — красная кромка (ошибка проверки), снимается при правке.
Rectangle {
    id: root
    property alias text: input.text
    property string placeholder: ""
    property bool bad: false
    signal accepted()
    function release() { input.focus = false }       // снять фокус до закрытия окна (иначе Qt падает при уничтожении)
    implicitHeight: 36
    radius: height / 2
    color: Colors.isl2
    border.width: bad || input.activeFocus ? 1.5 : 0
    border.color: bad ? Colors.bad : Colors.acc
    TextInput {
        id: input
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
        font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fg
        selectByMouse: true; selectionColor: Colors.alpha(Colors.acc, 0.35); selectedTextColor: Colors.fg
        clip: true
        onTextEdited: root.bad = false
        onAccepted: root.accepted()
        Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; visible: !input.text && !input.activeFocus
               text: root.placeholder; font: input.font; color: Colors.fgDim; elide: Text.ElideRight }
    }
}
