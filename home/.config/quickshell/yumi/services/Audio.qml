pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Звук через PipeWire: громкость/выкл выхода (sink) и микрофона (source) по умолчанию.
// Общий для OSD, центра управления и бара. Запись в громкость — тоже здесь (setVolume/setMicVolume/toggleMute…).
// YP_DRYRUN=1 — ничего не менять, только печатать в журнал.
Singleton {
    id: root
    readonly property bool dry: Quickshell.env("YP_DRYRUN") === "1"
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [root.sink, root.source] }

    // выход
    readonly property bool ready: sink !== null && sink.ready && sink.audio !== null
    readonly property real vol: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property string sinkName: sink ? sink.name : ""
    readonly property string sinkDesc: sink ? (sink.description || sink.nickname || "") : ""
    readonly property bool airpods: sinkName.startsWith("bluez_output.98_1C_A2_DD_1F_EE")
    readonly property bool jack: sinkName === "alsa_output.platform-sound.HiFi__Headphones__sink"
    readonly property bool bluetooth: sinkName.startsWith("bluez_output.")

    // микрофон
    readonly property bool micReady: source !== null && source.ready && source.audio !== null
    readonly property real micVol: source && source.audio ? source.audio.volume : 0
    readonly property bool micMuted: source && source.audio ? source.audio.muted : false
    readonly property string sourceDesc: source ? (source.description || source.nickname || "") : ""

    function clamp(v) { return Math.max(0, Math.min(1, v)) }
    function setVolume(v) {
        if (dry) { console.log("[dry] громкость →", Math.round(clamp(v) * 100) + "%"); return }
        if (!sink || !sink.audio) return
        sink.audio.volume = clamp(v)
        // 19.10: на 0 выход сам уходит в «без звука» (Bluetooth/PipeWire) — подняли ползунок выше нуля — звук обратно
        if (clamp(v) > 0 && sink.audio.muted) sink.audio.muted = false
    }
    function setMicVolume(v) {
        if (dry) { console.log("[dry] микрофон →", Math.round(clamp(v) * 100) + "%"); return }
        if (!source || !source.audio) return
        source.audio.volume = clamp(v)
        if (clamp(v) > 0 && source.audio.muted) source.audio.muted = false   // 19.10: как у выхода
    }
    function toggleMute() {
        if (dry) { console.log("[dry] звук вкл/выкл"); return }
        if (sink && sink.audio) sink.audio.muted = !sink.audio.muted
    }
    function toggleMicMute() {
        if (dry) { console.log("[dry] микрофон вкл/выкл"); return }
        if (source && source.audio) source.audio.muted = !source.audio.muted
    }
}
