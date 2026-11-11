import QtQuick
import Quickshell.Widgets
import qs
import qs.components

// Миниатюра картинки из истории (файл из кэша бэкенда): скруглённые углы — ClippingRectangle (без шейдеров и слоёв),
// пока не загрузилась — плашка isl2 со значком. Загрузка асинхронная, в память — уменьшенная копия (sourceSize).
ClippingRectangle {
    id: root
    property string source: ""
    implicitWidth: 74; implicitHeight: 46
    radius: 12
    color: Colors.isl2
    Glyph { anchors.centerIn: parent; text: "󰋩"; color: Colors.fgDim; visible: img.status !== Image.Ready }
    Image {
        id: img
        anchors.fill: parent
        source: root.source ? "file://" + root.source : ""
        sourceSize.width: 240
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
    }
}
