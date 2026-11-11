import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import qs
import qs.components
import qs.services
import qs.osd
import qs.bar.modules

// «Остров» (29.10): центральный остров сверху (top 6, Colors.isl, тень) — по окну на экран. Состояния (#isl в превью):
//   idle    380×30  круглая обложка 20, «Название — исполнитель», время «0:41/3:38», эквалайзер (Cava)
//   player  470×150 наведение: обложка 96, название, исполнитель · источник, прогресс с перемоткой, время,
//                   перемешать / назад / пауза / вперёд / текст
//   notif   450×96  уведомление (значок, приложение, заголовок, текст, кнопка действия / «Ответить»); crit — красная кромка
//   reply   450×150 быстрый ответ: поле ввода и «Отправить»
//   osd     340×48  громкость/яркость: значок, полоса акцентом, %
//   msg     270×30  раскладка, «не спать», Caps Lock
// Ширина/высота/радиус — пружина 550 мс (OutBack), содержимое проявляется после роста (opacity+scale, задержка 120 мс).
// Левый клик по острову ничего не открывает (окно плеера — только SUPER+M), колесо — перемотка ±5 с,
// средний — пауза, правый — следующий трек. Уведомления/OSD — на экране с фокусом; idle скрыт в полноэкранном режиме
// и когда бар спрятан. Очередь уведомлений и OSD — island/IslandState.qml.
// Слой Overlay, своё пространство имён yumi-island (без размытия Hyprland: у острова мягкая тень), ввод — только остров (mask).
Variants {
    property var screens: Quickshell.screens
    model: screens
    delegate: PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        readonly property string sn: modelData.name
        readonly property var mon: Hyprland.monitors.values.find(m => m.name === win.sn) || null
        readonly property bool fullscreen: !!IslandState.trueFs[sn]     // 29.10: только режим 2 (бар закрыт); «развернуть» (1) — остров виден

        anchors { top: true; left: true; right: true }
        margins.top: Theme.devLevel * Theme.barH
        implicitHeight: 230
        color: "transparent"
        WlrLayershell.namespace: "yumi-island"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: mode === "reply" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        mask: Region { item: isl.visible && isl.opacity > 0.05 ? isl : null
            Region { item: bubR.on ? bubR : null; intersection: Intersection.Combine }
            Region { item: bubL.on ? bubL : null; intersection: Intersection.Combine }
            Region { item: bubN.on ? bubN : null; intersection: Intersection.Combine } }
        visible: Signals.lazyReady && !Signals.bootHold

        // ---------- состояние ----------
        readonly property var e: IslandState.cur
        readonly property bool mineN: !!e && IslandState.notifScreen === sn
        readonly property bool mineO: IslandState.osdOn && IslandState.osdScreen === sn
        readonly property bool idleOk: Signals.barVisible && !fullscreen && !IslandState.playerCard && Signals.wallHide !== sn   // 30.10: и не во время выбора обоев   // 29.10: виден всегда, пока виден бар (без музыки — тоже)
        property bool hoverOpen: false
        // 30.10: пузыри (показ новой активности, системные, сводка) и активности — island/IslandState.qml
        readonly property var al: IslandState.alert
        readonly property bool mineA: !!al && al.screen === sn
        readonly property string alMode: !al ? "" : al.kind === "intro" ? (IslandState.acts[al.data.id] ? "actx" : "") : al.kind
        readonly property var mainA: IslandState.main
        readonly property bool mainCustom: !!mainA && !mainA.music
        // раскрытая активность: показ новой (intro) — она, иначе главная
        readonly property var xa: mineA && al.kind === "intro" ? (IslandState.acts[al.data.id] || null) : (mainCustom ? mainA : null)
        readonly property string mode: {
            const f = IslandState.force
            if (f) return f
            if (mineO) return IslandState.osdMsg ? "msg" : "osd"                      // отклик на действие — всегда
            if (mineA && al.urgent && alMode) return alMode                           // срочное — поверх баннера
            if (mineN) return IslandState.replyOpen ? "reply" : (IslandState.critical ? "crit" : "notif")
            if (mineA && alMode) return alMode
            if (!idleOk) return "none"                                                // полноэкранный / бар спрятан
            if (hoverOpen) return mainCustom ? "actx" : "player"
            return mainCustom ? "act" : "idle"
        }
        readonly property bool compact: mode === "idle" || mode === "act"
        // 30.10: круг виден и в раскрытом по наведению виде — колесо листает главную/круг, видно что листать
        readonly property bool hasR: (compact || mode === "actx" || mode === "player") && !!IslandState.second
        readonly property bool hasL: mode !== "none" && IslandState.summary.length > 0 && !fullscreen
        readonly property int bub: hasR || hasL ? 76 : 0          // круги по бокам: остров в покое уже на их место
        readonly property string msgLabel: IslandState.msgText || OsdState.label
        readonly property var dims: ({
            none:   [140, 30, 15], idle: [380, 30, 15], player: [470, 150, 34],
            notif:  [450, 96, 32], crit: [450, 96, 32], reply: [450, 150, 32],
            osd:    [340, 48, 24], msg: [Math.max(270, msgRow.implicitWidth + 48), 30, 15],
            act:    [mainA && mainA.progress >= 0 ? 380 : 360, 30, 15], actx: [450, 124, 32],
            pill:   [al && al.data && al.data.w ? al.data.w : 280, 36, 18], banner: [450, 84, 30], airpods: [420, 110, 36],
            summary: [480, al && al.kind === "summary" ? Math.min(4, al.data.items.length) * 28 + 100 : 150, 34]
        })
        readonly property var d: dims[mode] || dims.idle
        // место в потоке бара: остров не наезжает на соседние острова (бар спрятан / полный экран — просто по центру)
        readonly property bool inBar: Signals.barVisible && !fullscreen
        readonly property var pl: IslandState.place(sn, win.width, d[0], inBar && d[1] <= 30, bub)   // в строке бара — между крыльями
        // ширина острова в состоянии name — слои содержимого стоят в ней сразу и не перестраиваются, пока остров растёт
        function stW(name) { const dd = dims[name] || dims.idle; return IslandState.place(sn, win.width, dd[0], inBar && dd[1] <= 30, bub)[1] }

        // наведение: idle → плеер (уход — через 350 мс); на уведомлении — держать
        Timer { id: unhover; interval: 350; onTriggered: win.hoverOpen = false }
        function onHover(h) {
            if (h) { unhover.stop(); if (mode === "idle" || mode === "act") hoverOpen = true }
            else if (hoverOpen) unhover.restart()
            if (mineN) IslandState.setHold(h)
            if (mineA) IslandState.alertHold = h          // курсор держит пузырь (кроме показа новой активности)
        }
        onModeChanged: {
            if (["player", "idle", "act", "actx"].indexOf(mode) < 0) hoverOpen = false
            if (IslandState.logOn && sn === IslandState.focusedName()) IslandState.log("на экране " + sn + " — " + mode + whyMode())
        }
        function whyMode() {
            if (IslandState.force) return " (принудительно)"
            if (mode === "none") return fullscreen ? ": полноэкранное окно — скрыт вместе с баром" : ": бар спрятан"
            if (mode === "act") return ": главная «" + mainA.title + "» (уровень " + mainA.priority + ")" + (IslandState.second ? ", вторая — круг рядом" : "")
            if (mode === "idle") return Player.playing ? ": музыка — главная" : ": покой" + (Player.shown ? " (музыка на паузе — «Продолжить»)" : "")
            return ""
        }
        // отскок и «вдох» (только на экране, где виден остров)
        property real kv: 1
        SequentialAnimation { id: kickA; property real p: 1
            NumberAnimation { target: win; property: "kv"; to: 1 + 0.04 * kickA.p; duration: 90; easing.type: Easing.OutQuad }
            NumberAnimation { target: win; property: "kv"; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
        Connections {
            target: IslandState
            function onKicked(p) { if (win.mode !== "none" && win.visible) { kickA.stop(); kickA.p = Math.min(1.6, p); kickA.start() } }
            function onBreathed() { if (win.sn === IslandState.focusedName()) { breathA.stop(); breathA.start() } }
        }

        // позиция трека, пока раскрыт плеер (Player сам опрашивает только для окна плеера/экрана блокировки)
        // 29.10: время — общее Player.posSec (один такт с меню «Музыка»; раньше свёрнутый остров считал по часам и спешил на ~3 с)
        readonly property real pos: Player.posSec
        function fmt(s) { s = Math.max(0, Math.floor(s)); const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), r = s % 60
                          return h ? h + ":" + String(m).padStart(2, "0") + ":" + String(r).padStart(2, "0") : m + ":" + String(r).padStart(2, "0") }
        function seekBy(sec) {
            if (IslandState.dry) { console.log("[dry-run] плеер: перемотка", sec); return }
            Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/yumi-player-seek", String(sec)])
        }
        // кнопка «Текст песни» в раскрытом острове — окно плеера по центру, как SUPER+M, сразу с текстом
        function openPlayer(lyrics) {
            if (lyrics) Player.setPanel("lyrics")
            hoverOpen = false
            Player.showIsland("center")
        }

        // ---------- сам остров ----------
        RectangularShadow {
            anchors.fill: isl
            offset.y: 10; radius: isl.radius; blur: 30; spread: 0
            color: Qt.rgba(0, 0, 0, 0.35)
            opacity: isl.opacity
        }
        Rectangle {
            id: isl
            x: win.pl[0]; y: 6
            width: win.pl[1]; height: win.d[1]; radius: win.d[2]
            Behavior on x      { NumberAnimation { duration: Theme.springMs; easing.type: Easing.OutBack; easing.overshoot: 1.25 } }
            Behavior on width  { NumberAnimation { duration: Theme.springMs; easing.type: Easing.OutBack; easing.overshoot: 1.25 } }
            Behavior on height { NumberAnimation { duration: Theme.springMs; easing.type: Easing.OutBack; easing.overshoot: 1.25 } }
            Behavior on radius { NumberAnimation { duration: Theme.springMs; easing.type: Easing.OutBack; easing.overshoot: 1.25 } }
            color: Colors.isl
            Behavior on color { ColorAnimation { duration: Theme.normal } }
            clip: true
            opacity: win.mode === "none" ? 0 : 1
            scale: win.mode === "none" ? 0.85 : 1
            transformOrigin: Item.Top
            transform: Scale { origin.x: isl.width / 2; origin.y: 0; xScale: win.kv; yScale: win.kv }   // отскок при обновлении
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Theme.springMs; easing.type: Easing.OutBack } }
            visible: opacity > 0.01

            HoverHandler { id: hov; onHoveredChanged: win.onHover(hovered) }
            MouseArea {   // фон острова: клики по плееру; уведомление — действие «по умолчанию»
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (ev) => {
                    const m = win.mode, L = ev.button === Qt.LeftButton, M = ev.button === Qt.MiddleButton, Rb = ev.button === Qt.RightButton
                    if (m === "idle" || m === "player") {
                        // левый клик окно плеера не открывает (оно — только по SUPER+M); раскрытие — наведением
                        if (M) { if (win.mainA && win.mainA.music) IslandState.primaryOf(win.mainA); else Player.togglePlaying() }
                        else if (Rb) Player.next()
                    } else if (m === "act" || m === "actx") {
                        const a = m === "actx" ? win.xa : win.mainA
                        if (L) { IslandState.openOf(a); if (win.mineA && win.al.kind === "intro") IslandState.endAlert("клик") }
                        else if (M) IslandState.primaryOf(a)
                        else IslandState.hideMain()                                 // правый — скрыть до изменения
                    } else if ((m === "notif" || m === "crit") && L) IslandState.activate()
                    else if ((m === "notif" || m === "crit") && Rb) IslandState.dismiss()
                    else if (["pill", "banner", "airpods"].indexOf(m) >= 0 && (Rb || (L && win.al && win.al.dur > 0))) IslandState.endAlert("клик")
                    else if (m === "summary" && Rb) IslandState.endAlert("клик")
                }
                // колесо: две активности и больше — поменять главную и круг; иначе (музыка) — перемотка ±5 с
                onWheel: (w) => {
                    if (!win.compact && win.mode !== "player" && win.mode !== "actx") return
                    if (IslandState.ranked.length > 1) IslandState.swapMain()
                    else if (win.mode === "idle" || win.mode === "player") win.seekBy(w.angleDelta.y > 0 ? 5 : -5)
                }
            }

            // ===== idle =====
            Layer {
                st: "idle"; on: win.mode === "idle"
                // 30.10: покой (IslandState.rest — минута без музыки или трека нет): погода · дата · что дальше
                RowLayout {
                    id: restRow
                    anchors.fill: parent; anchors.leftMargin: 13; anchors.rightMargin: 13
                    spacing: 6
                    opacity: IslandState.rest ? 1 : 0; visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    readonly property var w: IslandState.restData.weather || null
                    readonly property var nx: IslandState.restData.next || null
                    property date now: new Date()
                    Timer { interval: 30000; repeat: true; running: restRow.visible; triggeredOnStart: true; onTriggered: restRow.now = new Date() }
                    Glyph { visible: !!restRow.w; text: restRow.w ? restRow.w.icon : ""; font.pixelSize: 15; color: Colors.acc }
                    Text {
                        visible: !!restRow.w
                        text: restRow.w ? restRow.w.t + "°" : ""
                        font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.DemiBold; font.features: ({ "tnum": 1 }); color: Colors.fg
                    }
                    Text { visible: !!restRow.w; text: "·"; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim }
                    Text {
                        Layout.fillWidth: !restRow.nx
                        text: { const s = Qt.locale("ru_RU").toString(restRow.now, "ddd, d MMMM"); return s.charAt(0).toUpperCase() + s.slice(1) }
                        font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium; color: Colors.fg
                    }
                    Item { visible: !!restRow.nx; Layout.preferredWidth: 4 }
                    Glyph { visible: !!restRow.nx; text: restRow.nx ? restRow.nx.icon : ""; font.pixelSize: 14; color: Colors.fgDim }
                    Text {
                        visible: !!restRow.nx
                        Layout.fillWidth: true; Layout.minimumWidth: 0
                        text: restRow.nx ? restRow.nx.text : ""
                        font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fg; elide: Text.ElideRight; maximumLineCount: 1
                    }
                    Text {                                    // когда — не обрезается
                        visible: !!restRow.nx
                        text: restRow.nx ? restRow.nx.when : ""
                        font.family: Theme.fontUi; font.pixelSize: 12; font.features: ({ "tnum": 1 }); color: Colors.fgDim
                    }
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 5; anchors.rightMargin: 12
                    spacing: 9
                    opacity: IslandState.rest ? 0 : 1; visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    Cover { size: 20; rad: 10 }
                    Text {
                        Layout.fillWidth: true
                        textFormat: Text.StyledText
                        text: (Player.shown && !Player.playing ? "<font color=\"" + Colors.fgDim + "\">Продолжить:</font> " : "")   // на паузе — покой «Продолжить»
                              + win.esc(Player.title) + (Player.artist ? " <font color=\"" + Colors.fgDim + "\">— " + win.esc(Player.artist) + "</font>" : "")
                        font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium
                        color: Colors.fg; elide: Text.ElideRight; maximumLineCount: 1
                        opacity: Player.playing ? 1 : 0.7
                    }
                    Text {                                    // время трека: прошло / всего (ширина по самой длинной строке — без прыжков)
                        visible: Player.length > 0
                        text: win.fmt(win.pos) + "/" + win.fmt(Player.length)
                        Layout.minimumWidth: Math.ceil(tw.advanceWidth) + 1
                        horizontalAlignment: Text.AlignRight
                        font.family: Theme.fontUi; font.pixelSize: 11; font.features: ({ "tnum": 1 }); color: Colors.fgDim
                        TextMetrics { id: tw; font.family: Theme.fontUi; font.pixelSize: 11; text: win.fmt(Player.length) + "/" + win.fmt(Player.length) }
                    }
                    Eq { bars: 4; bw: 2.5; gap: 2; eh: 12; rad: 1.25; playing: Player.playing && win.mode !== "none" && win.visible   // cava — пока остров виден (без перезапуска при наведении); кадры — только пока виден сам эквалайзер
                         sink: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.name : "" }
                }
            }

            // ===== player =====
            Layer {
                st: "player"; on: win.mode === "player"
                RowLayout {
                    // тесно (место в баре уже 420) — обложка 72 и поля 18; совсем тесно (< 340) — без обложки:
                    // ничто не шире острова (иначе край содержимого торчит за скруглением при раскрытии)
                    readonly property real w: win.stW("player")
                    readonly property bool narrow: w < 420
                    readonly property bool tiny: w < 340
                    anchors.fill: parent; anchors.margins: 18; anchors.leftMargin: narrow ? 18 : 22; anchors.rightMargin: narrow ? 18 : 22
                    spacing: narrow ? 14 : 16
                    Cover { visible: !parent.tiny; size: parent.narrow ? 72 : 96; rad: parent.narrow ? 16 : 20; Layout.alignment: Qt.AlignVCenter }
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                        Layout.minimumWidth: 0; Layout.preferredWidth: 0     // берёт остаток ширины, а не ширину названия
                        spacing: 3
                        Text { Layout.fillWidth: true; text: Player.title; font.family: Theme.fontUi; font.pixelSize: 16; font.weight: Font.DemiBold
                               color: Colors.fg; elide: Text.ElideRight }
                        Text { Layout.fillWidth: true; text: [Player.artist, Player.source.replace(/^[^\p{L}\p{N}]+/u, "")].filter(x => x).join("  ·  ")
                               font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim; elide: Text.ElideRight }
                        Item {   // прогресс: клик/перетаскивание — перемотка
                            Layout.fillWidth: true; Layout.preferredHeight: 14; Layout.topMargin: 4
                            readonly property real frac: Player.length > 0 ? Math.max(0, Math.min(1, (pa.pressed ? pa.dragX : win.pos) / Player.length)) : 0
                            Rectangle { id: track; anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; radius: 2
                                        color: Colors.alpha(Colors.fg, 0.16) }
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; height: 4; radius: 2; color: Colors.acc
                                        width: Math.max(4, track.width * parent.frac)
                                        Behavior on width { enabled: !pa.pressed; NumberAnimation { duration: 500 } } }
                            Rectangle { width: 10; height: 10; radius: 5; color: Colors.fg; anchors.verticalCenter: parent.verticalCenter
                                        x: track.width * parent.frac - 5; scale: pa.containsMouse || pa.pressed ? 1.2 : 1
                                        Behavior on x { enabled: !pa.pressed; NumberAnimation { duration: 500 } }
                                        Behavior on scale { NumberAnimation { duration: Theme.fast } } }
                            MouseArea {
                                id: pa; anchors.fill: parent; hoverEnabled: true; enabled: Player.length > 0
                                property real dragX: 0
                                function at(x) { return Player.length * Math.max(0, Math.min(1, x / width)) }
                                onPressed: (m) => dragX = at(m.x)
                                onPositionChanged: (m) => { if (pressed) dragX = at(m.x) }
                                onReleased: (m) => { const t = at(m.x); if (IslandState.dry) console.log("[dry-run] плеер: перемотка на", Math.round(t)); else Player.seek(t) }
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
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 8
                            Cb { icon: "󰒟"; tip: "Перемешать"; on: Player.has && Player.player.shuffleSupported && Player.player.shuffle
                                 onClicked: { if (IslandState.dry) console.log("[dry-run] плеер: перемешать"); else if (Player.has && Player.player.shuffleSupported) Player.player.shuffle = !Player.player.shuffle } }
                            Cb { icon: "󰒮"; onClicked: Player.previous() }
                            Cb { big: true; icon: Player.stopped && !Player.canResume ? "󰏌" : (Player.playing ? "󰏤" : "󰐊"); onClicked: Player.togglePlaying() }
                            Cb { icon: "󰒭"; onClicked: Player.next() }
                            Cb { icon: "󰗊"; tip: "Текст песни"; onClicked: win.openPlayer(true) }
                        }
                    }
                }
            }

            // ===== уведомление (notif / crit) =====
            Layer {
                st: "notif"; on: win.mode === "notif" || win.mode === "crit"
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 18
                    spacing: 14
                    AppIcon { size: 46; rad: 15; entry: win.e; crit: win.mode === "crit" }
                    NotifText { Layout.fillWidth: true; Layout.preferredWidth: 0; Layout.minimumWidth: 0; entry: win.e; crit: win.mode === "crit" }
                    Repeater {
                        model: IslandState.actionsOf(win.e).slice(0, win.pl[1] >= 430 ? 2 : 1)   // тесно — одна кнопка (остальные — в центре)
                        delegate: Rectangle {
                            id: act
                            required property var modelData
                            implicitWidth: al.implicitWidth + 28; implicitHeight: 30; radius: 14
                            color: am.containsMouse ? Colors.hover : Colors.isl2
                            Behavior on color { ColorAnimation { duration: Theme.fast } }
                            scale: am.pressed ? 0.94 : 1
                            Behavior on scale { NumberAnimation { duration: Theme.fast } }
                            Text { id: al; anchors.centerIn: parent; text: act.modelData.text; font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium; color: Colors.fg }
                            MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: act.modelData.id === "inline-reply" ? IslandState.openReply() : IslandState.invoke(act.modelData.id) }
                        }
                    }
                }
                CloseX { shown: hov.hovered; onClose: IslandState.dismiss() }
            }

            // ===== быстрый ответ =====
            Layer {
                st: "reply"; on: win.mode === "reply"
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 18; anchors.topMargin: 16
                    spacing: 12
                    RowLayout {
                        Layout.fillWidth: true; spacing: 12
                        AppIcon { size: 40; rad: 13; entry: win.e; crit: IslandState.critical }
                        NotifText { Layout.fillWidth: true; Layout.preferredWidth: 0; Layout.minimumWidth: 0; entry: win.e }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        IField {
                            id: field
                            icon: "󰍩"
                            placeholder: win.e && win.e.replyPlaceholder.length ? win.e.replyPlaceholder : "Ответить…"
                            onAccepted: IslandState.reply(field.text)
                            Keys.onEscapePressed: IslandState.closeReply()     // Esc из поля поднимается сюда
                        }
                        Rectangle {
                            implicitWidth: 40; implicitHeight: 40; radius: 20
                            color: sm.containsMouse ? Colors.mix(Colors.acc, Colors.fg, 0.15) : Colors.acc
                            scale: sm.pressed ? 0.92 : 1
                            Behavior on scale { NumberAnimation { duration: Theme.fast } }
                            Glyph { anchors.centerIn: parent; text: "󰒊"; font.pixelSize: 17; color: Colors.onAcc }
                            MouseArea { id: sm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: IslandState.reply(field.text) }
                        }
                    }
                }
                CloseX { shown: hov.hovered; onClose: IslandState.closeReply() }
                // поле: черновик — свой у каждого уведомления, фокус — при раскрытии
                Connections {
                    target: win
                    function onModeChanged() {
                        if (win.mode === "reply") { field.text = IslandState.draft(win.e); focusLater.restart() }
                    }
                }
                Timer { id: focusLater; interval: 60; onTriggered: field.input.forceActiveFocus() }
                Connections { target: field.input; function onTextChanged() { if (win.mode === "reply") IslandState.setDraft(win.e, field.text) } }
            }

            // ===== OSD =====
            Layer {
                st: "osd"; on: win.mode === "osd"
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 18
                    spacing: 14
                    Item {
                        Layout.preferredWidth: 22; Layout.preferredHeight: 22
                        Glyph { anchors.centerIn: parent; visible: !OsdState.pods; text: OsdState.icon; yumi: OsdState.yumiIcon
                                font.pixelSize: 18; color: OsdState.off ? Colors.fgDim : Colors.fg }
                        PodsGlyph { anchors.centerIn: parent; visible: OsdState.pods; pixelSize: 18; color: OsdState.off ? Colors.fgDim : Colors.fg }
                    }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 6; radius: 3
                        color: Colors.alpha(Colors.fg, 0.16)
                        Rectangle {
                            height: parent.height; radius: 3
                            width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, OsdState.level)))
                            color: OsdState.off ? Colors.fgDim : Colors.acc
                            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                            Behavior on color { ColorAnimation { duration: Theme.fast } }
                        }
                    }
                    Text { text: OsdState.label; Layout.minimumWidth: 36; horizontalAlignment: Text.AlignRight
                           font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium
                           font.features: ({ "tnum": 1 }); color: Colors.fg }
                }
            }

            // ===== сообщение =====
            Layer {
                st: "msg"; on: win.mode === "msg"
                RowLayout {
                    id: msgRow
                    anchors.centerIn: parent
                    spacing: 8
                    Glyph { text: IslandState.msgIcon || OsdState.icon; font.pixelSize: 15; color: OsdState.off && !IslandState.msgText ? Colors.fgDim : Colors.acc }
                    Text { text: win.msgLabel; font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium; color: Colors.fg }
                }
            }

            // ===== активность: компактно (главная — своя, не музыка) =====
            Layer {
                st: "act"; on: win.mode === "act"
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 5; anchors.rightMargin: 12
                    spacing: 9
                    ActIcon { act: win.mainA; size: 20 }
                    Text {
                        Layout.fillWidth: true
                        textFormat: Text.StyledText
                        text: !win.mainA ? "" : win.mainA.done ? win.esc(win.mainA.title) + " <font color=\"" + Colors.fgDim + "\">— " + win.esc(win.mainA.done) + "</font>"
                              : win.esc(win.mainA.title) + (win.mainA.sub ? " <font color=\"" + Colors.fgDim + "\">· " + win.esc(win.mainA.sub) + "</font>" : "")
                        font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium
                        color: Colors.fg; elide: Text.ElideRight; maximumLineCount: 1
                    }
                    Rectangle {           // прогресс: маленькая капсула
                        visible: !!win.mainA && win.mainA.progress >= 0 && !win.mainA.done
                        Layout.preferredWidth: 36; Layout.preferredHeight: 4; radius: 2; color: Colors.alpha(Colors.fg, 0.16)
                        Rectangle { height: 4; radius: 2; color: IslandState.toneColor(win.mainA ? win.mainA.tone : "")
                                    width: Math.max(4, parent.width * (win.mainA ? Math.max(0, win.mainA.progress) : 0))
                                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } } }
                    }
                    Text { visible: text.length > 0
                           text: !win.mainA || win.mainA.done ? "" : (win.mainA.trail || (win.mainA.progress >= 0 ? Math.round(win.mainA.progress * 100) + " %" : ""))
                           font.family: Theme.fontUi; font.pixelSize: 11; font.features: ({ "tnum": 1 })
                           color: IslandState.toneColor(win.mainA ? win.mainA.tone : "") }
                }
            }

            // ===== активность: развёрнуто (наведение или показ новой ~1,5 с) =====
            Layer {
                st: "actx"; on: win.mode === "actx"
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 18
                    spacing: 10
                    RowLayout {
                        Layout.fillWidth: true; spacing: 12
                        ActIcon { act: win.xa; size: 40 }
                        ColumnLayout {
                            Layout.fillWidth: true; Layout.preferredWidth: 0; spacing: 1
                            Text { Layout.fillWidth: true; text: win.xa ? (win.xa.done ? win.xa.title + " — готово" : win.xa.title) : ""
                                   font.family: Theme.fontUi; font.pixelSize: 15; font.weight: Font.DemiBold; color: Colors.fg; elide: Text.ElideRight }
                            Text { Layout.fillWidth: true; visible: text.length > 0; text: win.xa ? (win.xa.done || win.xa.sub) : ""
                                   font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim; elide: Text.ElideRight }
                        }
                        Text { visible: text.length > 0; text: win.xa && !win.xa.done ? (win.xa.trail || (win.xa.progress >= 0 ? Math.round(win.xa.progress * 100) + " %" : "")) : ""
                               font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.DemiBold; font.features: ({ "tnum": 1 })
                               color: IslandState.toneColor(win.xa ? win.xa.tone : "") }
                    }
                    Rectangle {
                        visible: !!win.xa && win.xa.progress >= 0 && !win.xa.done
                        Layout.fillWidth: true; Layout.preferredHeight: 6; radius: 3; color: Colors.alpha(Colors.fg, 0.16)
                        Rectangle { height: 6; radius: 3; color: IslandState.toneColor(win.xa ? win.xa.tone : "")
                                    width: Math.max(6, parent.width * (win.xa ? Math.max(0, win.xa.progress) : 0))
                                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } } }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        visible: !!win.xa && !win.xa.done && (!!win.xa.primary || !!win.xa.open)
                        Item { Layout.fillWidth: true }
                        Pill { visible: !!win.xa && !!win.xa.open; text: "Открыть"; onClicked: IslandState.openOf(win.xa) }
                        Pill { visible: !!win.xa && !!win.xa.primary; accent: true; text: win.xa && win.xa.primaryLabel ? win.xa.primaryLabel : "Действие"
                               onClicked: IslandState.run(win.xa.primary, "главное действие") }
                    }
                }
            }

            // ===== системный пузырь-пилюля (зарядка, раскладка…) =====
            Layer {
                st: "pill"; on: win.mode === "pill"
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                    spacing: 8
                    readonly property var dd: win.al && win.al.kind === "pill" ? win.al.data : ({})
                    Glyph { visible: !parent.dd.pods; text: parent.dd.icon || ""; font.pixelSize: 15; color: parent.dd.tone ? IslandState.toneColor(parent.dd.tone) : Colors.fg }
                    PodsGlyph { visible: !!parent.dd.pods; pixelSize: 20; color: Colors.fg; Layout.alignment: Qt.AlignVCenter }   // 30.10: режим AirPods
                    Text { text: parent.dd.l || ""; font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium
                           color: parent.dd.tone ? IslandState.toneColor(parent.dd.tone) : Colors.fg }
                    Item { Layout.fillWidth: true }
                    Text { text: parent.dd.r || ""; font.family: Theme.fontUi; font.pixelSize: 12; font.features: ({ "tnum": 1 })
                           color: parent.dd.tone ? IslandState.toneColor(parent.dd.tone) : Colors.fgDim }
                }
            }

            // ===== системный баннер (батарея 10 / 5 %) =====
            Layer {
                st: "banner"; on: win.mode === "banner"
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 18
                    spacing: 14
                    readonly property var dd: win.al && win.al.kind === "banner" ? win.al.data : ({})
                    Rectangle {
                        Layout.preferredWidth: 46; Layout.preferredHeight: 46; radius: 15
                        color: Colors.alpha(parent.dd.tone ? IslandState.toneColor(parent.dd.tone) : Colors.acc, 0.2)
                        Glyph { anchors.centerIn: parent; text: parent.parent.dd.icon || "󰂚"; font.pixelSize: 22
                                color: parent.parent.dd.tone ? IslandState.toneColor(parent.parent.dd.tone) : Colors.acc }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.preferredWidth: 0; spacing: 1
                        Text { text: (parent.parent.dd.app || "") + " · сейчас"; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim }
                        Text { Layout.fillWidth: true; text: parent.parent.dd.title || ""; font.family: Theme.fontUi; font.pixelSize: 14; font.weight: Font.DemiBold
                               color: parent.parent.dd.tone === "bad" ? Colors.bad : Colors.fg; elide: Text.ElideRight }
                        Text { Layout.fillWidth: true; text: parent.parent.dd.text || ""; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim; elide: Text.ElideRight }
                    }
                    Pill { visible: !!win.al && win.al.dur === 0; text: "Закрыть"; onClicked: IslandState.endAlert("закрыт кнопкой") }
                }
            }

            // ===== AirPods подключены: заряд Л / П / кейс =====
            Layer {
                st: "airpods"; on: win.mode === "airpods"
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 22; anchors.rightMargin: 22
                    spacing: 18
                    PodsGlyph { pixelSize: 44; color: Colors.fg; Layout.alignment: Qt.AlignVCenter; Layout.preferredWidth: 56 }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 2
                        Text { text: "Подключены · выход звука"; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim }
                        Text { text: IslandState.podsData.name; font.family: Theme.fontUi; font.pixelSize: 15; font.weight: Font.DemiBold; color: Colors.fg }
                        RowLayout {
                            Layout.topMargin: 6; spacing: 14
                            Repeater {
                                model: [["Л", IslandState.podsData.l], ["П", IslandState.podsData.r], ["кейс", IslandState.podsData.c]].filter(x => x[1] >= 0)
                                delegate: RowLayout {
                                    required property var modelData
                                    spacing: 6
                                    Ring { value: modelData[1] / 100; size: 24; color: modelData[1] <= 20 ? Colors.warn : Colors.ok }
                                    Text { text: modelData[0] + " " + modelData[1]; font.family: Theme.fontUi; font.pixelSize: 12; font.features: ({ "tnum": 1 }); color: Colors.fgDim }
                                }
                            }
                            Text { visible: IslandState.podsData.l < 0 && IslandState.podsData.r < 0; text: "заряд — ждём данные"
                                   font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim }
                        }
                    }
                }
            }

            // ===== сводка фокуса =====
            Layer {
                st: "summary"; on: win.mode === "summary"
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 18
                    spacing: 6
                    readonly property var dd: win.al && win.al.kind === "summary" ? win.al.data : ({ title: "", items: [] })
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: parent.parent.dd.title; font.family: Theme.fontUi; font.pixelSize: 15; font.weight: Font.DemiBold; color: Colors.fg }
                        Item { Layout.fillWidth: true }
                        Text { text: win.plural(parent.parent.dd.items.length); font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim }
                    }
                    Repeater {
                        model: parent.dd.items.slice(0, 4)
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true; spacing: 10
                            Glyph { text: modelData.icon || "󰂚"; font.pixelSize: 14; color: Colors.acc }
                            Text { text: modelData.who || ""; font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.DemiBold; color: Colors.fg; Layout.maximumWidth: 140; elide: Text.ElideRight }
                            Text { Layout.fillWidth: true; text: modelData.text || ""; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim; elide: Text.ElideRight }
                        }
                    }
                    Text { visible: parent.dd.items.length > 4; text: "и ещё " + (parent.dd.items.length - 4) + "…"; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim }
                    Item { Layout.fillHeight: true }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Pill { accent: true; text: "Открыть все"; onClicked: { Notifs.visible = true; IslandState.endAlert("«Открыть все» → центр уведомлений") } }
                        Pill { text: "Позже"; onClicked: IslandState.endAlert("«Позже»") }
                    }
                }
            }

            // критичное — красная кромка; обычная — тонкая кромка edge
            readonly property string edgeTone: win.mode === "crit" ? "bad"
                : (win.mode === "banner" || win.mode === "pill") && win.al && win.al.data.tone === "bad" ? "bad"
                : win.mode === "banner" && win.al && win.al.data.tone === "warn" ? "warn"
                : (win.mode === "act" || win.mode === "actx") && win.mainA && win.mainA.priority === 1 ? "acc" : ""
            Rectangle {
                anchors.fill: parent; radius: parent.radius; color: "transparent"
                border.width: isl.edgeTone ? 1.5 : 1
                border.color: isl.edgeTone === "bad" ? Colors.bad : isl.edgeTone === "warn" ? Colors.alpha(Colors.warn, 0.6) : isl.edgeTone === "acc" ? Colors.acc : Colors.edge
                Behavior on border.color { ColorAnimation { duration: Theme.normal } }
            }
            Rectangle {   // «вдох» подсветкой при новом событии
                id: breathR
                anchors.fill: parent; radius: parent.radius; color: "transparent"
                border.width: 2; border.color: Colors.acc; opacity: 0
                SequentialAnimation { id: breathA
                    NumberAnimation { target: breathR; property: "opacity"; to: 0.9; duration: 60 }
                    NumberAnimation { target: breathR; property: "opacity"; to: 0; duration: 900; easing.type: Easing.OutCubic } }
            }
        }

        function esc(s) { return String(s || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }
        function plural(n) { const m = n % 10, h = n % 100; return n + " " + (m === 1 && h !== 11 ? "уведомление" : m >= 2 && m <= 4 && (h < 10 || h >= 20) ? "уведомления" : "уведомлений") }

        // ---------- круги рядом с островом: слева — вторая активность («+N» — ещё), дальше слева — сводка фокуса ----------
        Bubble {
            id: bubR
            on: win.hasR
            x: isl.x - 38                      // 30.10: круги слева от острова
            Item {
                anchors.fill: parent
                ActIcon { anchors.centerIn: parent; act: IslandState.second; size: 22; flat: true }
                Badge { visible: IslandState.extra > 0; text: "+" + IslandState.extra }
            }
            onClicked: IslandState.swapMain()                                   // клик — сделать главной
            onWheel: IslandState.swapMain()
        }
        Bubble {
            id: bubL
            on: win.hasL
            x: isl.x - 38 - (bubR.on || bubN.on ? 38 : 0)   // 30.10: все круги слева, сводка — дальше
            Item {
                anchors.fill: parent
                Glyph { anchors.centerIn: parent; text: "󰂚"; font.pixelSize: 15; color: Colors.acc }
                Badge { text: String(IslandState.summary.length) }
            }
            onClicked: IslandState.deliverSummary("Сводка (по запросу)")
        }

        // 30.10: пачка уведомлений — показано свежее, остальные «+N» (они в центре уведомлений; клик — открыть журнал)
        Bubble {
            id: bubN
            on: (win.mode === "notif" || win.mode === "crit" || win.mode === "reply") && IslandState.more > 0
            x: isl.x - 38                      // 30.10: круги слева от острова
            Text { anchors.centerIn: parent; text: "+" + Math.min(99, IslandState.more)
                   font.family: Theme.fontUi; font.pixelSize: 11; font.features: ({ "tnum": 1 }); color: Colors.acc }
            onClicked: Notifs.visible = true
        }

        // 30.10: микрофон занят — точка слева от острова (как оранжевая точка iPhone); без раскрытия и без вытеснения музыки
        Rectangle {
            readonly property bool on: IslandState.micApps.length > 0 && win.mode !== "none"
            // слева, за всеми кругами (как и они)
            x: isl.x - 12 - (bubR.on || bubN.on ? 38 : 0) - (bubL.on ? 38 : 0); y: isl.y + Math.min(isl.height, 30) / 2 - 3
            width: 6; height: 6; radius: 3
            color: Colors.warn
            opacity: on ? 1 : 0; scale: on ? 1 : 0.3
            Behavior on opacity { NumberAnimation { duration: 220 } }
            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2 } }
        }

        // круг 30 px рядом с островом: появляется пружинкой
        component Bubble: Rectangle {
            id: bb
            default property alias content: inner.data
            property bool on: false
            signal clicked()
            signal wheel()
            // 30.10: остров выше бара (уведомление, плеер) — круг ниже строки бара, иначе наезжает на пилюли крыльев
            y: isl.height > 40 ? Theme.barH + 6 : 6; width: 30; height: 30; radius: 15
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            color: Colors.isl; border.width: 1; border.color: Colors.edge
            visible: scale > 0.05
            scale: on ? 1 : 0.2
            opacity: on ? 1 : 0
            Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
            Behavior on opacity { NumberAnimation { duration: 200 } }
            // 30.10: x без своей анимации — круг идёт ровно за краем острова (с запаздыванием он наезжал на растущий остров)
            Item { id: inner; anchors.fill: parent }
            // 30.10: скрытый круг (прозрачный, ещё не досжатый) клики не ловит — круги стоят на одном месте,
            // и невидимый «+N» перехватывал клик по кругу таймера (открывал журнал)
            MouseArea { anchors.fill: parent; enabled: bb.on; cursorShape: Qt.PointingHandCursor; onClicked: bb.clicked(); onWheel: bb.wheel() }
        }
        component Badge: Rectangle {
            property string text: ""
            anchors.right: parent.right; anchors.top: parent.top; anchors.rightMargin: -3; anchors.topMargin: -3
            width: Math.max(14, bt.implicitWidth + 6); height: 14; radius: 7; color: Colors.acc
            Text { id: bt; anchors.centerIn: parent; text: parent.text; font.family: Theme.fontUi; font.pixelSize: 9; font.weight: Font.Bold; color: Colors.onAcc }
        }
        // значок активности: музыка — обложка, иначе глиф в кружке цвета тона; готово — галочка
        component ActIcon: Item {
            id: ai2
            property var act: null
            property int size: 20
            property bool flat: false
            implicitWidth: size; implicitHeight: size
            Layout.preferredWidth: size; Layout.preferredHeight: size
            readonly property color tc: act ? (act.done ? Colors.ok : IslandState.toneColor(act.tone)) : Colors.acc
            Cover { anchors.fill: parent; visible: !!ai2.act && !!ai2.act.music; size: ai2.size; rad: ai2.size / 2 }
            Rectangle {
                anchors.fill: parent; radius: ai2.size / 2
                visible: !!ai2.act && !ai2.act.music
                color: ai2.act && ai2.act.done ? Colors.ok : ai2.flat ? "transparent" : Colors.alpha(ai2.tc, 0.2)
                Ring { anchors.fill: parent; visible: !!ai2.act && ai2.act.progress >= 0 && !ai2.act.done; value: ai2.act && ai2.act.progress >= 0 ? ai2.act.progress : 0; size: ai2.size; color: ai2.tc }
                Glyph { anchors.centerIn: parent; text: ai2.act ? (ai2.act.done ? "󰄬" : IslandState.glyph(ai2.act.icon)) : ""
                        font.pixelSize: Math.round(ai2.size * 0.6); color: ai2.act && ai2.act.done ? Colors.onAcc : ai2.tc }
            }
        }
        // кольцо прогресса (Shape — без шейдеров)
        component Ring: Item {
            id: rg
            property real value: 0
            property int size: 24
            property color color: Colors.acc
            implicitWidth: size; implicitHeight: size
            Shape {
                anchors.fill: parent; preferredRendererType: Shape.CurveRenderer
                ShapePath { strokeColor: Colors.alpha(Colors.fg, 0.14); strokeWidth: 2.5; fillColor: "transparent"
                    PathAngleArc { centerX: rg.size / 2; centerY: rg.size / 2; radiusX: rg.size / 2 - 2; radiusY: rg.size / 2 - 2; startAngle: 0; sweepAngle: 360 } }
                ShapePath { strokeColor: rg.color; strokeWidth: 2.5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: rg.size / 2; centerY: rg.size / 2; radiusX: rg.size / 2 - 2; radiusY: rg.size / 2 - 2; startAngle: -90; sweepAngle: 360 * Math.max(0, Math.min(1, rg.value)) } }
            }
        }
        // кнопка-капсула пузыря
        component Pill: Rectangle {
            id: pp
            property string text: ""
            property bool accent: false
            signal clicked()
            implicitWidth: ptx.implicitWidth + 28; implicitHeight: 30; radius: 15
            color: accent ? (pm.containsMouse ? Colors.mix(Colors.acc, Colors.fg, 0.15) : Colors.acc) : (pm.containsMouse ? Colors.hover : Colors.isl2)
            Behavior on color { ColorAnimation { duration: Theme.fast } }
            scale: pm.pressed ? 0.94 : 1
            Behavior on scale { NumberAnimation { duration: Theme.fast } }
            Text { id: ptx; anchors.centerIn: parent; text: pp.text; font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium; color: pp.accent ? Colors.onAcc : Colors.fg }
            MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pp.clicked() }
        }

        // ---------- детали ----------
        // слой состояния: проявляется после роста острова (задержка 120 мс), уходит быстро
        component Layer: Item {
            id: lay
            property bool on: false
            property string st: "idle"
            // свой размер — размер состояния (не размер растущего острова): содержимое раскладывается один раз
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            width: win.stW(st); height: (win.dims[st] || win.dims.idle)[1]
            visible: opacity > 0.01
            enabled: on
            // своё «появление» и «уход» явными анимациями: в Behavior длительность от on пересчитывалась позже старта,
            // и уходящий слой гас медленно (300 мс с задержкой) — торчал поверх раскрытого острова
            opacity: 0
            scale: 0.94
            Component.onCompleted: { opacity = on ? 1 : 0; scale = on ? 1 : 0.94 }
            onOnChanged: { if (on) { outA.stop(); inA.start() } else { inA.stop(); outA.start() } }
            ParallelAnimation {
                id: inA
                SequentialAnimation { PauseAnimation { duration: 120 }
                    NumberAnimation { target: lay; property: "opacity"; to: 1; duration: 300; easing.type: Easing.OutCubic } }
                SequentialAnimation { PauseAnimation { duration: 100 }
                    NumberAnimation { target: lay; property: "scale"; to: 1; duration: 400; easing.type: Easing.OutBack } }
            }
            ParallelAnimation {     // уход — сразу, за 80 мс в начале роста
                id: outA
                NumberAnimation { target: lay; property: "opacity"; to: 0; duration: 80 }
                NumberAnimation { target: lay; property: "scale"; to: 0.94; duration: 80 }
            }
        }
        // обложка трека
        component Cover: ClippingRectangle {
            id: cv
            property int size: 20
            property real rad: 10
            implicitWidth: size; implicitHeight: size
            Layout.preferredWidth: size; Layout.preferredHeight: size
            radius: rad
            color: Colors.isl2
            Image {
                id: cimg
                anchors.fill: parent
                source: IslandState.art
                sourceSize.width: Math.ceil(cv.size * Screen.devicePixelRatio); sourceSize.height: Math.ceil(cv.size * Screen.devicePixelRatio)
                fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.normal } }
            }
            Glyph { anchors.centerIn: parent; visible: cimg.status !== Image.Ready; text: "󰝚"; color: Colors.acc
                    font.pixelSize: Math.round(cv.size * 0.5) }
        }
        // кнопка плеера (.cb): 32, play — 40 акцентом
        component Cb: Rectangle {
            id: cb
            property string icon: ""
            property string tip: ""
            property bool big: false
            property bool on: false
            signal clicked()
            implicitWidth: big ? 40 : 32; implicitHeight: implicitWidth; radius: implicitWidth / 2
            color: big ? Colors.acc : (cbm.containsMouse ? Colors.isl2 : (on ? Colors.alpha(Colors.acc, 0.22) : Colors.alpha(Colors.isl2, 0)))
            Behavior on color { ColorAnimation { duration: Theme.fast } }
            scale: cbm.pressed ? 0.9 : 1
            Behavior on scale { NumberAnimation { duration: Theme.fast } }
            Glyph { anchors.centerIn: parent; text: cb.icon; font.pixelSize: cb.big ? 19 : 17
                    color: cb.big ? Colors.onAcc : (cb.on ? Colors.acc : Colors.fg) }
            MouseArea { id: cbm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: cb.clicked() }
        }
        // значок уведомления: картинка или значок приложения в квадрате; без них — глиф на подложке акцентом 20 %
        component AppIcon: Rectangle {
            id: ai
            property int size: 46
            property real rad: 15
            property var entry: null
            property bool crit: false
            Layout.preferredWidth: size; Layout.preferredHeight: size
            radius: rad
            color: Colors.alpha(crit ? Colors.bad : Colors.acc, 0.20)
            ClippingRectangle {
                anchors.fill: parent; radius: ai.rad; color: "transparent"
                visible: pic.status === Image.Ready
                Image {
                    id: pic
                    anchors.fill: parent
                    readonly property bool photo: !!(ai.entry && ai.entry.image && ai.entry.image.length > 0)
                    anchors.margins: photo ? 0 : 9
                    source: ai.entry ? Notifs.iconFor(ai.entry, true) : ""
                    sourceSize.width: Math.ceil(ai.size * Screen.devicePixelRatio); sourceSize.height: Math.ceil(ai.size * Screen.devicePixelRatio)
                    fillMode: photo ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                    asynchronous: true; smooth: true
                    onStatusChanged: {
                        // image-data → png в кэш журнала (как делала всплывашка): после истечения image:// уже не прочитать
                        if (status === Image.Ready && ai.entry && ai.entry.image.startsWith("image://") && !ai.entry.imageFile) {
                            const en = ai.entry
                            pic.grabToImage(r => { const p = Notifs.imageName(en); if (r.saveToFile(p)) Notifs.setImageFile(en, p) }, Qt.size(96, 96))
                        }
                    }
                }
            }
            Glyph { anchors.centerIn: parent; visible: pic.status !== Image.Ready; text: ai.crit ? "󰀦" : "󰂚"
                    font.pixelSize: 22; color: ai.crit ? Colors.bad : Colors.acc }
        }
        // приложение · заголовок · текст
        component NotifText: ColumnLayout {
            id: nt
            property var entry: null
            property bool crit: false
            spacing: 1
            Text { Layout.fillWidth: true; text: nt.entry ? nt.entry.app : ""; visible: text.length > 0
                   font.family: Theme.fontUi; font.pixelSize: 11; font.letterSpacing: 0.2; color: Colors.fgDim; elide: Text.ElideRight }
            Text { Layout.fillWidth: true; text: nt.entry ? (nt.entry.summary.length ? nt.entry.summary : nt.entry.app) : ""
                   font.family: Theme.fontUi; font.pixelSize: 14; font.weight: Font.DemiBold
                   color: nt.crit ? Colors.bad : Colors.fg; elide: Text.ElideRight; maximumLineCount: 1 }
            Text { Layout.fillWidth: true; visible: text.length > 0
                   text: nt.entry ? nt.entry.body.replace(/<[^>]+>/g, "").replace(/\s*\n\s*/g, " ") : ""
                   font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim; elide: Text.ElideRight; maximumLineCount: 1 }
            Rectangle {   // полоса прогресса (hint value)
                Layout.fillWidth: true; Layout.topMargin: 4; implicitHeight: 3; radius: 1.5
                visible: !!(nt.entry && nt.entry.hints && nt.entry.hints["value"] !== undefined)
                color: Colors.alpha(Colors.fg, 0.16)
                Rectangle { height: parent.height; radius: 1.5; color: Colors.acc
                            width: parent.width * Math.min(1, Math.max(0, (parent.visible ? Number(nt.entry.hints["value"]) : 0) / 100))
                            Behavior on width { NumberAnimation { duration: Theme.normal } } }
            }
        }
        // крестик при наведении
        component CloseX: Rectangle {
            id: cx
            property bool shown: false
            signal close()
            anchors.top: parent.top; anchors.right: parent.right; anchors.topMargin: 8; anchors.rightMargin: 14
            width: 20; height: 20; radius: 10
            color: xm.containsMouse ? Colors.bad : Colors.isl2
            opacity: cx.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.fast } }
            Behavior on color { ColorAnimation { duration: Theme.fast } }
            Glyph { anchors.centerIn: parent; text: "󰅖"; font.pixelSize: 12; color: xm.containsMouse ? Colors.onAcc : Colors.fg }
            MouseArea { id: xm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: cx.close() }
        }
    }
}
