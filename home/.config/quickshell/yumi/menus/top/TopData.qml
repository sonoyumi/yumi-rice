import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Данные меню «Процессы»: бэкенд ~/.local/lib/yumi/qs/top (поток JSON, живёт только пока active).
// Система (cpu/ram/temp/load/up) — раз в 1 с, приложения — раз в 2 с. Список приложений — ListModel `rows`,
// обновляется НА МЕСТЕ (set/move/insert/remove по имени), чтобы строки не мигали и не пересоздавались.
Item {
    id: root
    property bool active: false
    property string sort: "mem"               // "mem" | "cpu"
    property int maxRows: 8
    readonly property bool dry: Quickshell.env("YP_DRYRUN") === "1"

    // система
    property bool ready: false                // пришёл первый замер
    property real cpu: 0
    property real used: 0                     // кБ
    property real total: 1
    readonly property real ram: total > 0 ? used / total * 100 : 0
    property var temp: null                   // [°C, датчик] | null
    property var load: [0, 0, 0]
    property int up: 0
    property var hidden: []
    property int ncpu: 1
    signal sample(real cpu, real ram)         // для графиков

    // приложения
    property var apps: []                     // как пришли (отсортированы по памяти)
    property bool appsReady: false
    property ListModel rows: ListModel { id: model }
    property string page: ""                  // приложение подстраницы
    property var info: null                   // сведения о нём
    signal result(string sig, string name, bool ok, string msg, int n, bool dryRun)

    function fmtSize(kb) { return kb >= 1048576 ? (kb / 1048576).toFixed(1) + " ГБ" : Math.round(kb / 1024) + " МБ" }
    function fmtGb(kb) { return (kb / 1048576).toFixed(1) }
    function fmtDuration(sec) {
        sec = Math.max(0, Math.floor(sec))
        const d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60), s = sec % 60
        if (d) return d + " д " + h + " ч"
        if (h) return h + " ч " + (m < 10 ? "0" : "") + m + " мин"
        if (m) return m + " мин " + (s < 10 ? "0" : "") + s + " с"
        return s + " с"
    }
    function level(pct) { return pct >= 90 ? "crit" : pct >= 70 ? "warn" : "" }

    function send(obj) { if (proc.running) proc.write(JSON.stringify(obj) + "\n") }
    function setPage(name) { page = name; info = null; send({ cmd: "page", name: name }) }
    function signal(name, sig) { send({ cmd: "signal", name: name, sig: sig }) }

    onSortChanged: fill()
    onActiveChanged: if (!active) { ready = false; appsReady = false; page = ""; info = null }

    // список: верхние maxRows по текущей сортировке, правка модели на месте
    function fill() {
        const key = sort === "cpu" ? (a => -a.pct) : (a => -a.mem)
        const top = apps.slice().sort((a, b) => key(a) - key(b)).slice(0, maxRows)
        for (let i = 0; i < top.length; i++) {
            const a = top[i]
            const row = { name: a.name, mem: a.mem, pct: a.pct, n: a.n, prot: a.prot, icon: a.icon || "" }
            let j = -1
            for (let k = i; k < model.count; k++) if (model.get(k).name === a.name) { j = k; break }
            if (j < 0) model.insert(i, row)
            else { if (j !== i) model.move(j, i, 1); model.set(i, row) }
        }
        while (model.count > top.length) model.remove(model.count - 1)
    }

    Process {
        id: proc
        running: root.active
        command: ["python3", "-I", Quickshell.env("HOME") + "/.local/lib/yumi/qs/top"]
        stdinEnabled: true
        stdout: SplitParser { onRead: (line) => root.handle(line) }
        stderr: SplitParser { onRead: (l) => { if (l.trim()) console.log("top:", l) } }
    }
    function handle(line) {
        let d
        try { d = JSON.parse(line) } catch (e) { return }
        if (d.t === "sys") {
            cpu = d.cpu; used = d.used; total = d.total; temp = d.temp; load = d.load; up = d.up
            ready = true
            sample(cpu, ram)
        } else if (d.t === "apps") {
            apps = d.apps; fill(); appsReady = true
        } else if (d.t === "hello") {
            hidden = d.hidden; ncpu = d.ncpu
        } else if (d.t === "info") {
            if (d.name === page) info = d
        } else if (d.t === "result") {
            result(d.sig, d.name, d.ok, d.msg || "", d.n || 0, !!d.dry)
        }
    }
}
