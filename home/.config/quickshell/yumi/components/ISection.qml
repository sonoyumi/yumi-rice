import QtQuick
import QtQuick.Layouts
import qs

// «Остров»: подпись раздела — 11 px заглавными, разрядка, приглушённо (вместо черт «Карточки B»).
Text {
    Layout.fillWidth: true
    Layout.topMargin: 4
    font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.Medium
    font.capitalization: Font.AllUppercase; font.letterSpacing: 1
    color: Colors.fgDim
    elide: Text.ElideRight
}
