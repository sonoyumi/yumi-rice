import QtQuick
import qs

// Фокус клавиатуры. «Остров» (29.10): кромка акцентом 1.5 px, лёгкая подложка акцентом 0.10, скругление как у строк.
// on — показать (activeFocus элемента или зона).
Rectangle {
    property bool on: false
    anchors.fill: parent
    radius: Theme.radius
    color: Colors.alpha(Colors.acc, 0.10)
    border.width: 1.5; border.color: Colors.acc
    opacity: on ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.fast } }
}
