import QtQuick
import qs
import "Kb.js" as Kb

// Чип-капсула («󰑊 Запись · 2», устройство потока). live — красный с пульсирующей точкой (микрофон слушают).
Rectangle {
    id: root
    property string text: ""
    property bool live: false
    property bool enabled: true
    property string tooltip: ""
    property color base: Colors.isl2          // «Остров»: подложка капсулы (на подложке isl2 — Colors.hover)
    property color ink: live ? Colors.bad : (enabled ? Colors.fg : Colors.alpha(Colors.fgDim, 0.65))   // цвет текста (полноэкранный плеер — белый)
    readonly property bool hovered: area.containsMouse
    signal clicked()

    implicitHeight: 32
    activeFocusOnTab: enabled && visible
    Keys.onPressed: (e) => { if (Kb.nav(root, e)) return; if (Kb.activate(e)) { root.clicked(); e.accepted = true } }
    implicitWidth: label.implicitWidth + 24
    radius: height / 2                 // «Остров»: капсула isl2, у записи — красноватая
    color: !enabled ? "transparent" : live ? Colors.mix(root.base, Colors.bad, 0.2) : (area.containsMouse ? Colors.mix(root.base, Colors.fg, 0.08) : root.base)
    Behavior on color { ColorAnimation { duration: Theme.fast } }
    Behavior on implicitWidth { NumberAnimation { duration: Theme.normal; easing.type: Theme.easeSoft } }
    scale: area.pressed ? 0.95 : 1
    Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }

    FocusRing { on: root.activeFocus; radius: root.radius }
    Row {
        anchors.centerIn: parent
        spacing: 6
        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium
            color: root.ink
            Behavior on color { ColorAnimation { duration: Theme.normal } }
            SequentialAnimation on opacity {   // индикатор записи пульсирует
                running: root.live; loops: Animation.Infinite
                onRunningChanged: if (!running) label.opacity = 1
                NumberAnimation { to: 0.45; duration: 700; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
            }
        }
    }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: root.enabled; onClicked: root.clicked() }
}
