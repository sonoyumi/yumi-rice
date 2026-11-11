pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Одна cava на все бары (раньше — по копии на монитор). Эквалайзеры баров задают playing/sink (одинаковые)
// и читают target; rev растёт с каждой строкой cava. Живёт только пока играет.
// Звук (18.10): только музыка — yumi-cava-source --run сам запускает cava и кормит её потоком плеера
// (pw-record по потоку mpv/браузера), Discord, уведомления и звонки не попадают; выход (AirPods/динамики) неважен.
Singleton {
    id: root
    property bool playing: false
    property string sink: ""
    readonly property int bars: 10
    property var target: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property int rev: 0
    property bool restart: false

    readonly property string conf: Quickshell.env("XDG_RUNTIME_DIR") + "/yumi-qs-cava.conf"
    readonly property string script:
        "conf=$0; " +
        "printf '[general]\\nbars = 10\\nframerate = 30\\nautosens = 1\\n" +
        "[input]\\nmethod = fifo\\nsource = /dev/stdin\\nsample_rate = 48000\\nsample_bits = 16\\nchannels = 2\\n" +
        "[output]\\nmethod = raw\\nraw_target = /dev/stdout\\ndata_format = ascii\\nascii_max_range = 1000\\n" +
        "channels = mono\\nmono_option = average\\n[smoothing]\\nmonstercat = 1\\nnoise_reduction = 40\\n' > \"$conf\" " +
        "&& exec \"$HOME/.local/bin/yumi-cava-source\" --run \"$conf\""

    Process {
        id: cava
        command: ["sh", "-c", root.script, root.conf]
        stdout: SplitParser { onRead: (line) => {
            const p = line.split(";"), n = Math.min(root.bars, p.length)
            for (let i = 0; i < n; i++) root.target[i] = Math.min(1, (parseInt(p[i]) || 0) / 1000)
            root.rev++ } }
        onExited: {
            if (root.restart) { root.restart = false; running = true }
            else if (root.playing) retry.start()
        }
    }
    Timer { id: retry; interval: 3000; onTriggered: if (root.playing && !cava.running) cava.running = true }
    function sync() {
        if (cava.running) { root.restart = root.playing; cava.running = false }
        else if (root.playing) cava.running = true
    }
    onPlayingChanged: if (playing !== cava.running) sync()
    onSinkChanged: if (cava.running) sync()
}
