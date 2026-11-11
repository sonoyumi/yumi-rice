import QtQuick
import QtQuick.Layouts
import qs

// Подпись раздела («Громкость», «Выход»). «Остров» (29.10): как components/ISection — Onest 11 Medium ЗАГЛАВНЫМИ
// с разрядкой, приглушённо, без черты.
Text {
    Layout.fillWidth: true
    Layout.topMargin: 8
    font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.Medium
    font.capitalization: Font.AllUppercase; font.letterSpacing: 1
    color: Colors.fgDim
    elide: Text.ElideRight
    bottomPadding: 2
    Behavior on color { ColorAnimation { duration: Theme.normal } }
}
