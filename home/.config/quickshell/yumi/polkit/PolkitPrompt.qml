import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.components
import qs.services

// Окно пароля polkit «Остров» (29.10.2026, M.polkit в превью island.src.html): остров 440 (radius 26), печать 弓 48,
// «Требуется подтверждение», команда в подложке, пользователь, поле-капсула с точками, «или приложите палец к Touch ID»,
// Отмена / Подтвердить. Ошибка — тряска и красная кромка поля 1,2 с. Логика (поток, Touch ID, pending) — прежняя.
// Оверлей на мониторе в фокусе: весь экран затемнён (размытие — правило слоя yumi-qs-* в rules.lua), карточка по центру.
//
// flow — AuthFlow из Quickshell.Services.Polkit (PolkitService) или заглушка PolkitStubFlow (превью, dev-polkit.qml).
// Агент обнуляет flow сразу, как поток завершён (успех/отмена), — поэтому поток запоминается в cur, тексты — в снимке,
// и окно спокойно растворяется уже без flow.
// Клавиши: Enter — отправить пароль, Esc — отмена (cancelAuthenticationRequest). Клик мимо карточки ничего не делает.
// Touch ID: /etc/pam.d/polkit-1 сначала ждёт палец (pam_fprintd, 10 с × 2 попытки), пароль PAM спросит только потом.
// Пока ждёт — «Коснитесь Touch ID или введите пароль»: набирать можно сразу, Enter запоминает пароль, и он уходит,
// как только PAM попросит его (isResponseRequired).
//   st: typing | checking | error | ok
PanelWindow {
    id: win
    property var flow: null
    property var cur: null
    property bool open: false
    property string st: "typing"
    property bool pending: false              // Enter нажат, пока PAM ещё ждёт палец — отправить, когда спросит пароль
    property string msgText: ""
    property string actionText: ""
    readonly property string errorText: "Неверный пароль"

    readonly property string testScreen: Quickshell.env("YUMI_QS_SCREEN")
    property var target: null
    screen: target

    // ---------- жизненный цикл ----------
    onFlowChanged: flow ? begin(flow) : finish()
    // 19.10: polkit предлагает всех администраторов (группа wheel: alarm и основной пользователь), первым — alarm. Окно спрашивало
    // пароль alarm, и пароль пользователя не подходил. Выбрать себя ($USER); смена личности перезапускает проверку.
    function pickSelf(f) {
        try {
            const ids = f.identities || []
            console.log("yumi-polkit: личности", ids.map(i => i ? (i.name || i.displayName || i.id) : "?").join(", "))
            const me = ids.find(i => i && (i.name === user || i.displayName === user))
            if (me && f.selectedIdentity !== me) f.selectedIdentity = me
        } catch (e) { console.log("yumi-polkit: не выбрать личность:", e) }
    }
    function begin(f) {
        cur = f
        pickSelf(f)
        msgText = f.message || ""; actionText = f.actionId || ""
        errTimer.stop(); okTimer.stop(); closer.stop()
        input.text = ""; pending = false; st = "typing"
        if (!open) {
            const name = testScreen || (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "")
            target = Quickshell.screens.find(s => s.name === name) ?? null
        }
        open = true
        Brightness.refresh(); layoutProc.running = true
        input.forceActiveFocus()
    }
    // flow стал null: успех — растворение с полной чертой, иначе (отмена, отказ polkit) — быстро закрыть
    function finish() {
        if (st === "ok") return
        if (cur && cur.isSuccessful) { succeed(); return }
        close()
    }
    function succeed() { if (st === "ok") return; st = "ok"; pending = false; okTimer.restart() }
    function close() { pending = false; input.text = ""; if (open) { open = false; closer.restart() } }
    function cancel() { if (st === "ok") return; if (cur && !cur.isCompleted) cur.cancelAuthenticationRequest(); else close() }
    function submit() {
        if (!cur || !input.text.length || st === "checking" || st === "ok") return
        if (cur.isResponseRequired) { st = "checking"; pending = false; cur.submit(input.text) }
        else pending = true
    }
    // проверка вида без клавиатуры (превью): набрать / отправить
    function typeDemo(t) { if (st === "error") st = "typing"; input.text = t }
    function submitDemo() { submit() }

    Connections {
        target: win.cur
        ignoreUnknownSignals: true
        function onAuthenticationSucceeded() { win.succeed() }
        function onAuthenticationFailed() { win.st = "error"; win.pending = false; input.text = ""; errTimer.restart() }
        function onIsResponseRequiredChanged() {
            if (!win.cur || !win.cur.isResponseRequired) return
            if (win.st === "checking") win.st = "typing"          // PAM спросил ещё что-то (второй запрос)
            if (win.pending && input.text.length) { win.pending = false; win.st = "checking"; win.cur.submit(input.text) }
        }
    }
    Timer { id: errTimer; interval: 1200; onTriggered: if (win.st === "error") win.st = "typing" }
    Timer { id: okTimer; interval: 260; onTriggered: { win.open = false; closer.restart() } }   // черта дотянулась — растворить
    Timer { id: closer; interval: 460 }

    // ---------- Touch ID и подсказки ----------
    readonly property string supp: cur ? (cur.supplementaryMessage || "") : ""
    readonly property bool fpMsg: /finger|fingerprint|палец|пальц|отпечат|сканер|touch/i.test(supp)
    readonly property bool fpWait: !!cur && !cur.isResponseRequired && fpMsg && st !== "checking" && st !== "ok"
    readonly property bool fpMiss: fpWait && !!cur && cur.supplementaryIsError
    readonly property bool suppErr: !!cur && cur.supplementaryIsError && !fpMsg
    readonly property string hint: st === "error" ? errorText
        : st === "checking" ? "Проверяю…"
        : st === "ok" ? "Разрешено"
        : pending ? "Пароль отправится после Touch ID (до 10 с)"
        : fpMiss ? "Отпечаток не распознан — ещё раз или пароль"
        : fpWait ? "Коснитесь Touch ID или введите пароль"
        : (!fpMsg && supp) ? supp
        : ""
    readonly property bool hintBad: st === "error" || (fpMiss && !pending) || (suppErr && hint === supp)

    // «Команда»: pkexec пишет её в кавычках — `…' (C), «…» (ru), ‘…’, "…"
    readonly property string command: { const m = /[`‘«"„]([^'’»"“]+)['’»"“]/.exec(msgText); return m ? m[1].trim() : "" }
    readonly property string program: command ? command.split(/\s+/)[0].replace(/^.*\//, "") : ""

    // имя: выбранная личность polkit, иначе GECOS / $USER (как на экране блокировки)
    readonly property string user: Quickshell.env("USER") || "yumi"
    property string gecos: ""
    readonly property string shortName: { const n = gecos || user.replace(/[0-9_.-]+$/, ""); return n.charAt(0).toUpperCase() + n.slice(1) }
    Process { running: true; command: ["getent", "passwd", win.user]
              stdout: SplitParser { onRead: (l) => { const g = (l.split(":")[4] || "").split(",")[0].trim(); if (g) win.gecos = g } } }
    readonly property string prompt: cur ? (cur.inputPrompt || "") : ""
    readonly property string fieldLabel: prompt && !/^\s*(password|пароль)\s*:?\s*$/i.test(prompt) ? prompt.replace(/:\s*$/, "")
                                         : "Пароль пользователя " + shortName
    readonly property bool echo: !!cur && cur.responseVisible

    // раскладка: hyprctl при открытии, дальше — событие activelayout
    property string layoutCode: "—"
    function code(km) { return km.indexOf("Russian") >= 0 ? "RU" : km.indexOf("Ukrain") >= 0 ? "UA" : km.indexOf("English") >= 0 ? "EN" : km.indexOf("Italian") >= 0 ? "IT" : km.slice(0, 2).toUpperCase() }
    Process { id: layoutProc; command: ["hyprctl", "devices", "-j"]
              stdout: StdioCollector { onStreamFinished: { try { const ks = JSON.parse(text).keyboards; const k = ks.find(x => x.main) ?? ks[0]; if (k) win.layoutCode = win.code(k.active_keymap) } catch (e) {} } } }
    Connections { target: Hyprland; function onRawEvent(ev) { if (ev.name === "activelayout") win.layoutCode = win.code(ev.data.split(",").pop()) } }
    Timer { id: capsLater; interval: 120; onTriggered: Brightness.refresh() }

    // ---------- окно ----------
    visible: open || closer.running
    color: "transparent"
    WlrLayershell.namespace: "yumi-qs-polkit"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }

    Item {
        id: stage
        anchors.fill: parent
        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: win.open ? Theme.normal : (win.st === "ok" ? 420 : Theme.fast); easing.type: Easing.OutCubic } }

        // затемнение (размытие под ним — Hyprland); клики не проходят к окнам под ним
        Rectangle { anchors.fill: parent; color: Qt.rgba(0.024, 0.024, 0.03, 0.62); MouseArea { anchors.fill: parent } }

        Item {
            id: card
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -24
            width: 440
            height: body.implicitHeight + 36
            // появление: остров вырастает (0.94 → 1, пружина), уход — быстро
            scale: win.open ? 1 : 0.94
            Behavior on scale { NumberAnimation { duration: win.open ? Theme.menuOpen : Theme.fast; easing.type: win.open ? Easing.OutBack : Easing.OutCubic } }
            transform: Translate { id: shakeX }
            SequentialAnimation {
                id: shake
                NumberAnimation { target: shakeX; property: "x"; to: -14; duration: 90; easing.type: Easing.OutQuad }
                NumberAnimation { target: shakeX; property: "x"; to: 11; duration: 90; easing.type: Easing.InOutQuad }
                NumberAnimation { target: shakeX; property: "x"; to: -7; duration: 90; easing.type: Easing.InOutQuad }
                NumberAnimation { target: shakeX; property: "x"; to: 4; duration: 90; easing.type: Easing.InOutQuad }
                NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 90; easing.type: Easing.InQuad }
            }
            Connections { target: win; function onStChanged() { if (win.st === "error") shake.restart() } }

            RectangularShadow {
                anchors.fill: bg; radius: bg.radius; blur: 60; spread: 0; offset.y: 24
                color: Qt.rgba(0, 0, 0, 0.5)
            }
            Rectangle {
                id: bg
                anchors.fill: parent
                radius: Theme.radiusBig
                color: Colors.isl
                border.width: 1; border.color: Colors.edge
                Behavior on color { ColorAnimation { duration: Theme.normal } }
            }

            ColumnLayout {
                id: body
                x: 18; y: 18
                width: card.width - 36
                spacing: 12

                // ---- шапка: печать 48, «Требуется подтверждение», кто просит ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    YumiMark { size: 48 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "Требуется подтверждение"; font.family: Theme.fontUi; font.pixelSize: 16; font.weight: Font.DemiBold; color: Colors.fg }
                        Text { Layout.fillWidth: true
                               text: win.program ? win.program + " хочет выполнить действие от имени администратора"
                                                 : (win.msgText || "Действие требует прав администратора")
                               font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fgDim
                               wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight }
                    }
                }

                // ---- команда (pkexec) или действие polkit — моноширинным в подложке ----
                IBox {
                    visible: !!win.command || !!win.actionText
                    pad: 0
                    spacing: 4
                    Text { Layout.fillWidth: true; Layout.leftMargin: 14; Layout.rightMargin: 14; Layout.topMargin: 12
                           Layout.bottomMargin: win.command && win.actionText ? 0 : 12
                           text: win.command || win.actionText
                           font.family: Theme.fontMono; font.pixelSize: 12; color: Colors.fgDim
                           wrapMode: Text.WrapAnywhere; maximumLineCount: 3; elide: Text.ElideRight }
                    Text { visible: !!win.command && !!win.actionText
                           Layout.fillWidth: true; Layout.leftMargin: 14; Layout.rightMargin: 14; Layout.bottomMargin: 12
                           text: win.actionText; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim; opacity: 0.8
                           elide: Text.ElideMiddle }
                }

                // ---- пользователь ----
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40; radius: 20
                    color: Colors.isl2
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 10
                        Glyph { text: "󰀄"; font.pixelSize: 16; color: Colors.fgDim }
                        Text { Layout.fillWidth: true; text: win.user; font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fg; elide: Text.ElideRight }
                    }
                }

                // ---- поле пароля (как IField): замок · точки / подпись PAM · раскладка ----
                Rectangle {
                    id: field
                    Layout.fillWidth: true
                    implicitHeight: 40; radius: 20
                    readonly property bool err: win.st === "error"
                    color: err ? Colors.mix(Colors.isl2, Colors.bad, 0.18) : Colors.isl2
                    border.width: err || input.activeFocus ? 1.5 : 0
                    border.color: err ? Colors.bad : Colors.acc
                    Behavior on color { ColorAnimation { duration: 300 } }
                    Behavior on border.color { ColorAnimation { duration: 300 } }
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 10
                        Glyph { text: "󰌾"; font.pixelSize: 16; color: Colors.fgDim }
                        Item {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            clip: true
                            Text { anchors.verticalCenter: parent.verticalCenter; visible: input.text.length === 0
                                   width: parent.width; elide: Text.ElideRight
                                   text: win.st === "checking" ? "Проверяю…" : win.fieldLabel
                                   font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fgDim }
                            Text { anchors.verticalCenter: parent.verticalCenter; visible: win.echo; text: input.text
                                   font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fg }
                            Row {
                                visible: !win.echo
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.min(0, parent.width - width)
                                spacing: 6
                                opacity: win.st === "checking" ? 0.55 : 1
                                Repeater {
                                    model: input.text.length
                                    Rectangle {
                                        width: 7; height: 7; radius: 3.5; color: Colors.fg
                                        scale: 0
                                        Component.onCompleted: scale = 1
                                        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                                    }
                                }
                            }
                        }
                        Text { text: Brightness.caps ? "CAPS" : win.layoutCode
                               font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium
                               color: Brightness.caps ? Colors.warn : Colors.fgDim
                               Behavior on color { ColorAnimation { duration: 300 } } }
                    }
                }

                // ---- Touch ID / сообщение ----
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: body.width
                    spacing: 10
                    readonly property color tone: win.hintBad ? Colors.bad : (Brightness.caps && !win.hint ? Colors.warn : Colors.acc)
                    Glyph { anchors.verticalCenter: parent.verticalCenter; text: "󰈷"; font.pixelSize: 16; color: parent.tone
                            visible: !win.hint || win.fpWait || win.pending || win.fpMiss }
                    Text { anchors.verticalCenter: parent.verticalCenter
                           text: win.hint || (Brightness.caps ? "Caps Lock включён" : "или приложите палец к Touch ID")
                           font.family: Theme.fontUi; font.pixelSize: 13; color: parent.tone
                           width: Math.min(implicitWidth, body.width - 30); elide: Text.ElideRight
                           Behavior on color { ColorAnimation { duration: 300 } } }
                }

                // ---- кнопки ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    IButton { Layout.fillWidth: true; Layout.preferredWidth: 1; text: "Отмена"; onClicked: win.cancel() }
                    IButton { Layout.fillWidth: true; Layout.preferredWidth: 1; primary: true; text: "Подтвердить"
                              enabledLook: input.text.length > 0 && win.st !== "checking"
                              onClicked: { win.submit(); input.forceActiveFocus() } }
                }
            }
        }
    }

    // невидимое поле: принимает символы в любой раскладке; на экран — только квадраты
    TextInput {
        id: input
        parent: stage
        width: 0; height: 0; opacity: 0
        focus: true
        echoMode: win.echo ? TextInput.Normal : TextInput.Password
        readOnly: win.st === "checking" || win.st === "ok"
        onTextChanged: if (text.length && win.st === "error") win.st = "typing"
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_CapsLock) { capsLater.restart(); return }
            if (e.key === Qt.Key_Escape) { e.accepted = true; win.cancel(); return }
            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { e.accepted = true; win.submit(); return }
            if (win.st === "error") win.st = "typing"
        }
    }
}
