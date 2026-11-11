import QtQuick
import QtQuick.Effects
import qs
import qs.components
import qs.menus.wifi

// Плитка обоев — «Остров»: radius 16, текущие/выбранные — кромка акцентом (как Tile в yumi-menu-wallpaper): миниатюра со скруглением (общая маска mask — одна на всю сетку),
// подпись снизу при наведении/выборе, рамка акцента и галочка у текущих, крутилка пока применяются.
// Картинка грузится асинхронно и в размере плитки × devicePixelRatio (не весь файл 1000×563 в память).
Item {
    id: tile
    property string source: ""            // путь миниатюры (или самого файла)
    property string name: ""
    property bool current: false
    property bool selected: false          // выбор с клавиатуры
    property bool applying: false
    property bool hovered: false
    property Item mask: null
    property real dpr: 1
    readonly property bool lit: hovered || selected

    // file:// с процентной кодировкой каждого куска пути: пробелы, кириллица, «#» в именах
    function fileUrl(p) { return p ? "file://" + p.split("/").map(encodeURIComponent).join("/") : "" }

    Rectangle {
        anchors.fill: parent; radius: 16; color: Colors.isl2
        Behavior on color { ColorAnimation { duration: Theme.normal } }
        Glyph { anchors.centerIn: parent; text: "󰋩"; font.pixelSize: 21; color: Colors.alpha(Colors.fg, 0.45); visible: img.status !== Image.Ready }
    }
    Image {
        id: img
        anchors.fill: parent
        source: tile.fileUrl(tile.source)
        sourceSize.width: Math.round(tile.width * tile.dpr)
        sourceSize.height: Math.round(tile.height * tile.dpr)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: img; maskEnabled: !!tile.mask; maskSource: tile.mask
        visible: opacity > 0; opacity: img.status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
    }
    // подпись: градиент снизу, видна при наведении / выборе
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: label.implicitHeight + 19
        radius: 16
        opacity: tile.lit ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.fast } }
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.55) }
        }
        Text {
            id: label
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.leftMargin: 8; anchors.rightMargin: 8; anchors.bottomMargin: 5
            text: tile.name; elide: Text.ElideMiddle
            font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.DemiBold; color: "white"
        }
    }
    // применяются: затемнение и крутилка
    Rectangle {
        anchors.fill: parent; radius: 16; color: Qt.rgba(0, 0, 0, 0.45)
        opacity: tile.applying ? 1 : 0; visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.fast } }
        MSpinner { anchors.centerIn: parent; width: 28; height: 28; visible: tile.applying }
    }
    // рамка — поверх картинки: текущие — акцент 3 px, наведение — светлая 2 px, выбор клавиатурой — 2 px
    Rectangle {
        anchors.fill: parent; radius: 16
        color: "transparent"
        border.width: tile.current || tile.selected ? 2 : (tile.hovered ? 1 : 0)
        border.color: tile.current || tile.selected ? Colors.acc : Colors.alpha(Colors.fg, 0.4)
        /* выбор — без затухания (29.10) */
        Behavior on border.color { ColorAnimation { duration: Theme.fast } }
        Rectangle {   // вторая кромка у текущих под курсором/выбором
            anchors.fill: parent; anchors.margins: 2; radius: 14; color: "transparent"
            border.width: 2; border.color: Colors.alpha(Colors.fg, 0.55)
            visible: tile.current && tile.lit
        }
    }
    // галочка у текущих
    Rectangle {
        anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 6
        width: 22; height: 22; radius: 11; color: Colors.acc
        visible: tile.current
        Glyph { anchors.centerIn: parent; text: "󰄬"; font.pixelSize: 13; color: Colors.onAcc }
    }
}
