import QtQuick
import Quickshell
import Quickshell.Io

// ПРЕВЬЮ окна polkit без настоящего polkit и PAM: заглушка PolkitStubFlow, верный пароль — «yumi».
//   qs -p ~/.config/quickshell/yumi/dev-polkit.qml ipc call polkit preview        открыть (только пароль) / закрыть
//   … ipc call polkit previewTouch   с Touch ID впереди (10 с ждёт палец, потом пароль)
//   … ipc call polkit previewMsg     запрос не от pkexec (текст запроса вместо команды)
//   … ipc call polkit test <текст>   набрать;  test ""  — Enter (отправить)
//   … ipc call polkit fpMiss | fpMatch   палец не совпал / совпал;   close — Esc;   state — состояние
Scope {
    id: prev
    property var flow: null
    Component { id: stubC; PolkitStubFlow {} }

    function begin(touch, msg, action) {
        if (flow) { const old = flow; flow = null; old.destroy() }
        const f = stubC.createObject(null, { touch: touch, message: msg, actionId: action })
        // как агент: поток завершён — flow сразу null, сам объект удаляется позже
        f.isCompletedChanged.connect(() => { if (f.isCompleted && prev.flow === f) { prev.flow = null; Qt.callLater(() => f.destroy()) } })
        flow = f
    }
    readonly property string pkMsg: "Authentication is needed to run `/usr/bin/pacman -Syu' as the super user"

    PolkitPrompt { id: prompt; flow: prev.flow }

    IpcHandler {
        target: "polkit"
        function preview(): void { if (prev.flow) prev.flow.cancelAuthenticationRequest(); else prev.begin(false, prev.pkMsg, "org.archlinux.pkexec.pacman") }
        function previewTouch(): void { prev.begin(true, prev.pkMsg, "org.archlinux.pkexec.pacman") }
        function previewMsg(): void { prev.begin(false, "Authentication is required to mount Samsung SSD (/dev/sda1)", "org.freedesktop.udisks2.filesystem-mount-system") }
        function test(text: string): void { if (!prev.flow) return; if (text.length) prompt.typeDemo(text); else prompt.submitDemo() }
        function fpMiss(): void { if (prev.flow) prev.flow.fpMiss() }
        function fpMatch(): void { if (prev.flow) prev.flow.fpMatch() }
        function close(): void { prompt.cancel() }
        function state(): string { return (prompt.open ? "open" : "closed") + " st=" + prompt.st + " pending=" + prompt.pending + " fpWait=" + prompt.fpWait
                                   + " required=" + (prev.flow ? prev.flow.isResponseRequired : "-") }
    }
}
