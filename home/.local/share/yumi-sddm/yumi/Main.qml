// ┌──────────────────────────────────────────────────────────────┐
// │ yumi — тема SDDM в стиле экрана блокировки «Yumi Google»       │
// │ Тёмные полупрозрачные карточки поверх размытых обоев, пилюли,  │
// │ скругления. Цвета/обои/аватар — из theme.conf.user, который    │
// │ пишет yumi-sddm-sync (см. bin/).                               │
// │                                                                │
// │ HiDPI: Qt-масштабирование в greeter выключено (см. конфиг),    │
// │ 1 логический пиксель = 1 физический, а тема сама масштабирует  │
// │ всё от размера экрана (единица u). Поэтому текст рисуется в    │
// │ родном разрешении — чётко и на 2560×1600, и на 1920×1080.      │
// └──────────────────────────────────────────────────────────────┘
import QtQuick 2.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1600
    height: 1000
    color: deepColor

    // ── масштаб: дизайн в физических пикселях экрана MacBook (2560×1600) ──
    readonly property real u: Math.max(0.4, Math.min(width / 2560, height / 1600))
    function px(v) { return Math.round(v * u) }

    // ── цвета (theme.conf → theme.conf.user перекрывает) ──
    function cfg(key, def) {
        var v = config[key]
        return (v === undefined || v === null || String(v) === "") ? def : v
    }
    readonly property color accentColor: cfg("AccentColor", "#f2e6e6e6")
    readonly property color cardColor:   cfg("CardColor",   "#6b1c1c1c")
    readonly property color deepColor:   cfg("DeepColor",   "#f21c1c1c")
    readonly property color textColor:   cfg("TextColor",   "#ffffff")
    readonly property color mutedColor:  cfg("MutedColor",  "#b8b8b8")
    readonly property color errorColor:  cfg("ErrorColor",  "#ff8a80")
    readonly property color lineColor:   Qt.rgba(1, 1, 1, 0.09)
    // цвет текста на акценте: тёмный, если акцент светлый
    readonly property color onAccent: (accentColor.r * 0.299 + accentColor.g * 0.587 + accentColor.b * 0.114) > 0.6
                                      ? "#141414" : "#ffffff"

    readonly property string uiFont: cantarell.status === FontLoader.Ready ? cantarell.name : "Cantarell"
    readonly property string iconFont: cfg("IconFont", "JetBrainsMono Nerd Font Propo")
    readonly property var loc: Qt.locale(cfg("Locale", "ru_RU"))
    readonly property bool ru: String(cfg("Locale", "ru_RU")).indexOf("ru") === 0

    function ico(code) { return String.fromCodePoint(code) }
    function tr(ruText, enText) { return ru ? ruText : enText }

    FontLoader { id: cantarell; source: "fonts/Cantarell-VF.otf" }
    TextConstants { id: textConstants }

    // ── пользователь: последний вошедший → DefaultUser → первый в списке ──
    // (клик по имени/аватару переключает пользователей, если их несколько)
    property var users: []      // [{name, realName, icon}]
    property int userIndex: 0
    Repeater {
        model: userModel
        delegate: Item {
            visible: false
            Component.onCompleted: {
                var u = root.users.slice()
                u[index] = { name: model.name, realName: model.realName || "", icon: model.icon || "" }
                root.users = u
                root.pickUser()
            }
        }
    }
    function pickUser() {
        var want = [userModel.lastUser || "", String(cfg("DefaultUser", ""))]
        for (var w = 0; w < want.length; w++) {
            if (want[w] === "") continue
            for (var i = 0; i < users.length; i++)
                if (users[i] && users[i].name === want[w]) { userIndex = i; return }
        }
    }
    function nextUser() {
        if (users.length < 2) return
        userIndex = (userIndex + 1) % users.length
        password.text = ""; errorText = ""; password.forceActiveFocus()
    }
    readonly property var curUser: users[userIndex] || null
    readonly property string userName: curUser ? curUser.name : ""
    readonly property string userRealName: curUser ? curUser.realName : ""
    readonly property string userIcon: curUser ? curUser.icon : ""
    readonly property string shownName: userName !== "" ? userName : (userModel.lastUser || "")
    // для проверки в --test-mode: показать все кнопки питания и раскладку
    readonly property bool showAll: String(cfg("ShowAllButtons", "false")) === "true"

    // ── сеанс: по умолчанию DefaultSession (hyprland-uwsm), иначе последний ──
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property var sessionNames: []
    Repeater {
        id: sessionScan
        model: sessionModel
        delegate: Item {
            visible: false
            Component.onCompleted: {
                var n = root.sessionNames.slice()
                n[index] = model.name
                root.sessionNames = n
                var want = String(root.cfg("DefaultSession", "hyprland-uwsm.desktop"))
                var f = String(model.file || "")
                if (want !== "" && (f === want || f.endsWith("/" + want)))
                    root.sessionIndex = index
            }
        }
    }
    readonly property string sessionName: sessionNames[sessionIndex] || ""

    // ── вход ──
    property bool busy: false
    // PreviewError — только для проверки вида в --test-mode
    property string errorText: String(cfg("PreviewError", ""))
    function doLogin() {
        if (busy || shownName === "") return
        busy = true
        errorText = ""
        sddm.login(shownName, password.text, sessionIndex)
    }
    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false
            root.errorText = root.tr("Неверный пароль", "Wrong password")
            password.text = ""
            password.forceActiveFocus()
            shake.restart()
        }
        function onLoginSucceeded() { root.busy = false }
        function onInformationMessage(message) { root.errorText = message }
    }

    // ══════════════ фон ══════════════
    Image {
        id: bg
        anchors.fill: parent
        source: root.cfg("BackgroundBlur", root.cfg("Background", "background.jpg"))
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: false
        smooth: true
        sourceSize.width: 2560
        sourceSize.height: 1600
        onStatusChanged: if (status === Image.Error && source != "background.jpg") source = "background.jpg"
    }
    // лёгкое затемнение, чтобы карточки читались на светлых обоях
    Rectangle { anchors.fill: parent; color: "#000000"; opacity: Number(root.cfg("Dim", 0.18)) }

    // часы
    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

    // ══════════════ верх: пилюля с днём недели и именем компьютера ══════════════
    Rectangle {
        id: datePill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: px(33)
        height: px(56)
        width: dateRow.implicitWidth + px(56)
        radius: height / 2
        color: root.cardColor
        border.color: root.lineColor
        border.width: 1
        Row {
            id: dateRow
            anchors.centerIn: parent
            spacing: px(14)
            Text {
                text: root.ico(0xF00ED) // календарь
                font.family: root.iconFont; font.pixelSize: px(24)
                color: root.accentColor
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: {
                    var d = root.loc.toString(root.now, "dddd")
                    d = d.charAt(0).toUpperCase() + d.slice(1)
                    var h = sddm.hostName || ""
                    return h !== "" ? d + "  ·  " + h : d
                }
                font.family: root.uiFont; font.pixelSize: px(24); font.weight: Font.Medium
                color: root.textColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // ══════════════ центр ══════════════
    Column {
        id: center
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -px(40)
        spacing: px(36)

        // ── табло: часы | акцентная черта | приветствие ──
        Rectangle {
            id: board
            anchors.horizontalCenter: parent.horizontalCenter
            width: boardRow.implicitWidth + px(110)
            height: px(231)
            radius: px(38)
            color: root.cardColor
            border.color: root.lineColor
            border.width: 1
            Row {
                id: boardRow
                anchors.centerIn: parent
                spacing: px(44)
                Text {
                    id: clock
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatTime(root.now, "HH:mm")
                    font.family: root.uiFont; font.pixelSize: px(150); font.weight: Font.Bold
                    font.letterSpacing: -px(3)
                    color: root.textColor
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: px(6); height: px(150); radius: width / 2
                    color: root.accentColor
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: px(8)
                    Text {
                        text: {
                            var h = root.now.getHours()
                            if (h < 5)  return root.tr("Доброй ночи", "Good night")
                            if (h < 12) return root.tr("Доброе утро", "Good morning")
                            if (h < 18) return root.tr("Добрый день", "Good afternoon")
                            return root.tr("Добрый вечер", "Good evening")
                        }
                        font.family: root.uiFont; font.pixelSize: px(40); font.weight: Font.DemiBold
                        color: root.textColor
                    }
                    Text {
                        text: root.loc.toString(root.now, "d MMMM yyyy")
                        font.family: root.uiFont; font.pixelSize: px(28)
                        color: root.mutedColor
                    }
                }
            }
        }

        // ── карточка входа ──
        Rectangle {
            id: loginCard
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(px(720), board.width)
            height: loginCol.implicitHeight + px(64)
            radius: px(38)
            color: root.cardColor
            border.color: root.lineColor
            border.width: 1

            // тряска при ошибке
            transform: Translate { id: shakeT; x: 0 }
            SequentialAnimation {
                id: shake
                NumberAnimation { target: shakeT; property: "x"; to: -px(16); duration: 50 }
                NumberAnimation { target: shakeT; property: "x"; to: px(14); duration: 60 }
                NumberAnimation { target: shakeT; property: "x"; to: -px(9); duration: 60 }
                NumberAnimation { target: shakeT; property: "x"; to: px(5); duration: 60 }
                NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 60 }
            }

            Column {
                id: loginCol
                anchors.centerIn: parent
                width: parent.width - px(64)
                spacing: px(24)

                // аватар + имя (клик — следующий пользователь)
                Item {
                    width: parent.width; height: userRow.height
                    Row {
                        id: userRow
                        spacing: px(26)
                        Item {
                            width: px(104); height: width
                            Rectangle {
                                id: avatarFallback
                                anchors.fill: parent
                                radius: px(24)
                                color: root.accentColor
                                visible: avatar.status !== Image.Ready
                                Text {
                                    anchors.centerIn: parent
                                    text: root.shownName.charAt(0).toUpperCase()
                                    font.family: root.uiFont; font.pixelSize: px(48); font.weight: Font.Bold
                                    color: root.onAccent
                                }
                            }
                            // аватар уже скруглён в yumi-sddm-sync (PNG с альфой) —
                            // шейдеры/маски не нужны, работает и без GPU
                            Image {
                                id: avatar
                                anchors.fill: parent
                                source: (root.userName === String(root.cfg("AvatarUser", root.userName))) ? root.cfg("Avatar", root.userIcon) : root.userIcon
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: 512; sourceSize.height: 512
                                smooth: true; mipmap: true
                            }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: px(6)
                            Text {
                                text: root.userRealName !== "" ? root.userRealName : root.shownName
                                font.family: root.uiFont; font.pixelSize: px(38); font.weight: Font.DemiBold
                                color: root.textColor
                            }
                            Text {
                                text: "@" + root.shownName
                                visible: root.userRealName !== "" && root.userRealName !== root.shownName
                                font.family: root.uiFont; font.pixelSize: px(24)
                                color: root.mutedColor
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: userRow
                        cursorShape: root.users.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.nextUser()
                    }
                }

                // поле пароля (пилюля) + кнопка входа
                Row {
                    spacing: px(16)
                    width: parent.width
                    Rectangle {
                        id: field
                        width: parent.width - goBtn.width - parent.spacing
                        height: px(84)
                        radius: height / 2
                        color: Qt.rgba(0, 0, 0, 0.28)
                        border.width: password.activeFocus ? px(3) : 1
                        border.color: root.errorText !== "" ? root.errorColor
                                    : (password.activeFocus ? root.accentColor : root.lineColor)
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        Text {
                            id: lockIcon
                            anchors.left: parent.left; anchors.leftMargin: px(30)
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.ico(0xF033E) // замок
                            font.family: root.iconFont; font.pixelSize: px(30)
                            color: root.mutedColor
                        }
                        TextInput {
                            id: password
                            anchors.left: lockIcon.right; anchors.leftMargin: px(18)
                            anchors.right: capsHint.visible ? capsHint.left : parent.right
                            anchors.rightMargin: px(26)
                            anchors.verticalCenter: parent.verticalCenter
                            echoMode: TextInput.Password
                            passwordCharacter: "●"
                            passwordMaskDelay: 0
                            font.family: root.uiFont
                            font.pixelSize: px(30)
                            font.letterSpacing: px(4)
                            color: root.textColor
                            selectionColor: root.accentColor
                            selectedTextColor: root.onAccent
                            clip: true
                            focus: true
                            enabled: !root.busy
                            Keys.onReturnPressed: root.doLogin()
                            Keys.onEnterPressed: root.doLogin()
                            Keys.onEscapePressed: { text = ""; root.errorText = "" }
                            onTextChanged: if (text !== "") root.errorText = ""
                            Component.onCompleted: forceActiveFocus()
                        }
                        Text {
                            anchors.left: password.left
                            anchors.verticalCenter: parent.verticalCenter
                            visible: password.text === ""
                            text: root.busy ? root.tr("Вход…", "Signing in…") : root.tr("Пароль", "Password")
                            font.family: root.uiFont; font.pixelSize: px(28)
                            color: root.mutedColor
                            opacity: 0.8
                        }
                        Rectangle {
                            id: capsHint
                            visible: keyboard.capsLock
                            anchors.right: parent.right; anchors.rightMargin: px(18)
                            anchors.verticalCenter: parent.verticalCenter
                            height: px(44); width: capsText.implicitWidth + px(28)
                            radius: height / 2
                            color: root.accentColor
                            Text {
                                id: capsText
                                anchors.centerIn: parent
                                text: root.ico(0xF0632) + " Caps"
                                font.family: root.iconFont; font.pixelSize: px(20)
                                color: root.onAccent
                            }
                        }
                        MouseArea { anchors.fill: parent; z: -1; onClicked: password.forceActiveFocus() }
                    }
                    Rectangle {
                        id: goBtn
                        width: px(84); height: width; radius: width / 2
                        color: goMouse.pressed ? Qt.darker(root.accentColor, 1.2)
                             : (goMouse.containsMouse ? Qt.lighter(root.accentColor, 1.08) : root.accentColor)
                        Text {
                            anchors.centerIn: parent
                            text: root.busy ? root.ico(0xF0450) : root.ico(0xF0054) // ⟳ / →
                            font.family: root.iconFont; font.pixelSize: px(40)
                            color: root.onAccent
                        }
                        MouseArea { id: goMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.doLogin() }
                    }
                }

                // сообщение об ошибке
                Item {
                    width: parent.width
                    height: errText.text !== "" ? errText.implicitHeight : 0
                    Behavior on height { NumberAnimation { duration: 150 } }
                    clip: true
                    Row {
                        id: errText
                        property string text: root.errorText
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: px(10)
                        Text {
                            text: root.ico(0xF0026) // ⚠
                            font.family: root.iconFont; font.pixelSize: px(24)
                            color: root.errorColor
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.errorText
                            font.family: root.uiFont; font.pixelSize: px(24); font.weight: Font.Medium
                            color: root.errorColor
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }

    // ══════════════ низ: сеанс | раскладка | питание ══════════════
    component Pill: Rectangle {
        id: pill
        property string icon: ""
        property string label: ""
        property color iconColor: root.accentColor
        signal clicked()
        height: px(64)
        width: pillRow.implicitWidth + (label === "" ? px(40) : px(52))
        radius: height / 2
        color: pillMouse.containsMouse ? Qt.lighter(root.cardColor, 1.6) : root.cardColor
        border.color: root.lineColor
        border.width: 1
        Behavior on color { ColorAnimation { duration: 120 } }
        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: px(12)
            Text {
                text: pill.icon
                font.family: root.iconFont; font.pixelSize: px(28)
                color: pill.iconColor
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                visible: pill.label !== ""
                text: pill.label
                font.family: root.uiFont; font.pixelSize: px(24); font.weight: Font.Medium
                color: root.textColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea { id: pillMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pill.clicked() }
    }

    Row {
        id: leftBar
        anchors.left: parent.left; anchors.leftMargin: px(48)
        anchors.bottom: parent.bottom; anchors.bottomMargin: px(44)
        spacing: px(16)

        Pill {
            id: sessionPill
            icon: root.ico(0xF0379) // монитор
            label: root.sessionName
            onClicked: sessionMenu.visible = !sessionMenu.visible
        }
        Pill {
            id: layoutPill
            visible: root.showAll || (keyboard.layouts && keyboard.layouts.length > 1)
            icon: root.ico(0xF030C) // клавиатура
            label: {
                var l = keyboard.layouts
                var i = keyboard.currentLayout
                return (l && i >= 0 && i < l.length) ? String(l[i].shortName).toUpperCase() : "US"
            }
            onClicked: {
                var n = keyboard.layouts.length
                if (n > 1) keyboard.currentLayout = (keyboard.currentLayout + 1) % n
                password.forceActiveFocus()
            }
        }
    }

    // всплывающий список сеансов (над пилюлей)
    Rectangle {
        id: sessionMenu
        // PreviewMenu=true — открыть меню сразу (только для проверки вида)
        visible: String(root.cfg("PreviewMenu", "false")) === "true"
        anchors.left: leftBar.left
        anchors.bottom: leftBar.top; anchors.bottomMargin: px(14)
        width: Math.max(px(380), menuCol.implicitWidth + px(24))
        height: menuCol.implicitHeight + px(24)
        radius: px(30)
        color: root.deepColor
        border.color: root.lineColor
        border.width: 1
        Column {
            id: menuCol
            anchors.centerIn: parent
            spacing: px(4)
            Repeater {
                model: sessionModel
                delegate: Rectangle {
                    width: sessionMenu.width - px(24)
                    height: px(58)
                    radius: height / 2
                    color: index === root.sessionIndex ? root.accentColor
                         : (itemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: px(26)
                        anchors.verticalCenter: parent.verticalCenter
                        text: model.name
                        font.family: root.uiFont; font.pixelSize: px(24)
                        color: index === root.sessionIndex ? root.onAccent : root.textColor
                    }
                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent; hoverEnabled: true
                        onClicked: { root.sessionIndex = index; sessionMenu.visible = false; password.forceActiveFocus() }
                    }
                }
            }
        }
    }

    Row {
        anchors.right: parent.right; anchors.rightMargin: px(48)
        anchors.bottom: parent.bottom; anchors.bottomMargin: px(44)
        spacing: px(16)
        Pill {
            visible: sddm.canSuspend || root.showAll
            icon: root.ico(0xF0904) // сон
            label: root.tr("Сон", "Sleep")
            onClicked: sddm.suspend()
        }
        Pill {
            visible: sddm.canReboot || root.showAll
            icon: root.ico(0xF0709) // перезагрузка
            label: root.tr("Перезагрузка", "Restart")
            onClicked: sddm.reboot()
        }
        Pill {
            visible: sddm.canPowerOff || root.showAll
            icon: root.ico(0xF0425) // питание
            iconColor: root.errorColor
            label: root.tr("Выключить", "Shut down")
            onClicked: sddm.powerOff()
        }
    }

    // клик мимо меню — закрыть его
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: { sessionMenu.visible = false; password.forceActiveFocus() }
    }
}
