import QtQuick
import QtQuick.Layouts
import Quickshell
import qs

// Пилюля бара — «остров» (29.10): сплошная капсула Colors.isl, наведение isl2, активная — акцент. Содержимое — в content.
// Клики: onClick/onRightClick/onMiddleClick — команды оболочки; либо сигналы clicked/rightClicked/…
Item {
    id: root
    default property alias content: row.data
    property string onClick: ""
    property string onRightClick: ""
    property string onMiddleClick: ""
    property string onScrollUp: ""
    property string onScrollDown: ""
    property bool   active: false            // подсветить как «включено»
    property bool   danger: false            // наведение красноватое (пилюля питания: #pill.right4:hover)
    property alias  spacing: row.spacing
    property bool   hovered: mouse.containsMouse
    property int    padX: Theme.pillPadX
    property string tooltip: ""
    signal clicked()
    signal rightClicked()
    signal middleClicked()
    signal scrolled(int dir)

    implicitHeight: Theme.pillH
    implicitWidth: row.implicitWidth + padX * 2
    property bool animateWidth: true          // false — ширину анимирует само содержимое (пилюля плеера: пружина)
    Behavior on implicitWidth { enabled: root.animateWidth; NumberAnimation { duration: Theme.normal; easing.type: Theme.easeSoft } }

    Rectangle {
        id: glass
        anchors.fill: parent
        radius: height / 2                  // «Остров» (29.10): сплошной остров-капсула в оттенке обоев
        color: root.hovered ? (root.danger ? Colors.mix(Colors.isl, Colors.bad, 0.22) : Colors.isl2)
             : root.active ? Colors.mix(Colors.isl, Colors.acc, 0.22) : Colors.isl
        Behavior on color { ColorAnimation { duration: 100 } }
        border.width: 1
        border.color: root.active ? Colors.alpha(Colors.acc, 0.55) : Colors.edge
        Behavior on border.color { ColorAnimation { duration: Theme.fast } }
    }
    scale: mouse.pressed ? 0.94 : 1
    Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Theme.moduleGap
    }

    MouseArea {   // под содержимым (z −1): у модулей свои MouseArea — клик по модулю не должен уходить в пилюлю
        id: mouse
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: (e) => {
            if (e.button === Qt.LeftButton) { root.clicked(); if (root.onClick) Quickshell.execDetached(["sh", "-c", root.onClick]) }
            else if (e.button === Qt.RightButton) { root.rightClicked(); if (root.onRightClick) Quickshell.execDetached(["sh", "-c", root.onRightClick]) }
            else { root.middleClicked(); if (root.onMiddleClick) Quickshell.execDetached(["sh", "-c", root.onMiddleClick]) }
        }
        onWheel: (w) => {
            const up = w.angleDelta.y > 0
            root.scrolled(up ? 1 : -1)
            const cmd = up ? root.onScrollUp : root.onScrollDown
            if (cmd) Quickshell.execDetached(["sh", "-c", cmd])
        }
    }
}
