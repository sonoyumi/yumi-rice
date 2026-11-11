import QtQuick
import QtQuick.Layouts
import qs
import qs.services

// «Куда выводить звук» / «Какой микрофон» для одного потока: список устройств, клик — перенести (pactl move-*).
ColumnLayout {
    id: root
    property var menu
    property string kind: "sink"
    property string serial: ""
    readonly property var info: Sound.streamInfo(kind, serial)
    readonly property string title: kind === "sink" ? "Вывод звука" : "Микрофон"
    readonly property string subtitle: info ? info.icon + " " + info.app : ""
    readonly property var devs: kind === "sink" ? Sound.state.sinks : Sound.state.sources
    spacing: 6

    Connections { target: Sound; function onStateChanged() { if (Sound.ready && !root.info) { root.menu.pop(); Sound.toast("Приложение закрыло поток", false) } } }

    Text { Layout.fillWidth: true; wrapMode: Text.Wrap; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim; Layout.leftMargin: 6
           text: root.kind === "sink" ? "Звук этого приложения пойдёт на выбранное устройство, остальные не изменятся." : "Какой микрофон слушает это приложение." }
    Section { text: root.kind === "sink" ? "Выход" : "Микрофон" }
    Repeater {
        model: root.devs
        delegate: RowButton {
            required property var modelData
            icon: modelData.icon; text: modelData.ru; active: !!(root.info && root.info.dev === modelData.name)
            onClicked: { if (root.info) Sound.move(root.kind, root.info.index, modelData.name); root.menu.pop() }
        }
    }
    Item { Layout.fillHeight: true }
}
