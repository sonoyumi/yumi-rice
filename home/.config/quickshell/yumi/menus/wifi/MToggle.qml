import QtQuick
import qs

// «Остров» (29.10): переключатель 40×24 как components/IToggle — бегунок на пружине, вкл = акцент (бегунок onAcc).
// API прежний: checked задаёт родитель (из состояния), toggled(on) — что хочет пользователь.
Item {
    id: root
    property bool checked: false
    signal toggled(bool on)
    implicitWidth: 40; implicitHeight: 24
    opacity: enabled ? 1 : 0.4
    Behavior on opacity { NumberAnimation { duration: Theme.fast } }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: root.checked ? Colors.acc : Colors.hover
        Behavior on color { ColorAnimation { duration: 250 } }
        Rectangle {
            y: 3; height: 18; radius: 9
            width: m.pressed ? 24 : 18
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? Colors.onAcc : Colors.fg
            Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
            Behavior on width { NumberAnimation { duration: 180 } }
            Behavior on color { ColorAnimation { duration: 250 } }
        }
    }
    MouseArea { id: m; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggled(!root.checked) }
}
