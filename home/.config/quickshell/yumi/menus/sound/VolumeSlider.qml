import QtQuick
import QtQuick.Layouts
import qs
import "Kb.js" as Kb
import qs.components

// Ползунок: кнопка «без звука» + заливка акцентом + процент.
// value — живое значение 0..1 (из PipeWire); пока тянут и 800 мс после — внешние обновления не дёргают ползунок.
// Отправка наружу не чаще раза в 70 мс (как Throttle в GTK), последнее значение доходит всегда.
Item {
    id: root
    property real value: 0
    property bool muted: false
    property string onIcon: "󰕾"
    property string offIcon: "󰖁"
    property string tooltip: "Без звука"
    property real max: 1.0
    property int throttleMs: 70           // не чаще раза в N мс (в острове плеера 90 — против треска в BT)
    property int blockMs: 800             // после ручного изменения столько не перезаписывать извне
    signal mute()
    signal changed(real v)

    Layout.fillWidth: true
    implicitHeight: 32
    activeFocusOnTab: visible
    Keys.onPressed: (e) => {           // ←→ ±5 %, Enter/Пробел — без звука, ↑↓ — фокус дальше
        if (Kb.nav(root, e)) return
        if (e.key === Qt.Key_Left) root.push(root.shown - 0.05)
        else if (e.key === Qt.Key_Right) root.push(root.shown + 0.05)
        else if (Kb.activate(e)) root.mute()
        else return
        e.accepted = true
    }
    FocusRing { on: root.activeFocus; anchors.margins: -3; radius: 18 }

    property real shown: value
    property real pending: -1
    property bool blocked: false
    onValueChanged: if (!drag.pressed && !blocked) shown = value
    Timer { id: block; interval: root.blockMs; onTriggered: { root.blocked = false; root.shown = root.value } }
    Timer { id: throttle; interval: root.throttleMs; repeat: true
        onTriggered: { if (root.pending >= 0) { root.changed(root.pending); root.pending = -1 } else stop() } }
    function push(v) {
        v = Math.max(0, Math.min(root.max, v))
        shown = v; blocked = true; block.restart()
        if (!throttle.running) { root.changed(v); throttle.start() } else pending = v
    }

    // «Остров» (29.10): кнопка «без звука» — круг 30, дорожка-капсула 26 (trackColor) с заливкой акцентом, процент справа.
    // Отображение указателя: доля = x / ширина (заливка растёт от левого края капсулы).
    property color trackColor: Colors.isl2
    RowLayout {
        anchors.fill: parent
        spacing: 10
        // кнопка «без звука»
        Rectangle {
            Layout.preferredWidth: 30; Layout.preferredHeight: 30
            radius: 15
            color: root.muted ? Colors.mix(root.trackColor, Colors.bad, 0.25) : (muteArea.containsMouse ? Colors.mix(root.trackColor, Colors.fg, 0.08) : root.trackColor)
            Behavior on color { ColorAnimation { duration: Theme.fast } }
            scale: muteArea.pressed ? 0.9 : 1
            Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
            Glyph { anchors.centerIn: parent; text: root.muted ? root.offIcon : root.onIcon
                    color: root.muted ? Colors.fgDim : Colors.fg; font.pixelSize: 15 }
            MouseArea { id: muteArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.mute() }
        }
        // дорожка-капсула
        Rectangle {
            id: track
            Layout.fillWidth: true; Layout.preferredHeight: 26
            radius: 13
            color: root.trackColor
            clip: true
            Rectangle {
                id: fill
                height: parent.height; radius: parent.radius
                width: Math.max(root.shown > 0.005 ? parent.height : 0, parent.width * Math.max(0, Math.min(1, root.shown / root.max)))
                color: root.muted ? Colors.alpha(Colors.fg, 0.25) : Colors.acc
                Behavior on width { enabled: !drag.pressed; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: Theme.normal } }
            }
            MouseArea {
                id: drag
                anchors.fill: parent
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor; preventStealing: true
                function at(x) { return root.max * Math.max(0, Math.min(1, x / width)) }
                onPressed: (e) => root.push(at(e.x))
                onPositionChanged: (e) => { if (pressed) root.push(at(e.x)) }
                onWheel: (w) => root.push(root.shown + (w.angleDelta.y > 0 ? 0.05 : -0.05))
            }
        }
        Text {
            text: Math.round(root.shown * 100) + "%"
            font.family: Theme.fontUi; font.pixelSize: 12; font.features: ({ "tnum": 1 })
            color: Colors.fgDim
            horizontalAlignment: Text.AlignRight
            Layout.minimumWidth: 38
        }
    }
}
