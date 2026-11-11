import QtQuick
import qs

// Обычный текст меню: шрифт и цвет из темы, цвет меняется плавно (смена обоев)
Text {
    font.family: Theme.fontUi
    font.pixelSize: Theme.fontSize
    color: Colors.fg
    verticalAlignment: Text.AlignVCenter
    Behavior on color { ColorAnimation { duration: Theme.normal } }
}
