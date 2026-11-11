import QtQuick
import qs

// Фокус клавиатуры центра. «Остров» (29.10): кромка акцентом 1.5 px поверх элемента, лёгкая подложка акцентом 0.10.
// on — показать; inset — отступ рамки от элемента (-3 — снаружи).
Rectangle {
    property bool on: false
    anchors.fill: parent
    property int inset: -3
    anchors.margins: inset
    radius: Theme.radius
    color: Colors.alpha(Colors.acc, 0.10)
    border.width: 1.5; border.color: Colors.acc
    opacity: on ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.fast } }
}
