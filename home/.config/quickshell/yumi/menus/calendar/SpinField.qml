import QtQuick
import QtQuick.Layouts
import qs

// Поле «− 09 +» — «Остров» (29.10): капсула isl2, цифры Onest 19 (tnum); кнопки, колесо мыши, стрелки вверх/вниз,
// ввод цифр; значение по кругу 0..max. Фокус — кромка акцентом.
Rectangle {
    id: root
    property int value: 0
    property int max: 23
    property int step: 1
    implicitWidth: 120; implicitHeight: 40; radius: 20
    color: Colors.isl2
    border.width: field.activeFocus ? 1.5 : 0; border.color: Colors.acc
    opacity: enabled ? 1 : 0.35
    Behavior on opacity { NumberAnimation { duration: Theme.fast } }
    function set(v) { const n = max + 1; value = ((v % n) + n) % n; field.text = (value < 10 ? "0" : "") + value }
    Component.onCompleted: set(value)
    onValueChanged: if (field.text !== (value < 10 ? "0" : "") + value && !field.activeFocus) set(value)

    RowLayout {
        anchors.fill: parent; anchors.margins: 4; spacing: 2
        IconBtn { icon: "󰍴"; size: 32; iconPx: 13; flat: true; onClicked: root.set(root.value - root.step) }
        TextInput {
            id: field
            Layout.fillWidth: true
            horizontalAlignment: TextInput.AlignHCenter
            font.family: Theme.fontUi; font.pixelSize: 19; font.weight: Font.DemiBold; font.features: ({ "tnum": 1 })
            color: Colors.fg; selectionColor: Colors.alpha(Colors.acc, 0.45); selectedTextColor: Colors.fg
            maximumLength: 2
            inputMethodHints: Qt.ImhDigitsOnly
            validator: IntValidator { bottom: 0; top: root.max }
            onTextEdited: { const n = parseInt(text); if (!isNaN(n) && n <= root.max) root.value = n }
            onEditingFinished: root.set(root.value)
            onActiveFocusChanged: if (activeFocus) selectAll(); else root.set(root.value)
            Keys.onUpPressed: root.set(root.value + root.step)
            Keys.onDownPressed: root.set(root.value - root.step)
        }
        IconBtn { icon: "󰐕"; size: 32; iconPx: 13; flat: true; onClicked: root.set(root.value + root.step) }
    }
    MouseArea { anchors.fill: parent; z: -1; onWheel: w => root.set(root.value + (w.angleDelta.y > 0 ? root.step : -root.step)) }
}
