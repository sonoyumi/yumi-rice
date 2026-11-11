import QtQuick
import qs

// Знак Yumi-Rice — печать-ханко 弓 (как yumi-rice.svg в теме значков, 19.10): скруглённый квадрат цвета color,
// иероглиф «вырезан» цветом ink. Заменил значок Arch 󰣇 в баре, меню «Система», центре управления и виджете обоев.
Rectangle {
    id: mark
    property int size: Theme.iconSize
    property color ink: Colors.deep
    implicitWidth: size; implicitHeight: size
    radius: Math.max(2, Math.round(size * 0.15))
    color: Colors.acc
    Behavior on color { ColorAnimation { duration: 100 } }
    Text {
        anchors.centerIn: parent
        text: "弓"
        font.family: "Noto Serif CJK JP"; font.weight: Font.Black
        font.pixelSize: Math.round(mark.size * 0.69)          // 138 из 200 в SVG
        color: mark.ink
    }
}
