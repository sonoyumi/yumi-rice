import QtQuick
import Quickshell
import Quickshell.Io

// Данные мыши (Logitech PRO X 2) — обёртка над бэкендом ~/.local/lib/yumi/qs/mouse (Solaar + hidpp из ядра).
// active — бэкенд запущен (меню открыто или ещё grace мс после закрытия). Сообщения для шапки — toast(text, error).
Item {
    id: root
    property bool active: false
    property int grace: 30000
    readonly property string device: "PRO X 2"
    property var bat: null                 // {pct, state, model, maker} | null — не на связи
    property bool batKnown: false
    property var st: ({})                  // {dpi, rate_hz, onboard, onboard_choices}
    property bool loading: true
    property int busy: 0
    property bool dry: Quickshell.env("YP_DRYRUN") === "1"
    signal toast(string text, bool error, int hold)
    readonly property bool charging: bat !== null && (bat.state === "charging" || bat.state === "full")
    // «PRO X 2 · 56% · 800 DPI · 1000 Гц» (подзаголовок GTK-меню)
    readonly property string summary: {
        const p = [device]
        if (bat) p.push(bat.pct + "%" + (charging ? " 󱐋" : ""))
        else if (batKnown) p.push("не на связи")
        if (st.dpi) p.push(st.dpi + " DPI")
        if (st.rate_hz) p.push(st.rate_hz + " Гц")
        return p.join(" · ")
    }
    // «67% · 800 DPI» — пометка строки в «Устройствах»
    readonly property string meta: [bat ? bat.pct + "%" : "", st.dpi ? st.dpi + " DPI" : ""].filter(x => x).join(" · ")

    Timer { id: hold; interval: root.grace }
    onActiveChanged: if (!active) hold.restart(); else { hold.stop(); send({ cmd: "refresh" }) }
    Process {
        id: proc
        command: [Quickshell.env("HOME") + "/.local/lib/yumi/qs/mouse"]
        running: root.active || hold.running
        stdinEnabled: true
        stdout: SplitParser { onRead: line => root.apply(line) }
        stderr: SplitParser { onRead: line => console.log("mouse:", line) }
        onExited: { root.loading = true; root.busy = 0 }
    }
    function send(o) { if (proc.running) proc.write(JSON.stringify(o) + "\n") }
    function apply(line) {
        let j; try { j = JSON.parse(line) } catch (e) { return }
        if (j.t === "bat") { bat = j.off ? null : j; batKnown = true }
        else if (j.t === "st") { const s = Object.assign({}, j); delete s.t; delete s.loading; st = s; loading = !!j.loading }
        else if (j.t === "solaar_fail") toast("Solaar не ответил — DPI из конфига Solaar", true, 4)
        else if (j.t === "busy") { busy++; toast(j.label + "…", false, 10) }
        else if (j.t === "done") {
            busy = Math.max(0, busy - 1)
            if (j.ok) toast(j.label + " — готово" + (dry ? " (dry-run)" : ""), false, 3)
            else toast("Не удалось: " + j.msg, true, 5)
        }
    }
    function setDpi(d) { if (d !== st.dpi) send({ cmd: "dpi", v: d }) }
    function setRate(h) { if (h !== st.rate_hz) send({ cmd: "rate", hz: h }) }
    function setOnboard(on) { send({ cmd: "onboard", on: on }) }
    function openSolaar() { send({ cmd: "solaar" }) }
}
