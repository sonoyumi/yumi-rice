import QtQuick
import Quickshell.Widgets
import qs
import qs.components

// Квадратная обложка трека из кэша yumi-music. Файл — уменьшенная квадратная копия под физические пиксели
// (бэкенд: ~/.cache/yumi-music/menu-thumbs/<px>/<ключ>.jpg, тот же кэш, что у GTK-меню), px = size × devicePixelRatio.
// Загрузка асинхронная, пока нет файла — подложка со значком.
ClippingRectangle {
    id: root
    property var store: null              // MusicMenu: coverPath(key, px, rev)
    property string key: ""
    property int size: 36
    readonly property int px: Math.max(16, Math.round(size * (Screen.devicePixelRatio || 1)))
    readonly property string path: store && key ? store.coverPath(key, px, store.covRev) : ""
    width: size; height: size
    radius: 6
    color: Colors.isl2
    Behavior on color { ColorAnimation { duration: Theme.normal } }
    Glyph {
        anchors.centerIn: parent
        visible: img.status !== Image.Ready
        text: "󰝚"; font.pixelSize: Math.max(10, Math.round(root.size * 0.38)); color: Colors.alpha(Colors.fg, 0.3)
    }
    Image {
        id: img
        anchors.fill: parent
        source: root.path ? "file://" + root.path : ""
        sourceSize.width: root.px; sourceSize.height: root.px
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
    }
}
