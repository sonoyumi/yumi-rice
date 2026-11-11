import QtQuick
import qs
import qs.components
import qs.services

// Столбец микшера (вариант 09, 16.10): type "out" — основной выход, "mic" — основной микрофон, "app" — поток приложения.
// Сверху процент, высокий ползунок (тянуть / колесо), кнопка «без звука», подпись и устройство.
// Громкость: выход и микрофон — Sound.setVolume(узел), приложение — Sound.setStreamVolume (как StreamCard).
// Действия (их зовёт MainPage с клавиатуры или клик по подписи): enter() — выбор устройства / перенос потока,
// details() — настройки устройства. selected — тихая рамка фокуса.
Item {
    id: root
    property var menu
    property string type: "out"
    property string serial: ""
    property bool selected: false
    signal picked()

    readonly property var info: type === "app" ? Sound.streamInfo("sink", serial) : null
    readonly property var node: type === "out" ? Sound.defaultSink : type === "mic" ? Sound.defaultSource
                              : (info ? Sound.nodeBySerial(Sound.outStreams, info.serial) : null)
    readonly property bool isMuted: type === "app" ? (node ? Sound.muted(node) : !!(info && info.mute)) : Sound.muted(node)
    readonly property real level: type === "app" ? (node ? Sound.vol(node) : (info ? info.vol / 100 : 0)) : Sound.vol(node)
    readonly property string label: type === "out" ? "Выход" : type === "mic" ? "Микрофон" : (info ? info.app : "")
    readonly property string sub: type === "app" ? (info ? info.dev_short : "") : (node ? Sound.devName(type === "out" ? "sink" : "source", node) : "нет")
    readonly property string icon: type === "out" ? (isMuted ? "󰖁" : "󰕾") : type === "mic" ? (isMuted ? "󰍭" : "󰍬") : (isMuted ? "󰖁" : (info ? info.icon : "󰝚"))

    property real shown: level
    onLevelChanged: if (!drag.pressed && !hold.running) shown = level
    Timer { id: hold; interval: 800; onTriggered: root.shown = root.level }

    function setVol(v) {
        v = Math.max(0, Math.min(1, v)); shown = v; hold.restart()
        if (type === "app") Sound.setStreamVolume(info, node, v)
        else if (node) Sound.setVolume(node, v)
    }
    function vol(d) { setVol(shown + d) }
    function mute() { if (type === "app") Sound.toggleStreamMute(info, node); else if (node) Sound.toggleMute(node) }
    function enter() {
        if (type === "out") root.menu.push("Выход", "PickPage.qml", { kind: "sink" })
        else if (type === "mic") root.menu.push("Вход", "PickPage.qml", { kind: "source" })
        else if (info && info.movable) root.menu.push("Вывод звука", "MovePage.qml", { kind: "sink", serial: serial })
    }
    function details() {
        if (type === "app") { enter(); return }
        if (node) root.menu.push("", "DevicePage.qml", { kind: type === "out" ? "sink" : "source", name: node.name })
    }

    // «Остров» (29.10): строка микшера вида IRow — значок в квадрате 34 (кнопка «без звука»: акцент — звук есть,
    // приглушено — без звука), имя и куда идёт звук, ползунок-капсула 20 px с заливкой акцентом, процент справа.
    // Выбранная — подложка акцентом 0.16. sepAbove — подпись «Приложения» над строкой (высота строки + 26).
    // Действия и API прежние.
    property bool sepAbove: false
    readonly property int rowH: 52
    implicitHeight: rowH + (sepAbove ? 26 : 0)
    height: implicitHeight

    Text {
        visible: root.sepAbove
        x: 4; y: 6
        text: "Приложения"
        font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.Medium
        font.capitalization: Font.AllUppercase; font.letterSpacing: 1; color: Colors.fgDim
    }
    Item {
        id: rowBox
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: root.rowH
        Rectangle {   // выбор / наведение
            anchors.fill: parent; radius: Theme.radius
            color: root.selected ? Colors.alpha(Colors.acc, 0.16) : (rowHover.hovered ? Colors.isl2 : "transparent")
            /* выбор — без затухания (29.10) */
        }
        HoverHandler { id: rowHover }

        // значок — кнопка «без звука»
        Rectangle {
            id: muteBtn
            anchors.left: parent.left; anchors.leftMargin: 9; anchors.verticalCenter: parent.verticalCenter
            width: 34; height: 34; radius: 12
            color: root.isMuted ? Colors.mix(Colors.isl2, Colors.bad, 0.22) : (root.selected ? Colors.acc : Colors.isl2)
            /* выбор — без затухания (29.10) */
            scale: mma.pressed ? 0.92 : 1
            Behavior on scale { NumberAnimation { duration: Theme.fast } }
            Glyph { anchors.centerIn: parent; text: root.icon; font.pixelSize: 16
                    color: root.isMuted ? Colors.fgDim : (root.selected ? Colors.onAcc : Colors.fg) }
            MouseArea { id: mma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.picked(); root.mute() } }
        }
        Column {
            id: labels
            anchors.left: muteBtn.right; anchors.leftMargin: 12
            anchors.right: track.left; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text { width: parent.width; text: root.label; elide: Text.ElideRight
                   font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium; color: root.isMuted ? Colors.fgDim : Colors.fg }
            Text { width: parent.width; text: root.sub + (root.type !== "app" || (root.info && root.info.movable) ? " 󰅀" : "")
                   elide: Text.ElideRight; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim }
        }
        MouseArea { anchors.fill: labels; cursorShape: Qt.PointingHandCursor; onClicked: { root.picked(); root.enter() } }   // подпись — выбор устройства / перенос

        Rectangle {
            id: track
            anchors.right: pct.left; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
            width: 130; height: 20; radius: 10
            color: root.selected ? Colors.alpha(Colors.fg, 0.10) : Colors.isl2
            clip: true
            Rectangle {
                id: fill
                height: parent.height; radius: parent.radius
                width: Math.max(root.shown > 0.005 ? parent.height : 0, parent.width * Math.min(1, root.shown))
                color: root.isMuted ? Colors.alpha(Colors.fg, 0.25) : Colors.acc
                Behavior on width { enabled: !drag.pressed; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: Theme.normal } }
            }
            MouseArea {
                id: drag
                anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; preventStealing: true
                function at(x) { root.picked(); root.setVol((x - 6) / track.width) }
                onPressed: (e) => at(e.x)
                onPositionChanged: (e) => { if (pressed) at(e.x) }
                onWheel: (w) => { root.picked(); root.vol(w.angleDelta.y > 0 ? 0.05 : -0.05) }
            }
        }
        Text {
            id: pct
            anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
            width: 38; horizontalAlignment: Text.AlignRight
            text: Math.round(root.shown * 100) + "%"
            font.family: Theme.fontUi; font.pixelSize: 12; font.features: ({ "tnum": 1 })
            color: Colors.fgDim
        }
    }
}
