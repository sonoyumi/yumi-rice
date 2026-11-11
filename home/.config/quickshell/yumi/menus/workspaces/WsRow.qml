import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// Строка-кнопка (как yp-row): содержимое — внутрь, подсветка при наведении, активная — акцентом.
Rectangle {
    id: root
    property bool active: false
    property int pad: 10
    default property alias content: row.data
    signal clicked()
    Layout.fillWidth: true
    implicitHeight: Math.max(38, row.implicitHeight + 12)
    radius: 12
    color: active ? Colors.alpha(Colors.acc, mouse.containsMouse ? 0.28 : 0.2)
         : Colors.alpha(Colors.hover, mouse.containsMouse ? 0.5 : 0)
    Behavior on color { ColorAnimation { duration: Theme.fast } }
    scale: mouse.pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Theme.easeSpring } }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.clicked() }
    RowLayout { id: row; anchors.fill: parent; anchors.leftMargin: root.pad; anchors.rightMargin: root.pad; spacing: 10 }
}
