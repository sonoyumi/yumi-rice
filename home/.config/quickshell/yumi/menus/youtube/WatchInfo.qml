import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components

// YumiTube: под видео — название, канал (+ подписка), просмотры/дата и кнопки «Позже», «Только звук», «Ссылка», «Браузер».
ColumnLayout {
    id: wi
    property var app
    readonly property var v: app.current || ({})
    readonly property bool subscribed: !!v.channelId && app.subs.some(s => s.id === v.channelId)
    spacing: 10

    Text {
        Layout.fillWidth: true
        text: wi.v.title || "Загрузка…"
        wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
        font.family: Theme.fontUi; font.pixelSize: 18; font.weight: Font.DemiBold; color: Colors.fg
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Rectangle {   // «аватар» канала — буква в акцентной капсуле
            implicitWidth: 38; implicitHeight: 38; radius: 19; color: Colors.isl2
            Text { anchors.centerIn: parent; text: (wi.v.channel || "?").charAt(0).toUpperCase()
                   font.family: Theme.fontUi; font.pixelSize: 16; font.weight: Font.DemiBold; color: Colors.acc }
        }
        ColumnLayout {
            spacing: 0
            Layout.maximumWidth: 260
            Text {
                Layout.fillWidth: true
                text: wi.v.channel || ""
                elide: Text.ElideRight
                font.family: Theme.fontUi; font.pixelSize: 14; font.weight: Font.DemiBold
                color: chMa.containsMouse ? Colors.acc : Colors.fg
                MouseArea { id: chMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            enabled: !!wi.v.channelId; onClicked: wi.app.go("channel", wi.v.channelId) }
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: [wi.app.fmtCount(wi.v.views, "просмотров")].filter(s => s).join(" · ")
                elide: Text.ElideRight
                font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim
            }
        }
        IButton {
            visible: !!wi.v.channelId
            Layout.leftMargin: 6
            primary: !wi.subscribed
            implicitHeight: 34
            text: wi.subscribed ? "Вы подписаны" : "Подписаться"
            onClicked: wi.subscribed ? wi.app.unsubscribe(wi.v.channelId) : wi.app.subscribe(wi.v.channelId, wi.v.channel)
        }
        Item { Layout.fillWidth: true }
        IButton {
            implicitHeight: 34
            icon: wi.app.laterIds[wi.v.id] ? String.fromCodePoint(0xf012c) : String.fromCodePoint(0xf0150)
            text: wi.width > 640 ? "Позже" : ""
            onClicked: wi.app.toggleLater(wi.v)
        }
        IButton {
            implicitHeight: 34
            icon: String.fromCodePoint(0xf0337)
            text: wi.width > 640 ? "Ссылка" : ""
            onClicked: { Quickshell.execDetached(["wl-copy", "https://youtu.be/" + wi.v.id]); wi.app.flash("Ссылка скопирована") }
        }
        IButton {
            implicitHeight: 34
            icon: String.fromCodePoint(0xf059f)
            onClicked: Quickshell.execDetached(["xdg-open", "https://www.youtube.com/watch?v=" + wi.v.id])
        }
    }
}
