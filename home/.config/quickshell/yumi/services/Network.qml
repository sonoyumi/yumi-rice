pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wi-Fi: обёртка над бэкендом ~/.local/lib/yumi/qs/wifi (nmcli, nmcli monitor; логика как у yumi-menu-wifi).
// Бэкенд живёт, пока меню открыто (wanted), и ещё 2 минуты после — повторное открытие мгновенное.
// Состояние приходит JSON-строками, команды уходят JSON-строками в stdin. YP_DRYRUN=1 наследуется из окружения.
Singleton {
    id: root
    property bool wanted: false
    property bool loaded: false
    property bool radio: false
    property var cur: null                 // текущая сеть {ssid, signal, band, security, …} или null
    property var active: null              // [имя профиля, uuid]
    property int hidden: 0
    property int saved: 0
    property string busy: ""               // SSID, к которой идёт подключение
    property bool scanning: false
    property bool dry: false
    property var details: null             // ответ на details(): ip4, gw, dns, mac, ts, conf{autoconnect, metered}, …
    readonly property ListModel netModel: ListModel { dynamicRoles: true }   // доступные сети без текущей
    // «Сохранённые сети»: все профили NM (и тех сетей, которых сейчас нет рядом) и открытый профиль
    readonly property ListModel profileModel: ListModel { dynamicRoles: true }
    property bool profilesLoaded: false
    property int profilesCount: -1
    property string profilesText: ""
    property var profile: null             // {uuid, ssid, name, sub, current, secured, autoconnect, prio, metered, ip, addr, gw, dns, mac, macManual}
    signal toast(string text, bool error)
    signal result(string cmd, string ssid, bool ok, string msg)
    signal password(string text, bool ok, string uuid)

    function send(obj) { if (proc.running) proc.write(JSON.stringify(obj) + "\n") }
    function connectTo(ssid, pw) { send(pw === null || pw === undefined ? { cmd: "connect", ssid: ssid } : { cmd: "connect", ssid: ssid, password: pw }) }
    function disconnect() { send({ cmd: "disconnect" }) }
    function forget() { send({ cmd: "forget" }) }
    function setRadio(on) { send({ cmd: "radio", on: on }) }
    function scan() { send({ cmd: "scan" }) }
    function requestDetails() { send({ cmd: "details" }) }
    function modify(key, value) { send({ cmd: "modify", key: key, value: value }) }
    function showPassword(uuid) { send(uuid ? { cmd: "show_password", uuid: uuid } : { cmd: "show_password" }) }
    function loadProfiles() { send({ cmd: "profiles" }) }
    function loadProfile(uuid) { profile = null; send({ cmd: "profile", uuid: uuid }) }
    function pmodify(uuid, what, value, extra) { send(Object.assign({ cmd: "pmodify", uuid: uuid, what: what, value: value }, extra || {})) }
    function pforget(uuid) { send({ cmd: "pforget", uuid: uuid }) }
    function pconnect(uuid) { send({ cmd: "pconnect", uuid: uuid }) }

    // Список обновляется на месте (строки не пересоздаются — анимации не дёргаются)
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
        try { j = JSON.parse(line) } catch (e) { console.log("wifi: не JSON:", line); return }
        switch (j.type) {
        case "state":
            radio = j.radio; cur = j.cur; active = j.active; hidden = j.hidden; saved = j.saved; dry = j.dry
            busy = j.busy || ""
            syncModel(netModel, j.nets.filter(a => !a.inuse), "ssid")
            loaded = true
            break
        case "busy": busy = j.ssid || ""; break
        case "scanning": scanning = j.on; break
        case "details": details = j; break
        case "toast": toast(j.text, j.error); break
        case "result": result(j.cmd, j.ssid || "", j.ok, j.msg || ""); break
        case "password": password(j.text || "", j.ok, j.uuid || ""); break
        case "profiles": syncModel(profileModel, j.items, "uuid"); profilesCount = j.count; profilesText = j.countText; profilesLoaded = true; break
        case "profile": profile = j.missing ? null : j; break
        }
    }

    Process {
        id: proc
        // YUMI_QS_WIFI_BACKEND — другой путь к бэкенду (проверка копии перед заменой)
        command: ["python3", "-I", Quickshell.env("YUMI_QS_WIFI_BACKEND") || (Quickshell.env("HOME") + "/.local/lib/yumi/qs/wifi")]
        running: root.wanted || grace.running
        stdout: SplitParser { onRead: line => root.apply(line) }
        stderr: SplitParser { onRead: line => console.log("wifi:", line) }
        onExited: { root.loaded = false; root.details = null; root.scanning = false; root.busy = ""; root.profilesLoaded = false; root.profile = null }
    }
    Timer { id: grace; interval: 120000 }
    onWantedChanged: if (wanted) grace.stop(); else grace.restart()
}
