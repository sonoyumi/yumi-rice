//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Greetd
import qs
import qs.lock

// ЭКРАН ВХОДА (19.10.2026): после выхода из Hyprland greetd показывает его вместо текстового agreety (на VT нет
// консоли — fbcon выключен ради плавной загрузки). Вид «Остров» (29.10.2026) — lock/GreeterSurface.qml (#greet превью):
// часы-остров, аватар с печатью, поле-остров, сеанс чипом, сеть/раскладка, Сон/Перезагрузка/Выключение. Пароль уходит в greetd (PAM-сервис greetd-yumi), после входа — сеанс Hyprland.
// Запуск — в sway от пользователя greeter, с копией конфига (домашний каталог закрыт): yumi-greeter.
// Как у LockReal: WlSessionLock — поверхность на каждый монитор со своим масштабом; на встроенном экране — полный
// экран входа, на внешнем — заглушка (крышка закрыта — полный на внешнем). Пароль можно вводить на любом.
// Без greetd (нет $GREETD_SOCK) — ПРЕВЬЮ окном: пароль «yumi», вход не выполняется, Esc — закрыть:
//   qs -p ~/.config/quickshell/yumi/greeter.qml
// Превью через блокировку — только во вложенном sway (YUMI_GREETER_LOCKTEST=1 + $SWAYSOCK): в Hyprland она
// заблокировала бы настоящий сеанс.
ShellRoot {
    id: root
    readonly property bool demo: !Greetd.available
    readonly property bool useLock: !demo || (Quickshell.env("YUMI_GREETER_LOCKTEST") === "1" && !!Quickshell.env("SWAYSOCK"))
    // greeter работает от пользователя greeter — кого впускать, говорит yumi-greeter (YUMI_GREETER_USER: владелец копии в /var/lib/yumi-greeter)
    readonly property string user: Quickshell.env("YUMI_GREETER_USER") || Quickshell.env("USER")
    readonly property var session: ["systemd-cat", "-t", "yumi-session", "/home/" + user + "/.local/bin/yumi-hyprland-session"]
    property string pending: ""
    property string typed: ""                 // набранное — общее для всех мониторов
    property bool finished: false
    signal authResult(string state, string err)

    function start(): void { if (!demo && Greetd.state === GreetdState.Inactive) Greetd.createSession(root.user) }
    function fail(text: string): void { pending = ""; authResult("error", text) }

    function submit(pw: string): void {
        authResult("checking", "")
        if (demo) { stub.pw = pw; stub.restart(); return }
        pending = pw
        // сеанс greetd уже ждёт пароль — ответить сразу; иначе ответит onAuthMessage
        if (Greetd.state === GreetdState.Authenticating) { Greetd.respond(pw); pending = "" }
        else start()
    }

    // растворение закончилось (на каждом мониторе — один раз хватит): снять блокировку и передать вход greetd
    function finish(): void {
        if (finished) return
        finished = true
        sessionLock.locked = false            // иначе sway на миг покажет красный экран «клиент блокировки упал»
        if (demo) Qt.quit(); else Greetd.launch(root.session)
    }

    Component.onCompleted: start()

    // кнопки питания экрана входа (перезагрузка/выключение — по второму нажатию, это делает GreeterSurface).
    // Превью (без greetd) ничего не выполняет — только пишет в журнал
    function power(action: string): void {
        if (["suspend", "reboot", "poweroff"].indexOf(action) < 0) return
        if (demo) { console.log("yumi-greeter: превью — «" + action + "» не выполняется"); return }
        Quickshell.execDetached(["systemctl", action])
    }

    Connections {
        target: root.demo ? null : Greetd
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (!responseRequired) return
            if (root.pending.length) { Greetd.respond(root.pending); root.pending = "" }
        }
        function onAuthFailure(message) { root.fail("Неверный пароль"); Qt.callLater(root.start) }
        function onError(error) { root.fail("Ошибка входа: " + error); Greetd.cancelSession(); Qt.callLater(root.start) }
        function onReadyToLaunch() { root.authResult("ok", "") }      // растворение, затем запуск (finish)
    }

    Timer {
        id: stub
        property string pw: ""
        interval: 650
        onTriggered: { root.authResult(pw === "yumi" ? "ok" : "error", pw === "yumi" ? "" : "Неверный пароль · это превью"); pw = "" }
    }

    WlSessionLock {
        id: sessionLock
        locked: root.useLock
        WlSessionLockSurface {
            id: lockSurf
            color: "black"
            GreeterSurface {
                id: surface
                anchors.fill: parent
                screenName: lockSurf.screen ? lockSurf.screen.name : ""
                placeholder: Theme.lockPlaceholder(screenName)
                active: true
                sharedText: root.typed
                onTyped: (t) => root.typed = t
                onSubmitted: (pw) => root.submit(pw)
                onCancelled: {}                // Esc только возвращает к часам
                onDissolved: root.finish()
                onPower: (a) => root.power(a)
                Connections {
                    target: root
                    function onAuthResult(state, err) { if (err) surface.errorText = err; surface.authState = state }
                }
            }
        }
    }

    // превью в обычном сеансе — окном
    LazyLoader {
        active: !root.useLock
        FloatingWindow {
            title: "yumi-greeter"
            color: "black"
            visible: true
            GreeterSurface {
                id: winSurface
                anchors.fill: parent
                focus: true
                active: true
                errorText: "Неверный пароль · это превью"
                onSubmitted: (pw) => root.submit(pw)
                onCancelled: Qt.quit()
                onDissolved: root.finish()
                onPower: (a) => root.power(a)
                Connections {
                    target: root
                    function onAuthResult(state, err) { if (err) winSurface.errorText = err; winSurface.authState = state }
                }
            }
        }
    }
}
