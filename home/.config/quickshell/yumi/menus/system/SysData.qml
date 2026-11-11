import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Обёртка над бэкендом ~/.local/lib/yumi/qs/system (данные и команды как у yumi-menu-system).
// Бэкенд живёт, пока меню открыто (wanted), и ещё 2 минуты после — повторное открытие мгновенное.
// Состояние приходит JSON-строками, команды уходят JSON-строками в stdin. YP_DRYRUN=1 наследуется из окружения.
Scope {
    id: root
    property bool wanted: false
    property bool loaded: false
    property bool dry: false
    property string subtitle: ""
    property var recs: null              // [[менеджер, число]] или null — кеша yumi-update нет
    property var updList: null           // {менеджер: [[пакет, старая, новая]]} — после updates_list
    property var snaps: null             // {root: [...], home: [...]}; null — ещё загружаю; {} — snapper не настроен
    property string snapNote: ""
    property var stats: null             // {disk, mem, bat, temp: {text, frac, level, icon, tip}}
    property var doc: null               // отчёт yumi-doctor --json
    property bool docStale: false        // отчёт из кеша, новая проверка идёт
    property bool docRunning: false
    property bool snapping: false
    property bool listing: false
    signal toast(string text, bool error, int hold)
    signal dryText(string text)
    signal launched(string key)

    function send(obj) { if (proc.running) proc.write(JSON.stringify(obj) + "\n") }
    function launch(key) { send({ cmd: "launch", key: key }) }
    function listUpdates() { send({ cmd: "updates_list" }) }
    function snapshot() { send({ cmd: "snapshot" }) }
    function doctor(fix) { send({ cmd: fix ? "doctor_fix" : "doctor" }) }
    function doctorTerminal() { send({ cmd: "doctor_term" }) }
    function refresh() { send({ cmd: "refresh" }) }

    function apply(line) {
        let j
        try { j = JSON.parse(line) } catch (e) { console.log("system: не JSON:", line); return }
        switch (j.type) {
        case "info": subtitle = j.subtitle; dry = !!j.dry; loaded = true; break
        case "updates": recs = j.recs; break
        case "updates_list": updList = j.data; break
        case "snapshots": snaps = j.snaps; snapNote = j.note || ""; break
        case "stats": stats = j; break
        case "doctor": doc = j.rep; docStale = !!j.stale; docRunning = !!j.running; break
        case "busy":
            if (j.what === "snapshot") snapping = j.on
            else if (j.what === "updates") listing = j.on
            else if (j.what === "doctor") docRunning = j.on
            break
        case "toast": toast(j.text, !!j.error, j.hold || 3); break
        case "dry": dryText(j.text); break
        case "launched": launched(j.key); break
        }
    }

    Process {
        id: proc
        command: ["python3", "-I", Quickshell.env("HOME") + "/.local/lib/yumi/qs/system"]
        running: root.wanted || grace.running
        stdout: SplitParser { onRead: line => root.apply(line) }
        stderr: SplitParser { onRead: line => console.log("system:", line) }
        onExited: { root.loaded = false; root.updList = null; root.snapping = false; root.listing = false; root.docRunning = false }
    }
    Timer { id: grace; interval: 120000 }
    onWantedChanged: if (wanted) grace.stop(); else grace.restart()
}
