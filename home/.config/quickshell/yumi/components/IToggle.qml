import QtQuick
import qs

// «Остров»: переключатель 40×24 — бегунок на пружине, вкл = акцент (бегунок onAcc). Нажатие растягивает бегунок.
Rectangle {
    id: t
    property bool on: false
    property bool interactive: true
    signal toggled()
    implicitWidth: 40; implicitHeight: 24; radius: 12
    color: on ? Colors.acc : Colors.hover
    Behavior on color { ColorAnimation { duration: 250 } }
    Rectangle {
        y: 3; height: 18; radius: 9
        width: ma.pressed ? 24 : 18
        x: t.on ? t.width - width - 3 : 3
        color: t.on ? Colors.onAcc : Colors.fg
        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
        Behavior on width { NumberAnimation { duration: 180 } }
        Behavior on color { ColorAnimation { duration: 250 } }
    }
    MouseArea { id: ma; anchors.fill: parent; enabled: t.interactive; cursorShape: Qt.PointingHandCursor; onClicked: t.toggled() }
}
