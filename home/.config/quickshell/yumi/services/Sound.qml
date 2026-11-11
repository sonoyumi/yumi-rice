pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Звук для меню и бара. Живые данные — Quickshell.Services.Pipewire: списки устройств/потоков, громкость,
// «без звука», устройство по умолчанию (preferredDefaultAudioSink/Source). Всё остальное — Python-бэкенд
// ~/.local/lib/yumi/qs/sound (pactl): понятные имена и значки, разъёмы, профили карт, баланс, перенос потоков,
// кто слушает микрофон. Устройства сшиваются по имени узла, потоки — по object.serial (= индекс pactl).
// Бэкенд живёт, пока active (меню открыто) + 60 с после, чтобы повторное открытие было мгновенным.
// YP_DRYRUN=1 — ничего не меняется: действия только печатаются бэкендом и показываются тостом.
Singleton {
    id: root
    readonly property bool dry: Quickshell.env("YP_DRYRUN") === "1"
    readonly property string backend: Quickshell.env("HOME") + "/.local/lib/yumi/qs/sound"
    property bool active: false
    property bool islandActive: false     // остров плеера открыт: нужен список выходов (имена, значки, где играет поток)
    property bool fullActive: false       // полноэкранный плеер открыт (тот же чип выхода)
    readonly property bool wanted: active || islandActive || fullActive
    signal toast(string text, bool error)

    // ---------- PipeWire ----------
    readonly property var nodes: Pipewire.nodes.values
    function isType(n, flag) { return n && (n.type & flag) === flag }
    readonly property var sinks:   nodes.filter(n => isType(n, PwNodeType.AudioSink) && !n.isStream)
    readonly property var sources: nodes.filter(n => isType(n, PwNodeType.AudioSource) && !n.isStream)
    readonly property var outStreams: nodes.filter(n => isType(n, PwNodeType.AudioOutStream))
    readonly property var inStreams:  nodes.filter(n => isType(n, PwNodeType.AudioInStream))
    readonly property var defaultSink:   Pipewire.defaultAudioSink
    readonly property var defaultSource: Pipewire.defaultAudioSource
    PwObjectTracker { objects: root.tracked() }
    function tracked() {   // списки QML — не настоящие массивы JS (нет concat/flatMap); при старте могут быть пустыми
        const out = []
        for (const l of [root.sinks, root.sources, root.outStreams, root.inStreams]) if (l) for (let i = 0; i < l.length; i++) out.push(l[i])
        return out
    }

    function serialOf(n) { return n ? String(n.properties["object.serial"] ?? n.id) : "" }
    function nodeByName(list, name) { return list.find(n => n.name === name) ?? null }
    function nodeBySerial(list, serial) { return list.find(n => root.serialOf(n) === String(serial)) ?? null }
    function vol(n) { return n && n.audio ? Math.max(0, n.audio.volume) : 0 }
    function muted(n) { return !!(n && n.audio && n.audio.muted) }

    // ---------- состояние от бэкенда ----------
    property var state: ({ sinks: [], sources: [], streams: [], rec: [], cards: [], mics: 0, def_sink: "", def_src: "" })
    readonly property bool ready: state.sinks.length > 0 || state.sources.length > 0
    function devInfo(kind, name) { return (kind === "sink" ? state.sinks : state.sources).find(d => d.name === name) ?? null }
    function cardInfo(name) { return state.cards.find(c => c.name === name) ?? null }
    function streamInfo(kind, serial) { return (kind === "sink" ? state.streams : state.rec).find(s => s.serial === String(serial)) ?? null }
    // Стабильные ключи для списков (ScriptModel): карточки не пересоздаются при смене громкости/mute/устройства
    readonly property var streamSerials: state.streams.map(s => s.serial)
    readonly property var micSerials: state.rec.filter(s => !s.monitor).map(s => s.serial)
    readonly property var monSerials: state.rec.filter(s => s.monitor).map(s => s.serial)
    // Имя устройства: от бэкенда («Динамики»), пока его нет — описание узла PipeWire
    function devName(kind, n) { const i = n ? devInfo(kind, n.name) : null; return i ? i.ru : (n ? (n.description || n.nickname || n.name) : "—") }
    function devIcon(kind, n) { const i = n ? devInfo(kind, n.name) : null; return i ? i.icon : (kind === "sink" ? "󰓃" : "󰍬") }

    Process {
        id: proc
        command: ["python3", "-I", root.backend]
        running: root.wanted || grace.running
        stdinEnabled: true
        stdout: SplitParser {
            onRead: (line) => {
                let j; try { j = JSON.parse(line) } catch (e) { return }
                if (j.type === "state") root.state = j
                else if (j.type === "toast") root.toast(j.text, !!j.error)
            }
        }
        stderr: SplitParser { onRead: (line) => { if (line.trim()) console.log("sound-backend:", line) } }
    }
    Timer { id: grace; interval: 60000 }
    onWantedChanged: { if (!wanted) grace.restart(); else { grace.stop(); if (proc.running) send({ cmd: "refresh" }) } }
    function send(obj) { if (proc.running) proc.write(JSON.stringify(obj) + "\n") }

    // ---------- действия ----------
    // громкость 0..1 (как pactl %/100). Стерео с балансом — пропорционально по каналам, чтобы не сбить баланс
    function setVolume(n, v) {
        v = Math.max(0, Math.min(1.5, v))
        if (dry) { toast("[проверка] громкость " + Math.round(v * 100) + "%", false); return }
        if (!n || !n.audio) return
        const vols = n.audio.volumes
        if (vols.length === 2 && Math.abs(vols[0] - vols[1]) > 0.005) {
            const m = Math.max(vols[0], vols[1]) || 1
            n.audio.volumes = [v * vols[0] / m, v * vols[1] / m]
        } else n.audio.volume = v
        if (v > 0 && n.audio.muted) n.audio.muted = false   // 19.10: на 0 узел уходит в «без звука» — подняли выше нуля — звук обратно
    }
    function toggleMute(n) {
        if (dry) { toast("[проверка] без звука: " + (n ? n.name : "?"), false); return }
        if (n && n.audio) n.audio.muted = !n.audio.muted
    }
    function setDefault(kind, n) {
        if (!n) return
        if ((kind === "sink" ? defaultSink : defaultSource) === n) return
        if (dry) { send({ cmd: "set-default", kind: kind, name: n.name }); return }
        if (kind === "sink") Pipewire.preferredDefaultAudioSink = n; else Pipewire.preferredDefaultAudioSource = n
        toast((kind === "sink" ? "Выход: " : "Вход: ") + devName(kind, n), false)
    }
    function setPort(kind, name, port)     { send({ cmd: "set-port", kind: kind, name: name, port: port }) }
    function setProfile(card, key)         { send({ cmd: "set-profile", card: card, key: key }) }
    function setBalance(kind, name, value) { send({ cmd: "set-balance", kind: kind, name: name, value: Math.round(value) }) }
    function move(kind, index, target)     { send({ cmd: "move", kind: kind, index: index, target: target }) }
    // поток без узла PipeWire (ещё не появился в модели) — через pactl по индексу
    function setStreamVolume(info, n, v) { if (n && !dry) setVolume(n, v); else send({ cmd: "stream-vol", kind: info.kind, index: info.index, value: Math.round(v * 100) }) }
    function toggleStreamMute(info, n)   { if (n && !dry) toggleMute(n); else send({ cmd: "stream-mute", kind: info.kind, index: info.index }) }
    function openSettings() { Quickshell.execDetached(["pavucontrol"]) }
}
