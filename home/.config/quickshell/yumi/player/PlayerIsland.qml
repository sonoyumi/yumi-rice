import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs
import qs.components
import qs.services
import qs.menus.sound
import qs.island

// «Остров» (29.10): окно плеера вырастает из центрального острова (island/Island.qml): капсула сверху на 6 px за 300 мс
// (лёгкий OutBack) становится карточкой (Colors.isl, radius 26, кромка edge), пока остров уступает ей место (IslandState.playerCard).
// Открывается по бинду SUPER+M (player toggle center) — по центру экрана; player toggle bar — из острова. Закрытие — Esc / клик мимо.
// Карточка — как меню «Острова» (Popup): isl, radius 26, кромка edge, отступ 18; шапка в духе CardHead (обложка 68 radius 16,
// название 16 DemiBold, «исполнитель · источник» 12, справа IButton ♡ и «во весь экран»), прогресс-капсула 8 px акцентом с
// перемоткой, время tnum, IButton назад / играть (primary) / вперёд, громкость ISlider (значок — без звука), выход — IChip,
// «Текст / Очередь» — ISeg, панель — IBox. Пока данные Mpris/бэкенда догружаются — последнее известное, без заглушки.
// Ниже — прежнее описание (размеры карточки уже другие).
// «Остров» плеера: окно по центру под баром, выглядит как продолжение пилюли плеера. При открытии пилюля 30 px
// морфится в карточку 380×176 (width/height/radius; «Тушь» 19.10 — без пружины, OutCubic; пилюля радиуса Theme.pillRadius), обложка растёт 22 → 84 px, появляются название,
// исполнитель, прогресс (клик — перемотка), кнопки 󰒮 󰐊 󰒭 ♡ и переключатель «Текст / Очередь»; под карточкой —
// строки текста песни или очередь yumi-music. Данные — Quickshell.Services.Mpris (services/Player.qml).
// Режимы: «bar» — из пилюли, под баром, закрывается, когда курсор уходит от карточки (700 мс); «center» — по бинду
// (SUPER+M), по центру монитора в фокусе, с клавиатурой, сразу раскрыт с панелью, от курсора НЕ закрывается (как yumi-player --center).
//   qs -c yumi ipc call player toggle bar|center        qs -c yumi ipc call player open center lyrics   (сразу с текстом; «-» = без опции)
//   qs -c yumi ipc call player close                    Menus.toggle("player") — режим bar
//   YUMI_QS_OPEN=player [YUMI_QS_PLAYER_MODE=center] — открыть при старте (проверка)
// Закрывается: Esc, повторный вызов, клик мимо карточки (окно на весь экран, см. ниже);
// в режиме bar — ещё и уход курсора за поле (halo) на farTimer.
// Своё окно, а не components/Popup: у того карточка постоянного размера и радиуса, морф невозможен.
// Закрытие — те же правила, что у Popup: Esc, клик мимо, в режиме bar — уход курсора за поле (halo).
// Сборщику: пилюля плеера → onClick: Menus.toggle("player"); положение острова = центр экрана под баром,
// как у пилюли (anchors.centerIn). Свойства pillW/pillH задают исходную капсулу (ширина пилюли в баре).
PanelWindow {
    id: win
    readonly property bool open: Menus.current === "player"
    property string mode: Quickshell.env("YUMI_QS_PLAYER_MODE") || "bar"   // bar | center
    readonly property bool centered: mode === "center"
    property bool modeSet: Quickshell.env("YUMI_QS_PLAYER_MODE") !== ""   // режим задан явно (show / проверка), иначе при открытии — bar
    readonly property string testScreen: Quickshell.env("YUMI_QS_SCREEN")   // проверка: экран принудительно
    // экран не бывает пустым: null роняет Qt (QWindow::setScreen) при горячей перезагрузке
    screen: (testScreen ? Quickshell.screens.find(s => s.name === testScreen)
          : (centered && Hyprland.focusedMonitor ? Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor.name) : Menus.screen))
          ?? Menus.screen
    property int pillW: slotLH ? Math.min(310, IslandState.room(screen.name, width)) : 310   // капсула = центральный остров в покое
    property int pillH: Theme.pillH
    // «Остров»: из острова — не шире места острова в баре (IslandState.slot), по центру — 380
    readonly property var slotLH: !centered && screen ? IslandState.slot[screen.name] : null
    readonly property int cardW: 380                 // 29.10: окно ниже бара — по центру, ширина не зависит от крыльев
    readonly property int cardH: 256             // обложка 88, прогресс, кнопки, громкость (для центровки по бинду)
    readonly property int paneH: 170
    readonly property int halo: 40            // поле вокруг карточки: клик — закрыть, уход курсора за него — закрыть
    // Закрытие: в режиме center карточка остаётся раскрытой и просто гаснет (scale+opacity), иначе на время
    // closer-таймера мелькала бы капсула; в режиме bar — обратный морф в капсулу под баром (так и задумано).
    readonly property bool closing: !open && closer.running
    readonly property bool keep: centered && closing
    readonly property bool paneOn: (open || keep) && Player.panel !== "off" && Player.shown
    readonly property bool big: open || keep

    visible: open || closer.running
    color: "transparent"
    WlrLayershell.namespace: "yumi-qs-player"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    // Окно на весь экран, клавиатура Exclusive (как у всех меню, см. components/Popup): слой с Exclusive получает в Hyprland
    // весь ввод указателя, и клик мимо поля (field) приходит сюда же — закрыть. Поле — на месте прежнего окна.
    // открыто наведением на остров — без захвата клавиатуры и ввода мимо окна (уход курсора закрывает); закреплено/по бинду — Exclusive
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    readonly property int fieldTop: centered ? Math.round((height - (cardH + paneH + halo)) / 2) : 6 + Theme.devLevel * Theme.barH   // «Остров»: на месте центрального острова
    mask: Region { item: field }
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: win.close() }   // клик мимо поля — закрыть

    IpcHandler {
        target: "player"
        function toggle(mode: string): void { if (win.open && win.mode === mode) win.close(); else win.show(mode, "") }
        function open(mode: string, opt: string): void { win.show(mode, opt) }
        function close(): void { win.close() }
        function playpause(): void { Player.togglePlaying() }   // 30.10: бинды/наушники (yumi-play-pause) — игрока нет → последний трек с места
        function full(): void { Player.fullOpen = !Player.fullOpen; if (Player.fullOpen) win.close() }   // полноэкранный (player/FullPlayer.qml)
    }
    function show(m, opt) {
        mode = m === "center" ? "center" : "bar"; modeSet = true
        if (opt === "lyrics" || opt === "--lyrics") Player.setPanel("lyrics")
        Menus.open("player")
    }
    function close() { Menus.close("player") }
    Connections { target: Player; function onShowIsland(m) { win.show(m, "") } }
    function openFull() { Player.fullOpen = true; close() }   // как yumi-player open_fullscreen: остров закрывается
    Timer { id: closer; interval: 320 }
    // пока карточка раскрыта из острова (и пока сворачивается обратно) — остров её не дублирует
    Binding { target: IslandState; property: "playerCard"; value: (win.open || closer.running) && !win.centered }
    onOpenChanged: {
        Player.watching = open
        Sound.islandActive = open
        if (!open) devOpen = false
        if (open) { if (!modeSet) mode = "bar"; modeSet = false; picker = false; remember(); if (Player.panel === "queue") Player.requestQueue() }
        else closer.start()
    }
    // ---------- выход звука: чип рядом с громкостью, список выходов раскрывается под строкой ----------
    property bool devOpen: Quickshell.env("YUMI_QS_DEVLIST") === "1"   // проверка: список выходов открыт сразу
    readonly property int devRowH: 34
    readonly property int devH: devOpen ? Sound.sinks.length * (devRowH + 2) + 8 : 0
    readonly property string streamSerial: Player.stream ? Sound.serialOf(Player.stream) : ""
    readonly property var streamInfo: streamSerial ? Sound.streamInfo("sink", streamSerial) : null
    readonly property string curSink: streamInfo ? streamInfo.dev : (Sound.defaultSink ? Sound.defaultSink.name : "")
    readonly property var curSinkNode: Sound.nodeByName(Sound.sinks, curSink)
    function pickSink(n) {
        devOpen = false
        if (!n || n.name === curSink) return
        if (streamInfo) Sound.move("sink", streamInfo.index, n.name)       // перенос потока этого плеера (pactl move-sink-input)
        else Sound.setDefault("sink", n)                                     // поток не найден — системный выход
    }
    Connections { target: Sound; function onToast(t, e) { win.toastText = t; toastTimer.restart() } }
    property bool picker: false               // ♡ — выбор плейлиста на месте панели
    property string toastText: ""
    Timer { id: toastTimer; interval: 3000; onTriggered: win.toastText = "" }
    Connections { target: Player; function onToast(t, e) { win.toastText = t; toastTimer.restart() } }

    // поле вокруг карточки: ввод принимается только здесь (mask), клик мимо карточки — закрыть
    Item {
        id: field
        // с бара — под пилюлей плеера (бар сдвигает её, если мешают соседи), по центру — по центру экрана
        // «Остров»: как центральный остров — по центру экрана, если влезает в его место в баре, иначе внутри места
        readonly property real cx: -1        // 29.10: всегда по центру экрана, как центральный остров
        x: cx < 0 ? Math.round((parent.width - width) / 2)
                  : Math.round(Math.max(0, Math.min(cx - width / 2, parent.width - width)))
        y: win.fieldTop
        width: win.cardW + win.halo * 2
        height: card.height + win.halo
        MouseArea { anchors.fill: parent; onClicked: win.close() }

        FocusScope {
            anchors.fill: parent
            focus: win.open            // снять фокус до уничтожения (segfault в clearFocusInScope)
            Keys.onEscapePressed: { if (win.picker) win.picker = false; else win.close() }
            Keys.onPressed: (e) => {
                // буквы — по физической клавише (код xkb = evdev + 8), чтобы работали и в русской раскладке: F=41, L=46, Q=24
                const sc = e.nativeScanCode
                const isF = e.key === Qt.Key_F || sc === 41, isL = e.key === Qt.Key_L || sc === 46, isQ = e.key === Qt.Key_Q || sc === 24
                if (isF) { win.openFull(); e.accepted = true; return }
                if (isL) { Player.setPanel(Player.panel === "lyrics" ? "off" : "lyrics"); e.accepted = true; return }
                if (isQ) { Player.setPanel(Player.panel === "queue" ? "off" : "queue"); e.accepted = true; return }
                if (e.key === Qt.Key_Space) { Player.togglePlaying(); e.accepted = true }
                else if (e.key === Qt.Key_L) { Player.setPanel(Player.panel === "lyrics" ? "off" : "lyrics"); e.accepted = true }
                else if (e.key === Qt.Key_Q) { Player.setPanel(Player.panel === "queue" ? "off" : "queue"); e.accepted = true }
                else if (e.key === Qt.Key_F) { win.openFull(); e.accepted = true }
                else if (e.key === Qt.Key_Left) { Player.previous(); e.accepted = true }      // ←/→ — трек (перемотка — мышью)
                else if (e.key === Qt.Key_Right) { Player.next(); e.accepted = true }
                else if (e.key === Qt.Key_Up || e.key === Qt.Key_Down) { win.setVol(volSlider.value + (e.key === Qt.Key_Up ? 0.05 : -0.05)); e.accepted = true }
            }

            // ---------- карточка: как меню «Острова» (Popup) — капсула острова → карточка ----------
            Rectangle {
                id: card
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0
                width: win.big ? win.cardW : win.pillW
                height: win.big ? Math.ceil(content.implicitHeight) + 36 : win.pillH
                radius: win.big ? Theme.radiusBig : win.pillH / 2
                clip: true
                Behavior on width  { enabled: !win.centered; NumberAnimation { duration: win.big ? 300 : 200; easing.type: win.big ? Easing.OutBack : Easing.InCubic; easing.overshoot: 0.8 } }
                Behavior on height { NumberAnimation { duration: win.big ? 300 : 200; easing.type: win.big ? Easing.OutBack : Easing.InCubic; easing.overshoot: 0.8 } }
                Behavior on radius { enabled: !win.centered; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                scale: win.open || !win.centered ? 1 : 0.9
                transformOrigin: Item.Center
                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
                color: Colors.isl
                Behavior on color { ColorAnimation { duration: Theme.normal } }
                border.width: 1; border.color: Colors.edge
                opacity: win.open || (!win.centered && closer.running) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: win.open ? 120 : 200; easing.type: Easing.InCubic } }
                MouseArea { anchors.fill: parent; z: -1 }       // клики по карточке — не «мимо»

                // закрытое состояние (сворачивание в остров): обложка-кружок и «Название — Артист»
                Row {
                    x: 5; anchors.verticalCenter: parent.verticalCenter; spacing: 9
                    visible: opacity > 0
                    opacity: win.big ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                    ClippingRectangle { width: 20; height: 20; radius: 10; color: Colors.isl2
                        Image { anchors.fill: parent; source: win.tArt; sourceSize.width: 48; sourceSize.height: 48; fillMode: Image.PreserveAspectCrop; asynchronous: true } }
                    Text { width: card.width - 46; anchors.verticalCenter: parent.verticalCenter
                           text: win.tTitle + (win.tArtist ? " — " + win.tArtist : "")
                           font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium; color: Colors.fg; elide: Text.ElideRight }
                }

                // содержимое — сразу, в полной ширине карточки (не перестраивается при росте); отступ 18, как у меню
                ColumnLayout {
                    id: content
                    x: 18; y: 18
                    width: win.cardW - 36
                    spacing: 14
                    visible: opacity > 0
                    opacity: win.big ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: win.big ? 140 : Theme.fast } }

                    // шапка (как CardHead): обложка 68 · название 16 DemiBold · «исполнитель · источник» 12 · справа ♡ и «во весь экран»
                    RowLayout {
                        Layout.fillWidth: true; spacing: 12
                        ClippingRectangle {
                            Layout.preferredWidth: 68; Layout.preferredHeight: 68
                            radius: 16; color: Colors.isl2
                            Image { id: cover; anchors.fill: parent; source: win.tArt; sourceSize.width: 136; sourceSize.height: 136
                                    fillMode: Image.PreserveAspectCrop; asynchronous: true; opacity: status === Image.Ready ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: Theme.normal } } }
                            Glyph { anchors.centerIn: parent; visible: cover.status !== Image.Ready; text: "󰝚"; font.pixelSize: 26; color: Colors.acc }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; Layout.preferredWidth: 0; Layout.alignment: Qt.AlignVCenter
                            spacing: 3
                            Text { Layout.fillWidth: true; text: win.tTitle; font.family: Theme.fontUi; font.pixelSize: 16; font.weight: Font.DemiBold
                                   color: Colors.fg; elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap; lineHeight: 0.95 }
                            Text {   // исполнитель · источник; тост — акцентом на его месте
                                Layout.fillWidth: true
                                text: win.toastText ? win.toastText : win.tSub
                                font.family: Theme.fontUi; font.pixelSize: 12; color: win.toastText ? Colors.acc : Colors.fgDim; elide: Text.ElideRight
                                Behavior on color { ColorAnimation { duration: Theme.fast } }
                            }
                        }
                        IButton { icon: win.picker ? "󰋑" : "󰋕"; implicitWidth: 32; implicitHeight: 32; kb: win.picker
                                  enabledLook: Player.has; Layout.alignment: Qt.AlignTop
                                  onClicked: if (Player.has) win.picker = !win.picker }                 // в плейлист yumi-music
                        IButton { icon: "󰊓"; implicitWidth: 32; implicitHeight: 32; enabledLook: Player.shown; Layout.alignment: Qt.AlignTop
                                  onClicked: if (Player.shown) win.openFull() }                         // во весь экран (F)
                    }

                    // источник (30.10): игроков больше одного — чипы, выбранный закрепляется (Player.choose)
                    Flow {
                        Layout.fillWidth: true; spacing: 6
                        visible: Player.players.length > 1
                        Repeater {
                            model: Player.players
                            IChip { required property var modelData
                                    text: Player.nameOf(modelData) + (modelData.isPlaying ? "  󰐊" : "")
                                    on: Player.player === modelData
                                    onClicked: Player.choose(modelData) }
                        }
                    }

                    // прогресс: капсула 8 px акцентом (клик/перетаскивание — перемотка), время tnum 11
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 5
                        Item {
                            Layout.fillWidth: true; Layout.preferredHeight: 14
                            readonly property real frac: Player.length > 0 ? Math.max(0, Math.min(1, (progArea.pressed ? progArea.dragT : win.pos) / Player.length)) : 0
                            Rectangle { id: progTrack; anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 8; radius: 4
                                        color: Colors.isl2 }
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; height: 8; radius: 4; color: Colors.acc
                                        width: Math.max(8, progTrack.width * parent.frac)
                                        Behavior on width { enabled: !progArea.pressed; NumberAnimation { duration: 250; easing.type: Easing.Linear } } }
                            MouseArea {
                                id: progArea; anchors.fill: parent; hoverEnabled: true; enabled: Player.length > 0; preventStealing: true
                                cursorShape: Qt.PointingHandCursor
                                property real dragT: 0
                                function at(x) { return Player.length * Math.max(0, Math.min(1, x / width)) }
                                onPressed: (e) => dragT = at(e.x)
                                onPositionChanged: (e) => { if (pressed) dragT = at(e.x) }
                                onReleased: (e) => Player.seek(at(e.x))
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: Player.length > 0 ? win.fmt(win.pos) : "-:--"; font.family: Theme.fontUi; font.pixelSize: 11
                                   font.features: ({ "tnum": 1 }); color: Colors.fgDim }
                            Item { Layout.fillWidth: true }
                            Text { text: Player.length > 0 ? win.fmt(Player.length) : "-:--"; font.family: Theme.fontUi; font.pixelSize: 11
                                   font.features: ({ "tnum": 1 }); color: Colors.fgDim }
                        }
                    }

                    // управление: назад · играть (primary) · вперёд
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter; spacing: 10
                        IButton { icon: "󰒮"; implicitWidth: 52; enabledLook: Player.has && Player.player.canGoPrevious
                                  onClicked: if (enabledLook) Player.previous() }
                        IButton { primary: true; implicitWidth: 72
                                  icon: Player.stopped && !Player.canResume ? "󰏌" : (Player.playing ? "󰏤" : "󰐊"); enabledLook: Player.shown
                                  onClicked: Player.togglePlaying() }
                        IButton { icon: "󰒭"; implicitWidth: 52; enabledLook: Player.has && Player.player.canGoNext
                                  onClicked: if (enabledLook) Player.next() }
                    }

                    // громкость потока этого плеера (не вся система, если поток найден): ISlider; значок внутри — без звука
                    ISlider {
                        id: volSlider
                        icon: Player.muted || Player.volume <= 0 ? "󰝟" : (Player.volume < 0.5 ? "󰖀" : "󰕾")
                        value: volT.running ? volT.v : (Player.muted ? 0 : Player.volume)
                        onMoved: (v) => win.setVol(v)
                        MouseArea {   // значок внутри капсулы — без звука (как кнопка прежнего ползунка)
                            x: 0; y: 0; width: 32; height: 26; cursorShape: Qt.PointingHandCursor
                            onClicked: Player.toggleMute()
                        }
                    }
                    // выход звука: чип, клик раскрывает список выходов
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        IChip {
                            on: win.devOpen
                            text: (win.curSinkNode ? Sound.devIcon("sink", win.curSinkNode) + "  " : "󰓃  ")
                                  + (win.streamInfo ? win.streamInfo.dev_short : (win.curSinkNode ? Sound.devName("sink", win.curSinkNode) : "Выход")) + (win.devOpen ? "  󰅃" : "  󰅀")
                            onClicked: win.devOpen = !win.devOpen
                        }
                        Item { Layout.fillWidth: true }
                        Text { text: win.streamInfo ? "только этот плеер" : "вся система"; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim }
                    }
                    Column {
                        Layout.fillWidth: true
                        spacing: 2
                        visible: win.devOpen
                        Repeater {
                            model: win.devOpen ? Sound.sinks : []
                            delegate: RowButton {
                                id: devRow
                                required property var modelData
                                required property int index
                                width: parent.width; implicitHeight: win.devRowH
                                icon: Sound.devIcon("sink", modelData); text: Sound.devName("sink", modelData)
                                active: modelData.name === win.curSink
                                onClicked: win.pickSink(modelData)
                                opacity: 0                                       // каскад 40 мс
                                Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                                Timer { interval: 40 * devRow.index; running: true; onTriggered: devRow.opacity = 1 }
                            }
                        }
                    }

                    // «Текст / Очередь» (повторный выбор — выключить панель); под ним — панель IBox
                    ISeg {
                        Layout.fillWidth: true; implicitHeight: 34
                        model: ["Текст", "Очередь"]
                        current: Player.panel === "lyrics" ? 0 : Player.panel === "queue" ? 1 : -1
                        onPicked: (i) => {
                            const v = i === 0 ? "lyrics" : "queue"
                            Player.setPanel(Player.panel === v ? "off" : v)
                            if (Player.panel === "queue") Player.requestQueue()
                        }
                    }
                    IBox {
                        visible: win.paneOn || win.picker
                        pad: 14
                        Item {
                            Layout.fillWidth: true; Layout.preferredHeight: win.paneH
                            LyricsPane { anchors.fill: parent; visible: !win.picker && Player.panel === "lyrics"; running: visible && win.open }
                            QueuePane  { anchors.fill: parent; visible: !win.picker && Player.panel === "queue"; running: visible && win.open }
                            Loader { anchors.fill: parent; active: win.picker; sourceComponent: PlaylistPicker { onDone: win.picker = false } }
                        }
                    }
                }
            }
        }
    }

    // громкость: не чаще раза в 90 мс в PipeWire; ползунок держит своё значение ещё 1 с (как прежний VolumeSlider)
    Timer { id: volT; property real v: 0; interval: 1000 }
    Timer { id: volSend; interval: 90; onTriggered: Player.setVolume(volT.v) }
    function setVol(v) { v = Math.max(0, Math.min(1, v)); volT.v = v; volT.restart(); if (!volSend.running) volSend.start() }

    // «последнее известное»: пока Mpris/бэкенд догружаются (игрок на миг пропадает при открытии/смене трека),
    // показываем прежние название/обложку; заглушка «Тишина» — только если ничего нет дольше 1,2 с
    property string lastTitle: ""
    property string lastArtist: ""
    property string lastArt: ""
    property string lastSource: ""
    function remember() { if (Player.shown) { lastTitle = Player.title; lastArtist = Player.artist; lastSource = Player.source; if (IslandState.art) lastArt = IslandState.art } }
    Connections { target: Player
        function onTitleChanged() { win.remember() }
        function onArtistChanged() { win.remember() }
        function onShownChanged() { if (Player.shown) { quietT.stop(); win.quiet = false; win.remember() } else quietT.restart() } }
    Connections { target: IslandState; function onArtChanged() { win.remember() } }
    Component.onCompleted: { remember(); if (!Player.shown) quietT.start() }
    property bool quiet: !Player.shown && lastTitle === ""
    Timer { id: quietT; interval: 1200; onTriggered: win.quiet = !Player.shown }
    readonly property bool showLast: !Player.shown && !quiet && lastTitle !== ""
    readonly property string tTitle: Player.shown ? Player.title : (showLast ? lastTitle : "Ничего не играет")
    readonly property string tArtist: Player.shown ? Player.artist : (showLast ? lastArtist : "")
    readonly property string tArt: IslandState.art || (showLast ? lastArt : "")
    // подзаголовок шапки: «исполнитель · источник» (источник без значка), пусто — статус
    readonly property string srcName: (Player.shown ? Player.source : lastSource).replace(/^[^\p{L}\p{N}]+/u, "")
    readonly property string tSub: (Player.shown || showLast) ? [tArtist, srcName].filter(x => x).join("  ·  ")
                                 : "Тишина"

    // позиция для отрисовки: раз в 500 мс (как опрос MPRIS), полоса доезжает линейно за те же 500 мс
    readonly property real pos: Player.posSec          // 29.10: общее время (как остров и «Музыка»)
    function fmt(s) { s = Math.max(0, Math.floor(s)); const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), r = s % 60
                      return h ? h + ":" + String(m).padStart(2, "0") + ":" + String(r).padStart(2, "0") : m + ":" + String(r).padStart(2, "0") }
}
