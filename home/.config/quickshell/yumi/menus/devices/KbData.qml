import QtQuick
import Quickshell
import Quickshell.Io

// Подсветка клавиатуры (Logitech PRO Gaming) — как в yumi-menu-devices: состояние из ~/.config/yumi/kb/state.json,
// команды — ~/.local/bin/yumi-kb-light (OpenRGB, 1–3 с; по одной, лишние ждут очереди — последняя побеждает).
// YP_DRYRUN=1 — команды только пишутся в журнал. Ответ — сигнал done(ok, текст).
Item {
    id: root
    readonly property string home: Quickshell.env("HOME")
    readonly property bool dry: Quickshell.env("YP_DRYRUN") === "1"
    property var st: ({ brightness: 100, on: true, source: "wall", color: "FFFFFF" })
    property var fake: ({})                // dry-run: что «применили»
    readonly property var state: Object.assign({}, st, fake)
    signal done(bool ok, string text)

    FileView {
        id: file
        path: root.home + "/.config/yumi/kb/state.json"
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.st = Object.assign({ brightness: 100, on: true, source: "wall", color: "FFFFFF" }, JSON.parse(text())) } catch (e) {} }
    }
    function reload() { file.reload() }

    property var queued: null
    Process {
        id: proc
        property string out: ""
        stdout: SplitParser { onRead: l => { if (l.trim()) proc.out = l.trim() } }
        onExited: (code) => {
            root.done(code === 0, code === 0 ? proc.out.slice(0, 70) : "OpenRGB не ответил — клавиатура подключена?")
            file.reload()
            if (root.queued) { const q = root.queued; root.queued = null; root.run(q) }
        }
    }
    function run(args) {
        if (dry) {
            console.log("[dry-run] yumi-kb-light " + args.join(" "))
            const f = Object.assign({}, fake)
            if (args[0] === "on" || args[0] === "off") f.on = args[0] === "on"
            else if (args[0] === "wall") f.source = "wall"
            else if (args[0] === "color") { f.source = "fixed"; f.color = args[1] }
            else f.brightness = parseInt(args[0])
            fake = f
            done(true, "")
            return
        }
        if (proc.running) { queued = args; return }
        proc.out = ""; proc.command = [home + "/.local/bin/yumi-kb-light"].concat(args); proc.running = true
    }
    function setOn(on) { run([on ? "on" : "off"]) }
    function setBrightness(v) { run([String(Math.round(v))]) }
    function setWall() { run(["wall"]) }
    function setColor(hex) { run(["color", hex]) }
}
