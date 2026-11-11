import QtQuick
import qs

// Значок Nerd Font (как iconwrap: крупнее текста, чуть опущен)
Text {
    property bool yumi: false          // шрифт YumiIcons (AirPods, колонка)
    font.family: yumi ? Theme.fontYumi : Theme.fontIcon
    font.pixelSize: Theme.iconSize
    color: Colors.fg
    verticalAlignment: Text.AlignVCenter
    Behavior on color { ColorAnimation { duration: 100 } }
}
