import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Yumi.Mpv
import qs
import qs.components

// YumiTube: встроенный плеер — libmpv (Yumi.Mpv) + панель управления «Острова».
// Один экземпляр на окно; YtView двигает его между страницей просмотра, «кино» (всё окно) и мини-плеером в углу.
// Мышь: клик — пауза, двойной клик — «кино», колесо — громкость. Клавиши — в YtView.
ClippingRectangle {
    id: pl
    property var app
    readonly property string mode: app.playerMode
    readonly property bool mini: mode === "mini"
    property alias mpv: mp
    property bool controlsShown: true
    readonly property bool showUi: controlsShown || mp.paused || mp.idle || seekArea.dragging || volArea.containsMouse
    property real dragPos: -1

    radius: mode === "theater" ? 0 : mini ? 18 : Theme.radius
    color: "#000000"

    function poke() { controlsShown = true; hideTimer.restart() }
    function togglePause() { mp.paused = !mp.paused; poke() }
    function seekBy(s) { mp.seek(s, false); poke(); osd(s > 0 ? "+" + s + " с" : s + " с") }
    function setVol(v) {
        v = Math.max(0, Math.min(130, Math.round(v)))
        mp.volume = v
        app.settings.volume = v
        volSave.restart(); poke(); osd("Громкость " + v + "%")
    }
    function osd(t) { osdText.text = t; osdBox.opacity = 1; osdTimer.restart() }
    Timer { id: volSave; interval: 800; onTriggered: pl.app.setSetting("volume", pl.app.settings.volume) }
    Timer { id: hideTimer; interval: 2600; onTriggered: pl.controlsShown = false }

    MpvPlayer {
        id: mp
        anchors.fill: parent
        visible: !pl.app.audioOnly
        Component.onCompleted: {
            volume = pl.app.settings.volume !== undefined ? pl.app.settings.volume : 100
            setProp("ytdl-format", pl.app.ytFormat(pl.app.settings.quality))
            command(["load-script", pl.app.home + "/.config/mpv/scripts/sponsorblock_minimal.lua"])
            if (Quickshell.env("YUMI_YT_MUTE")) muted = true   // тесты: без звука
        }
        onFileLoaded: {
            retries = 0
            const c = pl.app.current
            if (c && !c.title) pl.app.current = Object.assign({}, c, { title: getProp("media-title"),
                                                                       channel: c.channel || getProp("metadata/by-key/uploader") })
        }
        onPositionChanged: { pl.app.curPos = position; if (position > 0) lastPos = position }
        onDurationChanged: pl.app.curDur = duration
        onDroppedChanged: pl.app.curDrop = dropped
        // YouTube иногда отказывает в потоке (случайный 403) — повторить с того же места, до 3 раз
        property int retries: 0
        property real lastPos: 0
        onEndFile: (reason, err) => {
            if (reason !== "error") return
            if (retries < 3) { retries++; retryTimer.restart(); return }
            pl.app.flash("Не воспроизводится: " + err)
        }
        onEofChanged: if (eof && pl.app.current && pl.app.settings.autoplay && pl.app.queue.length) nextTimer.start()
        onLogMessage: (lvl, t) => { if (lvl === "error") console.log("mpv:", t) }
    }
    Timer { id: retryTimer; interval: 1200; onTriggered: if (mp.source) mp.load(mp.source, Math.max(mp.lastPos, pl.app.resumeAt)) }
    Timer { id: nextTimer; interval: 1500; onTriggered: if (mp.eof) pl.app.playNext() }

    Connections {
        target: pl.app
        function onPlayRequested(url, start) {
            mp.retries = 0; mp.lastPos = 0
            mp.setProp("vid", pl.app.audioOnly ? "no" : "auto")
            mp.setProp("ytdl-format", pl.app.ytFormat(pl.app.settings.quality))
            mp.load(url, start)
            mp.paused = false
            pl.poke()
        }
        function onReloadRequested() {
            const pos = mp.position
            mp.setProp("ytdl-format", pl.app.ytFormat(pl.app.settings.quality))
            mp.load(mp.source, pos)
            pl.osd("Качество " + pl.app.qLabel(pl.app.settings.quality))
        }
        function onStopRequested() { mp.stop() }
        function onAudioOnlyChanged() { mp.setProp("vid", pl.app.audioOnly ? "no" : "auto") }
    }

    // ---- «только звук»: обложка вместо картинки ----
    Image {
        anchors.fill: parent
        visible: pl.app.audioOnly && !!pl.app.current
        source: pl.app.current ? "https://i.ytimg.com/vi/" + pl.app.current.id + "/hqdefault.jpg" : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: 0.55
    }
    Glyph {
        anchors.centerIn: parent
        visible: pl.app.audioOnly && !pl.mini
        text: String.fromCodePoint(0xf02cb); font.pixelSize: 54; color: Colors.fg
    }

    // ---- загрузка ----
    Rectangle {
        anchors.centerIn: parent
        width: pl.mini ? 40 : 64; height: width; radius: width / 2
        color: Colors.alpha(Colors.deep, 0.7)
        visible: !!pl.app.current && (mp.buffering || (mp.duration === 0 && !mp.eof))
        Glyph {
            anchors.centerIn: parent
            text: String.fromCodePoint(0xf0450); font.pixelSize: pl.mini ? 20 : 30; color: Colors.acc
            RotationAnimator on rotation { running: parent.parent.visible; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
        }
    }

    // ---- всплывающая подпись (громкость, перемотка) ----
    Rectangle {
        id: osdBox
        anchors.horizontalCenter: parent.horizontalCenter; y: pl.mini ? 10 : 24
        width: osdText.implicitWidth + 28; height: 34; radius: 17
        color: Colors.alpha(Colors.deep, 0.85)
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: Theme.fast } }
        Text { id: osdText; anchors.centerIn: parent; font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium; color: Colors.fg }
        Timer { id: osdTimer; interval: 900; onTriggered: osdBox.opacity = 0 }
    }

    // ---- мышь по видео ----
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: pl.showUi || pl.mini ? Qt.ArrowCursor : Qt.BlankCursor
        onPositionChanged: pl.poke()
        onClicked: { if (pl.mini) { pl.app.go("watch"); return } clickTimer.restart() }
        onDoubleClicked: { clickTimer.stop(); if (!pl.mini) pl.app.toggleTheater() }
        onWheel: (w) => pl.setVol(mp.volume + (w.angleDelta.y > 0 ? 5 : -5))
        Timer { id: clickTimer; interval: 230; onTriggered: pl.togglePause() }
    }

    // ---- верх: название (в «кино») / кнопки мини-плеера ----
    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: pl.mini ? 56 : 90
        opacity: pl.showUi && (pl.mode === "theater" || pl.mini) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
        gradient: Gradient {
            GradientStop { position: 0; color: Colors.alpha(Colors.deep, 0.85) }
            GradientStop { position: 1; color: "transparent" }
        }
        RowLayout {
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: pl.mini ? 8 : 18 }
            spacing: 10
            PBtn { visible: pl.mode === "theater"; icon: String.fromCodePoint(0xf0141); onClicked: pl.app.toggleTheater() }
            Text {
                Layout.fillWidth: true
                visible: !pl.mini
                text: pl.app.current ? pl.app.current.title : ""
                elide: Text.ElideRight
                font.family: Theme.fontUi; font.pixelSize: 16; font.weight: Font.DemiBold; color: Colors.fg
            }
            Item { Layout.fillWidth: true; visible: pl.mini }
            PBtn { visible: pl.mini; small: true; icon: String.fromCodePoint(0xf0293); tip: "Развернуть"; onClicked: pl.app.go("watch") }
            PBtn { visible: pl.mini; small: true; icon: String.fromCodePoint(0xf0156); tip: "Закрыть"; onClicked: pl.app.closePlayer() }
        }
    }

    // ---- мини-плеер: пауза по центру ----
    PBtn {
        visible: pl.mini
        anchors.centerIn: parent
        opacity: area.containsMouse || mp.paused ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.fast } }
        big: true; accent: true
        icon: mp.paused ? String.fromCodePoint(0xf040a) : String.fromCodePoint(0xf03e4)
        onClicked: pl.togglePause()
    }
    Rectangle {   // тонкая полоска прогресса у мини-плеера
        visible: pl.mini
        anchors { left: parent.left; bottom: parent.bottom }
        height: 3; color: Colors.acc
        width: mp.duration > 0 ? parent.width * mp.position / mp.duration : 0
    }

    // ---- низ: перемотка и кнопки ----
    Rectangle {
        id: bottomBar
        visible: !pl.mini
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 112
        opacity: pl.showUi ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: Colors.alpha(Colors.deep, 0.9) }
        }

        // полоса перемотки
        MouseArea {
            id: seekArea
            property bool dragging: false
            anchors { left: parent.left; right: parent.right; bottom: ctrlRow.top; leftMargin: 16; rightMargin: 16; bottomMargin: 2 }
            height: 22
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function frac(x) { return Math.max(0, Math.min(1, x / width)) }
            onPressed: (m) => { dragging = true; pl.dragPos = frac(m.x) * mp.duration }
            onPositionChanged: (m) => { pl.poke(); if (dragging) pl.dragPos = frac(m.x) * mp.duration }
            onReleased: (m) => { dragging = false; mp.seek(frac(m.x) * mp.duration, true); pl.dragPos = -1 }

            readonly property real shownPos: pl.dragPos >= 0 ? pl.dragPos : mp.position
            Rectangle {   // дорожка
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: seekArea.containsMouse || seekArea.dragging ? 6 : 4; radius: 3
                color: Colors.alpha(Colors.fg, 0.18)
                Behavior on height { NumberAnimation { duration: Theme.fast } }
                Rectangle {   // загружено
                    height: parent.height; radius: 3; color: Colors.alpha(Colors.fg, 0.28)
                    width: mp.duration > 0 ? parent.width * Math.min(1, mp.cacheEnd / mp.duration) : 0
                }
                Rectangle {   // просмотрено
                    height: parent.height; radius: 3; color: Colors.acc
                    width: mp.duration > 0 ? parent.width * seekArea.shownPos / mp.duration : 0
                }
            }
            Rectangle {   // ползунок
                x: (mp.duration > 0 ? seekArea.width * seekArea.shownPos / mp.duration : 0) - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 14; height: 14; radius: 7; color: Colors.acc
                scale: seekArea.containsMouse || seekArea.dragging ? 1 : 0
                Behavior on scale { NumberAnimation { duration: Theme.fast } }
            }
            Rectangle {   // подсказка времени под курсором
                visible: seekArea.containsMouse && mp.duration > 0
                x: Math.max(0, Math.min(seekArea.width - width, seekArea.mouseX - width / 2))
                y: -height - 6
                width: hoverT.implicitWidth + 16; height: 24; radius: 8; color: Colors.deep
                Text { id: hoverT; anchors.centerIn: parent; font.family: Theme.fontUi; font.pixelSize: 12; font.features: { "tnum": 1 }; color: Colors.fg
                       text: pl.app.fmtTime(seekArea.frac(seekArea.mouseX) * mp.duration) }
            }
        }

        RowLayout {
            id: ctrlRow
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 12; rightMargin: 12; bottomMargin: 10 }
            spacing: 4
            PBtn { accent: true; icon: mp.paused || mp.eof ? String.fromCodePoint(0xf040a) : String.fromCodePoint(0xf03e4)
                   tip: mp.paused ? "Смотреть (Пробел)" : "Пауза (Пробел)"
                   onClicked: { if (mp.eof) mp.seek(0, true); pl.togglePause() } }
            PBtn { icon: String.fromCodePoint(0xf045f); tip: "−10 с (J)"; onClicked: pl.seekBy(-10) }
            PBtn { icon: String.fromCodePoint(0xf0211); tip: "+10 с (L)"; onClicked: pl.seekBy(10) }
            PBtn { visible: pl.app.queue.length > 0; icon: String.fromCodePoint(0xf04ad); tip: "Следующее"; onClicked: pl.app.playNext() }
            // громкость
            MouseArea {
                id: volArea
                Layout.preferredWidth: containsMouse || volDrag.pressed ? 150 : 40
                Layout.preferredHeight: 40
                Behavior on Layout.preferredWidth { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                hoverEnabled: true
                clip: true
                PBtn {
                    id: volBtn
                    icon: mp.muted || mp.volume === 0 ? String.fromCodePoint(0xf0581) : mp.volume < 50 ? String.fromCodePoint(0xf057f) : String.fromCodePoint(0xf057e)
                    tip: ""
                    onClicked: { mp.muted = !mp.muted; pl.osd(mp.muted ? "Без звука" : "Звук") }
                }
                Item {
                    x: 46; width: 92; height: parent.height
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width; height: 4; radius: 2; color: Colors.alpha(Colors.fg, 0.2)
                        Rectangle { height: parent.height; radius: 2; color: Colors.fg; width: parent.width * Math.min(1, mp.volume / 100) }
                    }
                    MouseArea {
                        id: volDrag
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onPressed: (m) => pl.setVol(m.x / width * 100)
                        onPositionChanged: (m) => { if (pressed) pl.setVol(m.x / width * 100) }
                    }
                }
            }
            Text {
                Layout.leftMargin: 6
                text: pl.app.fmtTime(mp.position) + "  /  " + pl.app.fmtTime(mp.duration)
                font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium; font.features: { "tnum": 1 }
                color: Colors.fg
            }
            Item { Layout.fillWidth: true }
            PChip { text: mp.speed === 1 ? "1×" : String(mp.speed).replace(".", ",") + "×"; tip: "Скорость"
                    onClicked: { const s = [1, 1.25, 1.5, 1.75, 2, 0.75]; const i = s.indexOf(Math.round(mp.speed * 100) / 100); mp.speed = s[(i + 1) % s.length]; pl.poke() } }
            PChip { text: pl.app.qLabel(pl.app.settings.quality); tip: "Качество"
                    onClicked: { const q = pl.app.qualities; pl.app.setSetting("quality", q[(q.indexOf(pl.app.settings.quality) + 1) % q.length]) } }
            PBtn { icon: pl.app.audioOnly ? String.fromCodePoint(0xf0567) : String.fromCodePoint(0xf02cb)
                   tip: pl.app.audioOnly ? "Показать видео" : "Только звук"
                   onClicked: pl.app.audioOnly = !pl.app.audioOnly }
            PBtn { icon: pl.mode === "theater" ? String.fromCodePoint(0xf0294) : String.fromCodePoint(0xf0293)
                   tip: pl.mode === "theater" ? "Выйти (F / Esc)" : "Во весь экран (F)"
                   onClicked: pl.app.toggleTheater() }
        }
    }

    // ---- кнопка плеера ----
    component PBtn: Rectangle {
        id: b
        property string icon: ""
        property string tip: ""
        property bool accent: false
        property bool big: false
        property bool small: false
        signal clicked()
        implicitWidth: big ? 56 : small ? 32 : 40; implicitHeight: implicitWidth
        radius: implicitWidth / 2
        color: accent ? (bm.containsMouse ? Colors.mix(Colors.acc, Colors.fg, 0.15) : Colors.acc)
             : bm.containsMouse ? Colors.alpha(Colors.fg, 0.16) : (small ? Colors.alpha(Colors.deep, 0.7) : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        scale: bm.pressed ? 0.9 : 1
        Behavior on scale { NumberAnimation { duration: Theme.fast } }
        Glyph { anchors.centerIn: parent; text: b.icon; font.pixelSize: b.big ? 28 : b.small ? 16 : 21; color: b.accent ? Colors.onAcc : Colors.fg }
        MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked()
                    onEntered: pl.poke() }
        Rectangle {
            visible: bm.containsMouse && b.tip.length > 0
            anchors.bottom: parent.top; anchors.bottomMargin: 8; anchors.horizontalCenter: parent.horizontalCenter
            width: tt.implicitWidth + 16; height: 26; radius: 9; color: Colors.deep
            Text { id: tt; anchors.centerIn: parent; text: b.tip; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fg }
        }
    }
    component PChip: Rectangle {
        id: c
        property string text: ""
        property string tip: ""
        signal clicked()
        implicitWidth: ct.implicitWidth + 22; implicitHeight: 30; radius: 12
        color: cm.containsMouse ? Colors.alpha(Colors.fg, 0.16) : Colors.alpha(Colors.fg, 0.08)
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        Text { id: ct; anchors.centerIn: parent; text: c.text; font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.DemiBold; color: Colors.fg }
        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: c.clicked(); onEntered: pl.poke() }
    }
}
