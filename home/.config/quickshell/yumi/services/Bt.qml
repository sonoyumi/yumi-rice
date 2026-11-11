pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Bluetooth: обёртка над бэкендом ~/.local/lib/yumi/qs/bluetooth (D-Bus BlueZ, bluetoothctl, aap.py для AirPods;
// логика как у yumi-menu-bluetooth). Бэкенд живёт, пока меню открыто (wanted), и ещё 2 минуты после.
Singleton {
    id: root
    property bool wanted: false
    property bool loaded: false
    property var powered: null             // true / false / null — служба недоступна
    property var adapter: ({})             // {alias, address, discoverable, pairable}
    property int connectedCount: 0
    property bool scanning: false
    property int scanLeft: 0
    property bool dry: false
    property var busy: ({})                // mac → текст («Подключаю…»)
    property var airpods: ({})             // mac → снимок AAP {status, message, battery, ear, mode, allowed, conv, …}
    property var cards: ({})               // mac → {group, a2dp, hfp} — профиль звука
    property string pairMac: ""
    property var pairSteps: ["wait", "wait", "wait"]
    readonly property var pairTitles: ["Сопряжение", "Доверие", "Подключение"]
    property var pairAgent: null           // {kind: confirm|pin|passkey|display, code}
    property var pairResult: null          // {ok, msg}
    readonly property ListModel connectedModel: ListModel { dynamicRoles: true }
    readonly property ListModel pairedModel: ListModel { dynamicRoles: true }
    readonly property ListModel foundModel: ListModel { dynamicRoles: true }
    signal toast(string text, bool error)
    signal result(string cmd, string mac, bool ok, string msg)

    function send(obj) { if (proc.running) proc.write(JSON.stringify(obj) + "\n") }
    function setPower(on) { send({ cmd: "power", on: on }) }
    function connectDev(mac) { send({ cmd: "connect", mac: mac }) }
    function disconnectDev(mac) { send({ cmd: "disconnect", mac: mac }) }
    function trust(mac, on) { send({ cmd: "trust", mac: mac, on: on }) }
    function block(mac, on) { send({ cmd: "block", mac: mac, on: on }) }
    function remove(mac) { send({ cmd: "remove", mac: mac }) }
    function scan(on) { send({ cmd: "scan", on: on }) }
    function pair(mac) { pairMac = mac; pairSteps = ["wait", "wait", "wait"]; pairAgent = null; pairResult = null; send({ cmd: "pair", mac: mac }) }
    function pairReply(text) { pairAgent = null; send({ cmd: "pair_reply", text: text }) }
    function pairCancel() { if (pairMac) send({ cmd: "pair_cancel" }); pairMac = ""; pairAgent = null; pairResult = null }
    function airpodsSession(mac, on) { send({ cmd: "airpods", mac: mac, on: on }); if (!on) { const a = Object.assign({}, airpods); delete a[mac]; airpods = a } }
    function airpodsMode(mac, mode) { send({ cmd: "airpods_mode", mac: mac, mode: mode }) }
    function airpodsConv(mac, on) { send({ cmd: "airpods_conv", mac: mac, on: on }) }
    function card(mac) { send({ cmd: "card", mac: mac }) }
    function profile(mac, group) { send({ cmd: "profile", mac: mac, group: group }) }

    function syncModel(model, items, key) {
        for (let i = 0; i < items.length; i++) {
            let found = -1
            for (let j = i; j < model.count; j++) if (model.get(j)[key] === items[i][key]) { found = j; break }
            if (found < 0) model.insert(i, items[i])
            else { if (found !== i) model.move(found, i, 1); model.set(i, items[i]) }
        }
        while (model.count > items.length) model.remove(items.length)
    }

    function apply(line) {
        let j
        try { j = JSON.parse(line) } catch (e) { console.log("bt: не JSON:", line); return }
        switch (j.type) {
        case "state": {
            powered = j.powered; adapter = j.adapter; dry = j.dry; scanning = j.scanning; scanLeft = j.left
            const devs = j.devices
            connectedCount = devs.filter(d => d.connected).length
            syncModel(connectedModel, devs.filter(d => d.paired && d.connected), "mac")
            syncModel(pairedModel, devs.filter(d => d.paired && !d.connected), "mac")
            syncModel(foundModel, devs.filter(d => !d.paired && d.hasName), "mac")
            loaded = true
            break
        }
        case "busy": { const b = Object.assign({}, busy); if (j.text) b[j.mac] = j.text; else delete b[j.mac]; busy = b; break }
        case "scan": scanning = j.on; scanLeft = j.left; break
        case "toast": toast(j.text, j.error); break
        case "result": result(j.cmd, j.mac || "", j.ok, j.msg || ""); break
        case "airpods": airpods = Object.assign({}, airpods, { [j.mac]: j }); break
        case "card": cards = Object.assign({}, cards, { [j.mac]: j }); break
        case "pair": { if (j.mac !== pairMac) break; const s = pairSteps.slice(); s[j.step] = j.state; pairSteps = s; break }
        case "pair_agent": pairAgent = (j.mac === pairMac && j.kind) ? { kind: j.kind, code: j.code || "" } : null; break
        case "pair_done": if (j.mac === pairMac) { pairAgent = null; pairResult = { ok: j.ok, msg: j.msg || "" } } break
        }
    }

    Process {
        id: proc
        command: ["python3", "-I", Quickshell.env("HOME") + "/.local/lib/yumi/qs/bluetooth"]
        running: root.wanted || grace.running
        stdout: SplitParser { onRead: line => root.apply(line) }
        stderr: SplitParser { onRead: line => console.log("bt:", line) }
        onExited: { root.loaded = false; root.scanning = false; root.busy = ({}); root.airpods = ({}); root.cards = ({}); root.pairMac = "" }
    }
    Timer { id: grace; interval: 120000 }
    onWantedChanged: if (wanted) grace.stop(); else grace.restart()
}
