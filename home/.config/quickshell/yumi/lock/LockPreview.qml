import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs
import qs.services

// ПРЕВЬЮ экрана блокировки: обычное окно-оверлей (WlrLayer.Overlay) на весь монитор в фокусе — НЕ блокировка.
// Пароль проверяет заглушка: верный — строка «yumi», остальное — ошибка. PAM и WlSessionLock здесь не используются
// (каждая неудачная попытка PAM — это faillock, может заблокировать вход). Настоящий экран — lock/LockReal.qml.
//   qs -c yumi ipc call lock preview      открыть / закрыть
//   qs -c yumi ipc call lock previewBoot  открыть с входом «из логотипа» (как при загрузке)
// Esc при пустом поле или верный пароль — закрыть превью. YUMI_QS_SCREEN=eDP-1 — экран принудительно (проверка).
// YUMI_QS_LOCK_DEV=1 — свой dev-экземпляр: без синглтона Notifs (он поднял бы второй сервер уведомлений).
PanelWindow {
    id: win
    property bool open: false
    property bool boot: false                  // previewBoot: вход «из логотипа», как при загрузке
    readonly property string testScreen: Quickshell.env("YUMI_QS_SCREEN")
    readonly property bool devNoNotifs: Quickshell.env("YUMI_QS_LOCK_DEV") === "1"
    // dev без синглтона Notifs: YUMI_QS_LOCK_DEMO=1 — образец «4 уведомления» для проверки вида снимком
    readonly property bool demoNotifs: devNoNotifs && Quickshell.env("YUMI_QS_LOCK_DEMO") === "1"
    readonly property var demoCounts: demoNotifs ? [{ app: "Telegram", n: 2 }, { app: "yumi-backup", n: 1 }, { app: "yumi-update", n: 1 }] : []
    property var target: null
    screen: target
    function show() {
        const name = testScreen || (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "")
        target = Quickshell.screens.find(s => s.name === name) ?? null
        closer.stop(); open = true
    }
    function close() { if (open) { open = false; closer.restart() } }
    onVisibleChanged: if (!visible) boot = false

    visible: open || closer.running
    color: "transparent"
    WlrLayershell.namespace: "yumi-qs-lockpreview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    // Exclusive, пока открыто — как у настоящей блокировки: любая клавиша сразу начинает ввод, без клика
    // (OnDemand не давал фокуса до клика). Esc / IPC lock close отпускают клавиатуру.
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // Player опрашивает позицию и держит текст песни свежим, пока превью открыто
    Binding { target: Player; property: "lockOpen"; value: true; when: win.open }   // when — не перебивать LockReal
    anchors { top: true; bottom: true; left: true; right: true }
    Timer { id: closer; interval: Theme.normal }

    IpcHandler {
        target: "lock"
        function preview(): void { if (win.open) win.close(); else win.show() }
        function previewBoot(): void { if (win.visible) return; win.boot = true; win.show() }
        function close(): void { win.close() }
        // проверка вида без клавиатуры: lock test <текст> — набрать, lock test "" — отправить набранное
        function test(text: string): void { if (!win.open) win.show(); const s = loader.item; if (!s) return; if (text.length) s.typeDemo(text); else s.submitDemo() }
    }

    Loader {
        id: loader
        anchors.fill: parent
        active: win.visible
        focus: win.open                         // фокус в поле пароля; снять до выгрузки (segfault в clearFocusInScope)
        opacity: win.open ? 1 : 0
        // previewBoot: без проявления — первый кадр сразу непрозрачный, как у настоящей блокировки
        Behavior on opacity { enabled: !win.boot; NumberAnimation { duration: win.open ? Theme.normal : Theme.fast } }
        sourceComponent: LockSurface {
            id: surface
            active: win.open
            bootIntro: win.boot
            screenName: win.target ? win.target.name : ""
            notifCount: win.devNoNotifs ? (win.demoNotifs ? 4 : 0) : Notifs.count
            notifApps: win.devNoNotifs ? [] : Notifs.centerApps
            notifCounts: win.devNoNotifs ? win.demoCounts : Notifs.centerApps.map(a => ({ app: a, n: Notifs.centerFor(a).length }))
            errorText: "Неверный пароль · это превью"
            // заглушка вместо PAM: 650 мс «проверки», как в макете
            onSubmitted: (pw) => { stub.pw = pw; stub.restart() }
            onCancelled: win.close()
            onDissolved: win.close()
            Timer {
                id: stub
                property string pw: ""
                interval: 650
                onTriggered: { surface.authState = pw === "yumi" ? "ok" : "error"; pw = "" }
            }
        }
    }
}
