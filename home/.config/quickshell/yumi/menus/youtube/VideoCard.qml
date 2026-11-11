import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs
import qs.components

// YumiTube: карточка видео — превью 16:9 (radius 16), длительность/«LIVE»/Shorts на превью, под ним название в 2 строки
// и строка «канал · просмотры · когда». Наведение: превью чуть крупнее, кнопки «Позже» и «Звук»; клик — mpv.
Item {
    id: card
    property var app
    property var v: ({})
    property int index: 0
    signal channelClicked(string id)

    readonly property bool later: !!app.laterIds[v.id]
    readonly property bool hot: ma.containsMouse || laterBtn.hover || audioBtn.hover

    function dur(s) {
        if (!s) return ""
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), x = s % 60
        const p = n => (n < 10 ? "0" : "") + n
        return h ? h + ":" + p(m) + ":" + p(x) : m + ":" + p(x)
    }
    function views(n) {
        if (!n) return ""
        if (n >= 1e9) return (n / 1e9).toFixed(1).replace(".0", "").replace(".", ",") + " млрд просм."
        if (n >= 1e6) return (n / 1e6).toFixed(1).replace(".0", "").replace(".", ",") + " млн просм."
        if (n >= 1e3) return Math.round(n / 1e3) + " тыс. просм."
        return n + " просм."
    }
    function ago(ts) {
        if (!ts) return ""
        const d = Date.now() / 1000 - ts
        if (d < 3600) return Math.max(1, Math.floor(d / 60)) + " мин назад"
        if (d < 86400) return Math.floor(d / 3600) + " ч назад"
        if (d < 86400 * 30) return Math.floor(d / 86400) + " дн назад"
        if (d < 86400 * 365) return Math.floor(d / 86400 / 30) + " мес назад"
        return Math.floor(d / 86400 / 365) + " г назад"
    }

    // каскад появления
    opacity: 0
    Component.onCompleted: appear.start()
    SequentialAnimation {
        id: appear
        PauseAnimation { duration: Math.min(card.index, 12) * Theme.cascade }
        NumberAnimation { target: card; property: "opacity"; to: 1; duration: Theme.normal; easing.type: Easing.OutCubic }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 9

        ClippingRectangle {
            id: thumbBox
            Layout.fillWidth: true
            Layout.preferredHeight: width * 9 / 16
            radius: Theme.radius
            color: Colors.isl2
            border.width: card.hot ? 2 : 0
            border.color: Colors.alpha(Colors.acc, 0.85)

            Image {
                id: img
                anchors.fill: parent
                source: card.v.thumb || ""
                asynchronous: true; cache: true
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 480
                scale: card.hot ? 1.04 : 1
                Behavior on scale { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.normal } }
            }
            Glyph {   // заглушка, пока грузится превью
                anchors.centerIn: parent; visible: img.status !== Image.Ready
                text: String.fromCodePoint(0xf05c3); font.pixelSize: 30; color: Colors.alpha(Colors.fg, 0.18)
            }
            Rectangle {   // затемнение при наведении + кнопка воспроизведения
                anchors.fill: parent
                color: Colors.alpha(Colors.deep, card.hot ? 0.35 : 0)
                Behavior on color { ColorAnimation { duration: Theme.fast } }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 52; height: 52; radius: 26
                color: Colors.acc
                opacity: card.hot ? 1 : 0
                scale: card.hot ? (ma.pressed ? 0.92 : 1) : 0.7
                Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                Behavior on scale { NumberAnimation { duration: Theme.normal; easing.type: Theme.easeSpring; easing.overshoot: Theme.overshoot } }
                Glyph { anchors.centerIn: parent; anchors.horizontalCenterOffset: 2; text: String.fromCodePoint(0xf040a); font.pixelSize: 26; color: Colors.onAcc }
            }
            // метки снизу справа
            Row {
                anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 8
                spacing: 6
                Rectangle {
                    visible: card.v.short === true
                    width: shortT.implicitWidth + 14; height: 22; radius: 8; color: Colors.alpha(Colors.deep, 0.85)
                    Text { id: shortT; anchors.centerIn: parent; text: "Shorts"; font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.DemiBold; color: Colors.fg }
                }
                Rectangle {
                    visible: card.v.live === true || card.dur(card.v.duration).length > 0
                    width: durT.implicitWidth + 14; height: 22; radius: 8
                    color: card.v.live ? Colors.bad : Colors.alpha(Colors.deep, 0.85)
                    Text { id: durT; anchors.centerIn: parent; text: card.v.live ? "LIVE" : card.dur(card.v.duration)
                           font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.DemiBold; font.features: { "tnum": 1 }
                           color: card.v.live ? Colors.onAcc : Colors.fg }
                }
            }
            MouseArea {
                id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                onClicked: (e) => e.button === Qt.MiddleButton ? card.app.toggleLater(card.v) : card.app.play(card.v, false)
            }
            // кнопки сверху справа
            Row {
                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8
                spacing: 6
                opacity: card.hot || card.later ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                CardBtn {
                    id: laterBtn
                    icon: card.later ? String.fromCodePoint(0xf012c) : String.fromCodePoint(0xf0150)
                    on: card.later
                    tip: card.later ? "Убрать из «Позже»" : "Смотреть позже"
                    onClicked: card.app.toggleLater(card.v)
                }
                CardBtn {
                    id: audioBtn
                    visible: card.hot
                    icon: String.fromCodePoint(0xf02cb)
                    tip: "Только звук"
                    onClicked: card.app.play(card.v, true)
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: card.v.title || ""
            wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
            font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.DemiBold; lineHeight: 1.08
            color: Colors.fg
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                id: chT
                Layout.maximumWidth: card.width * 0.55
                text: card.v.channel || ""
                elide: Text.ElideRight
                font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium
                color: chMa.containsMouse ? Colors.acc : Colors.fgDim
                MouseArea { id: chMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            enabled: !!card.v.channelId; onClicked: card.channelClicked(card.v.channelId) }
            }
            Text {
                Layout.fillWidth: true
                text: [card.views(card.v.views), card.ago(card.v.ts || card.v.watched)].filter(s => s).map(s => "  ·  " + s).join("")
                elide: Text.ElideRight
                font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.alpha(Colors.fg, 0.5)
            }
        }
        Item { Layout.fillHeight: true }
    }

    component CardBtn: Rectangle {
        id: b
        property string icon: ""
        property string tip: ""
        property bool on: false
        readonly property bool hover: bma.containsMouse
        signal clicked()
        width: 32; height: 32; radius: 11
        color: on ? Colors.acc : (bma.containsMouse ? Colors.hover : Colors.alpha(Colors.deep, 0.82))
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        scale: bma.pressed ? 0.9 : 1
        Behavior on scale { NumberAnimation { duration: Theme.fast } }
        Glyph { anchors.centerIn: parent; text: b.icon; font.pixelSize: 16; color: b.on ? Colors.onAcc : Colors.fg }
        MouseArea { id: bma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
        Rectangle {   // подсказка
            visible: bma.containsMouse && b.tip.length > 0
            anchors.top: parent.bottom; anchors.topMargin: 6; anchors.right: parent.right
            width: tipT.implicitWidth + 16; height: 24; radius: 8; color: Colors.deep
            Text { id: tipT; anchors.centerIn: parent; text: b.tip; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fg }
        }
    }
}
