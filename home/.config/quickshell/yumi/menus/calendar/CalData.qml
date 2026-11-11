import QtQuick
import Quickshell
import Quickshell.Io

// Планы календаря: обёртка над бэкендом ~/.local/lib/yumi/qs/calendar (хранилище calstore, как у yumi-menu-calendar).
// Бэкенд живёт, пока меню открыто (wanted), и ещё 2 минуты после — повторное открытие мгновенное.
// Состояние приходит JSON-строками (state: today, now, events, weather), команды уходят JSON-строками в stdin.
Item {
    id: root
    property bool wanted: false
    // «Остров» (29.10, плавность): пока карточка растёт (hold), бэкенд не запускается и пришедшее состояние не применяется —
    // пересчёт сетки и создание строк планов идут после анимации. Одинаковое состояние повторно не применяется.
    property bool hold: false
    property string pending: ""
    property string lastState: ""
    onHoldChanged: if (!hold && pending) { const l = pending; pending = ""; apply(l) }
    property bool loaded: false
    property bool dry: false
    property string today: ""              // "2026-10-15" (с YP_CAL_NOW — подменённое)
    property string now: ""                // "13:48"
    property string weather: ""            // ~/.cache/yumi/weather.txt, если свежий
    property var events: []                // [{id, date, time|null, text, remind, done, …}] — отсортированы бэкендом
    signal result(string cmd, bool ok, string msg, string date)

    function send(obj) { if (proc.running) proc.write(JSON.stringify(obj) + "\n") }
    function save(ev) { send({ cmd: "save", ev: ev }) }
    function remove(id) { send({ cmd: "delete", id: id }) }
    function setDone(id, on) { send({ cmd: "done", id: id, on: on }) }
    function refresh() { send({ cmd: "refresh" }) }
    function dayEvents(isoDate) { return events.filter(e => e.date === isoDate) }

    Process {
        id: proc
        command: ["python3", "-I", Quickshell.env("HOME") + "/.local/lib/yumi/qs/calendar"]
        running: (root.wanted && !root.hold) || grace.running
        stdout: SplitParser { onRead: line => root.apply(line) }
        stderr: SplitParser { onRead: line => console.log("calendar:", line) }
        onExited: { root.loaded = false; root.lastState = "" }
    }
    Timer { id: grace; interval: 120000 }
    onWantedChanged: if (wanted) grace.stop(); else grace.restart()

    function apply(line) {
        let j
        try { j = JSON.parse(line) } catch (e) { console.log("calendar: не JSON:", line); return }
        if (j.type === "state") {
            if (hold) { pending = line; return }
            if (line === lastState) { loaded = true; return }
            lastState = line
            today = j.today; now = j.now; weather = j.weather || ""; dry = !!j.dry
            events = j.events || []
            loaded = true
        } else if (j.type === "result") result(j.cmd, !!j.ok, j.msg || "", j.date || "")
    }
}
