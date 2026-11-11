import QtQuick
import QtQuick.Layouts
import qs

// «Остров»: едва заметная черта (Colors.edge) — раньше «Карточка B»; черта 1 px через всю ширину (между разделами, над подвалом); vertical — вертикальная (между колонками)
Rectangle {
    property bool vertical: false
    Layout.fillWidth: !vertical
    Layout.fillHeight: vertical
    implicitHeight: vertical ? 10 : 1
    implicitWidth: vertical ? 1 : 10
    color: Colors.edge
}
