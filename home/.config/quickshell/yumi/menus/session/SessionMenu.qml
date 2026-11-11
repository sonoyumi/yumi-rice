import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// «Сеанс» — «Остров» (29.10): карточка по центру экрана, пять крупных кнопок isl2 radius 22, у каждой кольцо-дуга.
// ВСЕ действия — только удержанием ~1 с (Enter, буква действия или кнопка мыши): дуга акцентом замыкается, по готовности
// кнопка заливается акцентом; отпустили раньше — отмена.
// Клавиши: ←→ (↑↓, Tab) — выбор; Enter — держать; L/Д блокировка, S/Ы сон, E/У выход, R/К перезагрузка, P/З выключение;
// Esc — отмена удержания / закрыть. Команды выполняет бэкенд ~/.local/lib/yumi/qs/session (SessionData.qml).
// Открыть/закрыть: qs -c yumi ipc call menu toggle session.
// ВНИМАНИЕ: блокировка = настоящий hyprlock (любой запуск/закрытие — неверный пароль для faillock): проверять только с YP_DRYRUN=1.
// Проверка: YP_SESSION_ASK=reboot|logout|poweroff — сразу «удержать» это действие; YP_STAY=1 — в пробном режиме не закрывать;
//   qs … ipc call session ask <действие> (выбрать и удержать до конца) | key l|r|Left|Right|Return|Escape | state
//   | freeze <действие> <доля> (показать дугу на доле без выполнения — для снимка)
//   YUMI_QS_NOKB=1 — без захвата клавиатуры
Scope {
    id: menu
    readonly property bool open: Menus.current === "session"
    readonly property int holdMs: 1000
    property string doneTile: ""             // действие «выполнено» (имитация)
    property string toastText: ""
    property string dryText: ""

    // действие → значок, название, клавиши (латиница + кириллица) — как ACTIONS в yumi-menu-session
    readonly property var actions: [
        { key: "lock",     icon: "󰌾", name: "Блокировка",   keys: ["l", "д"], danger: false },
        { key: "suspend",  icon: "󰤄", name: "Сон",          keys: ["s", "ы"], danger: true },   // 29.10: сон — тоже удержанием (просьба пользователя)
        { key: "logout",   icon: "󰍃", name: "Выход",        keys: ["e", "у"], danger: true },
        { key: "reboot",   icon: "󰜉", name: "Перезагрузка", keys: ["r", "к"], danger: true },
        { key: "poweroff", icon: "󰐥", name: "Выключение",   keys: ["p", "з"], danger: true } ]
    function info(key) { return actions.find(a => a.key === key) }

    property int sel: 0
    readonly property var cur: actions[sel]
    function step(d) { if (holding) return; sel = (sel + d + actions.length) % actions.length }
    function selectKey(key) { const i = actions.findIndex(a => a.key === key); if (i >= 0 && !holding) sel = i }

    // ---- удержание ----
    property bool holding: false
    property real holdStart: 0
    property real holdFrac: 0
    Behavior on holdFrac { enabled: !menu.holding; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }   // отпустили — дуга плавно сходит
    Timer {
        id: holdTick
        interval: 16; repeat: true
        onTriggered: {
            menu.holdFrac = Math.min(1, (Date.now() - menu.holdStart) / menu.holdMs)
            if (menu.holdFrac >= 1) { stop(); menu.run(menu.cur.key) }
        }
    }
    function press() {                       // Enter/буква/кнопка нажата: блокировка и сон — сразу, опасные — держать (как было)
        if (holding || doneTile) return
        if (!cur.danger) { run(cur.key); return }
        holding = true; holdStart = Date.now(); holdFrac = 0; holdTick.start()
    }
    function release() {                     // отпущена до конца — отмена
        if (!holding) return
        holdTick.stop(); holding = false; holdFrac = 0
        say("Держите, пока дуга не замкнётся", 1600)
    }
    function cancelHold() { holdTick.stop(); holding = false; holdFrac = 0 }

    readonly property string status: toastText ? toastText : holding ? cur.name + "…" : !cur.danger ? "Нажмите — сразу" : "Держите, пока дуга не замкнётся"

    SessionData {
        id: sess
        wanted: menu.open
        onDone: (action, text) => Menus.close("session")
        onDryRun: (action, text, cmd) => {
            menu.say(text, 3000)
            menu.dryText = cmd
            if (!Quickshell.env("YP_STAY")) quitTimer.restart()
        }
    }
    Timer { id: doneTimer; interval: 1400; onTriggered: { menu.doneTile = ""; menu.holdFrac = 0 } }
    Timer { id: quitTimer; interval: 1500; onTriggered: Menus.close("session") }
    Timer { id: toastTimer; onTriggered: menu.toastText = "" }
    function say(text, ms) { toastText = text; toastTimer.interval = ms; toastTimer.restart() }

    function run(action) {
        holdTick.stop(); dryText = ""
        if (!sess.dry) { holding = false; Menus.close("session") }    // окно не мелькает поверх экрана блокировки
        else { holdFrac = 1; holding = false; doneTile = action; doneTimer.restart() }   // дуга замкнута, кнопка — акцентом
        sess.run(action)
    }

    onOpenChanged: {
        if (open) {
            closer.stop(); settle.restart()
            sel = 0
            scope.forceActiveFocus()
            const ask = Quickshell.env("YP_SESSION_ASK"); if (ask && info(ask)) askTimer.restart()
        } else {
            scope.focus = false                 // снять фокус до скрытия — иначе Qt падает, уничтожая элемент с фокусом
            cancelHold(); doneTile = ""; dryText = ""; toastText = ""; quitTimer.stop(); doneTimer.stop(); closer.restart()
        }
    }
    Timer { id: closer; interval: Theme.normal }
    Timer { id: askTimer; interval: 300; onTriggered: menu.ask(Quickshell.env("YP_SESSION_ASK")) }
    // проверка: выбрать и удержать до конца
    function ask(action) { if (!info(action)) return; cancelHold(); selectKey(action); Qt.callLater(menu.press) }

    // клавиши: press/release; автоповтор не считается
    function keyDown(name) {
        if (name === "Escape") { if (holding) cancelHold(); else Menus.close("session"); return true }
        if (name === "Left" || name === "Up") { step(-1); return true }
        if (name === "Right" || name === "Down" || name === "Tab") { step(1); return true }
        if (name === "Return") { press(); return true }
        const t = name.toLowerCase()
        for (const a of actions) if (a.keys.includes(t)) {
            if (holding) return true
            selectKey(a.key); Qt.callLater(menu.press)
            return true
        }
        return false
    }
    function keyUp(name) {
        const t = name.toLowerCase()
        if (name === "Return" || actions.some(a => a.keys.includes(t))) { release(); return true }
        return false
    }

    IpcHandler {
        target: "session"
        function ask(action: string): void { menu.ask(action) }
        function freeze(action: string, frac: string): void {   // дуга на доле, без выполнения (снимок вида)
            if (!menu.info(action)) return
            menu.cancelHold(); menu.selectKey(action); menu.holding = true; menu.holdFrac = Math.max(0, Math.min(0.99, parseFloat(frac) || 0))
        }
        function key(name: string): void {     // как нажатие клавиши; Return — полное удержание
            const r = menu.keyDown(name)
            console.log("session [key]", name, "→", r)
        }
        function state(): string {
            return JSON.stringify({ open: menu.open, sel: menu.cur.key, holding: menu.holding, frac: Math.round(menu.holdFrac * 100) / 100,
                                    toast: menu.toastText, dry: sess.dry })
        }
    }

    PanelWindow {
        id: win
        screen: Menus.screen
        visible: menu.open || closer.running
        color: "transparent"
        WlrLayershell.namespace: "yumi-qs-session"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: menu.open && Quickshell.env("YUMI_QS_NOKB") !== "1" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: true; right: true }

        // клик вне — закрыть; курсор дальше Theme.menuFar от карточки — закрыть, но не во время удержания
        MouseArea {
            anchors.fill: parent; acceptedButtons: Qt.AllButtons; hoverEnabled: true
            onClicked: Menus.close("session")
            onPositionChanged: (m) => { far.rect = Qt.rect(card.x, card.y, card.width, card.height); far.track(m.x, m.y) }
            onExited: far.reset()
        }
        Timer { id: settle; interval: 400 }
        FarWatch { id: far; enabled: menu.open && !menu.holding && !settle.running; onFar: Menus.close("session") }

        FocusScope {
            id: scope
            anchors.fill: parent
            focus: menu.open
            function keyName(e) {
                if (e.key === Qt.Key_Escape) return "Escape"
                if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) return "Return"
                if (e.key === Qt.Key_Left) return "Left"
                if (e.key === Qt.Key_Right) return "Right"
                if (e.key === Qt.Key_Up) return "Up"
                if (e.key === Qt.Key_Down) return "Down"
                if (e.key === Qt.Key_Tab) return "Tab"
                return e.text
            }
            Keys.onPressed: (e) => {
                if (e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return
                if (e.isAutoRepeat) { e.accepted = true; return }
                const n = keyName(e)
                if (n && menu.keyDown(n)) e.accepted = true
            }
            Keys.onReleased: (e) => {
                if (e.isAutoRepeat) { e.accepted = true; return }
                const n = keyName(e)
                if (n && menu.keyUp(n)) e.accepted = true
            }

            // ---- карточка-остров (как Popup: isl, radius 26, кромка; растёт из центра пружиной) ----
            Rectangle {
                id: card
                width: 620; height: body.implicitHeight + 36
                x: Math.round((parent.width - width) / 2)
                y: Math.round((parent.height - height) / 2)
                radius: Theme.radiusBig
                color: Colors.isl
                border.width: 1; border.color: Colors.edge
                Behavior on color { ColorAnimation { duration: Theme.normal } }
                property real grow: menu.open ? 1 : 0
                Behavior on grow { NumberAnimation { duration: menu.open ? Theme.menuOpen : Theme.fast
                                                     easing.type: menu.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.15 } }
                transform: Scale { origin.x: card.width / 2; origin.y: card.height / 2
                                   xScale: 0.9 + 0.1 * card.grow; yScale: 0.9 + 0.1 * card.grow }
                opacity: Math.min(1, grow * 3)
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; hoverEnabled: true; onEntered: far.reset() }

                ColumnLayout {
                    id: body
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
                    spacing: 12
                    opacity: menu.open ? 1 : 0
                    Behavior on opacity { SequentialAnimation {
                        PauseAnimation { duration: menu.open ? Theme.contentDelay : 0 }
                        NumberAnimation { duration: menu.open ? 260 : 120; easing.type: Easing.OutCubic } } }

                    CardHead {
                        title: "Сеанс"
                        status: menu.status
                        statusColor: menu.toastText ? Colors.acc : Colors.fgDim
                        dry: sess.dry
                        Text { text: sess.subtitle; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim
                               font.features: ({ "tnum": 1 }) }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Repeater {
                            model: menu.actions
                            Rectangle {
                                id: sb
                                required property var modelData
                                required property int index
                                readonly property bool on: index === menu.sel
                                readonly property bool done: menu.doneTile === modelData.key
                                readonly property real frac: on ? menu.holdFrac : 0
                                // 29.10: цвет действия — блокировка зелёная, сон синий, выход фиолетовый, перезагрузка оранжевая, выключение красное
                                readonly property color tone: ({ lock: "#7fd49a", suspend: "#8fb4f0", logout: "#c29af0",
                                                                 reboot: Colors.warn, poweroff: Colors.bad })[modelData.key] || Colors.acc
                                readonly property color ink: Colors.isl
                                Layout.fillWidth: true; Layout.preferredWidth: 10
                                implicitHeight: sbCol.implicitHeight + 32
                                radius: 22
                                color: done ? sb.tone : (ma.containsMouse ? Colors.hover : Colors.isl2)
                                border.width: on && !done ? 1.5 : 0; border.color: Colors.alpha(sb.tone, 0.7)
                                Behavior on color { ColorAnimation { duration: 260 } }
                                scale: ma.pressed ? 0.96 : (done ? 1.04 : 1)
                                Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
                                // каскад: кнопки проявляются по очереди
                                opacity: 0
                                property real dy: 8
                                transform: Translate { y: sb.dy }
                                states: State { when: menu.open; PropertyChanges { sb.opacity: 1; sb.dy: 0 } }
                                transitions: Transition {
                                    SequentialAnimation {
                                        PauseAnimation { duration: menu.open ? Theme.contentDelay + 40 + sb.index * Theme.cascade : 0 }
                                        NumberAnimation { properties: "opacity,dy"; duration: 280; easing.type: Easing.OutCubic } } }

                                ColumnLayout {
                                    id: sbCol
                                    anchors.centerIn: parent
                                    spacing: 10
                                    Item {
                                        Layout.alignment: Qt.AlignHCenter
                                        implicitWidth: 64; implicitHeight: 64
                                        Canvas {
                                            id: ring
                                            anchors.fill: parent
                                            visible: sb.modelData.danger           // 30.10: у блокировки (без удержания) кольца нет
                                            property real frac: sb.frac
                                            property color trackC: sb.done ? Colors.alpha(sb.ink, 0.25) : Colors.hover
                                            property color arcC: sb.done ? sb.ink : sb.tone
                                            onFracChanged: requestPaint()
                                            onTrackCChanged: requestPaint()
                                            onArcCChanged: requestPaint()
                                            onPaint: {
                                                const ctx = getContext("2d"); ctx.reset()
                                                const lw = 3 * width / 36, r = 16 * width / 36
                                                ctx.lineWidth = lw
                                                ctx.strokeStyle = trackC
                                                ctx.beginPath(); ctx.arc(width / 2, height / 2, r, 0, Math.PI * 2); ctx.stroke()
                                                if (frac > 0.001) {
                                                    ctx.lineCap = "round"; ctx.strokeStyle = arcC
                                                    ctx.beginPath(); ctx.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * frac); ctx.stroke()
                                                }
                                            }
                                        }
                                        Glyph { anchors.centerIn: parent; text: sb.modelData.icon; font.pixelSize: 24
                                                color: sb.done ? sb.ink : sb.tone }
                                    }
                                    Text { Layout.alignment: Qt.AlignHCenter; Layout.maximumWidth: sb.width - 12; elide: Text.ElideRight
                                           text: sb.modelData.name; font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium
                                           color: sb.done ? sb.ink : Colors.fg
                                           Behavior on color { ColorAnimation { duration: 260 } } }
                                }
                                MouseArea {
                                    id: ma
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onPressed: { menu.selectKey(sb.modelData.key); menu.press() }
                                    onReleased: menu.release()
                                    onCanceled: menu.release()
                                }
                            }
                        }
                    }

                    CardHints {
                        items: [["←→", "выбор"], [menu.cur.danger ? "держите Enter" : "Enter", "выполнить"], ["L S E R P", "выбрать"], ["Esc", "закрыть"]]
                    }
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        visible: menu.dryText.length > 0
                        implicitWidth: Math.min(card.width - 36, dryLbl.implicitWidth + 24); implicitHeight: dryLbl.implicitHeight + 12; radius: 12
                        color: Colors.isl2
                        Text { id: dryLbl; anchors.centerIn: parent; width: Math.min(implicitWidth, card.width - 60); elide: Text.ElideRight
                               text: menu.dryText; font.family: Theme.fontMono; font.pixelSize: 12; color: Colors.fgDim }
                    }
                }
            }
        }
    }
}
