import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Строка приложения во вкладке «Приложения» (16.10, в стиле шторки центра; прежняя карточка — StreamCard.qml):
// значок в кружке (клик — без звука), имя и трек, устройство вывода справа (клик — «куда выводить», MovePage),
// под ними — ползунок громкости потока. Логика — как у StreamCard (Sound.setStreamVolume / toggleStreamMute).
// Клавиатурой управляет MainPage: selected — тихая рамка; ←→ громкость, Пробел — без звука, Enter — куда выводить.
Rectangle {
    id: root
    property string kind: "sink"
    property string serial: ""
    property bool selected: false
    readonly property var info: Sound.streamInfo(kind, serial)
    readonly property var node: info ? Sound.nodeBySerial(info.kind === "sink" ? Sound.outStreams : Sound.inStreams, info.serial) : null
    readonly property bool isMuted: node ? Sound.muted(node) : !!(info && info.mute)
    readonly property real level: node ? Sound.vol(node) : (info ? info.vol / 100 : 0)
    property real shown: level
    onLevelChanged: if (!drag.pressed && !hold.running) shown = level
    Timer { id: hold; interval: 800; onTriggered: root.shown = root.level }
    signal move()
    signal picked()

    function setVol(v) { v = Math.max(0, Math.min(1, v)); shown = v; hold.restart(); Sound.setStreamVolume(info, node, v) }
    function vol(d) { setVol(shown + d) }
    function mute() { Sound.toggleStreamMute(info, node) }

    implicitHeight: 86
    radius: Theme.radiusTile                   // «Остров»: подложка isl2, выбранная — акцентом 0.16
    color: selected ? Colors.alpha(Colors.acc, 0.16) : (rowMa.containsMouse ? Colors.hover : Colors.isl2)
    /* выбор — без затухания (29.10) */

    MouseArea { id: rowMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.picked() }

    Rectangle {      // значок: вкл — заливка акцентом; клик — без звука
        id: badge
        x: 12; y: 10
        width: 34; height: 34; radius: 12          // «Остров»: квадрат 34, вкл — акцент
        color: root.isMuted ? Colors.hover : Colors.acc
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        Glyph { anchors.centerIn: parent; text: root.isMuted ? "󰖁" : (root.info ? root.info.icon : "󰝚"); font.pixelSize: 16
                color: root.isMuted ? Colors.fgDim : Colors.onAcc }
        MouseArea { anchors.fill: parent; onClicked: { root.picked(); root.mute() } }
    }
    Column {
        anchors.left: badge.right; anchors.leftMargin: 10
        anchors.right: dev.left; anchors.rightMargin: 8
        anchors.verticalCenter: badge.verticalCenter
        spacing: 1
        Text { width: parent.width; text: root.info ? root.info.app : ""; font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium; color: Colors.fg; elide: Text.ElideRight }
        Text { width: parent.width; visible: text.length > 0; text: root.info ? root.info.sub : ""; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim; elide: Text.ElideRight }
    }
    Rectangle {      // устройство вывода (куда выводить)
        id: dev
        anchors.right: parent.right; anchors.rightMargin: 10
        anchors.verticalCenter: badge.verticalCenter
        width: devText.implicitWidth + 20; height: 26; radius: 13   // «Остров»: капсула
        color: root.info && root.info.movable ? (devMa.containsMouse ? Colors.mix(Colors.hover, Colors.fg, 0.08) : Colors.hover) : "transparent"
        Text { id: devText; anchors.centerIn: parent; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim
               text: root.info ? (root.info.dev_icon + " " + root.info.dev_short + (root.info.movable ? " 󰅀" : "")) : "" }
        MouseArea { id: devMa; anchors.fill: parent; hoverEnabled: true; enabled: !!(root.info && root.info.movable); onClicked: { root.picked(); root.move() } }
    }
    // ползунок
    Rectangle {
        id: track
        anchors.left: parent.left; anchors.leftMargin: 12
        anchors.right: pct.left; anchors.rightMargin: 10
        y: 52; height: 22; radius: 11               // «Остров»: капсула
        color: Colors.hover
        Rectangle {
            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
            width: Math.max(track.height, track.width * Math.min(1, root.shown))
            radius: track.radius
            color: root.isMuted ? Colors.alpha(Colors.fg, 0.3) : Colors.acc
            Behavior on width { enabled: !drag.pressed; NumberAnimation { duration: Theme.normal; easing.type: Theme.easeSoft } }
            Behavior on color { ColorAnimation { duration: Theme.fast } }
        }
        MouseArea {
            id: drag
            anchors.fill: parent; hoverEnabled: true
            function at(x) { root.picked(); root.setVol((x - track.radius) / (width - track.radius * 2)) }
            onPressed: (e) => at(e.x)
            onPositionChanged: (e) => { if (pressed) at(e.x) }
            onWheel: (w) => { root.picked(); root.vol(w.angleDelta.y > 0 ? 0.05 : -0.05) }
        }
    }
    Text {
        id: pct
        anchors.right: parent.right; anchors.rightMargin: 12
        anchors.verticalCenter: track.verticalCenter
        width: 38; horizontalAlignment: Text.AlignRight
        text: Math.round(root.shown * 100) + "%"
        font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.DemiBold; color: root.isMuted ? Colors.fgDim : Colors.fg
    }
}
