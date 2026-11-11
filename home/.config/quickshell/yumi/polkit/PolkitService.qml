import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit

// Свой агент polkit (19.10.2026): окно пароля «Черта» (PolkitPrompt) вместо hyprpolkitagent.
// Регистрируется ТОЛЬКО при файле-флаге ~/.config/yumi/polkit-qs — иначе ничего не создаёт (агент в сессии один:
// пока работает hyprpolkitagent, второй не нужен). Флаг проверяется один раз при запуске оболочки:
// включение/откат — yumi-polkit-switch on|off|status (ставит/убирает флаг, переключает hyprpolkitagent, рестарт оболочки).
Scope {
    id: svc
    readonly property string flagPath: Quickshell.env("HOME") + "/.config/yumi/polkit-qs"
    property bool enabled: false
    readonly property bool registered: loader.item ? loader.item.registered : false

    Process { running: true; command: ["test", "-e", svc.flagPath]; onExited: (code) => svc.enabled = code === 0 }

    LazyLoader {
        id: loader
        active: svc.enabled
        Scope {
            readonly property bool registered: agent.isRegistered
            PolkitAgent {
                id: agent
                onIsRegisteredChanged: console.log("yumi-polkit: агент " + (isRegistered ? "зарегистрирован" : "не зарегистрирован"))
            }
            PolkitPrompt { flow: agent.flow }
        }
    }
}
