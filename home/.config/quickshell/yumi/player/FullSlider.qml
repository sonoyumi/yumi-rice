import QtQuick
import qs

// Белая тонкая полоса полноэкранного плеера (прогресс и громкость, как scale.yf-scale в yumi-player-full):
// дорожка 20 % белого, заливка 85 %, ручка появляется при наведении. value 0..1.
// «Остров» (29.10): дорожка-капсула, заливка fillColor (по умолчанию белая), ручка — круг; толще при наведении.
// Пока тянут и blockMs после — внешние значения не дёргают полосу; наружу moved(v) не чаще раза в throttleMs.
Item {
    id: root
    property real value: 0
    property real fillAlpha: 0.85
    property int throttleMs: 90
    property int blockMs: 1000
    property int track: 6
    property bool smooth: false            // плавное движение заливки (прогресс между опросами)
    property color fillColor: Qt.rgba(1, 1, 1, fillAlpha)
    signal moved(real v)

    implicitHeight: 22
    property real shown: value
    property bool blocked: false
    property real pending: -1
    onValueChanged: if (!area.pressed && !blocked) shown = value
    Timer { id: block; interval: root.blockMs; onTriggered: { root.blocked = false; root.shown = root.value } }
    Timer { id: thr; interval: root.throttleMs; repeat: true
        onTriggered: { if (root.pending >= 0) { root.moved(root.pending); root.pending = -1 } else stop() } }
    function push(v) {
        v = Math.max(0, Math.min(1, v))
        shown = v; blocked = true; block.restart()
        if (!thr.running) { moved(v); thr.start() } else pending = v
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width; height: root.track + (area.containsMouse || area.pressed ? 2 : 0); radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.2)
        Behavior on height { NumberAnimation { duration: 150 } }
        Rectangle {
            height: parent.height; radius: height / 2
            width: Math.max(height, parent.width * root.shown)
            color: root.fillColor
            Behavior on width { enabled: root.smooth && !area.pressed; NumberAnimation { duration: 500; easing.type: Easing.Linear } }
        }
        Rectangle {   // ручка
            x: parent.width * root.shown - width / 2; anchors.verticalCenter: parent.verticalCenter
            width: root.track * 2.6; height: width; radius: width / 2; color: "white"
            opacity: area.containsMouse || area.pressed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        function at(x) { return Math.max(0, Math.min(1, x / width)) }
        onPressed: (e) => root.push(at(e.x))
        onPositionChanged: (e) => { if (pressed) root.push(at(e.x)) }
    }
}
