import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services
import qs.menus.wifi

// Меню VPN — вариант 06 «Список и детали» (16.10; прежнее меню со страницами — VpnMenu.qml.bak-widget-20261016).
// Слева коротко всё: локации WireGuard (Cloudflare WARP, Proton Free через yumi-vpn), Tailscale, его устройства;
// справа подробно выбранное и его действия — без перехода на страницу и назад.
// Логика прежняя — бэкенд ~/.local/lib/yumi/qs/vpn (JSON-строки). Открыть/закрыть: qs -c yumi ipc call menu toggle vpn.
// Клавиши: ↑↓ строка, → к действиям справа (↑↓ между ними, ← назад к списку), Enter — действие
// (локация — подключиться / переключиться / отключиться, Tailscale — вкл/выкл с подтверждением, устройство — пинг),
// S — скопировать «ssh <устройство>», Esc — отмена подтверждения / к списку / закрыть. Клик вне окна закрывает.
// Проверка: YP_DRYRUN=1 (подключения только печатаются), YP_FAKE_NET=1 (выдуманные устройства), YP_FAKE_VPN=on, YUMI_QS_NOKB=1;
//   qs -c yumi ipc call vpn page regions|device:<имя>|back · vpn select <код> · vpn connect · vpn ts on|off · vpn key up|down|left|right|enter|esc · vpn state
Scope {
    id: menu
    readonly property bool open: Menus.current === "vpn"
    readonly property string home: Quickshell.env("HOME")

    // ---- состояние из бэкенда ----
    property bool loaded: false
    property bool ok: false                 // есть подключения «VPN …» в NetworkManager
    property bool dry: false
    property bool connected: false
    property string region: ""              // текущая (или последняя) локация, код «VPN …»
    property string regionName: ""
    property var regions: []                // [{code, service, where, name}]
    property var ts: null                   // null — Tailscale не установлен; {running, backend, self, online, total, peers}
    property bool connecting: false
    property string busyRegion: ""
    property var pings: ({})                // ip → «38 мс · через DERP (fra)»
    property string selected: ""            // выбранная локация (vpn select / Enter на строке)
    property bool confirmTs: false
    property string toastText: ""
    property bool toastError: false

    // ---- список и выбор ----
    readonly property var peers: ts && ts.running ? (ts.peers || []) : []
    readonly property var rows: {
        const out = []
        if (ok) for (const r of regions) out.push({ kind: "vpn", key: "v:" + r.code, code: r.code, service: r.service, where: r.where, name: r.name })
        if (loaded) out.push({ kind: "ts", key: "ts" })
        for (const p of peers) out.push({ kind: "peer", key: "p:" + p.name, name: p.name })
        return out
    }
    property string selKey: ""              // выбор держится по ключу — строки обновляются каждые 4 с
    readonly property int sel: { const i = rows.findIndex(r => r.key === selKey); return i < 0 ? 0 : i }
    readonly property var selRow: rows.length ? rows[sel] : null
    property int df: -1                     // фокус в деталях: -1 — в списке, иначе номер действия справа
    readonly property var acts: {           // действия справа для выбранной строки (по ним ходят ↑↓ при фокусе справа)
        const r = selRow
        if (!r) return []
        if (r.kind === "vpn") return [{ id: "go" }]
        if (r.kind === "ts") {
            if (!ts) return []
            const a = [{ id: "ts" }]
            if (ts.running && ts.self) { if (ts.self.ip4) a.push({ id: "copy", v: ts.self.ip4 }); if (ts.self.dns) a.push({ id: "copy", v: ts.self.dns }) }
            return a
        }
        const d = peerOf(r.name)
        if (!d) return []
        const a = []
        if (d.online && d.ip4) a.push({ id: "ping" })
        if (d.dns) a.push({ id: "ssh" })
        for (const v of [d.ip4, d.ip6, d.dns]) if (v) a.push({ id: "copy", v: v })
        return a
    }
    onSelKeyChanged: { df = -1; confirmTs = false; detAnim.restart() }

    function peerOf(name) { return peers.find(p => p.name === name) || null }
    function nameOf(code) { const r = regions.find(x => x.code === code); return r ? r.name : (code === region ? regionName : code.replace(/^VPN /, "")) }
    readonly property bool wouldDisconnect: connected && (selected === "" || selected === region)
    function subtitle() {
        if (toastText) return toastText
        if (!loaded) return "Читаю состояние…"
        const parts = []
        if (ok) parts.push("VPN: " + (connecting ? "…" : connected ? "вкл" : "выкл"))
        if (ts) parts.push("Tailscale: " + (ts.running ? "в сети" : "выкл"))
        return parts.join(" · ")
    }
    function toast(text, error) { toastText = text; toastError = !!error; toastTimer.restart() }
    Timer { id: toastTimer; interval: 3000; onTriggered: menu.toastText = "" }

    // ---- бэкенд ----
    function send(obj) { if (proc.running) proc.write(JSON.stringify(obj) + "\n") }
    function apply(line) {
        let j
        try { j = JSON.parse(line) } catch (e) { console.log("vpn: не JSON:", line); return }
        switch (j.type) {
        case "state":
            ok = j.ok; connected = j.state === "Connected"; region = j.region; regionName = j.regionName
            regions = j.regions; ts = j.ts; dry = j.dry
            if (!loaded && !selKey) selKey = region ? "v:" + region : ""
            loaded = true
            break
        case "busy": connecting = j.on; busyRegion = j.region; break
        case "toast": toast(j.text, j.error); break
        case "result": if (j.cmd === "up" && j.ok) selected = ""; break
        case "ping": { const p = Object.assign({}, pings); p[j.ip] = j.text; pings = p; break }
        }
    }
    Process {
        id: proc
        command: ["python3", "-I", menu.home + "/.local/lib/yumi/qs/vpn"]
        running: menu.open || grace.running
        stdout: SplitParser { onRead: line => menu.apply(line) }
        stderr: SplitParser { onRead: line => console.log("vpn:", line) }
        onExited: { menu.loaded = false; menu.connecting = false }
    }
    Timer { id: grace; interval: 30000 }   // после закрытия бэкенд живёт ещё 30 с (опрос приостановлен) — повтор мгновенный
    onOpenChanged: {
        if (open) {
            grace.stop(); send({ cmd: "active", on: true })
            selKey = region ? "v:" + region : (rows.length ? rows[0].key : ""); df = -1
        } else { grace.restart(); send({ cmd: "active", on: false }); confirmTs = false; toastText = ""; df = -1 }
    }

    // ---- действия (команды те же, что у прежнего меню: yumi-vpn up/down, tailscale up/down) ----
    function connect() {
        if (connecting || !ok) return
        if (wouldDisconnect) { send({ cmd: "down" }); return }
        send({ cmd: "up", region: selected || region || "VPN WARP" })
    }
    function disconnect() { if (!connecting) send({ cmd: "down" }) }
    function pickRegion(code) { selected = code; selKey = "v:" + code; toast("Выбрано: " + nameOf(code) + " — Enter, чтобы подключиться") }
    function goRegion(code) { selected = code; connect() }      // Enter на локации: подключиться / переключиться / отключиться
    function tsToggle() {
        if (!ts) return
        if (ts.running) { if (confirmTs) { confirmTs = false; send({ cmd: "ts", on: false }) } else confirmTs = true }   // SSH идёт через Tailscale
        else send({ cmd: "ts", on: true })
    }
    function ping(ip) { if (!ip) return; const p = Object.assign({}, pings); p[ip] = "…"; pings = p; send({ cmd: "ping", ip: ip }) }
    function pingText(p) { return ((p && (pings[p.ip4] || p.ping)) || "").split(" · ")[0] }
    function ssh(d) { if (!d || !d.dns) return; Quickshell.execDetached(["wl-copy", "ssh " + d.dns]); toast("Скопировано: ssh " + d.dns.split(".")[0]) }
    function copy(v) { if (!v) return; Quickshell.execDetached(["wl-copy", v]); toast("Скопировано: " + v) }
    function rowAction(r) {
        if (!r) return
        if (r.kind === "vpn") goRegion(r.code)
        else if (r.kind === "ts") tsToggle()
        else { const d = peerOf(r.name); if (d && d.online && d.ip4) ping(d.ip4); else toast((d ? d.name : r.name) + " не в сети") }
    }
    function act(a) {
        const r = selRow
        if (!a || !r) return
        if (a.id === "go") goRegion(r.code)
        else if (a.id === "ts") tsToggle()
        else if (a.id === "ping") { const d = peerOf(r.name); if (d) ping(d.ip4) }
        else if (a.id === "ssh") ssh(peerOf(r.name))
        else if (a.id === "copy") copy(a.v)
    }
    function key(k) {
        if (k === "esc") {
            if (confirmTs) confirmTs = false
            else if (df >= 0) df = -1
            else Menus.close("vpn")
            return
        }
        if (df >= 0) {
            if (k === "up") df = Math.max(0, df - 1)
            else if (k === "down") df = Math.min(acts.length - 1, df + 1)
            else if (k === "left") df = -1
            else if (k === "enter") act(acts[df])
            return
        }
        if (k === "up" && sel > 0) { selKey = rows[sel - 1].key; list.show(sel) }
        else if (k === "down" && sel < rows.length - 1) { selKey = rows[sel + 1].key; list.show(sel) }
        else if (k === "right" && acts.length) df = 0
        else if (k === "enter") rowAction(selRow)
        else if (k === "ssh" && selRow && selRow.kind === "peer") ssh(peerOf(selRow.name))
    }

    IpcHandler {
        target: "vpn"
        function page(what: string): void {      // прежние страницы → выбор строки
            if (what === "regions") menu.selKey = menu.rows.length ? menu.rows[0].key : ""
            else if (what.startsWith("device:")) menu.selKey = "p:" + what.slice(7)
            else { menu.df = -1; menu.confirmTs = false }
        }
        function select(code: string): void { menu.pickRegion(code) }
        function connect(): void { menu.connect() }
        function ts(on: string): void { menu.selKey = "ts"; if (on === "off") menu.confirmTs = true; else menu.send({ cmd: "ts", on: true }) }
        function ping(ip: string): void { menu.ping(ip) }
        function key(name: string): void { menu.key(name) }
        function state(): string {
            return JSON.stringify({ open: menu.open, loaded: menu.loaded, connected: menu.connected, region: menu.region, selected: menu.selected,
                                    sel: menu.selKey, df: menu.df, acts: menu.acts.map(a => a.id), rows: menu.rows.length, confirmTs: menu.confirmTs })
        }
    }

    // фокус клавиатуры «Острова»: подложка акцентом 0.16, кромка акцентом 1.5 px, скругление строк
    component KbRing: Rectangle {
        property bool on: false
        anchors.fill: parent; radius: Theme.radius
        color: on ? Colors.alpha(Colors.acc, 0.16) : "transparent"
        border.width: on ? 1.5 : 0; border.color: Colors.acc
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }
    // кнопка действия справа (MButton + тихий фокус)
    component ActBtn: Item {
        id: ab
        property alias text: btn.text
        property alias kind: btn.kind
        property int idx: -1
        signal clicked()
        Layout.fillWidth: true
        implicitHeight: 36
        Rectangle {
            anchors.fill: parent; anchors.margins: -3; radius: 19; color: "transparent"
            border.width: menu.df === ab.idx ? 1.5 : 0; border.color: Colors.acc
        }
        MButton { id: btn; anchors.fill: parent; enabled: ab.enabled; onClicked: { menu.df = ab.idx; ab.clicked() } }
    }
    // «Остров»: шапка подробностей — значок в квадрате 34 (акцент — активно), название 14 DemiBold, подпись — в IBox
    component DetHead: IBox {
        id: dh
        property bool on: false
        property string icon: ""
        property string title: ""
        property string sub: ""
        RowLayout {
            Layout.fillWidth: true; spacing: 12
            MIconSq { icon: dh.icon; on: dh.on; base: Colors.hover }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                MText { Layout.fillWidth: true; text: dh.title; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight }
                MText { Layout.fillWidth: true; visible: text.length > 0; text: dh.sub; font.pixelSize: 12; color: Colors.fgDim; elide: Text.ElideRight }
            }
        }
    }
    // «ключ — значение» с копированием (фокус клавиатуры — Enter копирует)
    component CopyRow: Item {
        id: cr
        property string k: ""
        property string v: ""
        property int idx: -1
        Layout.fillWidth: true
        visible: v.length > 0
        implicitHeight: 30
        KbRing { on: menu.df === cr.idx }
        InfoRow { anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; key: cr.k; value: cr.v; copy: true }
    }

    PillPopup {
        id: pop
        name: "vpn"
        open: menu.open
        screen: Menus.screen
        marginRight: 200                     // под пилюлей VPN (правый блок бара)
        marginTop: Theme.barH * (Theme.dev ? 2 : 1) + 6
        contentW: 600
        pad: 18
        readonly property int bodyH: 460
        fixedH: head.implicitHeight + bodyH + hints.implicitHeight + 16 + pad * 2
        contentH: fixedH

        FocusScope {
            anchors.fill: parent
            focus: true
            Keys.onPressed: (e) => {
                const m = { [Qt.Key_Up]: "up", [Qt.Key_Down]: "down", [Qt.Key_Left]: "left", [Qt.Key_Right]: "right",
                            [Qt.Key_Return]: "enter", [Qt.Key_Enter]: "enter", [Qt.Key_Space]: "enter", [Qt.Key_Escape]: "esc", [Qt.Key_S]: "ssh" }
                const k = m[Latin.key(e)]   // буквы — по физической клавише (RU/UA раскладка)
                if (k) { menu.key(k); e.accepted = true }
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 12

                // ---- шапка: значок, «VPN», состояние, переключатель ----
                MenuHeader {
                    id: head
                    Layout.fillWidth: true
                    icon: "󰖂"; iconOn: menu.connected
                    title: "VPN"; subtitle: menu.subtitle(); error: menu.toastError && menu.toastText.length > 0
                    checked: menu.connected || menu.connecting; toggleEnabled: menu.loaded && menu.ok && !menu.connecting; dry: menu.dry
                    onToggled: on => { if (on && !menu.connected) menu.connect(); else if (!on && menu.connected) menu.disconnect() }
                }

                // ---- две панели ----
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: pop.bodyH
                    radius: Theme.radius
                    color: "transparent"
                    clip: true

                    RowLayout {
                        anchors.fill: parent
                        spacing: 16

                        // ---- слева: список ----
                        Flickable {
                            id: list
                            Layout.preferredWidth: 286; Layout.fillHeight: true
                            contentHeight: listCol.implicitHeight + 12
                            clip: true; boundsBehavior: Flickable.StopAtBounds; interactive: contentHeight > height
                            Behavior on contentY { NumberAnimation { duration: Theme.normal; easing.type: Theme.easeSoft } }
                            function show(i) {
                                const it = rep.itemAt(Math.max(0, Math.min(rep.count - 1, i)))
                                if (!it) return
                                const y = it.y + listCol.y, h = it.height
                                if (y < contentY + 6) contentY = Math.max(0, y - 30)
                                else if (y + h > contentY + height - 6) contentY = Math.min(contentHeight - height, y + h - height + 10)
                            }
                            ColumnLayout {
                                id: listCol
                                x: 0; y: 4
                                width: list.width - 4
                                spacing: 2
                                MHint { visible: !menu.loaded; text: "Читаю состояние…" }
                                MHint { visible: menu.loaded && !menu.ok; text: "Нет подключений «VPN …» в NetworkManager" }
                                Repeater {
                                    id: rep
                                    model: menu.rows
                                    delegate: ColumnLayout {
                                        id: line
                                        required property var modelData
                                        required property int index
                                        readonly property var r: modelData
                                        readonly property var prev: index > 0 ? menu.rows[index - 1] : null
                                        readonly property bool on: index === menu.sel
                                        readonly property var dev: r.kind === "peer" ? menu.peerOf(r.name) : null
                                        readonly property string section: {
                                            if (r.kind === "vpn") return !prev || prev.kind !== "vpn" || prev.service !== r.service ? r.service : ""
                                            if (r.kind === "ts") return "Tailscale"
                                            return prev && prev.kind === "ts" && menu.ts ? "Устройства · " + menu.ts.online + " из " + menu.ts.total + " в сети" : ""
                                        }
                                        Layout.fillWidth: true
                                        spacing: 2
                                        MSection { visible: line.section !== ""; text: line.section; Layout.topMargin: line.index > 0 ? 8 : 0; Layout.bottomMargin: 4; Layout.leftMargin: 2; Layout.fillWidth: true
                                                   trail: line.index === 0 ? String(menu.rows.filter(x => x.kind === "vpn" && x.service === line.r.service).length) : "" }
                                        Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight: 52; radius: Theme.radius   // «Остров»: вид IRow
                                            readonly property bool live: line.r.kind === "vpn" ? menu.connected && line.r.code === menu.region
                                                                       : line.r.kind === "ts" ? !!(menu.ts && menu.ts.running) : !!(line.dev && line.dev.online)
                                            color: line.on && menu.df >= 0 ? Colors.alpha(Colors.acc, 0.08) : area.containsMouse && !line.on ? Colors.isl2 : "transparent"
                                            /* выбор — без затухания (29.10) */
                                            scale: area.pressed ? 0.985 : 1
                                            Behavior on scale { NumberAnimation { duration: Theme.fast } }
                                            KbRing { on: line.on && menu.df < 0 }
                                            RowLayout {
                                                anchors.fill: parent; anchors.leftMargin: 9; anchors.rightMargin: 10; spacing: 12
                                                MIconSq {
                                                    on: parent.parent.live
                                                    icon: line.r.kind === "vpn" ? (line.r.service === "Cloudflare WARP" ? "󰅟" : "󰍎") : line.r.kind === "ts" ? "󰛳" : (line.dev ? line.dev.icon : "󰍹")
                                                }
                                                ColumnLayout {
                                                    Layout.fillWidth: true; spacing: 1
                                                    MText {
                                                        Layout.fillWidth: true; elide: Text.ElideRight; font.weight: Font.Medium
                                                        text: line.r.kind === "vpn" ? (line.r.where || line.r.service) : line.r.kind === "ts" ? "Tailscale" : line.r.name
                                                        opacity: line.r.kind === "peer" && line.dev && !line.dev.online ? 0.6 : 1
                                                    }
                                                    MText {
                                                        Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 12; color: Colors.fgDim
                                                        text: {
                                                            const r = line.r
                                                            if (r.kind === "vpn") {
                                                                if (menu.connecting && menu.busyRegion === r.code) return "подключаюсь…"
                                                                if (r.code === menu.region) return menu.connected ? "подключено" : "последняя"
                                                                return r.code === menu.selected ? "выбрано" : ""
                                                            }
                                                            if (r.kind === "ts") return !menu.ts ? "не установлен" : menu.ts.running ? "в сети" : (menu.ts.backend || "выкл")
                                                            const d = line.dev
                                                            return d ? (d.online ? (menu.pingText(d) || "в сети") : (d.ago || "не в сети")) : ""
                                                        }
                                                        visible: text.length > 0
                                                    }
                                                }
                                                // «Остров»: состояние справа — галочка у активного, крутилка при подключении
                                                MSpinner { visible: line.r.kind === "vpn" && menu.connecting && menu.busyRegion === line.r.code }
                                                Glyph {
                                                    visible: line.r.kind !== "peer" && !(menu.connecting && menu.busyRegion === line.r.code)
                                                             && (line.r.kind === "ts" ? !!(menu.ts && menu.ts.running) : menu.connected && line.r.code === menu.region)
                                                    text: "󰄬"; font.pixelSize: 16; color: Colors.acc
                                                }
                                            }
                                            MouseArea {
                                                id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: { if (menu.selKey === line.r.key && menu.df < 0) menu.rowAction(line.r); else { menu.selKey = line.r.key; menu.df = -1 } }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ---- справа: подробности ----
                        Item {
                            id: det
                            Layout.fillWidth: true; Layout.fillHeight: true
                            clip: true
                            readonly property var r: menu.selRow
                            readonly property var dev: r && r.kind === "peer" ? menu.peerOf(r.name) : null
                            readonly property bool regionOn: !!r && r.kind === "vpn" && menu.connected && r.code === menu.region
                            ParallelAnimation {    // смена выбранного: мягкий сдвиг и проявление
                                id: detAnim
                                NumberAnimation { target: detBody; property: "opacity"; from: 0; to: 1; duration: Theme.normal }
                                NumberAnimation { target: detShift; property: "x"; from: 12; to: 0; duration: Theme.normal; easing.type: Theme.easeSoft }
                            }
                            Flickable {
                                anchors.fill: parent; anchors.topMargin: 4
                                contentHeight: detBody.implicitHeight
                                clip: true; boundsBehavior: Flickable.StopAtBounds; interactive: contentHeight > height
                                ColumnLayout {
                                    id: detBody
                                    width: parent.width
                                    spacing: 10
                                    transform: Translate { id: detShift }

                                    // ---- локация VPN ----
                                    ColumnLayout {
                                        visible: det.r !== null && det.r.kind === "vpn"
                                        Layout.fillWidth: true; spacing: 10
                                        DetHead {
                                            on: det.regionOn
                                            icon: det.r && det.r.service === "Cloudflare WARP" ? "󰅟" : "󰍎"
                                            title: det.r && det.r.kind === "vpn" ? det.r.service : ""
                                            sub: det.regionOn ? "Трафик идёт через VPN" : "Трафик идёт напрямую"
                                        }
                                        // «Остров»: сводка плитками «подпись / значение» (kv превью)
                                        GridLayout {
                                            Layout.fillWidth: true; columns: 2; columnSpacing: 8; rowSpacing: 8
                                            IStat { Layout.preferredWidth: 1; label: "Состояние"; value: det.regionOn ? "вкл" : (menu.connecting && det.r && menu.busyRegion === det.r.code) ? "…" : "выкл" }
                                            IStat { Layout.preferredWidth: 1; label: "Локация"; value: det.r && det.r.kind === "vpn" ? (det.r.where || det.r.name) : "" }
                                            IStat { Layout.columnSpan: 2; label: "Сейчас"; value: menu.connected ? "VPN: " + menu.regionName : "VPN выключен" }
                                            IStat { Layout.columnSpan: 2; label: "Подключение"; value: det.r && det.r.kind === "vpn" ? det.r.code : "" }
                                        }
                                        Reveal {
                                            shown: menu.connecting
                                            RowLayout { spacing: 8; MSpinner {} MText { text: "Подключаюсь: " + menu.nameOf(menu.busyRegion); font.pixelSize: 12; color: Colors.fgDim } }
                                        }
                                        ActBtn {
                                            idx: 0; Layout.topMargin: 4
                                            enabled: menu.loaded && menu.ok && !menu.connecting
                                            kind: det.regionOn ? "plain" : "primary"
                                            text: det.regionOn ? "Отключиться" : (menu.connected ? "Переключиться сюда" : "Подключиться")
                                            onClicked: if (det.r) menu.goRegion(det.r.code)
                                        }
                                    }

                                    // ---- Tailscale ----
                                    ColumnLayout {
                                        visible: det.r !== null && det.r.kind === "ts"
                                        Layout.fillWidth: true; spacing: 10
                                        DetHead {
                                            on: !!(menu.ts && menu.ts.running); icon: "󰛳"; title: "Tailscale"
                                            sub: menu.ts ? (menu.ts.running ? "устройств в сети: " + menu.ts.online + " из " + menu.ts.total : "Состояние: " + menu.ts.backend) : ""
                                        }
                                        MHint { visible: menu.ts === null; text: "Tailscale не установлен или не отвечает" }
                                        GridLayout {
                                            visible: menu.ts !== null
                                            Layout.fillWidth: true; columns: 2; columnSpacing: 8; rowSpacing: 8
                                            IStat { Layout.preferredWidth: 1; label: "Состояние"; value: menu.ts && menu.ts.running ? "в сети" : "выкл" }
                                            IStat { Layout.preferredWidth: 1; label: "Устройства"; value: menu.ts ? menu.ts.online + " из " + menu.ts.total : "" }
                                        }
                                        Reveal {
                                            shown: menu.confirmTs
                                            MConfirm {
                                                text: "Отключить Tailscale? SSH-доступ к ноутбуку через Tailscale пропадёт. Enter — да · Esc — нет"
                                                yesText: "Отключить"
                                                onYes: { menu.confirmTs = false; menu.send({ cmd: "ts", on: false }) }
                                                onNo: menu.confirmTs = false
                                            }
                                        }
                                        ActBtn {
                                            idx: 0; visible: menu.ts !== null
                                            kind: menu.ts && menu.ts.running ? (menu.confirmTs ? "danger" : "plain") : "primary"
                                            text: menu.ts && menu.ts.running ? (menu.confirmTs ? "Да, отключить" : "Отключить Tailscale") : "Включить Tailscale"
                                            onClicked: menu.tsToggle()
                                        }
                                        CopyRow { idx: 1; k: "Мой адрес"; v: menu.ts && menu.ts.running && menu.ts.self ? menu.ts.self.ip4 || "" : "" }
                                        CopyRow { idx: menu.ts && menu.ts.self && menu.ts.self.ip4 ? 2 : 1; k: "Имя"; v: menu.ts && menu.ts.running && menu.ts.self ? menu.ts.self.dns || "" : "" }
                                    }

                                    // ---- устройство Tailscale ----
                                    ColumnLayout {
                                        visible: det.dev !== null
                                        Layout.fillWidth: true; spacing: 6
                                        readonly property var d: det.dev || ({ name: "", icon: "", os: "", online: false, ip4: "", ip6: "", dns: "", link: "", ago: "", traffic: "", exitNode: false, ping: "" })
                                        id: devBox
                                        DetHead {
                                            on: devBox.d.online; icon: devBox.d.icon; title: devBox.d.name
                                            sub: devBox.d.online ? "в сети" + (devBox.d.link ? " · " + devBox.d.link : "") : "не в сети" + (devBox.d.ago ? " · " + devBox.d.ago : "")
                                        }
                                        GridLayout {
                                            Layout.fillWidth: true; columns: 2; columnSpacing: 8; rowSpacing: 8
                                            IStat { Layout.preferredWidth: 1; visible: devBox.d.online; label: "Пинг"; value: menu.pingText(devBox.d) || "…" }
                                            IStat { Layout.preferredWidth: 1; label: "Система"; value: devBox.d.os || "—" }
                                        }
                                        IBox {
                                            visible: devBox.d.traffic.length > 0 || devBox.d.exitNode
                                            spacing: 5
                                            InfoRow { key: "Трафик"; value: devBox.d.traffic }
                                            InfoRow { key: "Выходной узел"; value: devBox.d.exitNode ? "доступен" : "" }
                                        }
                                        Repeater {    // действия и копируемые строки — по menu.acts (тот же порядок, что ходят ↑↓)
                                            model: det.dev ? menu.acts : []
                                            delegate: Loader {
                                                id: ld
                                                required property var modelData
                                                required property int index
                                                Layout.fillWidth: true
                                                sourceComponent: ld.modelData.id === "copy" ? copyC : btnC
                                                Component { id: btnC
                                                    ActBtn { idx: ld.index
                                                             text: ld.modelData.id === "ping" ? "Пинг" : "SSH — скопировать команду"
                                                             onClicked: menu.act(ld.modelData) } }
                                                Component { id: copyC
                                                    CopyRow { idx: ld.index
                                                              k: ld.modelData.v === devBox.d.ip4 ? "IPv4" : ld.modelData.v === devBox.d.ip6 ? "IPv6" : "Имя"
                                                              v: ld.modelData.v } }
                                            }
                                        }
                                    }
                                    MText { visible: menu.dry; text: "ПРОВЕРКА: ИЗМЕНЕНИЯ НЕ ВЫПОЛНЯЮТСЯ"; font.pixelSize: 9; font.weight: Font.DemiBold; font.letterSpacing: 1; color: Colors.acc; topPadding: 4 }
                                }
                            }
                        }
                    }
                }

                // ---- подсказки клавиш капсулами ----
                MFooter {
                    id: hints
                    hints: menu.df >= 0 ? [["↑↓", "действие"], ["Enter", "выполнить"], ["←", "к списку"], ["Esc", "назад"]]
                         : menu.confirmTs ? [["Enter", "да, отключить"], ["Esc", "нет"]]
                         : [["↑↓", "строка"], ["→", "действия"], ["Enter", menu.selRow && menu.selRow.kind === "peer" ? "пинг" : menu.selRow && menu.selRow.kind === "ts" ? "вкл/выкл" : "подключить"], ["S", "ssh"], ["Esc", "закрыть"]]
                }
            }
        }
    }
}
