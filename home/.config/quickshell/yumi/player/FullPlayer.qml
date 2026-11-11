import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs
import qs.components
import qs.services

// Полноэкранный плеер: слой поверх живого фона из цветов обложки или обоев (C), по центру крупная обложка с тенью
// в цвете обложки; смена трека — карусель с пружиной. «Остров» (29.10): Onest, обложка radius 28, капсулы, сегменты
// Текст / Очередь / Плейлисты (ISeg), текст песни — текущая строка ярко, остальные 35 %, прокрутка пружиной. Три уровня (↑↓):
//   «Текст» (справа, синхронный: ←→ — строка, Enter — перейти к ней) · «Плеер» (←→ — трек назад/вперёд) ·
//   «Далее» (полка обложек снизу: ←→ — трек очереди, Enter — включить).
//   qs -c yumi ipc call player full        открыть / закрыть (обработчик — в PlayerIsland, флаг Player.fullOpen)
// Клавиши: Esc — закрыть, пробел — пауза, Ctrl+↑/↓ (или +/−) — громкость, L — текст, Q — далее, C — цвета фона,
// H — ♡ добавить в плейлист, M — свернуть в окно плеера. Мышь — как раньше: полосы, кнопки, строки текста, очередь.
// Состояние (фон, панель) — тот же файл, что у GTK-версии: ~/.local/state/yumi-player/full.json.
// Проверка: YUMI_QS_SCREEN=eDP-1 — экран принудительно; YUMI_QS_NOKB=1 — без клавиатуры (тестовое окно не забирает ввод).
PanelWindow {
    id: win
    readonly property bool open: Player.fullOpen
    readonly property string testScreen: Quickshell.env("YUMI_QS_SCREEN")
    property var target: null
    screen: target
    onOpenChanged: {
        if (open) {
            const name = testScreen || (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "")
            target = Quickshell.screens.find(s => s.name === name) ?? null
            level = "cover"; picker = false
            if (panel === "queue") Player.requestQueue()
        } else closer.restart()
        Sound.fullActive = open
    }
    visible: open || closer.running
    color: "transparent"
    WlrLayershell.namespace: "yumi-qs-fullplayer"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    // OnDemand, не Exclusive: исключительная клавиатура не давала второму экрану ни клавиатуры, ни мыши (урок GTK-версии)
    WlrLayershell.keyboardFocus: open && Quickshell.env("YUMI_QS_NOKB") !== "1" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    Timer { id: closer; interval: Theme.slow }
    function close() { Player.fullOpen = false }

    // ---------- размеры от высоты экрана ----------
    readonly property real hh: height > 0 ? height : 1080
    readonly property real ww: width > 0 ? width : 1920
    function u(f) { return Math.max(1, Math.round(hh * f)) }
    readonly property string font: "Inter Display"

    // ---------- состояние: фон и панель (общий файл с yumi-player-full) ----------
    property string bgMode: "cover"            // cover | wall
    property string panel: "lyrics"            // lyrics | queue | none
    FileView {
        id: stateFile
        path: Quickshell.env("HOME") + "/.local/state/yumi-player/full.json"
        onLoaded: { try { const d = JSON.parse(text()); win.bgMode = d.bg || "cover"; win.panel = d.panel || "lyrics" } catch (e) {} }
    }
    function save() { stateFile.setText(JSON.stringify({ bg: bgMode, panel: panel })) }
    function setPanel(p) { panel = panel === p ? "none" : p; save(); if (panel === "queue") Player.requestQueue(); if (level !== "cover" && panel !== level) level = "cover" }
    function showPanel(p) { if (panel !== p) { panel = p; save() } if (p === "queue") Player.requestQueue() }
    function toggleBg() { bgMode = bgMode === "cover" ? "wall" : "cover"; save() }
    function minimize() { close(); Player.showIsland("center") }   // «Свернуть в окно плеера»

    // ---------- уровни для клавиатуры: lyrics ↑ cover ↓ queue ----------
    property string level: "cover"
    property int qSel: 0                       // выбранный трек полки «Далее»
    property int lSel: -1                      // строка текста, выбранная стрелками (-1 — следовать песне)
    function goUp() {
        if (level === "queue") level = "cover"
        else if (level === "cover") { showPanel("lyrics"); level = "lyrics"; lSel = -1 }
    }
    function goDown() {
        if (level === "lyrics") { level = "cover"; lSel = -1 }
        else if (level === "cover") { showPanel("queue"); level = "queue"; qSel = 0; qList.positionViewAtBeginning() }
    }
    function sideKey(d) {
        if (level === "cover") { win.dir = d; if (d > 0) Player.next(); else Player.previous() }
        else if (level === "queue") { if (Player.queue.length) { qSel = Math.max(0, Math.min(Player.queue.length - 1, qSel + d)); qList.positionViewAtIndex(qSel, ListView.Contain) } }
        else if (level === "lyrics" && Player.lyrics.length) {
            const base = lSel >= 0 ? lSel : Math.max(0, lyr.current)
            lSel = Math.max(0, Math.min(Player.lyrics.length - 1, base + d)); lyr.manual = true; manualOff.restart()
            lyrList.positionViewAtIndex(lSel, ListView.Center)
        }
    }
    function enterKey() {
        if (level === "queue") { const q = Player.queue[qSel]; if (q) { win.dir = 1; Player.play(q.n) } }
        else if (level === "lyrics" && lSel >= 0 && Player.lyricsSynced) { const l = Player.lyrics[lSel]; if (l) Player.seek(Math.max(0, l[0] - Player.lyricsShift)); lSel = -1 }
        else Player.togglePlaying()
    }

    // ---------- палитра фона: пять насыщенных разных цветов обложки или цвета обоев ----------
    ColorQuantizer { id: quant; source: win.open && Player.artUrl ? Player.artUrl : ""; depth: 4; rescaleSize: 32 }
    function coverPalette() {
        const cs = quant.colors.map(c => ({ c: c, s: c.hsvSaturation * 0.6 + c.hsvValue * 0.4 })).filter(x => x.c.hsvValue >= 0.18)
        cs.sort((a, b) => b.s - a.s)
        const pick = []
        for (const x of cs) {
            if (pick.every(q => Math.hypot(q.r - x.c.r, q.g - x.c.g, q.b - x.c.b) > 0.24)) pick.push(x.c)
            if (pick.length === 5) break
        }
        while (pick.length < 5) pick.push(pick.length ? pick[pick.length - 1] : Qt.rgba(0.45, 0.45, 0.45, 1))
        return pick
    }
    function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1) }
    readonly property var wallPal: [Colors.acc, mix(Colors.fg, Colors.acc, 0.5), Colors.acc5, Colors.bg, mix(Colors.hover, Colors.acc, 0.4)]
    readonly property var pal: bgMode === "cover" && quant.colors.length ? coverPalette() : wallPal
    property color c0: pal[0]; property color c1: pal[1]; property color c2: pal[2]; property color c3: pal[3]; property color c4: pal[4]
    Behavior on c0 { ColorAnimation { duration: 1500 } } Behavior on c1 { ColorAnimation { duration: 1500 } }
    Behavior on c2 { ColorAnimation { duration: 1500 } } Behavior on c3 { ColorAnimation { duration: 1500 } }
    Behavior on c4 { ColorAnimation { duration: 1500 } }
    // акцент обложки — для тени, выделения и полос (светлота в коридоре, как Colors.band)
    readonly property color acc: Colors.band(c0, 0.62, 0.80)
    readonly property color deepTone: Qt.rgba(c3.r * 0.16, c3.g * 0.16, c3.b * 0.16, 1)

    // позиция для отрисовки (опрос MPRIS раз в 500 мс, полоса доезжает линейно)
    property real pos: 0
    Timer { interval: 500; running: win.open && Player.shown; repeat: true; triggeredOnStart: true; onTriggered: win.pos = Player.position() }
    function fmt(s) { s = Math.max(0, Math.floor(s)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0") }

    // ---------- карусель обложки: при смене трека старая уезжает, новая приезжает ----------
    property int dir: 1                        // куда листали: 1 — вперёд (по умолчанию), -1 — назад
    property string shownArt: ""
    property string oldArt: ""
    readonly property string art: Player.artUrl
    onArtChanged: {
        if (!open) { shownArt = art; return }
        if (art === shownArt) return
        oldArt = shownArt; shownArt = art
        swap.restart()
    }
    Component.onCompleted: shownArt = art
    ParallelAnimation {
        id: swap
        NumberAnimation { target: coverNew; property: "slide"; from: win.dir; to: 0; duration: 560; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        NumberAnimation { target: coverOld; property: "slide"; from: 0; to: -win.dir; duration: 420; easing.type: Easing.OutCubic }
        onFinished: { win.oldArt = ""; win.dir = 1 }
    }

    Item {
        id: stage
        anchors.fill: parent
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: win.open ? Theme.normal : Theme.fast } }
        Behavior on scale { NumberAnimation { duration: win.open ? Theme.menuOpen : Theme.fast; easing.type: win.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.15 } }

        // ---------- живой фон: пять мягких пятен (как раньше) + затемнение тёмным тоном обложки ----------
        Rectangle { anchors.fill: parent; color: win.deepTone; Behavior on color { ColorAnimation { duration: 1500 } } }
        Item {
            id: bg
            anchors.fill: parent
            opacity: 0.8
            property real t: 0
            // пульс под бас: cava (raw ascii, 60 к/с) только по музыке (yumi-cava-source --run, без Discord), пока открыто и играет
            property real bass: 0
            Behavior on bass { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
            Process {
                running: win.visible && Player.playing
                command: ["sh", "-c",
                    "conf=$XDG_RUNTIME_DIR/yumi-qs-cava-full.conf; " +
                    "printf '[general]\\nbars = 8\\nframerate = 60\\nautosens = 1\\n[input]\\nmethod = fifo\\nsource = /dev/stdin\\nsample_rate = 48000\\nsample_bits = 16\\nchannels = 2\\n" +
                    "[output]\\nmethod = raw\\nraw_target = /dev/stdout\\ndata_format = ascii\\nascii_max_range = 1000\\n" +
                    "channels = mono\\nmono_option = average\\n[smoothing]\\nnoise_reduction = 30\\n' > \"$conf\" && exec \"$HOME/.local/bin/yumi-cava-source\" --run \"$conf\""]
                stdout: SplitParser { onRead: (line) => {
                    const p = line.split(";"), n = Math.min(3, p.length)
                    let sum = 0; for (let i = 0; i < n; i++) sum += Number(p[i]) || 0
                    bg.bass = n ? Math.min(1, sum / n / 1000) : 0 } }
                onRunningChanged: if (!running) bg.bass = 0
            }
            NumberAnimation on t { from: 0; to: 6283; duration: 6283 * 1000; loops: Animation.Infinite; running: win.visible }
            Repeater {
                model: 5
                delegate: Shape {
                    required property int index
                    readonly property color col: [win.c0, win.c1, win.c2, win.c3, win.c4][index]
                    readonly property real rad: Math.max(bg.width, bg.height) * (0.5 + 0.05 * Math.sin(bg.t * 0.2 + index)) * (1 + 0.16 * bg.bass * (index % 2 ? 0.7 : 1))
                    readonly property real cx: bg.width * (0.5 + 0.42 * Math.sin(bg.t * (0.07 + index * 0.013) + index * 1.7))
                    readonly property real cy: bg.height * (0.5 + 0.40 * Math.cos(bg.t * (0.06 + index * 0.011) + index * 2.3))
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeWidth: -1
                        fillGradient: RadialGradient {
                            centerX: cx; centerY: cy; centerRadius: rad; focalX: cx; focalY: cy
                            GradientStop { position: 0; color: Qt.rgba(col.r, col.g, col.b, 0.42 + 0.2 * bg.bass) }
                            GradientStop { position: 1; color: Qt.rgba(col.r, col.g, col.b, 0) }
                        }
                        PathRectangle { x: 0; y: 0; width: bg.width; height: bg.height }
                    }
                }
            }
        }
        Rectangle { anchors.fill: parent; color: Colors.alpha(win.deepTone, 0.35) }   // вуаль: как затемнение у меню

        FocusScope {
            anchors.fill: parent
            focus: win.open                     // снять фокус до уничтожения (segfault в clearFocusInScope)
            Keys.onPressed: (e) => {
                const k = e.key, t = e.text.toLowerCase(), ctrl = e.modifiers & Qt.ControlModifier
                if (win.picker && k === Qt.Key_Escape) win.picker = false
                else if (k === Qt.Key_Escape) win.close()
                else if (k === Qt.Key_Space) Player.togglePlaying()
                else if ((k === Qt.Key_Up || k === Qt.Key_Down) && ctrl) vol.push(vol.shown + (k === Qt.Key_Up ? 0.05 : -0.05))
                else if (k === Qt.Key_Plus || k === Qt.Key_Equal || k === Qt.Key_Minus) vol.push(vol.shown + (k === Qt.Key_Minus ? -0.05 : 0.05))
                else if (k === Qt.Key_Up) win.goUp()
                else if (k === Qt.Key_Down) win.goDown()
                else if (k === Qt.Key_Left) win.sideKey(-1)
                else if (k === Qt.Key_Right) win.sideKey(1)
                else if (k === Qt.Key_Return || k === Qt.Key_Enter) win.enterKey()
                else if (t === "l" || t === "д") win.setPanel("lyrics")
                else if (t === "q" || t === "й") win.setPanel("queue")
                else if (t === "c" || t === "с") win.toggleBg()
                else if (t === "h" || t === "р") win.picker = !win.picker
                else if (t === "m" || t === "ь") win.minimize()
                else return
                e.accepted = true
            }

            // ---------- центр: обложка, название, полосы, кнопки ----------
            Item {
                id: mainCol
                readonly property bool side: win.panel === "lyrics"
                readonly property bool shelf: win.panel === "queue"
                width: side ? Math.round(win.ww * 0.44) : win.ww
                height: parent.height - (shelf ? shelfBox.height + shelfBox.anchors.bottomMargin + win.u(0.03) : 0)
                Behavior on width { NumberAnimation { duration: Theme.slow; easing.type: Theme.easeSoft } }
                Behavior on height { NumberAnimation { duration: Theme.slow; easing.type: Theme.easeSoft } }
                readonly property int px: Math.min(width * 0.62, shelf ? win.u(0.26) : (side ? win.u(0.44) : win.u(0.5)))

                ColumnLayout {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: win.u(0.01)
                    width: Math.max(mainCol.px, win.u(0.46))
                    spacing: win.u(0.022)

                    // обложка: тень в цвете обложки (сдержанная), карусель при смене трека
                    Item {
                        id: coverBox
                        Layout.preferredWidth: mainCol.px; Layout.preferredHeight: mainCol.px
                        Layout.alignment: Qt.AlignHCenter
                        Behavior on Layout.preferredWidth { NumberAnimation { duration: Theme.slow; easing.type: Theme.easeSoft } }
                        Behavior on Layout.preferredHeight { NumberAnimation { duration: Theme.slow; easing.type: Theme.easeSoft } }
                        scale: win.level === "cover" ? 1 : 0.96
                        Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
                        RectangularShadow {
                            anchors.fill: parent; radius: 28; blur: 28; spread: 0
                            color: Colors.alpha(win.acc, 0.3)
                            Behavior on color { ColorAnimation { duration: 1500 } }
                        }
                        Item {                    // всё, что выходит за обложку при карусели, обрезается
                            anchors.fill: parent
                            clip: true
                            ClippingRectangle {
                                anchors.fill: parent; radius: 28; color: Qt.rgba(1, 1, 1, 0.08)
                                CoverImage { id: coverOld; src: win.oldArt; visible: win.oldArt !== "" }
                                CoverImage { id: coverNew; src: win.shownArt }
                                Text { anchors.centerIn: parent; visible: coverNew.status !== Image.Ready; text: "󰝚"; color: Qt.rgba(1, 1, 1, 0.5)
                                       font.family: Theme.fontIcon; font.pixelSize: win.u(0.12) }
                            }
                        }
                        Rectangle {               // кромка: на уровне «Плеер» — тонкий акцент
                            anchors.fill: parent; anchors.margins: win.level === "cover" ? -3 : 0; radius: win.level === "cover" ? 31 : 28; color: "transparent"
                            border.width: win.level === "cover" ? 2 : 1; border.color: win.level === "cover" ? win.acc : Qt.rgba(1, 1, 1, 0.10)
                            Behavior on border.color { ColorAnimation { duration: Theme.normal } }
                        }
                        MouseArea { anchors.fill: parent; onClicked: { win.level = "cover"; Player.togglePlaying() } }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: win.u(0.004)
                        RowLayout {
                            Layout.fillWidth: true; spacing: win.u(0.012)
                            Text { Layout.fillWidth: true; text: Player.shown ? Player.title : "Ничего не играет"; elide: Text.ElideRight
                                   font.family: Theme.fontUi; font.pixelSize: win.u(0.029); font.weight: Font.DemiBold; color: "white" }
                            Row {   // пять мягких столбиков у названия
                                spacing: Math.max(2, win.u(0.036) / 8.5 * 0.9)
                                Repeater {
                                    model: 5
                                    Rectangle {
                                        required property int index
                                        readonly property real bw: Math.max(2, win.u(0.036) / 8.5)
                                        property real lv: 0.2
                                        width: bw; radius: bw / 2; anchors.verticalCenter: parent.verticalCenter
                                        height: Math.max(bw, win.u(0.022) * (Player.playing ? lv : 0.15))
                                        color: Player.playing ? win.acc : Qt.rgba(1, 1, 1, 0.5)
                                        Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
                                        Timer { interval: 170 + index * 23; running: Player.playing && win.open; repeat: true
                                                onTriggered: parent.lv = 0.25 + Math.random() * 0.75 }
                                    }
                                }
                            }
                        }
                        Text { Layout.fillWidth: true; text: Player.artist; visible: text.length > 0; elide: Text.ElideRight
                               font.family: Theme.fontUi; font.pixelSize: win.u(0.020); color: Qt.rgba(1, 1, 1, 0.62) }
                        FullSlider {
                            Layout.fillWidth: true; Layout.topMargin: win.u(0.012)
                            track: Math.max(4, win.u(0.005)); throttleMs: 150; blockMs: 800; smooth: true
                            fillColor: win.acc
                            value: Player.length > 0 ? Math.min(1, win.pos / Player.length) : 0
                            onMoved: (v) => Player.seek(v * Player.length)
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { Layout.fillWidth: true; text: win.fmt(win.pos); font.family: Theme.fontUi; font.pixelSize: win.u(0.013); color: Qt.rgba(1, 1, 1, 0.45); font.features: ({ "tnum": 1 }) }
                            Text { font.features: ({ "tnum": 1 }); text: "-" + win.fmt(Math.max(0, Player.length - win.pos)); font.family: Theme.fontUi; font.pixelSize: win.u(0.013); color: Qt.rgba(1, 1, 1, 0.45) }
                        }
                        Row {
                            Layout.alignment: Qt.AlignHCenter; Layout.topMargin: win.u(0.004)
                            spacing: win.u(0.045)
                            FullButton { anchors.verticalCenter: parent.verticalCenter; icon: "󰒮"; size: win.u(0.058); iconPx: win.u(0.032); tooltip: "Назад (←)"
                                         onClicked: { win.dir = -1; Player.previous() } }
                            FullButton { anchors.verticalCenter: parent.verticalCenter; icon: Player.stopped && !Player.canResume ? "󰏌" : (Player.playing ? "󰏤" : "󰐊"); size: win.u(0.076); iconPx: win.u(0.046)
                                         raised: true; fill: win.acc; ink: win.deepTone
                                         tooltip: Player.stopped ? (Player.canResume ? "Продолжить (пробел)" : "Открыть в браузере") : "Пауза (пробел)"; onClicked: Player.togglePlaying() }
                            FullButton { anchors.verticalCenter: parent.verticalCenter; icon: "󰒭"; size: win.u(0.058); iconPx: win.u(0.032); tooltip: "Вперёд (→)"
                                         onClicked: { win.dir = 1; Player.next() } }
                        }
                        RowLayout {   // громкость проигрывателя (поток этого плеера) и выход звука
                            Layout.fillWidth: true; Layout.topMargin: win.u(0.008)
                            spacing: win.u(0.012)
                            Text { text: Player.muted ? "󰖁" : "󰕿"; font.family: Theme.fontIcon; font.pixelSize: win.u(0.015); color: Qt.rgba(1, 1, 1, 0.5)
                                   MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: Player.toggleMute() } }
                            FullSlider { id: vol; Layout.fillWidth: true; fillAlpha: 0.7; track: Math.max(4, win.u(0.005))
                                         value: Player.volume; onMoved: (v) => Player.setVolume(v) }
                            Text { text: "󰕾"; font.family: Theme.fontIcon; font.pixelSize: win.u(0.015); color: Qt.rgba(1, 1, 1, 0.5) }
                            Pill {
                                text: (win.curSinkNode ? Sound.devIcon("sink", win.curSinkNode) + "  " : "󰓃  ")
                                      + (win.streamInfo ? win.streamInfo.dev_short : (win.curSinkNode ? Sound.devName("sink", win.curSinkNode) : "Выход")) + (win.devOpen ? "  󰅃" : "  󰅀")
                                on: win.devOpen
                                onClicked: win.devOpen = !win.devOpen
                            }
                        }
                        Column {   // список выходов (как в острове) — раскрывается на месте
                            Layout.fillWidth: true
                            visible: win.devOpen
                            spacing: 2
                            Repeater {
                                model: win.devOpen ? Sound.sinks : []
                                delegate: Rectangle {
                                    id: devRow
                                    required property var modelData
                                    required property int index
                                    readonly property bool active: modelData.name === win.curSink
                                    width: parent.width; height: 40; radius: Theme.radius
                                    color: active ? Colors.alpha(win.acc, 0.2) : Qt.rgba(1, 1, 1, devArea.containsMouse ? 0.08 : 0)
                                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                                    opacity: 0
                                    Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                                    Timer { interval: 40 * devRow.index; running: true; onTriggered: devRow.opacity = 1 }
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter; x: 12; spacing: 10
                                        Text { text: Sound.devIcon("sink", devRow.modelData); font.family: Theme.fontIcon; font.pixelSize: 15; color: devRow.active ? win.acc : "white" }
                                        Text { text: Sound.devName("sink", devRow.modelData); font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium; color: "white" }
                                    }
                                    MouseArea { id: devArea; anchors.fill: parent; hoverEnabled: true; onClicked: win.pickSink(devRow.modelData) }
                                }
                            }
                        }
                    }
                }
            }

            // ---------- справа: текст песни (уровень «Текст») ----------
            Item {
                id: right
                x: mainCol.width; width: win.ww - mainCol.width; height: parent.height
                opacity: win.panel === "lyrics" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 350 } }

                Item {
                    id: lyr
                    anchors.fill: parent
                    anchors.topMargin: win.u(0.12); anchors.bottomMargin: win.u(0.12); anchors.rightMargin: Math.round(win.ww * 0.07)
                    property int current: -1
                    property bool manual: false
                    readonly property bool synced: win.open && win.panel === "lyrics" && Player.lyricsSynced && Player.lyrics.length > 0
                    function update() {
                        if (!synced) { nextLine.stop(); return }
                        const i = Player.lyricIndex()
                        if (i !== current) current = i
                        if (!Player.playing) { nextLine.stop(); return }
                        const n = Player.lyrics[i + 1]
                        if (!n) { nextLine.stop(); return }
                        nextLine.interval = Math.max(20, Math.round((n[0] - Player.lyricsShift - Player.position()) * 1000))
                        nextLine.restart()
                    }
                    Timer { id: nextLine; onTriggered: lyr.update() }
                    onSyncedChanged: update()
                    Connections {
                        target: Player
                        function onPosBaseChanged() { lyr.update() }
                        function onPlayingChanged() { lyr.update() }
                        function onLyricsChanged() { lyr.current = -1; lyr.manual = false; win.lSel = -1; lyrScroll.stop(); lyrList.positionViewAtBeginning(); lyr.update() }
                    }
                    Timer { id: manualOff; interval: 3000; onTriggered: { lyr.manual = false; if (win.level !== "lyrics") win.lSel = -1; lyr.follow() } }
                    // текущая строка — на 30 % высоты, прокрутка пружиной (OutBack)
                    onCurrentChanged: follow()
                    function follow() {
                        if (!synced || manual || current < 0) return
                        const it = lyrList.itemAtIndex(current)
                        if (!it) { lyrList.positionViewAtIndex(current, ListView.Center); return }
                        const maxY = Math.max(lyrList.originY, lyrList.originY + lyrList.contentHeight - lyrList.height)
                        const to = Math.max(lyrList.originY, Math.min(maxY, it.y - lyrList.height * 0.3))
                        if (Math.abs(to - lyrList.contentY) < 1) return
                        lyrScroll.to = to; lyrScroll.restart()
                    }
                    NumberAnimation { id: lyrScroll; target: lyrList; property: "contentY"; duration: 620; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
                    ListView {
                        id: lyrList
                        anchors.fill: parent
                        clip: true
                        spacing: win.u(0.004)
                        model: Player.lyrics
                        boundsBehavior: Flickable.StopAtBounds
                        highlightRangeMode: ListView.NoHighlightRange
                        cacheBuffer: 3000
                        onHeightChanged: lyr.follow()
                        header: Item { height: lyr.synced ? 0 : win.u(0.02) }
                        delegate: Rectangle {
                            id: line
                            required property var modelData
                            required property int index
                            readonly property bool cur: Player.lyricsSynced && index === lyr.current
                            readonly property bool near: Player.lyricsSynced && Math.abs(index - lyr.current) === 1
                            readonly property bool picked: win.level === "lyrics" && index === win.lSel
                            width: lyrList.width
                            height: txt.implicitHeight + win.u(0.024)
                            radius: Theme.radiusTile
                            color: picked ? Colors.alpha(win.acc, 0.18) : Qt.rgba(1, 1, 1, lineArea.containsMouse ? 0.06 : 0)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text {
                                id: txt
                                x: win.u(0.016); width: parent.width - win.u(0.032); anchors.verticalCenter: parent.verticalCenter
                                text: line.modelData[1]
                                wrapMode: Text.Wrap
                                font.family: Theme.fontUi; font.pixelSize: win.u(0.044); font.weight: Font.DemiBold
                                color: "white"
                                // «Остров»: текущая — ярко, остальные — 35 % (наведение — 55 %)
                                opacity: !Player.lyricsSynced ? 1 : (line.cur || line.picked ? 1 : (lineArea.containsMouse ? 0.55 : 0.35))
                                transformOrigin: Item.Left
                                scale: line.cur ? 1.03 : 1
                                Behavior on scale { NumberAnimation { duration: 360; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
                                Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.InOutQuad } }
                            }
                            MouseArea { id: lineArea; anchors.fill: parent; hoverEnabled: true; enabled: Player.lyricsSynced
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Player.seek(Math.max(0, line.modelData[0] - Player.lyricsShift)) }
                        }
                        onMovementStarted: { lyr.manual = true; lyrScroll.stop(); manualOff.restart() }
                        WheelHandler { onWheel: { lyr.manual = true; lyrScroll.stop(); manualOff.restart() } }
                    }
                    Text { anchors.verticalCenter: parent.verticalCenter; x: win.u(0.02); visible: Player.lyrics.length === 0
                           text: Player.shown ? Player.lyricsMsg : "Ничего не играет"
                           font.family: Theme.fontUi; font.pixelSize: win.u(0.023); color: Qt.rgba(1, 1, 1, 0.5) }
                    Text { anchors.bottom: parent.bottom; anchors.bottomMargin: -win.u(0.05); x: win.u(0.02)
                           visible: Player.lyrics.length > 0; text: Player.lyricsSource
                           font.family: Theme.fontUi; font.pixelSize: win.u(0.012); color: Qt.rgba(1, 1, 1, 0.35) }
                }
            }

            // ---------- снизу: полка «Далее» (уровень «Далее») ----------
            Item {
                id: shelfBox
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                anchors.bottomMargin: win.u(0.07)
                height: win.u(0.25)
                opacity: win.panel === "queue" ? 1 : 0
                visible: opacity > 0
                transform: Translate { y: win.panel === "queue" ? 0 : win.u(0.06)
                                       Behavior on y { NumberAnimation { duration: Theme.slow; easing.type: Theme.easeSoft } } }
                Behavior on opacity { NumberAnimation { duration: 350 } }
                Timer { interval: 3000; running: win.open && win.panel === "queue"; repeat: true; onTriggered: Player.requestQueue() }
                Text {
                    id: qHead
                    x: Math.round(win.ww * 0.06)
                    text: Player.queueHead || "Далее"                // «Остров»: как ISection — заглавными, разрядка
                    font.family: Theme.fontUi; font.pixelSize: win.u(0.014); font.weight: Font.Medium
                    font.capitalization: Font.AllUppercase; font.letterSpacing: 1.2
                    color: win.level === "queue" ? win.acc : Qt.rgba(1, 1, 1, 0.5)
                }
                ListView {
                    id: qList
                    anchors.top: qHead.bottom; anchors.topMargin: win.u(0.014)
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    leftMargin: Math.round(win.ww * 0.06); rightMargin: Math.round(win.ww * 0.06)
                    orientation: ListView.Horizontal
                    clip: false; spacing: win.u(0.022)
                    model: Player.queue
                    boundsBehavior: Flickable.StopAtBounds
                    Behavior on contentX { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.0 } }
                    delegate: Item {
                        id: qItem
                        required property var modelData
                        required property int index
                        readonly property bool on: win.level === "queue" && index === win.qSel
                        width: win.u(0.13); height: qList.height
                        opacity: 0
                        property real dy: 8
                        transform: Translate { y: qItem.dy }
                        Timer { interval: 40 * Math.min(qItem.index, 10); running: true; onTriggered: { qItem.opacity = 1; qItem.dy = 0 } }   // каскад
                        Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                        Behavior on dy { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                        Item {
                            id: qPlate
                            width: parent.width; height: width
                            scale: qArea.pressed ? 0.94 : qItem.on ? 1.1 : (qArea.containsMouse ? 1.04 : 1)
                            Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }
                            RectangularShadow { anchors.fill: parent; radius: 18; blur: 18; spread: 0
                                                color: Colors.alpha(win.acc, 0.25); opacity: qItem.on ? 1 : 0
                                                Behavior on opacity { NumberAnimation { duration: Theme.fast } } }
                            ClippingRectangle {
                                anchors.fill: parent; radius: 18; color: Qt.rgba(1, 1, 1, 0.08)
                                Image { anchors.fill: parent; source: qItem.modelData.cover ? "file://" + qItem.modelData.cover : ""; asynchronous: true
                                        sourceSize.width: 256; sourceSize.height: 256; fillMode: Image.PreserveAspectCrop }
                            }
                            Rectangle { anchors.fill: parent; anchors.margins: qItem.on ? -3 : 0; radius: qItem.on ? 21 : 18; color: "transparent"
                                        border.width: qItem.on ? 2 : 1; border.color: qItem.on ? win.acc : Qt.rgba(1, 1, 1, 0.10) }
                        }
                        Column {
                            anchors.top: qPlate.bottom; anchors.topMargin: win.u(0.014)
                            width: parent.width; spacing: 1
                            Text { width: parent.width; text: qItem.modelData.title; elide: Text.ElideRight
                                   font.family: Theme.fontUi; font.pixelSize: win.u(0.015); font.weight: Font.Medium; color: "white" }
                            Text { width: parent.width; text: (qItem.modelData.artist || "") + (qItem.modelData.dur ? "  ·  " + win.fmt(qItem.modelData.dur) : "")
                                   elide: Text.ElideRight; font.family: Theme.fontUi; font.pixelSize: win.u(0.012); color: Qt.rgba(1, 1, 1, 0.55) }
                        }
                        MouseArea { id: qArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { win.level = "queue"; win.qSel = qItem.index; win.dir = 1; Player.play(qItem.modelData.n) } }
                    }
                }
                Text { visible: Player.queue.length === 0; anchors.verticalCenter: qList.verticalCenter; x: Math.round(win.ww * 0.06)
                       text: Player.queueMsg === "Это последний трек в очереди" || !Player.queueMsg ? "Дальше ничего нет" : Player.queueMsg
                       font.family: Theme.fontUi; font.pixelSize: win.u(0.021); color: Qt.rgba(1, 1, 1, 0.5) }
            }

            // ---------- подпись слева сверху (как шапки меню) ----------
            Text {
                anchors.top: parent.top; anchors.left: parent.left
                anchors.topMargin: win.u(0.035) + 6; anchors.leftMargin: win.u(0.04)
                text: "Плеер"; font.family: Theme.fontUi; font.pixelSize: 16; font.weight: Font.DemiBold; color: Qt.rgba(1, 1, 1, 0.9)
            }

            // ---------- сверху справа: стеклянные пилюли ----------
            Row {
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: win.u(0.035); anchors.rightMargin: win.u(0.04)
                spacing: 8
                // сегменты: Текст (L) · Очередь (Q) · Плейлисты (H, добавить в плейлист); повторный щелчок — скрыть панель
                ISeg {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 330; implicitHeight: 36
                    model: ["Текст", "Очередь", "Плейлисты"]
                    current: win.picker ? 2 : win.panel === "lyrics" ? 0 : win.panel === "queue" ? 1 : -1
                    onPicked: (i) => { if (i === 2) win.picker = !win.picker; else { win.picker = false; win.setPanel(i === 0 ? "lyrics" : "queue") } }
                }
                Pill { text: "󰏘  " + (win.bgMode === "cover" ? "Обложка" : "Обои"); onClicked: win.toggleBg() }
                Pill { text: "󰊔"; onClicked: win.minimize() }
                Pill { text: "󰅖"; onClicked: win.close() }
            }

            // ♡ — «Добавить в плейлист» (тот же список, что в острове): карточка под пилюлями
            Rectangle {
                anchors.top: parent.top; anchors.right: parent.right
                anchors.topMargin: win.u(0.035) + 44; anchors.rightMargin: win.u(0.04)
                width: 340; height: 320; radius: Theme.radiusBig            // «Остров»: карточка-остров
                color: Colors.isl
                border.width: 1; border.color: Colors.edge
                opacity: win.picker ? 1 : 0
                scale: win.picker ? 1 : 0.9
                transformOrigin: Item.TopRight
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }
                Loader { anchors.fill: parent; anchors.margins: 16; active: win.picker; sourceComponent: PlaylistPicker { onDone: win.picker = false } }
            }

            // ---------- подсказки клавиш ----------
            // подсказки — капсулы, как CardHints
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: win.u(0.025)
                spacing: 14
                Repeater {
                    model: win.level === "lyrics" ? [["←→", "строка"], ["Enter", "перейти"], ["↓", "к плееру"], ["Esc", "закрыть"]]
                         : win.level === "queue" ? [["←→", "трек"], ["Enter", "включить"], ["↑", "к плееру"], ["Esc", "закрыть"]]
                         : [["←→", "трек"], ["Пробел", "пауза"], ["↑", "текст"], ["↓", "далее"], ["Ctrl ↑↓", "громкость"], ["Esc", "закрыть"]]
                    Row {
                        required property var modelData
                        spacing: 6
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: hk.implicitWidth + 14; height: 20; radius: 7
                            color: Qt.rgba(0, 0, 0, 0.3); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
                            Text { id: hk; anchors.centerIn: parent; text: parent.parent.modelData[0]; font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.Medium; color: "white" }
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: parent.modelData[1]; font.family: Theme.fontUi; font.pixelSize: 12; color: Qt.rgba(1, 1, 1, 0.62) }
                    }
                }
            }
        }
    }

    // ---------- ♡ ----------
    property bool picker: false

    // проверка без клавиатуры (ничего не включает и не переключает треки): уровень и состояние
    IpcHandler {
        target: "fullplayer"
        function level(name: string): void { if (name === "lyrics") { win.level = "cover"; win.goUp() } else if (name === "queue") { win.level = "cover"; win.goDown() } else win.level = "cover" }
        function picker(on: bool): void { win.picker = on }
        function state(): string { return JSON.stringify({ open: win.open, level: win.level, panel: win.panel, bg: win.bgMode, queue: Player.queue.length, lyrics: Player.lyrics.length }) }
    }

    // ---------- выход звука (как в острове) ----------
    property bool devOpen: false
    onVisibleChanged: if (!visible) { devOpen = false; picker = false }
    readonly property string streamSerial: Player.stream ? Sound.serialOf(Player.stream) : ""
    readonly property var streamInfo: streamSerial ? Sound.streamInfo("sink", streamSerial) : null
    readonly property string curSink: streamInfo ? streamInfo.dev : (Sound.defaultSink ? Sound.defaultSink.name : "")
    readonly property var curSinkNode: Sound.nodeByName(Sound.sinks, curSink)
    function pickSink(n) {
        devOpen = false
        if (!n || n.name === curSink) return
        if (streamInfo) Sound.move("sink", streamInfo.index, n.name)
        else Sound.setDefault("sink", n)
    }

    // ---------- части ----------
    // обложка карусели: slide — сдвиг на долю ширины (0 — на месте, ±1 — за краем)
    component CoverImage: Image {
        property string src: ""
        property real slide: 0
        anchors.fill: parent
        source: src
        asynchronous: true
        sourceSize.width: 1024; sourceSize.height: 1024
        fillMode: Image.PreserveAspectCrop
        opacity: status === Image.Ready ? 1 - Math.min(1, Math.abs(slide)) * 0.6 : 0
        transform: Translate { x: slide * (coverBox.width + win.u(0.04)) }
        Behavior on opacity { enabled: slide === 0; NumberAnimation { duration: Theme.normal } }
    }
    // капсула (как IChip): on — заливка акцентом обложки
    component Pill: Rectangle {
        id: pill
        property alias text: pt.text
        property bool on: false
        signal clicked()
        implicitWidth: pt.implicitWidth + 26; implicitHeight: 36; radius: implicitHeight / 2   // implicit: в RowLayout width игнорируется (18.10)
        color: on ? win.acc : Qt.rgba(0, 0, 0, pa.containsMouse ? 0.36 : 0.24)
        scale: pa.pressed ? 0.96 : 1
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        Behavior on scale { NumberAnimation { duration: Theme.fast } }
        Text { id: pt; anchors.centerIn: parent; font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium; color: pill.on ? win.deepTone : "white" }
        MouseArea { id: pa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pill.clicked() }
    }
}
