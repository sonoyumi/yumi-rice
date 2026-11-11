import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services

// «Запись»: кто слушает микрофон; отдельно — кто слушает звук системы (мониторы: визуализаторы, запись экрана).
Flickable {
    id: root
    property var menu
    readonly property string title: "Запись"
    readonly property var mics: Sound.state.rec.filter(s => !s.monitor)
    readonly property var mons: Sound.state.rec.filter(s => s.monitor)
    readonly property string subtitle: mics.length ? "Микрофон слушают: " + mics.length : "Микрофон свободен"
    contentHeight: col.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: col
        width: root.width
        spacing: 8
        Section { text: "Используют микрофон"; Layout.topMargin: 0 }
        Repeater {
            model: ScriptModel { values: Sound.micSerials }
            delegate: StreamCard { required property var modelData; kind: "source"; serial: modelData
                                   onMove: root.menu.push("Микрофон", "MovePage.qml", { kind: "source", serial: modelData }) }
        }
        Text { visible: root.mics.length === 0; text: "󰍭  Сейчас микрофон никто не использует"; font.family: Theme.fontUi
               font.pixelSize: Theme.fontSize; color: Colors.fgDim; Layout.leftMargin: 6 }
        Section { text: "Слушают звук системы"; visible: root.mons.length > 0 }
        Text { visible: root.mons.length > 0; text: "Визуализаторы и запись экрана — микрофон им не нужен."; wrapMode: Text.Wrap
               Layout.fillWidth: true; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim; Layout.leftMargin: 6 }
        Repeater {
            model: ScriptModel { values: Sound.monSerials }
            delegate: StreamCard { required property var modelData; kind: "source"; serial: modelData }
        }
    }
}
