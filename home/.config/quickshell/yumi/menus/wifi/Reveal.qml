import QtQuick
import QtQuick.Layouts
import qs

// Раскрывающийся блок (как Gtk.Revealer): высота 0 ↔ высота содержимого, содержимое выезжает снизу
Item {
    id: root
    property bool shown: false
    property int spacing: 8
    default property alias content: inner.data
    Layout.fillWidth: true
    implicitHeight: shown ? inner.implicitHeight : 0
    clip: true
    opacity: shown ? 1 : 0
    visible: implicitHeight > 0 || shown
    Behavior on implicitHeight { NumberAnimation { duration: Theme.normal; easing.type: Theme.easeSoft } }
    Behavior on opacity { NumberAnimation { duration: Theme.normal } }
    ColumnLayout { id: inner; width: parent.width; y: root.height - height; spacing: root.spacing }
}
