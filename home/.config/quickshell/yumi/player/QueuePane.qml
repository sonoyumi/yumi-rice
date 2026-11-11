import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs
import qs.services

// Очередь yumi-music под карточкой: «Далее · N треков», обложки из кэша yumi-music, клик по треку — играть его.
Item {
    id: root
    property bool running: false
    Timer { interval: 3000; running: root.running; repeat: true; triggeredOnStart: true; onTriggered: Player.requestQueue() }

    ColumnLayout {
        anchors.fill: parent
        spacing: 4
        Text { text: Player.queueHead; font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.Medium   // «Остров»: как ISection
               font.capitalization: Font.AllUppercase; font.letterSpacing: 1; color: Colors.fgDim; Layout.leftMargin: 4; Layout.bottomMargin: 2 }
        ListView {
            id: list
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true
            spacing: 2
            model: Player.queue
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                width: list.width; height: 48; radius: Theme.radius           // «Остров»: как IRow
                color: area.containsMouse ? Colors.isl2 : "transparent"
                scale: area.pressed ? 0.985 : 1
                Behavior on scale { NumberAnimation { duration: Theme.fast } }
                // 30.10: подсветка без затухания — уходящая строка тянулась «второй подсветкой»
                opacity: 0
                property real dy: 8
                transform: Translate { y: row.dy }
                Timer { interval: 40 * Math.min(row.index, 8); running: true; onTriggered: { row.opacity = 1; row.dy = 0 } }   // каскад
                Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                Behavior on dy { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 7; anchors.rightMargin: 10
                    spacing: 12
                    ClippingRectangle {
                        Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 12
                        color: Colors.isl2
                        Image { anchors.fill: parent; source: row.modelData.cover ? "file://" + row.modelData.cover : ""
                                sourceSize.width: 68; sourceSize.height: 68; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                        Text { anchors.centerIn: parent; visible: !row.modelData.cover; text: "󰝚"; font.family: Theme.fontIcon; font.pixelSize: 16; color: Colors.fgDim }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 0
                        Text { text: row.modelData.title; font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium; color: Colors.fg; elide: Text.ElideRight; Layout.fillWidth: true }
                        Text { visible: text.length > 0; text: row.modelData.artist; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim; elide: Text.ElideRight; Layout.fillWidth: true }
                    }
                    Text { text: row.modelData.dur ? root.fmt(row.modelData.dur) : ""; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim; font.features: ({ "tnum": 1 }) }
                }
                MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Player.play(row.modelData.n) }
            }
        }
    }
    Text {
        anchors.centerIn: parent
        visible: Player.queue.length === 0
        text: Player.queueMsg || "Очередь пуста"
        font.family: Theme.fontUi; font.pixelSize: Theme.fontSize; color: Colors.fgDim
    }
    function fmt(s) { s = Math.max(0, Math.round(s)); const m = Math.floor(s / 60), r = s % 60
                      return m >= 60 ? Math.floor(m / 60) + ":" + String(m % 60).padStart(2, "0") + ":" + String(r).padStart(2, "0") : m + ":" + String(r).padStart(2, "0") }
}
