import QtQuick
import qs
import qs.services

// Текст песни: строки из Player.lyrics (yumilyrics через бэкенд). «Остров» (29.10): Onest, текущая строка — fg,
// остальные — fg 35 % (без таймингов — все fg); текущая держится по центру, прокрутка — пружина (OutBack).
// Индекс строки не опрашивается таймером, а переключается ровно в момент следующей строки (таймер на разницу
// времени; позиция интерполируется в Player.position()). Клик по строке — перемотка; колесо — ручная прокрутка,
// слежение возвращается через 3 с. px / weight — размер и насыщенность строк (остров бара — 13, меню «Музыка» — 20).
Item {
    id: root
    property bool running: false
    property int current: -1
    property bool manual: false
    property int px: 13
    property int weight: Font.Normal
    property int lineGap: 4
    property bool showSource: true

    readonly property bool synced: running && Player.lyricsSynced && Player.lyrics.length > 0
    function update() {
        if (!synced) { next.stop(); return }
        const i = Player.lyricIndex()
        if (i !== current) current = i
        if (!Player.playing) { next.stop(); return }
        const n = Player.lyrics[i + 1]
        if (!n) { next.stop(); return }
        next.interval = Math.max(20, Math.round((n[0] - Player.lyricsShift - Player.position()) * 1000))
        next.restart()
    }
    Timer { id: next; onTriggered: root.update() }
    onSyncedChanged: update()
    onCurrentChanged: follow()
    Connections {
        target: Player
        function onPosBaseChanged() { root.update() }      // опрос позиции (500 мс) / перемотка — пересчитать
        function onPlayingChanged() { root.update() }
        function onLyricsChanged() { root.current = -1; root.manual = false; scroll.stop(); list.positionViewAtBeginning(); root.update() }
    }
    Timer { id: manualOff; interval: 3000; onTriggered: { root.manual = false; root.follow() } }

    // текущая строка — к центру, пружиной
    function follow() {
        if (!synced || manual || current < 0) return
        const it = list.itemAtIndex(current)
        if (!it) { list.positionViewAtIndex(current, ListView.Center); return }
        const maxY = Math.max(list.originY, list.originY + list.contentHeight - list.height)
        const to = Math.max(list.originY, Math.min(maxY, it.y + it.height / 2 - list.height / 2))
        if (Math.abs(to - list.contentY) < 1) return
        scroll.to = to
        scroll.restart()
    }
    NumberAnimation { id: scroll; target: list; property: "contentY"; duration: 560; easing.type: Easing.OutBack; easing.overshoot: 1.1 }

    ListView {
        id: list
        anchors.fill: parent
        anchors.bottomMargin: root.showSource ? 16 : 0
        clip: true
        spacing: root.lineGap
        model: Player.lyrics
        boundsBehavior: Flickable.StopAtBounds
        highlightRangeMode: ListView.NoHighlightRange
        cacheBuffer: 2000
        onHeightChanged: root.follow()
        delegate: Text {
            id: line
            required property var modelData
            required property int index
            readonly property bool cur: Player.lyricsSynced && index === root.current
            width: list.width
            text: modelData[1]
            wrapMode: Text.Wrap
            font.family: Theme.fontUi
            font.pixelSize: root.px
            font.weight: root.weight
            color: cur || !Player.lyricsSynced ? Colors.fg : Colors.alpha(Colors.fg, 0.35)
            Behavior on color { ColorAnimation { duration: Theme.normal } }
            transformOrigin: Item.Left
            scale: cur ? 1.04 : 1
            Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
            leftPadding: 2
            MouseArea { anchors.fill: parent; enabled: Player.lyricsSynced; cursorShape: Qt.PointingHandCursor
                        onClicked: Player.seek(Math.max(0, line.modelData[0] - Player.lyricsShift)) }
        }
        WheelHandler { onWheel: { root.manual = true; scroll.stop(); manualOff.restart() } }
        onMovementStarted: { root.manual = true; scroll.stop(); manualOff.restart() }
    }
    // сообщение («Ищу текст…», «Текст не найден»)
    Text {
        anchors.centerIn: parent
        visible: Player.lyrics.length === 0
        text: Player.lyricsMsg
        font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fgDim
        horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; width: parent.width - 20
    }
    // источник
    Text {
        anchors { right: parent.right; bottom: parent.bottom }
        visible: root.showSource && Player.lyrics.length > 0 && Player.lyricsSource.length > 0
        text: Player.lyricsSource
        font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.alpha(Colors.fgDim, 0.7)
        elide: Text.ElideLeft; width: Math.min(implicitWidth, parent.width)
    }
}
