import QtQuick
import QtQuick.Layouts
import qs

// «Остров» (29.10): едва заметная черта Colors.edge (как components/CardRule). В «Острове» разделы отделяются
// отступами и подписями — новые меню её не ставят; strength оставлен для совместимости.
Rectangle {
    property real strength: 0.12
    Layout.fillWidth: true
    implicitHeight: 1
    height: 1
    color: Colors.edge
    Behavior on color { ColorAnimation { duration: Theme.normal } }
}
