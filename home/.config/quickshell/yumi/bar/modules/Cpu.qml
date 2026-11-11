import QtQuick
import Quickshell.Io
import qs
import qs.components

// Загрузка ЦП по /proc/stat раз в 5 с (разница между замерами), как cpu в Waybar; min-length 5
Mod {
    id: m
    property real prevIdle: 0
    property real prevTotal: 0
    property int usage: 0
    minW: 30
    tip: "Процессор: " + usage + "%"
    Process {
        id: stat; command: ["head", "-1", "/proc/stat"]; running: true
        stdout: SplitParser { onRead: (l) => {
            const f = l.trim().split(/\s+/).slice(1).map(Number)
            const idle = f[3] + f[4], total = f.reduce((a, b) => a + b, 0)
            if (m.prevTotal > 0 && total > m.prevTotal) m.usage = Math.round(100 * (1 - (idle - m.prevIdle) / (total - m.prevTotal)))
            m.prevIdle = idle; m.prevTotal = total
        } }
    }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: stat.running = true }
    Glyph { text: "󰍛"; font.pixelSize: Theme.barIcon; color: m.ink }   // «Остров»: значок ЦП (было 核)
    Text { text: m.usage + "%"; font.family: Theme.fontUi; font.pixelSize: Theme.barFont; font.features: ({ "tnum": 1 })
           color: m.lit ? Colors.acc : (m.tone === Colors.fg ? Colors.fgDim : m.tone) }
}
