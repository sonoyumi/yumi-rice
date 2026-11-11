import QtQuick
import qs
import qs.components

// Кнопка острова: значок Nerd Font, подсветка при наведении, сжатие при нажатии.
// «Остров» (29.10): круглая (.cb превью), наведение — isl2, включённая — акцент с onAcc; нажатие 0.9.
Rectangle {
    id: root
    property string icon: ""
    property bool active: false
    property bool enabled: true
    property int size: 32
    property int iconSize: 17
    property string tooltip: ""
    signal clicked()

    width: size; height: size; radius: size / 2
    color: root.active ? Colors.acc : (area.containsMouse && root.enabled ? Colors.isl2 : "transparent")
    Behavior on color { ColorAnimation { duration: Theme.fast } }
    opacity: root.enabled ? 1 : 0.35
    scale: area.pressed ? 0.9 : 1
    Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
    Glyph { anchors.centerIn: parent; text: root.icon; font.pixelSize: root.iconSize
            color: root.active ? Colors.onAcc : Colors.fg }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; enabled: root.enabled; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
