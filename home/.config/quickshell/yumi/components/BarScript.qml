import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "Pango.js" as Pango

// Обёртка над скриптами пилюль ~/.local/lib/yumi/bar/* (формат Waybar: JSON {text,tooltip,class,alt,percentage}).
//   command:  ["/path/script", "arg"]   interval: сек (0 = бесконечный поток, как restart-interval)
//   name:     имя для Signals.refresh(name) — замена pkill -RTMIN+N waybar
// Наружу: text (rich text Qt), raw (как есть), tooltip, cls, alt, percentage, ok (скрипт что-то выдал).
QtObject {
    id: root
    property list<string> command: []
    property int interval: 0
    property string name: ""
    property bool enabled: true

    property string raw: ""
    property string text: ""
    property string tooltip: ""
    property string cls: ""
    property string alt: ""
    property real percentage: -1
    property bool ok: false

    function refresh() { if (!proc.running) proc.running = true; else restartPending = true }
    property bool restartPending: false

    function apply(line) {
        line = line.trim(); if (!line) return
        let j = null
        try { j = JSON.parse(line) } catch (e) { j = { text: line } }
        raw = j.text || ""
        text = Pango.toQt(raw, Theme.fontSize, Colors.fg)
        tooltip = Pango.toQt(j.tooltip || "", Theme.fontSize, Colors.fg)
        cls = Array.isArray(j.class) ? j.class.join(" ") : (j.class || "")
        alt = j.alt || ""
        percentage = (j.percentage !== undefined) ? Number(j.percentage) : -1
        ok = true
    }

    property Process proc: Process {
        command: root.command
        running: root.enabled && root.command.length > 0
        stdout: SplitParser { onRead: (line) => root.apply(line) }
        onExited: {
            if (root.restartPending) { root.restartPending = false; running = true; return }
            if (root.interval === 0 && root.enabled) restart.start()   // поток упал — поднять через 3 с (restart-interval)
        }
    }
    property Timer restart: Timer { interval: 3000; onTriggered: if (root.enabled) root.proc.running = true }
    property Timer tick: Timer {
        interval: root.interval * 1000; running: root.interval > 0 && root.enabled; repeat: true
        onTriggered: root.refresh()
    }
    property Connections sig: Connections {
        target: Signals
        function onRefresh(n) { if (n === root.name && root.name) root.refresh() }
    }
}
