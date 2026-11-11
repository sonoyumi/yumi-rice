import QtQuick
import qs

// Маленькая кнопка-капсула («Все · N», «Очистить») центра управления. «Остров» (29.10): как components/IChip — isl2,
// наведение hover, нажатие 0.95; ink — цвет подписи (красный — для «Очистить»).
Rectangle {
    id: chip
    property string label: ""
    property color ink: Colors.fg
    property bool kb: false            // фокус клавиатуры шторки
    signal clicked()
    implicitWidth: chipText.implicitWidth + 24; implicitHeight: 28; radius: 14
    color: chipMa.containsMouse ? Colors.hover : Colors.isl2
    Behavior on color { ColorAnimation { duration: Theme.fast } }
    scale: chipMa.pressed ? 0.95 : 1
    Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
    KbRing { on: chip.kb; inset: -2; radius: 16 }
    Text { id: chipText; anchors.centerIn: parent; text: chip.label
           font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium; color: chip.ink }
    MouseArea { id: chipMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked() }
}
