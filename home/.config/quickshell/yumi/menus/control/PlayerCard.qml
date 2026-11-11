import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs
import qs.components
import qs.services

// Плеер центра управления: обложка, название, исполнитель, прогресс, назад / пауза / вперёд. Видна всегда: данные —
// из сервиса Player, без живого плеера — последний трек (last.json), ▶ продолжает его с места (Player.resume).
// «Остров» (29.10): мини-плеер в подложке isl2 radius 18 — обложка 46 radius 14, название 14 DemiBold, исполнитель
// приглушённо, полоска прогресса 4 px акцентом, кнопки-круги 32, пауза — круг 40 акцентом.
Rectangle {
    id: card
    property string kb: ""             // фокус клавиатуры центра: previous | toggle | next
    implicitHeight: 70 + (srcRow.visible ? srcRow.height + 10 : 0)
    radius: Theme.radiusTile
    color: Colors.isl2
    property real frac: 0
    function upd() { frac = Player.length > 0 ? Math.max(0, Math.min(1, Player.position() / Player.length)) : 0 }
    Timer { interval: 1000; repeat: true; running: card.visible && Player.playing; triggeredOnStart: true; onTriggered: card.upd() }
    Connections { target: Player; function onTrackKeyChanged() { card.upd() } function onPlayingChanged() { card.upd() } }
    Component.onCompleted: upd()

    // источник (30.10): игроков больше одного — чипы под плеером, выбранный закрепляется (Player.choose), как в острове
    Flow {
        id: srcRow
        x: 12; y: 66; width: parent.width - 22; spacing: 6
        visible: Player.players.length > 1
        Repeater {
            model: Player.players
            IChip { required property var modelData
                    text: Player.nameOf(modelData) + (modelData.isPlaying ? "  󰐊" : "")
                    on: Player.player === modelData
                    onClicked: Player.choose(modelData) }
        }
    }

    RowLayout {
        x: 12; width: parent.width - 22; height: 70
        spacing: 12
        ClippingRectangle {
            Layout.preferredWidth: 46; Layout.preferredHeight: 46
            radius: 14
            color: Colors.acc5
            Rectangle {     // заглушка обложки — градиент акцента (как .cover превью)
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Colors.acc }
                    GradientStop { position: 0.5; color: Colors.acc5 }
                    GradientStop { position: 1; color: Colors.deep }
                }
            }
            Glyph { anchors.centerIn: parent; text: "󰎆"; color: Colors.onAcc; visible: art.status !== Image.Ready; font.pixelSize: 18 }
            Image { id: art; anchors.fill: parent; source: Player.artUrl
                    sourceSize.width: 92; sourceSize.height: 92; fillMode: Image.PreserveAspectCrop; asynchronous: true }
        }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 2
            Text { text: Player.title; font.family: Theme.fontUi; font.pixelSize: 14; font.weight: Font.DemiBold
                   color: Colors.fg; elide: Text.ElideRight; Layout.fillWidth: true }
            Text { text: Player.artist || Player.source.replace(/^[^\p{L}\p{N}]+/u, ""); font.family: Theme.fontUi; font.pixelSize: 12
                   color: Colors.fgDim; elide: Text.ElideRight; Layout.fillWidth: true; visible: text.length > 0 }
            Rectangle {
                Layout.fillWidth: true; Layout.topMargin: 4
                implicitHeight: 4; radius: 2
                color: Colors.alpha(Colors.fg, 0.16)
                visible: Player.length > 0
                Rectangle { height: parent.height; radius: 2; width: parent.width * card.frac; color: Colors.acc
                            Behavior on width { NumberAnimation { duration: 900; easing.type: Easing.Linear } } }
            }
        }
        Repeater {
            model: [
                { g: "󰒮", act: "previous" },
                { g: Player.playing ? "󰏤" : "󰐊", act: "toggle" },
                { g: "󰒭", act: "next" }
            ]
            delegate: Rectangle {
                id: cb
                required property var modelData
                readonly property bool pp: modelData.act === "toggle"
                Layout.preferredWidth: pp ? 40 : 32; Layout.preferredHeight: pp ? 40 : 32
                radius: width / 2
                color: pp ? (ma.containsMouse ? Colors.mix(Colors.acc, Colors.fg, 0.15) : Colors.acc) : (ma.containsMouse ? Colors.hover : "transparent")
                Behavior on color { ColorAnimation { duration: Theme.fast } }
                scale: ma.pressed ? 0.9 : 1
                Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
                KbRing { on: card.kb === cb.modelData.act; inset: -3; radius: width / 2 }
                Glyph { anchors.centerIn: parent; text: cb.modelData.g; color: cb.pp ? Colors.onAcc : Colors.fg; font.pixelSize: cb.pp ? 18 : 16 }
                MouseArea {
                    id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (cb.modelData.act === "toggle") Player.togglePlaying()   // нет плеера — продолжить последний трек
                        else if (cb.modelData.act === "next") Player.next()
                        else Player.previous()
                    }
                }
            }
        }
    }
}
