import QtQuick
import qs

// Кнопка полноэкранного плеера: прозрачная (button.yf-btn) или «верхняя» с подложкой (button.yf-top, on — белая).
// «Остров» (29.10): круглая; «верхняя» с fill — заливка (акцент обложки), ink — цвет значка на ней; нажатие 0.9 пружиной.
Rectangle {
    id: root
    property string icon: ""
    property bool raised: false
    property bool lit: false
    property int size: 48
    property int iconPx: 24
    property string tooltip: ""
    property color fill: "transparent"     // заливка «верхней» (прозрачная — прежнее стекло)
    property color ink: "#111111"
    signal clicked()
    readonly property bool filled: raised && fill.a > 0
    width: size; height: size; radius: size / 2
    border.width: raised && !lit && !filled ? 1 : 0; border.color: Qt.rgba(1, 1, 1, area.containsMouse ? 0.30 : 0.18)
    color: lit ? Qt.rgba(1, 1, 1, 0.88) : filled ? (area.containsMouse ? Qt.lighter(fill, 1.12) : fill)
         : Qt.rgba(1, 1, 1, raised ? (area.containsMouse ? 0.22 : 0.12) : (area.containsMouse ? 0.1 : 0))
    Behavior on color { ColorAnimation { duration: 150 } }
    scale: area.pressed ? 0.9 : 1
    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2 } }
    // глиф по центру своего рисунка, а не строки шрифта: у Nerd-значков разные поля и линия шрифта выше центра
    TextMetrics { id: tm; text: root.icon; font.family: Theme.fontIcon; font.pixelSize: root.iconPx }
    FontMetrics { id: fm; font: tm.font }
    Text { anchors.centerIn: parent; text: root.icon; font: tm.font
           anchors.horizontalCenterOffset: implicitWidth / 2 - (tm.tightBoundingRect.x + tm.tightBoundingRect.width / 2)
           anchors.verticalCenterOffset: implicitHeight / 2 - (fm.ascent + tm.tightBoundingRect.y + tm.tightBoundingRect.height / 2)
           color: root.lit ? "#111111" : root.filled ? root.ink : "white" }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
