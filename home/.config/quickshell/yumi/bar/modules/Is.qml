import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs

// «Остров» (29.10): остров бара (.is в превью) — сплошная капсула 30 px Colors.isl с кромкой edge и мягкой тенью;
// внутри кнопки K (24 px, промежуток 4). Видимость острова задаёт бар (visible) — не по детям: их visible зависит от родителя.
Item {
    id: root
    default property alias content: row.data
    property int padX: 3
    property alias spacing: row.spacing
    implicitHeight: Theme.pillH
    implicitWidth: row.implicitWidth + padX * 2
    Layout.alignment: Qt.AlignVCenter
    Behavior on implicitWidth { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

    RectangularShadow {
        anchors.fill: bg
        offset.y: 3
        radius: bg.radius; blur: 12; spread: 0
        color: Qt.rgba(0, 0, 0, 0.26)
    }
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: height / 2
        color: Colors.isl
        border.width: 1; border.color: Colors.edge
        Behavior on color { ColorAnimation { duration: Theme.normal } }
    }
    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        x: root.padX
        spacing: 4
    }
}
