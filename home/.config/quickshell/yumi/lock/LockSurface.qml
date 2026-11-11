import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.UPower
import qs
import qs.components
import qs.services

// Экран блокировки «Остров» (29.10.2026, превью island.src.html, #lock): чёткие обои с затемнением 0.23; справа сверху
// остров статуса (Wi-Fi, VPN, раскладка, батарея); по центру печать 弓 52 → часы 150 Onest 600 → дата; ниже три
// острова — погода (по часам), плеер, уведомления (только число и приложения — без текста и отправителей); внизу
// остров пароля 380×58 (аватар, точки, Touch ID; ввод — шире 420 и кромка акцентом) и подсказка.
// Набор пароля: виджеты гаснут и уезжают вниз, обои размываются, колонка с часами поднимается; ошибка — тряска
// острова пароля; разблокировка — растворение 520 мс (прозрачность, лёгкое приближение).
// Вход «из логотипа» (intro внизу файла) НЕ менялся: кадр-мост, растворение 400 мс, каскад начинается под ним.
//
// Этот файл НЕ проверяет пароль. Владелец (LockPreview — заглушка, LockReal — PAM, greeter — greetd) слушает
// submitted(pw) и отвечает, выставляя authState = "error" (тряска, поле очищается) или "ok" (растворение → dissolved()).
//   authState: idle | typing | checking | error | ok
Item {
    id: root
    // ---------- наружу ----------
    property string authState: "idle"
    property bool active: true                 // окно показано: таймеры, опросы, погода
    property int notifCount: 0                 // только число и приложения — без отправителей и текста
    property var notifApps: []
    property var notifCounts: []               // [{ app, n }] — число по приложениям (необязательно; нет — только имена)
    property string errorText: "Неверный пароль"
    property string userName: ""               // пусто — из GECOS, иначе из $USER («yumi123» → «Yumi»)
    property bool blankCursor: false           // 18.10: при загрузке курсора на экране блокировки нет (показ — после разблокировки)
    property bool bootIntro: false             // вход при загрузке: первый кадр = последний кадр Plymouth (логотип на чёрном)
    property string screenName: ""             // имя монитора (eDP-1…) — настоящий масштаб из yumi-monitors.json
    // заглушка (16.10): второй монитор (MSI), пока встроенный экран включён — только логотип и часы, пароль вводится
    // на Mac (печатать на MSI тоже можно: поле невидимо, но работает, видны точки). Крышка закрыта — полный экран.
    property bool placeholder: false
    // общий ввод (19.10, задаёт LockReal): текст, набранный на любой поверхности, — сюда; свой набор — сигналом typed
    property string sharedText: ""
    signal typed(string t)
    onSharedTextChanged: if (input.text !== sharedText) input.text = sharedText
    // Touch ID (19.10.2026, задаёт LockReal): fpState — подсказка off | wait | miss; fpOk — палец совпал → растворение
    property string fpState: "off"
    property bool fpOk: false
    onFpOkChanged: if (fpOk && active && authState !== "ok") authState = "ok"
    readonly property string fpText: fpState === "miss" ? "Отпечаток не распознан" : fpState === "wait" ? "Коснитесь Touch ID" : ""
    // виджеты-острова (погода, плеер, уведомления); экран входа их прячет
    property bool widgets: true
    signal submitted(string pw)
    signal cancelled()                         // Esc при пустом поле
    signal dissolved()                         // растворение после «ok» закончилось
    signal introFinished()                     // вход «из логотипа» растворился (бар можно показать)
    signal introGone()                         // растворение входа закончилось (прозрачность 0) — можно включать MSI

    // ---------- размеры: превью 1600×1000 лог. px (eDP-1 при scale 1.6) → экран ----------
    readonly property real u: Math.max(0.6, Math.min(width / 1600, height / 1000))
    function px(n) { return Math.max(1, Math.round(n * u)) }
    // y из превью (сверху) → от центра экрана: на других пропорциях всё держится середины
    function py(n) { return Math.round(height / 2 + (n - 500) * u) }
    readonly property int dur: 520             // durationMs из макета: растворение
    readonly property var spring: [0.34, 1.25, 0.64, 1, 1, 1]     // --spring превью
    readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
    readonly property string font: Theme.fontUi
    readonly property var tnum: ({ "tnum": 1 })

    readonly property bool typing: authState !== "idle"
    readonly property bool busy: authState === "checking"
    readonly property bool unlocked: authState === "ok"
    property bool started: false               // каскад островов при появлении
    // появление при блокировке (16.10): 0,8 с из прозрачного поверх рабочего стола (session_lock_xray) — зеркально
    // растворению при разблокировке; вход при загрузке — без него (там свой вход «из логотипа»)
    property bool appeared: bootIntro
    opacity: appeared ? 1 : 0
    // OpacityAnimator, а не NumberAnimation: идёт в потоке отрисовки этого окна по частоте ЕГО экрана; обычные
    // анимации тикают по частоте одного экрана (MSI 165 Гц) — на встроенном 60 Гц шаги неровные (16.10, замер)
    Behavior on opacity { enabled: !root.bootIntro; OpacityAnimator { duration: 800; easing.type: Easing.InOutQuad } }
    // поверхность блокировки сплошная, кроме анимаций появления и растворения (см. LockReal: color)
    readonly property bool solid: opacity > 0.999 && !unlocked
    // appeared = appeared — разорвать привязку к bootIntro (16.10): после входа bootIntro выключается (introDone),
    // и привязка гасила весь экран блокировки на Mac — оставался «пустой» некликабельный рабочий стол без поля пароля
    Component.onCompleted: { appeared = appeared; if (!appeared) Qt.callLater(() => appeared = true); started = !bootIntro; input.forceActiveFocus(); Brightness.refresh(); layoutProc.running = true; whoProc.running = true; avatarProc.running = true
                             if (focusDiag) console.info("lock-focus:", screenName, "поверхность создана, bootIntro =", bootIntro) }
    // диагностика фокуса (19.10): получила ли поверхность клавиатуру (окно активно); через 2 с без неё — снимок Hyprland
    property bool focusDiag: false             // только настоящий экран блокировки (LockReal); превью и greetd — нет
    readonly property bool kbActive: Window.active
    onKbActiveChanged: if (focusDiag) console.info("lock-focus:", screenName, "клавиатура у поверхности =", kbActive)
    Timer { interval: 2000; running: root.focusDiag && root.active && !root.kbActive && !root.placeholder; repeat: false
            onTriggered: { console.warn("lock-focus:", root.screenName, "2 с без клавиатуры"); Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/yumi-lock-focus-snap", "no-focus " + root.screenName]) } }

    // ---------- состояние ввода ----------
    function startTyping() { if (authState === "idle") authState = "typing"; input.forceActiveFocus(); idleTimer.restart() }
    function typeDemo(t) { startTyping(); input.text = t }          // превью: показать ввод без клавиатуры (IPC lock test)
    function submitDemo() { if (input.text.length && !busy) { authState = "checking"; submitted(input.text) } }
    function backToIdle() { input.text = ""; authState = "idle"; msg = ""; input.forceActiveFocus() }
    // каждый новый показ — с чистого листа: даже если поверхность переиспользуется, «ok» прошлой разблокировки
    // не должно снять следующую блокировку без пароля
    onActiveChanged: if (active) { dissolve.stop(); backToIdle()
                                   if (!bootIntro) { appeared = false; Qt.callLater(() => appeared = true) } }
    property string msg: ""
    onAuthStateChanged: {
        if (authState === "error") {
            input.text = ""; msg = errorText
            shake.restart(); errTimer.restart(); idleTimer.restart()
        } else if (authState === "checking") {
            msg = "Проверяю…"; idleTimer.stop()
        } else if (authState === "ok") {
            msg = ""; idleTimer.stop(); dissolve.restart()
        } else if (authState === "idle") {
            msg = ""; idleTimer.stop()
        }
    }
    Timer { id: errTimer; interval: 1200; onTriggered: if (root.authState === "error") root.authState = "typing" }
    // без нажатий: пустое поле — назад к часам через 12 с, набранное — стереть через 30 с
    Timer { id: idleTimer; interval: input.text.length ? 30000 : 12000; onTriggered: if (root.authState === "typing" || root.authState === "error") root.backToIdle() }

    // ввод пароля начинается только с клавиатуры (16.10): мышью — плеер и перемотка, ввод не открывается

    // ---------- сцена: всё, что растворяется при разблокировке (520 мс, приближение 1.05) ----------
    Item {
        id: scene
        anchors.fill: parent
        opacity: root.unlocked ? 0 : 1
        scale: root.unlocked ? 1.05 : 1
        Behavior on opacity { NumberAnimation { duration: root.dur; easing.type: Easing.InQuad } }
        Behavior on scale { NumberAnimation { duration: root.dur; easing.type: Easing.InQuad } }

        // ---- обои: текущие из wall.set; набор пароля — размытие и чуть темнее ----
        Item {
            id: wall
            anchors.fill: parent
            Image {
                id: wallImg
                anchors.fill: parent
                source: "file://" + Quickshell.env("HOME") + "/.cache/yumi/theme/wall.set"
                sourceSize.width: Math.round(root.width * root.dpr * 1.05)
                sourceSize.height: Math.round(root.height * root.dpr * 1.05)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                visible: false
                smooth: true
            }
            MultiEffect {
                anchors.fill: parent
                source: wallImg
                autoPaddingEnabled: false
                // размытие считается, только когда оно есть (ввод пароля): иначе проходы по всему экрану 2560×1600
                // в каждом кадре — на 60 Гц анимации появления/растворения не успевали за 16,7 мс и дёргались (16.10, замер)
                blurEnabled: blur > 0.001
                blurMax: 40
                blur: root.typing && !root.unlocked ? 0.75 : 0          // ≈ 30 px, как blur(30px) в превью
                Behavior on blur { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                // края размытия не видны: обои чуть крупнее экрана (inset −20px в превью)
                scale: 1.03
            }
            // затемнение 0.23; при наборе 0.42 (.dim / #lock.typing .dim)
            Rectangle { anchors.fill: parent; color: "black"; opacity: root.typing ? 0.42 : 0.23
                        Behavior on opacity { NumberAnimation { duration: 500 } } }
            // запасной фон, пока обои грузятся / не найдены
            Rectangle { anchors.fill: parent; z: -1; color: Colors.deep }
        }

        // ---- остров статуса справа сверху (.stat): Wi-Fi, VPN, раскладка, батарея ----
        LockCard {
            id: stat
            u: root.u; order: 0; shown: root.started
            anchors { right: parent.right; top: parent.top; rightMargin: root.px(14); topMargin: root.px(10) }
            padX: 12; padY: 0; r: 15
            width: statRow.implicitWidth + root.px(12) * 2
            height: root.px(30)
            Row {
                id: statRow
                height: root.px(30)
                spacing: root.px(8)
                Glyph { anchors.verticalCenter: parent.verticalCenter; visible: root.wifiOn !== ""; text: root.wifiOn === "on" ? "󰖩" : "󰖪"
                        font.pixelSize: root.px(16); color: root.wifiOn === "on" ? Colors.fg : Colors.fgDim }
                Glyph { anchors.verticalCenter: parent.verticalCenter; text: root.vpnOn ? "󰒃" : "󰦞"
                        font.pixelSize: root.px(16); color: root.vpnOn ? Colors.fg : Colors.fgDim }
                Text { anchors.verticalCenter: parent.verticalCenter; text: Brightness.caps ? "CAPS" : root.layoutCode
                       font.family: root.font; font.pixelSize: root.px(12.5); font.weight: Font.Medium
                       color: Brightness.caps ? Colors.warn : Colors.fg }
                Glyph { anchors.verticalCenter: parent.verticalCenter; visible: root.batPct >= 0; text: root.batIcon
                        font.pixelSize: root.px(16); color: root.batLow ? Colors.bad : Colors.fg }
                Text { anchors.verticalCenter: parent.verticalCenter; visible: root.batPct >= 0; text: root.batPct + "%"
                       font.family: root.font; font.pixelSize: root.px(12.5); font.weight: Font.Medium; font.features: root.tnum
                       color: Colors.fg }
            }
        }

        // ---- колонка: печать 52 → часы 150 → дата (.lcol, top 150, gap 8); при наборе поднимается на 30 ----
        Column {
            id: lcol
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.py(150)
            spacing: root.px(8)
            transform: Translate { y: root.typing && !root.unlocked ? -root.px(30) : 0
                Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.BezierSpline; easing.bezierCurve: root.spring } } }
            LockCard {
                plain: true; u: root.u; order: 1; shown: root.started
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.px(52); height: width
                YumiMark { size: root.px(52) }
            }
            LockCard {
                plain: true; u: root.u; order: 2; shown: root.started
                anchors.horizontalCenter: parent.horizontalCenter
                width: timeT.implicitWidth; height: timeT.implicitHeight
                Text {
                    id: timeT
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    font.family: root.font; font.pixelSize: root.px(150); font.weight: Font.DemiBold
                    font.letterSpacing: -root.px(150) * 0.04; font.features: root.tnum
                    color: Colors.fg
                    lineHeight: 1; lineHeightMode: Text.ProportionalHeight
                    layer.enabled: true
                    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.25); shadowBlur: 0.8; shadowVerticalOffset: root.px(4) }
                }
            }
            LockCard {
                plain: true; u: root.u; order: 3; shown: root.started
                anchors.horizontalCenter: parent.horizontalCenter
                width: dateT.implicitWidth; height: dateT.implicitHeight
                Text { id: dateT; text: clock.date.toLocaleDateString(Qt.locale("ru_RU"), "dddd, d MMMM")
                       font.family: root.font; font.pixelSize: root.px(20); font.weight: Font.Medium; color: Colors.fgDim }
            }
        }

        // ---- ряд островов (.lw, top 560, gap 14): при наборе гаснут и уезжают вниз ----
        Item {
            id: lw
            anchors.left: parent.left; anchors.right: parent.right
            y: root.py(560)
            height: cards.height
            visible: root.widgets && opacity > 0.01
            readonly property bool away: root.typing
            opacity: away ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 400 } }
            transform: [
                Translate { y: lw.away ? root.px(20) : 0
                            Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.BezierSpline; easing.bezierCurve: root.spring } } },
                Scale { origin.x: lw.width / 2; origin.y: lw.height / 2; xScale: lw.away ? 0.97 : 1; yScale: xScale
                        Behavior on xScale { NumberAnimation { duration: 500; easing.type: Easing.BezierSpline; easing.bezierCurve: root.spring } } }
            ]
            Row {
                id: cards
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root.px(14)
                // одинаковая высота островов (align-items: stretch в превью)
                readonly property real rowH: Math.max(wxCard.visible ? wxCol.implicitHeight : 0, muCard.visible ? muCol.implicitHeight : 0, ntCol.implicitHeight) + root.px(16) * 2

                // ---- погода: сейчас + по часам ----
                LockCard {
                    id: wxCard
                    visible: !weather.off          // погода не настроена (нет ~/.config/yumi/weather.conf) — без острова
                    u: root.u; order: 4; shown: root.started
                    width: root.px(300); height: cards.rowH
                    Column {
                        id: wxCol
                        width: parent.width
                        spacing: root.px(10)
                        Row {
                            spacing: root.px(12)
                            Rectangle {
                                width: root.px(44); height: width; radius: root.px(15)
                                color: Colors.alpha(Colors.acc, 0.2)
                                Glyph { anchors.centerIn: parent; text: weather.now.icon || "󰖐"; font.pixelSize: root.px(22); color: Colors.acc }
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Text { text: weather.ok ? (weather.now.t ?? "–") + "°" : "–°"; font.family: root.font; font.pixelSize: root.px(26)
                                       font.weight: Font.DemiBold; font.features: root.tnum; color: Colors.fg
                                       lineHeight: 1.05; lineHeightMode: Text.ProportionalHeight }
                                Text {
                                    width: root.px(300 - 36 - 44 - 12)
                                    text: !weather.ok ? (weather.error || "Загружаю погоду…")
                                          : [weather.place, (weather.now.text || "").toLowerCase()].filter(s => s).join(" · ")
                                            + (weather.stale ? " · нет сети" : "")
                                    elide: Text.ElideRight
                                    font.family: root.font; font.pixelSize: root.px(12.5); color: Colors.fgDim
                                }
                            }
                        }
                        Row {
                            visible: weather.ok && weather.hours.length > 0
                            Repeater {
                                model: weather.hours.slice(0, 5)
                                Column {
                                    required property var modelData
                                    width: wxCol.width / 5
                                    spacing: root.px(4)
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: { const h = String(modelData.h); return /^\d{1,2}$/.test(h) ? h.padStart(2, "0") + ":00" : h }   // бэкенд даёт «21» → «21:00»
                                           font.family: root.font; font.pixelSize: root.px(12); font.features: root.tnum; color: Colors.fgDim }
                                    Glyph { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.icon; font.pixelSize: root.px(16); color: Colors.fgDim }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.t + "°"
                                           font.family: root.font; font.pixelSize: root.px(12); font.weight: Font.Medium; font.features: root.tnum; color: Colors.fg }
                                }
                            }
                        }
                    }
                }

                // ---- плеер: обложка, название, исполнитель, кнопки, прогресс ----
                LockCard {
                    id: muCard
                    visible: Player.shown          // нет игрока — последний трек (▶ продолжает)
                    u: root.u; order: 5; shown: root.started
                    width: root.px(380); height: cards.rowH
                    Column {
                        id: muCol
                        width: parent.width
                        spacing: root.px(10)
                        RowLayout {
                            width: parent.width
                            spacing: root.px(12)
                            ClippingRectangle {
                                Layout.preferredWidth: root.px(58); Layout.preferredHeight: root.px(58)
                                radius: root.px(16)
                                Rectangle { anchors.fill: parent; rotation: 0
                                    gradient: Gradient {
                                        orientation: Gradient.Vertical
                                        GradientStop { position: 0; color: Colors.acc }
                                        GradientStop { position: 0.45; color: Colors.acc5 }
                                        GradientStop { position: 1; color: Colors.deep }
                                    } }
                                Image { id: cover; anchors.fill: parent; source: Player.artUrl; asynchronous: true; fillMode: Image.PreserveAspectCrop
                                        sourceSize.width: Math.round(root.px(58) * root.dpr); sourceSize.height: Math.round(root.px(58) * root.dpr)
                                        opacity: status === Image.Ready ? 1 : 0; Behavior on opacity { NumberAnimation { duration: Theme.normal } } }
                                Glyph { anchors.centerIn: parent; visible: cover.status !== Image.Ready; text: "󰝚"
                                        font.pixelSize: root.px(24); color: Colors.onAcc }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: root.px(4)
                                Text { Layout.fillWidth: true; text: Player.title || "Нет трека"; elide: Text.ElideRight; font.family: root.font
                                       font.pixelSize: root.px(16); font.weight: Font.DemiBold; color: Colors.fg }
                                Text { Layout.fillWidth: true; text: Player.artist || Player.source.replace(/^\S+\s/, ""); elide: Text.ElideRight
                                       font.family: root.font; font.pixelSize: root.px(12.5); color: Colors.fgDim }
                            }
                            Row {
                                spacing: root.px(8)
                                Repeater {
                                    model: [["󰒮", "prev"], [Player.playing ? "󰏤" : "󰐊", "play"], ["󰒭", "next"]]
                                    Rectangle {
                                        required property var modelData
                                        readonly property bool pp: modelData[1] === "play"
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: root.px(pp ? 40 : 32); height: width; radius: width / 2
                                        color: pp ? Colors.acc : (cbMa.containsMouse ? Colors.isl2 : "transparent")
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                        scale: cbMa.pressed ? 0.9 : 1
                                        Behavior on scale { NumberAnimation { duration: 150 } }
                                        Glyph { anchors.centerIn: parent; text: modelData[0]; font.pixelSize: root.px(17)
                                                color: parent.pp ? Colors.onAcc : Colors.fg }
                                        MouseArea { id: cbMa; anchors.fill: parent; hoverEnabled: true; cursorShape: root.blankCursor ? Qt.BlankCursor : Qt.PointingHandCursor
                                                    onClicked: modelData[1] === "prev" ? Player.previous() : modelData[1] === "next" ? Player.next() : Player.togglePlaying() }
                                    }
                                }
                            }
                        }
                        // прогресс: клик или перетаскивание — перемотка (если плеер умеет)
                        Item {
                            id: track
                            width: parent.width; height: root.px(10)
                            property real dragFrac: -1                 // во время перетаскивания — куда тянем
                            readonly property real frac: dragFrac >= 0 ? dragFrac : (Player.length > 0 ? Math.min(1, root.pos / Player.length) : 0)
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: root.px(4); radius: height / 2
                                        color: Colors.alpha(Colors.fg, 0.16) }
                            Rectangle { id: fill; anchors.verticalCenter: parent.verticalCenter; height: root.px(4); radius: height / 2; color: Colors.acc
                                        width: parent.width * track.frac
                                        Behavior on width { enabled: track.dragFrac < 0; NumberAnimation { duration: 1000 } } }
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; x: fill.width - width / 2
                                        width: root.px(10); height: width; radius: width / 2; color: Colors.fg; visible: Player.length > 0 }
                            MouseArea {
                                anchors.fill: parent; anchors.topMargin: -root.px(6); anchors.bottomMargin: -root.px(6)
                                enabled: Player.length > 0
                                hoverEnabled: true; cursorShape: root.blankCursor ? Qt.BlankCursor : Qt.PointingHandCursor
                                function frac(x) { return Math.max(0, Math.min(1, x / track.width)) }
                                onPressed: (m) => track.dragFrac = frac(m.x)
                                onPositionChanged: (m) => { if (pressed) track.dragFrac = frac(m.x) }
                                onReleased: { const t = track.dragFrac * Player.length; Player.seek(t); root.pos = t; track.dragFrac = -1 }
                                onCanceled: track.dragFrac = -1
                            }
                        }
                        RowLayout {
                            width: parent.width
                            Text { text: root.fmt(track.dragFrac >= 0 ? track.dragFrac * Player.length : root.pos); font.family: root.font
                                   font.pixelSize: root.px(11); font.features: root.tnum; color: Colors.fgDim }
                            Item { Layout.fillWidth: true }
                            Text { text: Player.length > 0 ? root.fmt(Player.length) : "–:––"; font.family: root.font
                                   font.pixelSize: root.px(11); font.features: root.tnum; color: Colors.fgDim }
                        }
                    }
                }

                // ---- уведомления: только число и приложения (без отправителей и текста) ----
                LockCard {
                    id: ntCard
                    u: root.u; order: 6; shown: root.started
                    width: root.px(270); height: cards.rowH
                    Column {
                        id: ntCol
                        width: parent.width
                        spacing: root.px(10)
                        Row {
                            spacing: root.px(12)
                            Rectangle {
                                width: root.px(44); height: width; radius: root.px(15)
                                color: Colors.alpha(Colors.acc, 0.2)
                                Glyph { anchors.centerIn: parent; text: root.notifCount > 0 ? "󰂚" : "󰂜"; font.pixelSize: root.px(20); color: Colors.acc }
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: root.px(2)
                                Text { text: root.notifCount > 0 ? root.notifCount + " " + root.plural(root.notifCount, "уведомление", "уведомления", "уведомлений") : "Нет уведомлений"
                                       font.family: root.font; font.pixelSize: root.px(16); font.weight: Font.DemiBold; font.features: root.tnum; color: Colors.fg }
                                Text { text: root.notifCount > 0 ? "текст скрыт до входа" : "всё прочитано"
                                       font.family: root.font; font.pixelSize: root.px(12.5); color: Colors.fgDim }
                            }
                        }
                        Flow {
                            visible: root.appChips.length > 0
                            width: parent.width
                            spacing: root.px(8)
                            Repeater {
                                model: root.appChips
                                Rectangle {
                                    required property var modelData
                                    width: chipRow.implicitWidth + root.px(17); height: root.px(28); radius: root.px(14)
                                    color: Colors.isl2
                                    Row {
                                        id: chipRow
                                        x: root.px(7); anchors.verticalCenter: parent.verticalCenter
                                        spacing: root.px(6)
                                        Glyph { anchors.verticalCenter: parent.verticalCenter; text: root.appIcon(modelData.app); font.pixelSize: root.px(15); color: Colors.acc }
                                        Text { anchors.verticalCenter: parent.verticalCenter
                                               text: root.appLabel(modelData.app) + (modelData.n > 1 ? " " + modelData.n : "")
                                               font.family: root.font; font.pixelSize: root.px(12.5); font.features: root.tnum; color: Colors.fg }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---- остров пароля (.pw, top 790, 380×58; ввод — 420 и кромка акцентом) ----
        LockCard {
            id: pw
            u: root.u; order: 7; shown: root.started
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.py(790)
            readonly property bool on: root.typing && !root.unlocked
            readonly property bool err: root.authState === "error"
            width: root.px(on ? 420 : 380)
            Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.BezierSpline; easing.bezierCurve: root.spring } }
            height: root.px(58)
            padX: 8; padY: 0; r: 29
            edgeW: on || err ? root.px(1.5) : 1
            edgeColor: err ? Colors.bad : on ? Colors.acc : Colors.edge
            // тряска: −14, +11, −7, +4 (keyframes shake, 450 мс)
            SequentialAnimation {
                id: shake
                NumberAnimation { target: pw; property: "shiftX"; to: -root.px(14); duration: 90; easing.type: Easing.OutQuad }
                NumberAnimation { target: pw; property: "shiftX"; to: root.px(11); duration: 90; easing.type: Easing.InOutQuad }
                NumberAnimation { target: pw; property: "shiftX"; to: -root.px(7); duration: 90; easing.type: Easing.InOutQuad }
                NumberAnimation { target: pw; property: "shiftX"; to: root.px(4); duration: 90; easing.type: Easing.InOutQuad }
                NumberAnimation { target: pw; property: "shiftX"; to: 0; duration: 90; easing.type: Easing.InQuad }
            }
            RowLayout {
                width: parent.width; height: parent.height
                spacing: root.px(12)
                // аватар 42: картинка или буква на градиенте акцента
                ClippingRectangle {
                    Layout.preferredWidth: root.px(42); Layout.preferredHeight: root.px(42)
                    radius: width / 2
                    Rectangle { anchors.fill: parent
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Colors.acc }
                            GradientStop { position: 1; color: Colors.acc5 }
                        } }
                    Image { id: avatar; anchors.fill: parent; source: root.avatarPath ? "file://" + root.avatarPath : ""; visible: status === Image.Ready
                            fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true; mipmap: true
                            sourceSize.width: Math.round(root.px(42) * root.dpr); sourceSize.height: Math.round(root.px(42) * root.dpr) }
                    Text { anchors.centerIn: parent; visible: !avatar.visible; text: root.shortName.charAt(0).toUpperCase()
                           font.family: root.font; font.pixelSize: root.px(16); font.weight: Font.Bold; color: Colors.onAcc }
                }
                // точки / подсказка; кольцо проверки — точки «дышат»
                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true
                    Text { anchors.verticalCenter: parent.verticalCenter; visible: input.text.length === 0
                           text: root.busy ? "Проверяю…" : "Пароль"
                           font.family: root.font; font.pixelSize: root.px(14); color: Colors.fgDim }
                    Row {
                        id: dots
                        anchors.verticalCenter: parent.verticalCenter
                        // длинный пароль — видны последние точки (поле не растёт)
                        x: Math.min(0, parent.width - width)
                        spacing: root.px(8)
                        opacity: root.busy ? 0.55 : 1
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        Repeater {
                            model: input.text.length
                            Rectangle {
                                width: root.px(9); height: width; radius: width / 2
                                color: Colors.fg
                                scale: 0
                                Component.onCompleted: scale = 1
                                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.34, 1.56, 0.64, 1, 1, 1] } }
                            }
                        }
                    }
                }
                // раскладка (29.10): чип RU/EN прямо в поле — видно, на каком языке вводится пароль; CAPS — оранжевым
                Rectangle {
                    Layout.preferredHeight: root.px(28)
                    Layout.preferredWidth: Math.max(root.px(38), layT.implicitWidth + root.px(16))
                    radius: height / 2
                    color: Brightness.caps ? Colors.alpha(Colors.warn, 0.22) : Colors.isl2
                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                    Text { id: layT; anchors.centerIn: parent
                           text: Brightness.caps ? root.layoutCode + " · CAPS" : root.layoutCode
                           font.family: root.font; font.pixelSize: root.px(12); font.weight: Font.Medium
                           color: Brightness.caps ? Colors.warn : Colors.fg }
                }
                // Touch ID: ждёт — акцент, промах — красный, нет сенсора — тусклый
                Rectangle {
                    Layout.preferredWidth: root.px(42); Layout.preferredHeight: root.px(42)
                    radius: width / 2
                    color: root.fpState === "miss" ? Colors.alpha(Colors.bad, 0.18) : Colors.isl2
                    Behavior on color { ColorAnimation { duration: 300 } }
                    Glyph {
                        id: fpIcon
                        anchors.centerIn: parent
                        text: "󰈷"; font.pixelSize: root.px(22)
                        color: root.fpState === "miss" ? Colors.bad : root.fpState === "wait" ? Colors.acc : Colors.fgDim
                        // ждёт касания — мягко «дышит»
                        SequentialAnimation on opacity {
                            running: root.active && root.fpState === "wait"; loops: Animation.Infinite
                            onRunningChanged: if (!running) fpIcon.opacity = 1
                            NumberAnimation { to: 0.55; duration: 1100; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: 1100; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
        }

        // ---- подсказка (.lhint, top 860): сообщение, Touch ID, Caps Lock ----
        LockCard {
            plain: true; u: root.u; order: 8; shown: root.started
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.py(860)
            width: hintT.implicitWidth; height: hintT.implicitHeight
            Text {
                id: hintT
                readonly property bool bad: root.msg === root.errorText || (!root.msg && root.fpState === "miss")
                text: root.msg ? root.msg
                      : root.fpState === "miss" ? root.fpText
                      : (Brightness.caps ? "Caps Lock включён · " : "")
                        + (root.typing ? "Enter — войти · Esc — назад" + (root.fpState === "wait" ? " · или Touch ID" : "")
                                       : root.fpState === "wait" ? "Введите пароль или приложите палец" : "Введите пароль")
                font.family: root.font; font.pixelSize: root.px(12.5)
                color: bad ? Colors.bad : Brightness.caps ? Colors.warn : Colors.fgDim
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }
    }


    // невидимое поле: принимает символы в любой раскладке; на экран — только точки
    TextInput {
        id: input
        width: 0; height: 0; opacity: 0
        focus: true
        echoMode: TextInput.Password
        readOnly: root.busy || root.unlocked
        onTextChanged: { if (text.length && (root.authState === "idle" || root.authState === "error")) root.authState = "typing"; idleTimer.restart(); root.typed(text) }
        Keys.onPressed: (e) => {
            if (root.unlocked) { e.accepted = true; return }
            if (e.key === Qt.Key_CapsLock) { capsLater.restart(); return }
            if (e.key === Qt.Key_Escape) {
                e.accepted = true
                if (root.busy) return
                if (text.length) { root.backToIdle(); return }
                root.backToIdle(); root.cancelled(); return
            }
            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                e.accepted = true
                if (root.authState === "idle") { root.startTyping(); return }
                if (!text.length || root.busy) return
                root.authState = "checking"
                root.submitted(text)
                return
            }
            if (root.authState === "idle") root.startTyping()
            if (root.authState === "error") root.authState = "typing"
            idleTimer.restart()
        }
    }
    Timer { id: capsLater; interval: 120; onTriggered: Brightness.refresh() }

    // растворение после «ok»
    Timer { id: dissolve; interval: root.dur + 20; onTriggered: root.dissolved() }   // «Остров»: растворение 520 мс (было 0,8 с)

    // ---------- данные ----------
    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string greeting: { const h = clock.date.getHours(); return h < 5 ? "Доброй ночи" : h < 12 ? "Доброе утро" : h < 18 ? "Добрый день" : h < 23 ? "Добрый вечер" : "Доброй ночи" }
    function fmt(t) { t = Math.max(0, Math.floor(t)); return Math.floor(t / 60) + ":" + String(t % 60).padStart(2, "0") }
    function plural(n, one, few, many) { const a = n % 10, b = n % 100; return a === 1 && b !== 11 ? one : (a >= 2 && a <= 4 && (b < 12 || b > 14)) ? few : many }


    // имя: GECOS → $USER без цифр с заглавной
    property string gecos: ""
    readonly property string user: Quickshell.env("USER") || "yumi"
    readonly property string statusUser: user.charAt(0).toUpperCase() + user.slice(1)
    readonly property string shortName: { const n = userName || gecos || user.replace(/[0-9_.-]+$/, ""); return n.charAt(0).toUpperCase() + n.slice(1) }
    Process { id: whoProc; command: ["getent", "passwd", root.user]
              stdout: SplitParser { onRead: (l) => { const g = (l.split(":")[4] || "").split(",")[0].trim(); if (g) root.gecos = g } } }

    // аватар: тот же, что у hyprlock (~/.config/hypr/hyprlock/avatar.jpg), иначе ~/.face, ~/.face.icon, ~/.config/yumi/avatar.*; нет файла — буква
    property string avatarPath: ""
    Process { id: avatarProc
              command: ["sh", "-c", "for f in \"$HOME/.config/hypr/hyprlock/avatar.jpg\" \"$HOME/.face\" \"$HOME/.face.icon\" \"$HOME\"/.config/yumi/avatar.*; do [ -f \"$f\" ] && { echo \"$f\"; exit; }; done; true"]
              stdout: SplitParser { onRead: (l) => root.avatarPath = l.trim() } }

    // раскладка: сначала hyprctl devices (основная клавиатура), дальше — событие activelayout
    property string layoutCode: "—"
    function code(km) { return km.indexOf("Russian") >= 0 ? "RU" : km.indexOf("Ukrain") >= 0 ? "UA" : km.indexOf("English") >= 0 ? "EN" : km.indexOf("Italian") >= 0 ? "IT" : km.slice(0, 2).toUpperCase() }
    Process { id: layoutProc; command: ["hyprctl", "devices", "-j"]
              stdout: StdioCollector { onStreamFinished: { try { const ks = JSON.parse(text).keyboards; const k = ks.find(x => x.main) ?? ks[0]; if (k) root.layoutCode = root.code(k.active_keymap) } catch (e) {} } } }
    Connections { target: Hyprland; function onRawEvent(ev) { if (ev.name === "activelayout") root.layoutCode = root.code(ev.data.split(",").pop()) } }

    // сеть: те же скрипты, что у пилюль бара (только показ)
    BarScript { id: wifi; command: [Quickshell.env("HOME") + "/.local/lib/yumi/bar/wifi"]; interval: 15; enabled: root.active }
    BarScript { id: bt; command: [Quickshell.env("HOME") + "/.local/lib/yumi/bar/bt"]; interval: 15; enabled: root.active }
    BarScript { id: vpn; command: [Quickshell.env("HOME") + "/.local/lib/yumi/bar/vpn"]; interval: 20; enabled: root.active }
    readonly property string wifiText: {
        if (!wifi.ok) return ""
        if (wifi.cls.indexOf("connected") === 0) { const m = /<b>([^<]*)<\/b>/.exec(wifi.tooltip); return "󰖩 " + (m ? m[1].replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&quot;/g, "\"") : "Wi‑Fi") }
        return wifi.raw
    }
    readonly property string vpnText: vpn.ok && vpn.cls === "connected" ? "󰖂 " + vpn.tooltip.replace(/<[^>]*>/g, "").replace(/^VPN:\s*/, "") : "󰖂 выкл"
    // «Остров»: остров статуса — значки без текста; "" — скрипт Wi-Fi не ответил (значок не показываем)
    readonly property string wifiOn: !wifi.ok ? "" : wifi.cls.indexOf("connected") === 0 ? "on" : "off"
    readonly property bool vpnOn: vpn.ok && vpn.cls === "connected"
    // батарея — UPower (как модуль бара Battery); нет батареи — −1, не показываем
    readonly property var batDev: UPower.displayDevice
    readonly property int batPct: batDev && batDev.isLaptopBattery ? Math.round(batDev.percentage * 100) : -1
    readonly property bool batCharging: batDev ? batDev.state === UPowerDeviceState.Charging : false
    readonly property bool batLow: batPct >= 0 && batPct <= 15 && !batCharging
    readonly property string batIcon: batCharging ? "󰂄" : ["󰂎","󰁺","󰁻","󰁼","󰁽","󰁾","󰁿","󰂀","󰂁","󰂂","󰁹"][Math.max(0, Math.min(10, Math.round(batPct / 10)))]

    // уведомления: чипы «приложение число» — из notifCounts, иначе по именам из notifApps; не больше трёх
    readonly property var appChips: (notifCounts.length ? notifCounts : notifApps.map(a => ({ app: a, n: 0 }))).slice(0, 3)
    function appLabel(a) { const s = String(a || ""); const l = s.toLowerCase()
        return l.indexOf("telegram") >= 0 ? "Telegram" : l.indexOf("yumi-backup") >= 0 || l.indexOf("borg") >= 0 ? "Бэкап" : l.indexOf("update") >= 0 ? "Обновления"
             : s.length > 14 ? s.slice(0, 13) + "…" : s }
    function appIcon(a) { const l = String(a || "").toLowerCase()
        return l.indexOf("telegram") >= 0 ? "󰒊" : l.indexOf("discord") >= 0 || l.indexOf("vesktop") >= 0 ? "󰙯"
             : l.indexOf("chrom") >= 0 || l.indexOf("zen") >= 0 || l.indexOf("firefox") >= 0 ? "󰊯"
             : l.indexOf("backup") >= 0 || l.indexOf("borg") >= 0 ? "󰁯" : l.indexOf("update") >= 0 ? "󰚰"
             : l.indexOf("music") >= 0 || l.indexOf("player") >= 0 ? "󰝚" : "󰂚" }

    // погода: бэкенд ~/.local/lib/yumi/qs/weather (кэш 30 мин, офлайн — кэш с пометкой времени)
    QtObject {
        id: weather
        property bool ok: false
        property bool off: false        // бэкенд: unconfigured — нет weather.conf
        property string error: ""
        property var now: ({})
        property var hours: []
        property string place: ""
        property real at: 0
        property bool stale: false
    }
    Process {
        id: wxProc
        command: ["python3", "-I", Quickshell.env("HOME") + "/.local/lib/yumi/qs/weather"]
        stdout: SplitParser { onRead: (l) => {
            let j; try { j = JSON.parse(l) } catch (e) { return }
            if (j.error) { weather.off = !!j.unconfigured; if (!weather.ok) weather.error = j.error; return }
            weather.off = false
            weather.now = j.now || {}; weather.hours = j.hours || []; weather.place = j.place || ""; weather.at = j.at || 0
            weather.stale = !!j.stale; weather.ok = true } }
        stderr: SplitParser { onRead: (l) => { if (l.trim()) console.log("lock-weather:", l) } }
    }
    Timer { interval: 30 * 60 * 1000; running: root.active; repeat: true; triggeredOnStart: true; onTriggered: wxProc.running = true }

    // музыка: позицию опрашивает сам Player, пока выставлен Player.lockOpen (его держит владелец: LockPreview / LockReal);
    // здесь только снимаем значения — полоса, время и строка текста догоняют новый трек за ≤ 0,5 с
    property real pos: 0
    property string lyricTarget: ""
    Connections { target: Player; function onTrackKeyChanged() { root.pos = 0; root.lyricTarget = "" } }
    Timer {
        interval: 500; repeat: true; triggeredOnStart: true
        running: root.active && Player.shown
        onTriggered: {
            root.pos = Player.position()
            if (Player.lyricsSynced && Player.lyrics.length) { const i = Player.lyricIndex(); root.lyricTarget = i >= 0 ? Player.lyrics[i][1] : "" }
            else root.lyricTarget = ""
        }
    }

    // ---------- заглушка на втором мониторе ----------
    Rectangle {
        anchors.fill: parent
        z: 900
        visible: root.placeholder
        color: "black"
        Column {
            anchors.centerIn: parent
            spacing: 26
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 160; height: 160
                source: Qt.resolvedUrl("boot-logo.png"); sourceSize.width: 256; sourceSize.height: 256
                smooth: true; opacity: 0.85
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                font.family: Theme.fontUi; font.pixelSize: 44; font.weight: Font.Light
                color: Qt.rgba(1, 1, 1, 0.7)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: input.text.length ? "•".repeat(Math.min(input.text.length, 24)) : "Введите пароль"   // можно печатать и здесь (16.10)
                font.family: Theme.fontUi; font.pixelSize: 15
                color: Qt.rgba(1, 1, 1, input.text.length ? 0.8 : 0.35)
            }
        }
    }

    // ---------- вход при загрузке «из логотипа» ----------
    // Первый кадр = финальный кадр заставки Plymouth (тема yumi, DeviceScale=1) и фон Hyprland (wall0.png): чёрный,
    // логотип 256×256, полоска 160/160 (100 %), три точки 0.6, подпись «Starting session...» — в тех же физических пикселях
    // (координаты — шапка docs/boot/plymouth/yumi/yumi.script). Дальше точки снова «дышат»; когда обои загрузились
    // (или через 0,5 с) — всё растворяется, проявляется экран блокировки.
    // Клавиши во время растворения уже вводят пароль.
    Item {
        id: intro
        anchors.fill: parent
        z: 1000
        visible: root.bootIntro && opacity > 0
        // настоящий масштаб монитора (Qt округляет дробный 1.6 до 2 → всё было на 20 % меньше). С первого кадра:
        // yumi-lock --boot заранее пишет `hyprctl monitors -j` в $XDG_RUNTIME_DIR/yumi-monitors.json — читаем синхронно
        // (16.10: масштаб от Hyprland.monitorFor приходил на кадр позже → логотип «прыгал» в размере)
        FileView { id: monFile; path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/yumi-monitors.json"
                   blockLoading: true; printErrors: false }
        readonly property real sc: {
            try {
                const m = JSON.parse(monFile.text()).find(x => x.name === root.screenName)
                if (m && m.scale > 0) return m.scale
            } catch (e) {}
            return root.dpr
        }
        // физический центр экрана и перевод физических px → логические (как у Plymouth: Math.Int(W/2))
        readonly property int pcx: Math.floor(Math.round(width * sc) / 2)
        readonly property int pcy: Math.floor(Math.round(height * sc) / 2)
        function lx(off) { return (pcx + off) / sc }
        function ly(off) { return (pcy + off) / sc }
        function ls(n) { return n / sc }

        property bool go: false                    // растворение
        property real breathe: 1                   // точки дышат сразу — продолжение заставки, без замирания
        // полоска и «дыхание» — продолжение заставки yumi-splash (окно в Hyprland): длина — из
        // $XDG_RUNTIME_DIR/yumi-splash-bar, время — от старта ядра (/proc/uptime), как у неё (16.10)
        FileView { id: barFile; path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/yumi-splash-bar"
                   blockLoading: true; printErrors: false }
        FileView { id: upFile; path: "/proc/uptime"; blockLoading: true; printErrors: false }
        readonly property real bar0: { const v = parseFloat((barFile.text() || "").split(" ")[0]); return v > 0 && v <= 160 ? v : 155 }
        readonly property real up0: { const v = parseFloat((upFile.text() || "").split(" ")[0]); return v > 0 ? v : 0 }
        readonly property double ms0: Date.now()
        property real barPx: bar0                  // длина полоски, физ. px — с того места, где остановилась заставка
        property real t: up0 * 50                  // «тик» дыхания точек: время от старта ядра × 50, как у заставки
        FrameAnimation {
            running: intro.visible
            property int gaps: 0
            onTriggered: {
                intro.t = (intro.up0 + (Date.now() - intro.ms0) / 1000) * 50
                // журнал рывков входа при загрузке (16.10, «подлагивает на 97 %»): journalctl --user -u yumi-quickshell | grep yumi-intro
                if (frameTime > 0.030 && gaps < 40) { gaps++; console.log("yumi-intro: кадр через " + Math.round(frameTime * 1000) + " мс, uptime " + (intro.up0 + (Date.now() - intro.ms0) / 1000).toFixed(2)) }
            }
        }
        readonly property bool ready: wallImg.status === Image.Ready || wallImg.status === Image.Error
        onReadyChanged: if (ready && root.bootIntro) finish.start()
        Component.onCompleted: if (root.bootIntro && ready) finish.start()
        Timer { running: root.bootIntro; interval: 250; onTriggered: if (!finish.running && !intro.go) finish.start() }
        SequentialAnimation {
            id: finish
            // загрузка закончилась: полоска доходит до 100 %, потом всё растворяется в экран блокировки
            // флаг для заставки Touch Bar (yumi-splash): тот же финал там — 200 мс, без паузы, растворение 400 мс
            // (18.10, ускорение загрузки: было 380 / 120 / 650 мс; копия LockSurface.qml.bak-speed-20261018)
            ScriptAction { script: Quickshell.execDetached(["touch", (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/yumi-intro-finish"]) }
            NumberAnimation { target: intro; property: "barPx"; to: 160; duration: 200; easing.type: Easing.OutCubic }
            ScriptAction { script: {
                intro.go = true; root.started = true; root.introFinished()
                // 18.10: курсор при загрузке не возвращаем — он появится на рабочем столе при первом движении мыши
                // (yumi-cursor-wait --after-unlock из env.lua). Было: yumi-cursor-restore здесь
                Quickshell.execDetached(["sh", "-c", "sleep 1; pkill -x swaybg"])
            } }
        }
        // растворение целиком: логотип, полоска, точки и чёрный фон уходят вместе — без чёрной паузы
        opacity: go ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.InOutQuad } }
        onOpacityChanged: if (go && opacity <= 0) root.introGone()
        Rectangle { anchors.fill: parent; color: "black" }
        Item {
            anchors.fill: parent
            Image {
                x: intro.lx(-128); y: intro.ly(-128); width: intro.ls(256); height: width
                source: Qt.resolvedUrl("boot-logo.png"); sourceSize.width: 256; sourceSize.height: 256; smooth: false
            }
            // полоска 160×2: фон 0.18 и заполнение
            Rectangle { x: intro.lx(-80); y: intro.ly(184); width: intro.ls(160); height: intro.ls(2); color: Qt.rgba(232/255, 232/255, 232/255, 0.18) }
            Rectangle { x: intro.lx(-80); y: intro.ly(184); width: intro.ls(Math.round(intro.barPx)); height: intro.ls(2); color: "#e8e8e8" }
            Repeater {
                model: 3
                Image {
                    required property int index
                    x: intro.lx(-21 + index * 14); y: intro.ly(204); width: intro.ls(6); height: width
                    source: Qt.resolvedUrl("boot-dot.png"); sourceSize.width: 6; sourceSize.height: 6; smooth: false
                    // та же формула, что у Plymouth: 0.25 + 0.75·max(0, sin(t/9 − i·0.9))
                    readonly property real breath: 0.25 + 0.75 * Math.max(0, Math.sin(intro.t / 9 - index * 0.9))
                    opacity: 0.6 * (1 - intro.breathe) + breath * intro.breathe
                }
            }
            Image {
                x: intro.lx(-160); y: intro.ly(228); width: intro.ls(320); height: intro.ls(30)
                source: Qt.resolvedUrl("boot-caption.png"); sourceSize.width: 320; sourceSize.height: 30; smooth: false
            }
        }
    }

    // 18.10: при загрузке над экраном блокировки курсор пустой (Hyprland вернул его в момент блокировки — патч);
    // клики не перехватывает (NoButton), кнопки со своим cursorShape остаются как есть. Показ — yumi-cursor-wait
    MouseArea {
        anchors.fill: parent; z: -1
        acceptedButtons: Qt.NoButton; hoverEnabled: true
        cursorShape: root.blankCursor ? Qt.BlankCursor : Qt.ArrowCursor
    }
}
