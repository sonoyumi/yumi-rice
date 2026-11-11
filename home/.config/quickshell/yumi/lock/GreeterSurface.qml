import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.components
import qs.services

// Экран входа «D · терминальный в цветах A» (29.10.2026, макет greeter-DA.html, .vD): чёрный фон, как у загрузки,
// с едва заметной сеткой 40 px; сверху строка 46 px (печать загрузки, Yumi-Rice, «greetd · tty1 · сеанса нет»,
// Wi-Fi, время); слева крупная красная печать загрузки, справа «Вход в систему · сеанс не запущен», заголовок
// (причина выхода, если известна), журнал моноширинным и форма: логин, сеанс, пароль с нижней чертой.
// Цвет обоев на экране один — черта поля при вводе (Colors.acc). Снизу F1 Сон · F2 Перезагрузка · F3 Выключение
// (каждое — по второму нажатию за 3 с; F1–F3 работают и из поля пароля).
// Причина выхода — /var/lib/yumi-greeter/last-session.json ({"ended": unix, "code": rc}), его пишет
// ~/.local/bin/yumi-hyprland-session после выхода Hyprland; файла нет или он старше 12 ч — «сеанс не запущен».
// Тот же договор, что у LockSurface (greeter.qml не знает разницы): submitted(pw) → владелец отвечает
// authState = "error" (тряска, красная черта) или "ok" (растворение 450 мс → dissolved()). Пароль здесь НЕ проверяется.
//   authState: idle | typing | checking | error | ok
Item {
    id: root
    // ---------- наружу (как у LockSurface) ----------
    property string authState: "idle"
    property bool active: true
    property string errorText: "Неверный пароль"
    property string userName: ""               // пусто — $USER (логин пользователя)
    property string screenName: ""
    property bool placeholder: false           // второй монитор при открытом ноутбуке — заглушка, ввод на Mac
    property string sharedText: ""
    property string sessionName: "Hyprland"
    property bool capsDemo: false              // только dev-greeter: показать CAPS без клавиши
    signal typed(string t)
    signal submitted(string pw)
    signal cancelled()
    signal dissolved()
    signal power(string action)
    onSharedTextChanged: if (input.text !== sharedText) input.text = sharedText

    readonly property real u: Math.max(0.6, Math.min(width / 1600, height / 1000))
    function px(n) { return Math.max(1, Math.round(n * u)) }
    readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
    readonly property string font: Theme.fontUi
    readonly property string mono: "JetBrainsMonoNL Nerd Font"     // системный (/usr/share/fonts) — виден greeter
    readonly property var tnum: ({ "tnum": 1 })
    // гамма «A»: чёрный, как загрузка; красный печати; цвет обоев — только черта поля
    readonly property color cBar: "#0b0b0c"
    readonly property color cLine: Qt.rgba(1, 1, 1, 0.078)
    readonly property color cText: "#ececec"
    readonly property color cSoft: "#d6d6d6"
    readonly property color cDim: "#8d8d93"
    readonly property color cLog: "#9a9aa0"
    readonly property color cRed: "#e05a4e"
    readonly property color cWarm: "#e8a06a"
    readonly property color cKey: "#1b1b1d"
    readonly property color cKey2: "#161618"

    readonly property bool typing: authState !== "idle"
    readonly property bool busy: authState === "checking"
    readonly property bool unlocked: authState === "ok"
    readonly property bool caps: Brightness.caps || capsDemo
    readonly property double startedAt: Date.now()
    Component.onCompleted: { input.forceActiveFocus(); Brightness.refresh(); avatarProc.running = true }

    // ---------- состояние ввода (как у LockSurface) ----------
    function typeDemo(t) { if (authState === "idle") authState = "typing"; input.text = t }
    function submitDemo() { if (input.text.length && !busy) { authState = "checking"; submitted(input.text) } }
    function backToIdle() { input.text = ""; authState = "idle"; msg = ""; input.forceActiveFocus() }
    onActiveChanged: if (active) { dissolve.stop(); backToIdle() }
    property string msg: ""
    onAuthStateChanged: {
        if (authState === "error") { input.text = ""; msg = errorText; shake.restart(); errTimer.restart() }
        else if (authState === "checking") msg = "Проверяю…"
        else if (authState === "ok") { msg = ""; dissolve.restart() }
        else if (authState === "idle") msg = ""
    }
    Timer { id: errTimer; interval: 1200; onTriggered: if (root.authState === "error") root.authState = "typing" }
    Timer { id: idleTimer; interval: 30000; running: root.authState === "typing" && input.text.length > 0; onTriggered: root.backToIdle() }
    Timer { id: dissolve; interval: 470; onTriggered: root.dissolved() }

    // питание: каждое действие — по второму нажатию за 3 с (мышь или F1–F3)
    property string armedAction: ""
    Timer { id: armTimer; interval: 3000; onTriggered: root.armedAction = "" }
    function press(a) {
        if (root.armedAction === a) { armTimer.stop(); root.armedAction = ""; root.power(a) }
        else { root.armedAction = a; armTimer.restart() }
        input.forceActiveFocus()
    }
    readonly property var powers: [["suspend", "Сон"], ["reboot", "Перезагрузка"], ["poweroff", "Выключение"]]
    readonly property string armedLabel: { const p = powers.find(x => x[0] === armedAction); return p ? p[1].toLowerCase() : "" }

    // ---------- причина выхода ----------
    // HOME экрана входа = /var/lib/yumi-greeter/home → файл в его родителе; иначе (превью) — тот же системный путь.
    // YUMI_GREETER_LAST — свой файл для проверки вида (dev-greeter)
    readonly property string lastPath: {
        const e = Quickshell.env("YUMI_GREETER_LAST"); if (e) return e
        const h = Quickshell.env("HOME") || ""
        return h.endsWith("/home") ? h.slice(0, -5) + "/last-session.json" : "/var/lib/yumi-greeter/last-session.json"
    }
    FileView { id: lastFile; path: root.lastPath; blockLoading: true; printErrors: false }
    readonly property var last: {
        try {
            const j = JSON.parse(lastFile.text() || "")
            const age = startedAt / 1000 - j.ended
            if (j.ended > 0 && age >= -60 && age < 12 * 3600) return j
        } catch (e) {}
        return null
    }
    function hms(d) { return Qt.formatDateTime(d, "HH:mm:ss") }
    readonly property string endedAt: last ? hms(new Date(last.ended * 1000)) : ""
    readonly property string greetAt: hms(new Date(startedAt))
    // строки журнала: [время, источник, текст, тёплым?]
    readonly property var logLines: last
        ? [[endedAt, "hyprland", "завершился (код " + last.code + ")", true],
           [endedAt, "greetd", "сеанс " + login + " закрыт, окна закрыты", false],
           [greetAt, "greetd", "экран входа запущен — ждёт пароль", false]]
        : [[greetAt, "greetd", "сеанс не запущен", false],
           [greetAt, "greetd", "экран входа запущен — ждёт пароль", false]]

    // ---------- сцена ----------
    Item {
        id: scene
        anchors.fill: parent
        opacity: root.unlocked ? 0 : 1
        scale: root.unlocked ? 0.98 : 1
        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.InQuad } }
        Behavior on scale { NumberAnimation { duration: 450; easing.type: Easing.InQuad } }

        Rectangle { anchors.fill: parent; color: "#000000" }
        // сетка 40 px, белые линии 4 %, к краям гаснет (маска radial-gradient 30 % → 75 %); рисуется один раз
        Canvas {
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const c = getContext("2d"), w = width, h = height, s = 40 * root.u
                c.reset()
                c.fillStyle = "rgba(255,255,255,0.04)"
                for (let x = 0; x < w; x += s) c.fillRect(Math.round(x), 0, 1, h)
                for (let y = 0; y < h; y += s) c.fillRect(0, Math.round(y), w, 1)
                c.globalCompositeOperation = "destination-in"
                c.save()
                c.translate(w * 0.45, h * 0.5)
                c.scale(w * 0.62, h * 0.62)
                const g = c.createRadialGradient(0, 0, 0, 0, 0, 1)
                g.addColorStop(0, "rgba(0,0,0,1)"); g.addColorStop(0.3, "rgba(0,0,0,1)")
                g.addColorStop(0.75, "rgba(0,0,0,0)"); g.addColorStop(1, "rgba(0,0,0,0)")
                c.fillStyle = g
                c.fillRect(-2, -2, 4, 4)
                c.restore()
            }
        }

        // ---- верхняя строка 46 px ----
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: root.px(46)
            color: root.cBar
            Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: root.cLine }
            RowLayout {
                anchors { fill: parent; leftMargin: root.px(18); rightMargin: root.px(18) }
                spacing: root.px(14)
                ClippingRectangle {
                    Layout.preferredWidth: root.px(26); Layout.preferredHeight: root.px(26); radius: root.px(5); color: "black"
                    Image { anchors.fill: parent; source: Qt.resolvedUrl("boot-logo.png"); smooth: true; mipmap: true
                            sourceSize.width: 128; sourceSize.height: 128 }
                }
                Text { text: "Yumi-Rice"; font.family: root.font; font.pixelSize: root.px(13); font.weight: Font.DemiBold; color: root.cText }
                Text { text: "greetd · tty1 · сеанса нет"; font.family: root.mono; font.pixelSize: root.px(12.5); color: root.cDim }
                Item { Layout.fillWidth: true }
                Row {
                    visible: root.wifiOn !== ""
                    spacing: root.px(7)
                    Glyph { anchors.verticalCenter: parent.verticalCenter; text: root.wifiOn === "on" ? "󰖩" : "󰖪"; font.pixelSize: root.px(16); color: root.cSoft }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: root.wifiName || (root.wifiOn === "on" ? "Wi‑Fi" : "Нет сети")
                           font.family: root.font; font.pixelSize: root.px(13); color: root.cSoft }
                }
                Row {
                    spacing: root.px(7)
                    Text { text: Qt.formatDateTime(clock.date, "HH:mm"); font.family: root.font; font.pixelSize: root.px(13)
                           font.weight: Font.Bold; font.features: root.tnum; color: root.cSoft }
                    Text { text: clock.date.toLocaleDateString(Qt.locale("ru_RU"), "dddd, d MMMM"); font.family: root.font
                           font.pixelSize: root.px(13); color: root.cDim }
                }
            }
        }

        // ---- центральная композиция (макет: печать 210,236; блок 470,226 шириной 820) — держится середины ----
        Item {
            width: root.px(1600); height: root.px(1000)
            anchors.centerIn: parent

            Image {
                x: root.px(210); y: root.px(236)
                width: root.px(210); height: width
                source: Qt.resolvedUrl("boot-logo.png"); smooth: true; mipmap: true
                sourceSize.width: 256; sourceSize.height: 256
            }

            Column {
                x: root.px(470); y: root.px(226)
                width: root.px(820)
                spacing: 0

                Text { text: "ВХОД В СИСТЕМУ · СЕАНС НЕ ЗАПУЩЕН"; font.family: root.font; font.pixelSize: root.px(12)
                       font.weight: Font.DemiBold; font.letterSpacing: root.px(12) * 0.14; color: root.cRed }
                Text { topPadding: root.px(6); bottomPadding: root.px(22)
                       text: root.last ? "Hyprland завершился" : "Вход в систему"
                       font.family: root.font; font.pixelSize: root.px(40); font.weight: Font.DemiBold
                       font.letterSpacing: -root.px(40) * 0.02; color: root.cText }

                // журнал
                Rectangle {
                    width: parent.width
                    height: logCol.implicitHeight + root.px(14) * 2
                    radius: root.px(16)
                    color: "#0c0c0d"
                    border.width: 1; border.color: root.cLine
                    Column {
                        id: logCol
                        x: root.px(18); y: root.px(14)
                        Repeater {
                            model: root.logLines
                            Row {
                                required property var modelData
                                height: root.px(24.5)
                                Text { anchors.verticalCenter: parent.verticalCenter; text: modelData[0] + "  "
                                       font.family: root.mono; font.pixelSize: root.px(14); color: root.cRed }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: (modelData[1] + "           ").slice(0, 11)
                                       font.family: root.mono; font.pixelSize: root.px(14); color: root.cLog }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: modelData[2]
                                       font.family: root.mono; font.pixelSize: root.px(14); color: modelData[3] ? root.cWarm : root.cLog }
                            }
                        }
                    }
                }

                Item { width: 1; height: root.px(26) }

                // форма: подписи 150 px, моноширинный 18
                GridLayout {
                    width: parent.width
                    columns: 2
                    columnSpacing: 0; rowSpacing: root.px(14)

                    Text { Layout.preferredWidth: root.px(150); text: "логин:"; font.family: root.mono; font.pixelSize: root.px(18); color: root.cDim }
                    Row {
                        spacing: root.px(10)
                        ClippingRectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.px(30); height: width; radius: width / 2; color: root.cKey
                            Image { id: avatar; anchors.fill: parent; source: root.avatarPath ? "file://" + root.avatarPath : ""; visible: status === Image.Ready
                                    fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true; mipmap: true
                                    sourceSize.width: Math.round(root.px(30) * root.dpr); sourceSize.height: Math.round(root.px(30) * root.dpr) }
                            Text { anchors.centerIn: parent; visible: !avatar.visible; text: root.login.charAt(0).toUpperCase()
                                   font.family: root.font; font.pixelSize: root.px(13); font.weight: Font.Bold; color: root.cText }
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: root.login; font.family: root.mono; font.pixelSize: root.px(18); color: root.cText }
                    }

                    Text { text: "сеанс:"; font.family: root.mono; font.pixelSize: root.px(18); color: root.cDim }
                    Rectangle {
                        implicitWidth: sessRow.implicitWidth + root.px(12) * 2; implicitHeight: root.px(34)
                        radius: root.px(10); color: "transparent"
                        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.15)
                        Row {
                            id: sessRow
                            anchors.centerIn: parent
                            spacing: root.px(8)
                            Glyph { anchors.verticalCenter: parent.verticalCenter; text: "󰍹"; font.pixelSize: root.px(16); color: root.cText }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: root.sessionName; font.family: root.mono
                                   font.pixelSize: root.px(16); font.weight: Font.Medium; color: root.cText }
                        }
                    }

                    Text { text: "пароль:"; font.family: root.mono; font.pixelSize: root.px(18); color: root.cDim }
                    Row {
                        id: pwRow
                        spacing: root.px(12)
                        readonly property bool err: root.authState === "error"
                        readonly property bool hot: root.typing || (input.activeFocus && Window.active)
                        transform: Translate { id: shakeX }
                        SequentialAnimation {
                            id: shake
                            NumberAnimation { target: shakeX; property: "x"; to: -root.px(14); duration: 90; easing.type: Easing.OutQuad }
                            NumberAnimation { target: shakeX; property: "x"; to: root.px(11); duration: 90; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: shakeX; property: "x"; to: -root.px(7); duration: 90; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: shakeX; property: "x"; to: root.px(4); duration: 90; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 90; easing.type: Easing.InQuad }
                        }
                        Glyph { anchors.verticalCenter: parent.verticalCenter; text: "󰌾"; font.pixelSize: root.px(18); color: root.cDim }
                        // поле с нижней чертой: точки моноширинным; ввод — черта акцентом обоев, ошибка — красная
                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.px(330); height: root.px(38)
                            clip: true
                            Text { anchors.verticalCenter: parent.verticalCenter; x: root.px(2); visible: input.text.length === 0
                                   text: root.busy ? "проверяю…" : "Пароль"
                                   font.family: root.mono; font.pixelSize: root.px(15); color: root.cDim }
                            Text { anchors.verticalCenter: parent.verticalCenter
                                   x: Math.min(root.px(2), parent.width - width - root.px(2))
                                   text: "•".repeat(input.text.length)
                                   font.family: root.mono; font.pixelSize: root.px(18); font.weight: Font.Medium
                                   font.letterSpacing: root.px(18) * 0.2; color: root.cText
                                   opacity: root.busy ? 0.55 : 1 }
                            Rectangle {
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                height: Math.max(1, root.px(1.5))
                                color: pwRow.err ? Colors.bad : pwRow.hot ? Colors.acc : Qt.rgba(1, 1, 1, 0.19)
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                        }
                        // CAPS (горит тёплым, если включён) · EN (в sway экрана входа раскладка одна — us)
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(root.px(40), capsT.implicitWidth + root.px(18)); height: root.px(28); radius: root.px(8)
                            color: root.caps ? Qt.rgba(245 / 255, 169 / 255, 127 / 255, 0.22) : "transparent"
                            Behavior on color { ColorAnimation { duration: 200 } }
                            Text { id: capsT; anchors.centerIn: parent; text: "CAPS"; font.family: root.mono; font.pixelSize: root.px(12)
                                   font.weight: Font.DemiBold; font.letterSpacing: root.px(12) * 0.04
                                   color: root.caps ? Colors.warn : Qt.rgba(236 / 255, 236 / 255, 236 / 255, 0.3) }
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(root.px(40), kbT.implicitWidth + root.px(18)); height: root.px(28); radius: root.px(8)
                            color: root.cKey
                            Text { id: kbT; anchors.centerIn: parent; text: "EN"; font.family: root.mono; font.pixelSize: root.px(12)
                                   font.weight: Font.DemiBold; color: root.cSoft }
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.px(46); height: root.px(36); radius: root.px(10)
                            color: goMa.containsMouse ? "#26262a" : root.cKey
                            Behavior on color { ColorAnimation { duration: 150 } }
                            scale: goMa.pressed ? 0.94 : 1
                            Behavior on scale { NumberAnimation { duration: 120 } }
                            Glyph { anchors.centerIn: parent; text: "󰁔"; font.pixelSize: root.px(16); color: root.cSoft }
                            MouseArea { id: goMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { root.submitDemo(); input.forceActiveFocus() } }
                        }
                    }

                    Item { implicitHeight: 1 }
                    Text {
                        readonly property bool bad: root.msg === root.errorText
                        text: root.msg ? root.msg
                              : root.armedAction ? "Ещё раз — " + root.armedLabel
                              : root.caps ? "Caps Lock включён · Enter — войти"
                              : "Enter — войти · F1–F3 — питание"
                        font.family: root.mono; font.pixelSize: root.px(13)
                        color: bad || root.armedAction ? Colors.bad : root.caps ? Colors.warn : root.cDim
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
            }
        }

        // ---- нижняя строка 52 px: F1–F3 питание ----
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: root.px(52)
            color: root.cBar
            Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 1; color: root.cLine }
            RowLayout {
                anchors { fill: parent; leftMargin: root.px(14); rightMargin: root.px(14) }
                spacing: root.px(10)
                Repeater {
                    model: root.powers
                    Rectangle {
                        id: fk
                        required property var modelData
                        required property int index
                        readonly property bool armed: root.armedAction === modelData[0]
                        implicitWidth: fkRow.implicitWidth + root.px(5) + root.px(12); implicitHeight: root.px(34)
                        radius: root.px(10)
                        color: fkMa.containsMouse ? root.cKey2 : "transparent"
                        Behavior on color { ColorAnimation { duration: 200 } }
                        scale: fkMa.pressed ? 0.96 : 1
                        Behavior on scale { NumberAnimation { duration: 120 } }
                        Row {
                            id: fkRow
                            x: root.px(5); anchors.verticalCenter: parent.verticalCenter
                            spacing: root.px(9)
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: kbd.implicitWidth + root.px(14); height: kbd.implicitHeight + root.px(8); radius: root.px(7)
                                color: root.cKey2
                                Text { id: kbd; anchors.centerIn: parent; text: "F" + (fk.index + 1); font.family: root.mono
                                       font.pixelSize: root.px(12); font.weight: Font.DemiBold; color: fk.armed ? Colors.bad : root.cRed }
                            }
                            Text { anchors.verticalCenter: parent.verticalCenter
                                   text: fk.armed ? "Ещё раз — " + fk.modelData[1].toLowerCase() : fk.modelData[1]
                                   font.family: root.font; font.pixelSize: root.px(13); font.weight: Font.Medium
                                   color: fk.armed ? Colors.bad : root.cSoft }
                        }
                        MouseArea { id: fkMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.press(fk.modelData[0]) }
                    }
                }
                Item { Layout.fillWidth: true }
                Text { text: "Arch Linux ARM · MacBook Air M1"; font.family: root.mono; font.pixelSize: root.px(12.5); color: root.cDim }
            }
        }
    }

    // невидимое поле: символы в любой раскладке; на экран — только точки
    TextInput {
        id: input
        width: 0; height: 0; opacity: 0
        focus: true
        echoMode: TextInput.Password
        readOnly: root.busy || root.unlocked
        onTextChanged: { if (text.length && (root.authState === "idle" || root.authState === "error")) root.authState = "typing"; root.typed(text) }
        Keys.onPressed: (e) => {
            if (root.unlocked) { e.accepted = true; return }
            if (e.key === Qt.Key_F1 || e.key === Qt.Key_F2 || e.key === Qt.Key_F3) {
                e.accepted = true
                root.press(root.powers[e.key - Qt.Key_F1][0]); return
            }
            if (e.key === Qt.Key_CapsLock) { capsLater.restart(); return }
            if (e.key === Qt.Key_Escape) {
                e.accepted = true
                if (root.busy) return
                if (root.armedAction) { armTimer.stop(); root.armedAction = ""; return }
                const had = text.length > 0
                root.backToIdle(); if (!had) root.cancelled(); return
            }
            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                e.accepted = true
                if (!text.length || root.busy) return
                root.authState = "checking"
                root.submitted(text)
                return
            }
            if (root.authState === "error") root.authState = "typing"
        }
    }
    Timer { id: capsLater; interval: 120; onTriggered: Brightness.refresh() }

    // ---------- данные ----------
    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string user: Quickshell.env("USER") || "yumi"
    readonly property string login: userName || user

    property string avatarPath: ""
    Process { id: avatarProc
              command: ["sh", "-c", "for f in \"$HOME/.config/hypr/hyprlock/avatar.jpg\" \"$HOME/.face\" \"$HOME/.face.icon\" \"$HOME\"/.config/yumi/avatar.*; do [ -f \"$f\" ] && { echo \"$f\"; exit; }; done; true"]
              stdout: SplitParser { onRead: (l) => root.avatarPath = l.trim() } }

    // сеть — тот же скрипт, что у пилюли бара (только показ)
    BarScript { id: wifi; command: [Quickshell.env("HOME") + "/.local/lib/yumi/bar/wifi"]; interval: 20; enabled: root.active && !root.placeholder }
    readonly property string wifiOn: !wifi.ok ? "" : wifi.cls.indexOf("connected") === 0 ? "on" : "off"
    readonly property string wifiName: { if (wifiOn !== "on") return ""; const m = /<b>([^<]*)<\/b>/.exec(wifi.tooltip)
        return m ? m[1].replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&quot;/g, "\"") : "" }

    // ---------- заглушка на втором мониторе (как у LockSurface) ----------
    Rectangle {
        anchors.fill: parent
        z: 900
        visible: root.placeholder
        color: "black"
        Column {
            anchors.centerIn: parent
            spacing: 26
            Image { anchors.horizontalCenter: parent.horizontalCenter; width: 160; height: 160
                    source: Qt.resolvedUrl("boot-logo.png"); sourceSize.width: 256; sourceSize.height: 256; smooth: true; opacity: 0.85 }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDateTime(clock.date, "HH:mm")
                   font.family: Theme.fontUi; font.pixelSize: 44; font.weight: Font.Light; color: Qt.rgba(1, 1, 1, 0.7) }
            Text { anchors.horizontalCenter: parent.horizontalCenter
                   text: input.text.length ? "•".repeat(Math.min(input.text.length, 24)) : "Введите пароль"
                   font.family: Theme.fontUi; font.pixelSize: 15; color: Qt.rgba(1, 1, 1, input.text.length ? 0.8 : 0.35) }
        }
    }
}
