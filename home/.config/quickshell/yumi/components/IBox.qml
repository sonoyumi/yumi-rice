import QtQuick
import QtQuick.Layouts
import qs

// «Остров»: блок-подложка внутри карточки (isl2, radius 18) — для статистики, плеера, сводок. Содержимое — ColumnLayout.
Rectangle {
    id: box
    default property alias content: col.data
    property int pad: 12
    property alias spacing: col.spacing
    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + pad * 2
    radius: Theme.radiusTile
    color: Colors.isl2
    ColumnLayout { id: col; anchors.fill: parent; anchors.margins: box.pad; spacing: 8 }
}
