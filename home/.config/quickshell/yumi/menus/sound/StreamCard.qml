import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Карточка потока (ys-card): значок приложения, имя и трек, чип устройства (клик — куда выводить),
// ползунок с «без звука». info — запись бэкенда (streams/rec), node — узел PipeWire (живая громкость).
Rectangle {
    id: root
    property string kind: "sink"
    property string serial: ""
    readonly property var info: Sound.streamInfo(kind, serial)     // обновляется на месте при новом состоянии
    readonly property var node: info ? Sound.nodeBySerial(info.kind === "sink" ? Sound.outStreams : Sound.inStreams, info.serial) : null
    readonly property bool isMuted: node ? Sound.muted(node) : !!(info && info.mute)
    readonly property real level: node ? Sound.vol(node) : (info ? info.vol / 100 : 0)
    signal move()

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 24
    radius: Theme.radiusTile                   // «Остров»: подложка isl2 radius 18
    color: Colors.isl2
    opacity: info && info.event ? 0.8 : 1
    Behavior on color { ColorAnimation { duration: Theme.normal } }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Rectangle {
                implicitWidth: 34; implicitHeight: 34; radius: 12
                color: root.isMuted ? Colors.hover : Colors.acc
                Behavior on color { ColorAnimation { duration: Theme.normal } }
                Glyph { anchors.centerIn: parent; text: root.info ? root.info.icon : "󰝚"; font.pixelSize: 16
                        color: root.isMuted ? Colors.fgDim : Colors.onAcc }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text { text: root.info ? root.info.app : ""; font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium
                       color: Colors.fg; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { visible: text.length > 0; text: root.info ? root.info.sub : ""; font.family: Theme.fontUi; font.pixelSize: 12
                       color: Colors.fgDim; elide: Text.ElideRight; Layout.fillWidth: true }
            }
            Chip {
                base: Colors.hover
                text: root.info ? (root.info.dev_icon + " " + root.info.dev_short + (root.info.movable ? " 󰅀" : "")) : ""
                enabled: !!(root.info && root.info.movable)
                tooltip: root.info && root.info.kind === "sink" ? "Куда выводить звук" : "Какой микрофон"
                onClicked: root.move()
            }
        }
        VolumeSlider {
            trackColor: Colors.hover
            value: root.level
            muted: root.isMuted
            onIcon: root.info && root.info.kind === "sink" ? "󰕾" : "󰍬"
            offIcon: root.info && root.info.kind === "sink" ? "󰖁" : "󰍭"
            onChanged: (v) => Sound.setStreamVolume(root.info, root.node, v)
            onMute: Sound.toggleStreamMute(root.info, root.node)
        }
    }
}
