import QtQuick
import QtQuick.Layouts
import qs
import "Kb.js" as Kb
import qs.components
import qs.services

// Страница устройства: громкость, баланс Л/П (стерео), «Сделать основным», разъём, профиль карты,
// кто играет здесь / слушает, системное имя. Громкость/mute — PipeWire, баланс/разъём/профиль — бэкенд.
Flickable {
    id: root
    property var menu
    property string kind: "sink"
    property string name: ""
    readonly property var info: Sound.devInfo(kind, name)
    readonly property var node: Sound.nodeByName(kind === "sink" ? Sound.sinks : Sound.sources, name)
    readonly property bool isDefault: node && node === (kind === "sink" ? Sound.defaultSink : Sound.defaultSource)
    readonly property string title: (info ? info.icon : Sound.devIcon(kind, node)) + "  " + (info ? info.ru : Sound.devName(kind, node))
    readonly property string subtitle: info ? info.type_text : (kind === "sink" ? "Выход" : "Вход")
    readonly property var card: info && info.card ? Sound.cardInfo(info.card) : null
    contentHeight: col.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // устройство пропало — назад
    Connections { target: Sound; function onStateChanged() { if (Sound.ready && !root.info && !root.node) { root.menu.pop(); Sound.toast("Устройство отключилось", false) } } }

    // баланс: -100..100, пока тянут и 800 мс после — не дёргать
    property int bal: 0
    property bool balBlocked: false
    onInfoChanged: if (info && !balBlocked) bal = info.balance
    Timer { id: balBlock; interval: 800; onTriggered: { root.balBlocked = false; if (root.info) root.bal = root.info.balance } }
    Timer { id: balThrottle; interval: 70; repeat: true; property int pending: -999
        onTriggered: { if (pending !== -999) { Sound.setBalance(root.kind, root.name, pending); pending = -999 } else stop() } }
    function setBal(v) {
        v = Math.round(Math.max(-100, Math.min(100, v)))
        if (Math.abs(v) < 4) v = 0                       // лёгкое «прилипание» к центру
        bal = v; balBlocked = true; balBlock.restart()
        if (!balThrottle.running) { Sound.setBalance(kind, name, v); balThrottle.start() } else balThrottle.pending = v
    }
    function balText(v) { return v === 0 ? "центр" : (v < 0 ? "Л " + (-v) + "%" : "П " + v + "%") }

    ColumnLayout {
        id: col
        width: root.width
        spacing: 6

        Section { text: "Громкость"; Layout.topMargin: 0 }
        VolumeSlider {
            value: root.node ? Sound.vol(root.node) : (root.info ? root.info.vol / 100 : 0)
            muted: root.node ? Sound.muted(root.node) : !!(root.info && root.info.mute)
            onIcon: root.kind === "sink" ? "󰕾" : "󰍬"; offIcon: root.kind === "sink" ? "󰖁" : "󰍭"
            onChanged: (v) => Sound.setVolume(root.node, v)
            onMute: Sound.toggleMute(root.node)
        }

        Section { text: "Баланс"; visible: !!(root.info && root.info.stereo) }
        RowLayout {
            visible: !!(root.info && root.info.stereo)
            Layout.fillWidth: true
            spacing: 8
            Text { text: "Л"; font.family: Theme.fontUi; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold; color: Colors.fgDim; Layout.minimumWidth: 16 }
            Item {
                id: balTrack
                Layout.fillWidth: true; Layout.preferredHeight: 30
                activeFocusOnTab: parent.visible
                Keys.onPressed: (e) => {       // ←→ баланс ±5, Enter/Пробел — в центр
                    if (Kb.nav(balTrack, e)) return
                    if (e.key === Qt.Key_Left) root.setBal(root.bal - 5)
                    else if (e.key === Qt.Key_Right) root.setBal(root.bal + 5)
                    else if (Kb.activate(e)) root.setBal(0)
                    else return
                    e.accepted = true
                }
                FocusRing { on: balTrack.activeFocus; anchors.margins: -2; radius: 17 }
                readonly property real knobX: (parent.width > 0 ? (balTrack.width - 22) * (root.bal + 100) / 200 : 0)
                // «Остров»: дорожка-капсула isl2, заливка акцентом от центра, бегунок — круг цвета текста
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 10; radius: 5; color: Colors.isl2 }
                Rectangle { anchors.centerIn: parent; width: 2; height: 16; radius: 1; color: Colors.fgDim }
                Rectangle {   // заливка от центра к ручке
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.min(balTrack.width / 2, balTrack.knobX + 11); width: Math.abs(balTrack.knobX + 11 - balTrack.width / 2)
                    height: 10; radius: 5; color: Colors.acc
                    Behavior on x { enabled: !balDrag.pressed; NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                    Behavior on width { enabled: !balDrag.pressed; NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                }
                Rectangle {   // ручка
                    x: balTrack.knobX; anchors.verticalCenter: parent.verticalCenter
                    width: 22; height: 22; radius: 11; color: Colors.fg
                    scale: balDrag.pressed ? 1.1 : 1
                    Behavior on x { enabled: !balDrag.pressed; NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: Theme.fast } }
                }
                MouseArea {
                    id: balDrag
                    anchors.fill: parent
                    function at(x) { return 200 * Math.max(0, Math.min(1, (x - 11) / (width - 22))) - 100 }
                    onPressed: (e) => root.setBal(at(e.x))
                    onPositionChanged: (e) => { if (pressed) root.setBal(at(e.x)) }
                    onWheel: (w) => root.setBal(root.bal + (w.angleDelta.y > 0 ? 5 : -5))
                }
            }
            Text { text: "П"; font.family: Theme.fontUi; font.pixelSize: Theme.fontSize; font.weight: Font.DemiBold; color: Colors.fgDim; Layout.minimumWidth: 16 }
            Text { text: root.balText(root.bal); font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim
                   horizontalAlignment: Text.AlignRight; Layout.minimumWidth: 48 }
            Rectangle {
                Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 16   // «Остров»: круглая кнопка isl2
                color: centerArea.containsMouse ? Colors.hover : Colors.isl2
                Behavior on color { ColorAnimation { duration: Theme.fast } }
                Glyph { anchors.centerIn: parent; text: "󰘞"; font.pixelSize: 14 }
                MouseArea { id: centerArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.setBal(0) }
            }
        }

        // основное устройство
        Text { visible: root.isDefault; text: "󰄬  Основное устройство"; font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium
               color: Colors.ok; Layout.leftMargin: 6; Layout.topMargin: 6 }
        RowButton { visible: !root.isDefault; icon: "󰓎"; text: "Сделать основным"; Layout.topMargin: 6
                    onClicked: Sound.setDefault(root.kind, root.node) }

        Section { text: "Разъём"; visible: !!(root.info && root.info.ports.length > 1) }
        Repeater {
            model: root.info && root.info.ports.length > 1 ? root.info.ports : []
            delegate: RowButton {
                required property var modelData
                icon: root.kind === "sink" ? "󰡁" : "󰍬"; text: modelData.ru; meta: modelData.meta; active: modelData.active
                onClicked: Sound.setPort(root.kind, root.name, modelData.name)
            }
        }

        Section { text: "Профиль"; visible: !!root.card }
        ProfileList { visible: !!root.card; card: root.card; Layout.fillWidth: true }

        Text { visible: !!(root.info && root.info.users.length); Layout.fillWidth: true; Layout.topMargin: 6; wrapMode: Text.Wrap
               text: (root.kind === "sink" ? "Играет здесь: " : "Слушают: ") + (root.info ? root.info.users.join(", ") : "")
               font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim; Layout.leftMargin: 6 }
        Text { visible: !!(root.info && root.info.desc !== root.info.ru); Layout.fillWidth: true; wrapMode: Text.Wrap
               text: "Устройство: " + (root.info ? root.info.desc : "")
               font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim; Layout.leftMargin: 6 }
    }
}
