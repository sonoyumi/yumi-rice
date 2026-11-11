import QtQuick
import Quickshell
import qs
import qs.services

// Эквалайзер в пилюле плеера — замена cffi/yumi-eq (стиль classic): 10 столбиков 3 px, зазор 2, высота 16,
// цвет Colors.acc, скругление 1.5. Данные — cava (raw / ascii) с МОНИТОРА текущего выхода через pulse
// (source = auto у pipewire — это микрофон Bluetooth-наушников, нельзя). cava живёт только пока играет
// (playing), при смене выхода перезапускается; на паузе столбики оседают до 12 % и бледнеют, после чего
// кадры не считаются вовсе. Сглаживание — как в yumi-eq: подъём быстрее спада, перерисовка от 0.5 px.
Item {
    id: root
    property bool playing: false
    property string sink: ""                   // имя выхода PipeWire → <sink>.monitor; пусто — pactl get-default-sink
    // «Остров» (29.10): размеры задаёт место — бар/остров idle: 4 столбика 2.5 px, зазор 2, высота 12, скругление 1.25;
    // при bars < 10 полосы cava усредняются группами (низы слева)
    property int bars: 10
    property real bw: 3
    property real gap: 2
    property int eh: 16
    property real rad: 0
    implicitWidth: bars * bw + (bars - 1) * gap
    implicitHeight: eh

    property var target: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var disp:   [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var drawn:  [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    function group(src) {
        if (bars >= src.length) return src
        const out = [], n = src.length
        for (let i = 0; i < bars; i++) {
            const a = Math.floor(i * n / bars), b = Math.max(a + 1, Math.floor((i + 1) * n / bars))
            let v = 0; for (let j = a; j < b; j++) v = Math.max(v, src[j]); out.push(v)
        }
        return out
    }
    property real fade: 0
    property int tick: 0            // меняется, когда столбики надо перерисовать
    // данные — общий services/Cava (одна cava на оба бара)
    Binding { target: Cava; property: "playing"; value: root.playing }
    Binding { target: Cava; property: "sink"; value: root.sink }
    Connections { target: Cava; function onRevChanged() { if (!root.visible) return; root.target = root.group(Cava.target); if (!anim.running) anim.running = true } }   // скрыт (слой острова погас) — кадры не считаем
    onPlayingChanged: anim.running = true
    onVisibleChanged: if (!visible) anim.running = false

    // 29.10: ровно 60 к/с (как раньше на экране ноутбука) вместо FrameAnimation — тот тикал на каждом кадре экрана,
    // на MSI это 165 перерисовок окна острова в секунду, пока играет музыка
    Timer {
        id: anim
        interval: 16; repeat: true; running: false
        property real last: 0
        onRunningChanged: last = Date.now()
        onTriggered: { const now = Date.now(); root.step(Math.min(0.05, (now - last) / 1000)); last = now }
    }
    function step(dt) {
        const want = playing ? 1 : 0
        fade += (want - fade) * (1 - Math.exp(-dt * 6))
        let moving = Math.abs(want - fade), changed = false
        for (let i = 0; i < bars; i++) {
            const tgt = playing ? target[i] : 0
            const rate = tgt > disp[i] ? 40 : 18                  // резкий подъём, быстрый спад — в ритм трека
            disp[i] += (tgt - disp[i]) * (1 - Math.exp(-dt * rate))
            moving += disp[i]
            const px = ((0.18 + 0.82 * disp[i]) * fade + 0.12 * (1 - fade)) * eh
            if (Math.abs(px - drawn[i]) >= 0.5) changed = true
        }
        if (changed) {
            for (let i = 0; i < bars; i++) drawn[i] = ((0.18 + 0.82 * disp[i]) * fade + 0.12 * (1 - fade)) * eh
            root.tick++
        }
        if (!playing && moving < 0.01) anim.running = false   // всё осело — не считать впустую
    }

    // столбики рисует видеокарта (раньше — холст программно с частотой экрана, 165 к/с на MSI)
    Repeater {
        model: root.bars
        delegate: Rectangle {
            required property int index
            readonly property real bh: { root.tick; return Math.max(1.5, root.drawn[index]) }
            x: index * (root.bw + root.gap); width: root.bw; height: bh
            y: Math.floor((root.height + root.eh) / 2) - bh
            radius: root.rad
            color: Colors.alpha(Colors.acc, 0.45 + 0.55 * root.fade)
        }
    }
}
