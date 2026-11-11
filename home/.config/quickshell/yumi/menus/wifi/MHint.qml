import QtQuick
import QtQuick.Layouts
import qs

// Подсказка: приглушённый текст с переносом по ширине меню
Text {
    Layout.fillWidth: true
    font.family: Theme.fontUi
    font.pixelSize: 11
    color: Colors.fgDim
    wrapMode: Text.Wrap
    leftPadding: 6; rightPadding: 6
    Behavior on color { ColorAnimation { duration: Theme.normal } }
}
