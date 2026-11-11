import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Обёртка над бэкендом ~/.local/lib/yumi/qs/session (команды как у yumi-menu-session: loginctl, systemctl, uwsm stop).
// Бэкенд живёт, пока меню открыто (wanted), и ещё минуту после. YP_DRYRUN=1 наследуется из окружения —
// команды только печатаются (блокировка = настоящий hyprlock, проверять только так).
Scope {
    id: root
    property bool wanted: false
    property bool loaded: false
    property bool dry: false
    property string user: ""
    property string uptime: ""
    property string subtitle: ""
    property var commands: ({})          // действие → строка команды (для показа)
    signal done(string action, string text)
    signal dryRun(string action, string text, string cmd)

    function send(obj) { if (proc.running) proc.write(JSON.stringify(obj) + "\n") }
    function run(action) { send({ cmd: "run", action: action }) }

    function apply(line) {
        let j
        try { j = JSON.parse(line) } catch (e) { console.log("session: не JSON:", line); return }
        switch (j.type) {
        case "info": user = j.user; uptime = j.uptime; subtitle = j.subtitle; dry = !!j.dry; loaded = true; break
        case "commands": delete j.type; commands = j; break
        case "done": done(j.action, j.text); break
        case "dry": dryRun(j.action, j.text, j.cmd); break
        }
    }

    Process {
        id: proc
        command: ["python3", "-I", Quickshell.env("HOME") + "/.local/lib/yumi/qs/session"]
        running: root.wanted || grace.running
        stdout: SplitParser { onRead: line => root.apply(line) }
        stderr: SplitParser { onRead: line => console.log("session:", line) }
        onExited: root.loaded = false
    }
    Timer { id: grace; interval: 60000 }
    onWantedChanged: if (wanted) grace.stop(); else grace.restart()
}
