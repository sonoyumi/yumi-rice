pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower
import qs
import qs.components
import qs.services
import qs.osd

// «Остров» (29.10): общее состояние центрального острова для всех экранов (island/Island.qml рисует его на каждом).
// Уведомления: очередь всплывашек Notifs.popups — по одной, ~4,2 с (низкие 3,5; срок приложения 2,5–10 с; критичные —
// пока не закроют). Пока карточка ждёт в очереди или показана, авто-скрытие Notifs стоит; показ кончился —
// Notifs.hidePopup (как истечение всплывашки раньше: копия остаётся в центре). Наведение держит, уход — ещё 2 с.
// «Ответить» раскрывает остров с полем ввода (черновик хранится, пока уведомление живо).
// OSD (osd/Osd.qml → OsdState): уровни 1,6 с, сообщения 1,5 с; поверх уведомления, которое потом доигрывает.
// Экран события — тот, где фокус (YUMI_QS_SCREEN — всегда этот).
// 30.10 — движок «как в превью» (island-live.html): активности с приоритетами (главная в острове, вторая — круг справа,
// 3+ — «+N»), IPC для скриптов, системные пузыри (зарядка, батарея 10/5 %, AirPods), «Фокус» со сводкой, «Не беспокоить»,
// полноэкранный (проходит только срочное и отклик на действия), журнал решений (YUMI_ISLAND_LOG=1).
//   qs -c yumi ipc call island start <id> '<json>'   поля: title sub trail icon tone(acc|ok|warn|bad) priority(1–7)
//                                                     progress(0..1 или 0..100) open(команда по клику) primary(команда:
//                                                     средний клик / кнопка) primaryLabel urgent(true — проходит фокус)
//   qs -c yumi ipc call island update <id> '<json>'  (неизвестный id — игнор)
//   qs -c yumi ipc call island end <id> '{"done":"Готово"}'   (галочка 2 с и уход; без done — уходит сразу)
//   qs -c yumi ipc call island focus on|off|toggle   (состояние — ~/.local/state/yumi-island/focus)
//   qs -c yumi ipc call island list                  (активности и что показано — для проверки)
// Проверка: qs … ipc call island state idle|player|notif|osd|msg|-   (принудительное состояние, «-» — снять)
//           qs … ipc call island msg "<текст>"   ·   уведомление без шины — YUMI_NOTIF_DEBUG=1 + notif fake …
Singleton {
    id: root
    readonly property bool dry: Quickshell.env("YP_DRYRUN") === "1"
    property string force: Quickshell.env("YUMI_ISLAND_STATE")     // проверка: состояние на всех экранах

    function focusedName() {
        return Quickshell.env("YUMI_QS_SCREEN") || (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "")
    }

    // ---------- обложка: запасной PNG скрипта бара, когда у игрока нет artUrl ----------
    property BarScript cover: BarScript {
        command: [Quickshell.env("HOME") + "/.local/lib/yumi/bar/player-cover"]; interval: 30; name: "cover"
    }
    readonly property string art: Player.artUrl.length > 0 ? Player.artUrl : (cover.raw.length > 0 ? "file://" + cover.raw : "")
    property Connections trackConn: Connections { target: Player; function onTrackKeyChanged() { root.cover.refresh() } }
    // место острова в потоке бара на каждом экране (пишет bar/Bar.qml): [lo, hi] по x экрана между левыми и правыми
    // островами. Остров (и окно плеера из него) не шире этого промежутка и встаёт по центру экрана, если влезает.
    property var slot: ({})
    function setSlot(screen, lo, hi) {
        const o = slot[screen]; lo = Math.round(lo); hi = Math.round(hi)
        if (o && o[0] === lo && o[1] === hi) return
        const m = Object.assign({}, slot); m[screen] = [lo, hi]; slot = m
    }
    // положение острова шириной w на экране шириной sw: [x, ширина]
    // 29.10 (бар «Два крыла»): остров ВСЕГДА строго по центру экрана. useSlot — состояние в одну строку с баром
    // (покой, сообщение): ширина ≤ экран − 2·max(левое крыло, правое) − 2·8; выше бара (плеер, уведомление, OSD) —
    // только не шире экрана. Возвращает [x, ширина].
    function room(screen, sw) {
        const sl = slot[screen]
        if (!sl) return sw - 32
        return Math.max(120, 2 * Math.min(sw / 2 - sl[0], sl[1] - sw / 2) - 16)
    }
    function place(screen, sw, w, useSlot, shrink) {      // shrink — место под круги рядом (30.10)
        const ww = Math.round(Math.min(w, sw - 32, useSlot ? room(screen, sw) - (shrink || 0) : 1e6))
        return [Math.round((sw - ww) / 2), ww]
    }
    // 29.10: НАСТОЯЩИЙ полноэкранный режим (Hyprland fullscreen 2 — бар закрыт) по мониторам: { "DP-1": true }.
    // Режим 1 («развернуть», бар виден) — не полноэкранный: остров в покое остаётся. Обновляется по событиям Hyprland.
    property var trueFs: ({})
    property Process fsProc: Process {
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector { onStreamFinished: {
            try {
                const cl = JSON.parse(text)
                const out = {}
                for (const m of Hyprland.monitors.values) {
                    const wid = m.activeWorkspace ? m.activeWorkspace.id : null
                    out[m.name] = cl.some(c => c.workspace && c.workspace.id === wid && c.fullscreen === 2)
                }
                root.trueFs = out
            } catch (e) {}
        } }
    }
    property Timer fsLater: Timer { interval: 60; onTriggered: root.fsProc.running = true }
    property Connections fsConn: Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (["fullscreen", "workspace", "workspacev2", "focusedmon", "focusedmonv2", "activespecial", "closewindow", "movewindow", "movewindowv2", "openwindow"].indexOf(ev.name) >= 0) root.fsLater.restart()
        }
    }
    property bool playerCard: false        // PlayerIsland раскрыт из острова (режим bar) — остров уступает ему место

    // ================= уведомления =================
    property var cur: null                 // показываемая запись Notifs
    property real curTime: 0
    property var queue: []
    property var done: new Map()           // запись → time, до которого она уже показана
    property string notifScreen: ""
    property bool hold: false              // курсор на острове с уведомлением
    property bool replyOpen: false
    property var drafts: new Map()         // запись → черновик ответа
    readonly property bool critical: !!cur && cur.urgency === 2

    property Connections notifConn: Connections {
        target: Notifs
        function onEntriesChanged() { Qt.callLater(root.scan) }
        function onDndChanged() { Qt.callLater(root.scan) }
    }
    Component.onCompleted: { Qt.callLater(scan); fsLater.restart() }

    function alive(e) { return !!e && Notifs.entries.indexOf(e) >= 0 }
    function scan() {
        if (cur && (!alive(cur) || !cur.popup)) { const was = cur; cur = null; replyOpen = false; showT.stop(); if (alive(was)) done.set(was, was.time) }
        for (const e of Array.from(done.keys())) if (!alive(e)) done.delete(e)
        for (const e of Array.from(drafts.keys())) if (!alive(e)) drafts.delete(e)
        let q = queue.filter(e => alive(e) && e.popup)
        // «Не беспокоить»: Notifs не делает всплывашку вовсе — срочное (свежее) поднимаем сами
        if (Notifs.dnd) for (const e of Notifs.entries) if (!e.popup && e.alive && urgentN(e) && !done.has(e) && Date.now() - e.time < 15000) { e.popup = true; log("«" + nName(e) + "» → показать: срочное — проходит через «Не беспокоить»") }
        for (const e of Notifs.popups.slice().reverse()) {          // старые первыми
            if (e === cur) {
                if (e.time > curTime) { curTime = e.time; restartShow() }   // обновилось на месте (прогресс, правка) — показать заново
                e.timer.stop(); continue
            }
            if (q.indexOf(e) >= 0) { e.timer.stop(); continue }
            const d = done.get(e)
            if (d !== undefined && d >= e.time) continue
            // 30.10: blueman про AirPods не показываем и не храним — вместо него один пузырь острова с наушниками
            if (/blueman|bluetooth/i.test(e.app || "") && /airpods/i.test((e.summary || "") + " " + (e.body || ""))) {
                done.set(e, e.time); log("«" + nName(e) + "» → убрано: blueman про AirPods, есть свой пузырь")
                Qt.callLater(() => { if (alive(e)) Notifs.dismiss(e) })
                continue
            }
            // куда: показать / в сводку фокуса / тихо в центр — и почему (как route() в превью)
            const r = route({ cat: "notif", urgent: urgentN(e), name: nName(e) })
            if (r.act !== "show") {
                done.set(e, e.time)
                if (r.act === "summary") { summary = summary.concat([{ icon: urgentIcon(e), who: e.app || e.summary, text: e.summary && e.app ? e.summary : e.body }]); kick(0.6) }
                Qt.callLater(() => { if (alive(e) && e.popup) Notifs.hidePopup(e) })
                continue
            }
            e.timer.stop(); q.push(e)
        }
        queue = q
        collapse()
        if (!cur) next()
    }
    // 30.10: пачка уведомлений не ждёт в очереди по 4 с каждое — показывается самое свежее, остальные уходят
    // в центр уведомлений и считаются в «+N» кружком рядом с островом. Срочные не сворачиваются; уведомление,
    // на котором курсор или открыт ответ, не вытесняется.
    property int more: 0
    function collapse() {
        const fresh = queue.filter(e => !urgentN(e))
        if (!fresh.length) return
        const newest = fresh.reduce((x, y) => y.time >= x.time ? y : x)
        const drop = fresh.filter(e => e !== newest)
        const retireCur = !!cur && !hold && !replyOpen && !urgentN(cur) && cur.urgency !== 2
        if (!drop.length && !retireCur) return
        for (const e of drop) { done.set(e, e.time); if (alive(e) && e.popup) Notifs.hidePopup(e) }
        queue = queue.filter(e => drop.indexOf(e) < 0)
        let n = drop.length
        if (retireCur) {
            const was = cur
            cur = null; showT.stop()
            if (alive(was)) { done.set(was, was.time); if (was.popup) Notifs.hidePopup(was) }
            n++
        }
        more += n
        log("пачка уведомлений: показано свежее «" + nName(newest) + "», ещё " + more + " — числом рядом")
    }
    function next() {
        let q = queue.slice()
        while (q.length) {
            const e = q.shift()
            if (alive(e) && e.popup) { queue = q; show(e); return }
        }
        queue = q
        cur = null
        more = 0
    }
    function show(e) {
        cur = e; curTime = e.time; replyOpen = false; hold = false
        notifScreen = focusedName()
        breath()
        restartShow()
    }
    function duration(e) {
        if (!e) return 0
        if (e.expireTimeout > 0) return Math.max(2500, Math.min(10000, e.expireTimeout))
        if (e.urgency === 2) return 0
        return e.urgency === 0 ? 3500 : 4200
    }
    function restartShow(ms) {
        showT.stop()
        if (!cur || hold || replyOpen || osdOn) return
        const d = duration(cur)
        if (d > 0) { showT.interval = ms > 0 ? Math.min(ms, d) : d; showT.start() }
    }
    // показ кончился: всплывашка «истекла» (копия — в центре), дальше — следующая
    function finish() {
        const e = cur
        cur = null; replyOpen = false; showT.stop()
        if (alive(e)) { done.set(e, e.time); if (e.popup) Notifs.hidePopup(e) }
        next()
    }
    property Timer showT: Timer { onTriggered: root.finish() }
    function setHold(h) {
        if (hold === h) return
        hold = h
        if (h) showT.stop(); else restartShow(2000)
    }
    property bool alertHold: false         // курсор на пузыре (не на показе новой активности) — держит
    // действия из острова
    function dismiss() { const e = cur; if (!e) return; done.set(e, e.time); Notifs.dismiss(e); Qt.callLater(scan) }
    function activate() { const e = cur; if (!e) return; Notifs.activate(e); Qt.callLater(() => { if (root.cur === e) root.finish() }) }
    function invoke(id) { const e = cur; if (!e) return; Notifs.invoke(e, id); Qt.callLater(() => { if (root.cur === e) root.finish() }) }
    function openReply() { if (!cur) return; replyOpen = true; showT.stop() }
    function closeReply() { replyOpen = false; restartShow(3000) }
    function draft(e) { return e && drafts.has(e) ? drafts.get(e) : "" }
    function setDraft(e, t) { if (e) drafts.set(e, t) }
    function reply(text) {
        const e = cur; if (!e || !text.length) return
        if (dry) console.log("[dry-run] уведомление: ответ", JSON.stringify(text))
        else Notifs.reply(e, text)
        drafts.delete(e)
        Qt.callLater(() => { if (root.cur === e) root.finish() })
    }
    // первая кнопка: «Ответить» (быстрый ответ) или первое действие приложения
    function actionsOf(e) {
        if (!e) return []
        const out = []
        if (e.hasInlineReply && e.alive) out.push({ id: "inline-reply", text: "Ответить" })
        for (const a of e.actions) if (a.id !== "default" && a.id !== "inline-reply") out.push(a)
        return out.slice(0, 2)
    }

    // ================= OSD и сообщения =================
    property bool osdOn: false
    property bool osdMsg: false
    property string osdScreen: ""
    property string msgText: ""            // свой текст сообщения (ipc island msg), иначе OsdState.label
    property string msgIcon: ""
    property Connections osdConn: Connections {
        target: OsdState
        function onShown() { root.msgText = ""; root.msgIcon = ""; root.startOsd(!OsdState.hasLevel) }
    }
    function startOsd(isMsg) {
        osdMsg = isMsg
        osdScreen = focusedName()
        osdOn = true
        showT.stop()
        osdT.interval = isMsg ? 1500 : 1600
        osdT.restart()
    }
    property Timer osdT: Timer { onTriggered: { root.osdOn = false; root.restartShow(2500) } }

    // ======================================================================================================
    //  30.10: ДВИЖОК «КАК В ПРЕВЬЮ» — журнал, режимы, маршрутизация, активности, пузыри
    // ======================================================================================================
    readonly property bool logOn: Quickshell.env("YUMI_ISLAND_LOG") === "1"
    function log(t) { if (logOn) console.log("остров: " + t) }
    signal kicked(real power)              // лёгкий отскок острова (обновление активности, новый трек)
    signal breathed()                      // «вдох» подсветкой (новое событие)
    function kick(p) { kicked(p === undefined ? 1 : p) }
    function breath() { breathed() }

    // ---------- режимы ----------
    property bool focus: false
    property var summary: []               // [{icon, who, text}] — несрочное, пока идёт «Фокус»
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/yumi-island"
    property FileView focusFile: FileView {
        path: root.stateDir + "/focus"; printErrors: false; blockLoading: true
        onLoaded: { const on = text().trim() === "1"; if (on !== root.focus) root.setFocus(on, "состояние из файла") }
    }
    function setFocus(on, why) {
        if (on === focus) return
        focus = on
        Quickshell.execDetached(["mkdir", "-p", stateDir])
        Qt.callLater(() => focusFile.setText(on ? "1\n" : "0\n"))
        if (on) {
            log("Фокус включён" + (why ? " (" + why + ")" : "") + ": несрочное → в сводку; срочное (батарея 5 %, звонок/микрофон, Touch ID/sudo) проходит")
            start("focus", JSON.stringify({ title: "Фокус", sub: "несрочное — в сводку", icon: "target", priority: 3 }), true)
        } else {
            log("Фокус выключен" + (why ? ": " + why : ""))
            end("focus", "{}")
            deliverSummary("Сводка за фокус")
        }
    }
    function deliverSummary(title) {
        if (!summary.length) { log("сводка пуста — показывать нечего"); return }
        if (fsNow()) { log("сводка (" + summary.length + ") отложена: полноэкранное окно"); return }
        const items = summary; summary = []
        pushAlert({ kind: "summary", label: "сводка", data: { title: title, items: items }, dur: 7000,
                    why: title.toLowerCase() + ": одна сводка вместо " + items.length + " баннеров" })
    }
    onTrueFsChanged: if (!fsNow() && !focus && summary.length) Qt.callLater(() => root.deliverSummary("Пока было полноэкранное"))   // полноэкранное закрыто — отложенная сводка
    function fsNow() { return !!trueFs[focusedName()] }

    // срочное (по умолчанию превью: батарея 5 %, звонок/микрофон, Touch ID/sudo) + критичные уведомления
    function urgentN(e) {
        if (!e) return false
        if (e.urgency === 2) return true
        const t = (e.app + " " + e.desktopEntry + " " + e.category + " " + e.summary).toLowerCase()
        return /polkit|sudo|touch ?id|fprint|отпечат/.test(t) || /call|звон|микрофон|microphone/.test(e.category + " " + e.summary.toLowerCase())
    }
    function urgentIcon(e) { return /telegram/i.test(e.app) ? "󰔁" : "󰂚" }
    function nName(e) { return (e.app ? e.app + ": " : "") + (e.summary || e.body || "") }
    // маршрутизация: show / summary / center / drop — и почему
    function route(ev) {
        let r
        if (ev.urgent) r = { act: "show", why: "срочное — проходит" + (focus ? " через Фокус" : "") + (Notifs.dnd ? " через «Не беспокоить»" : "") + (fsNow() ? " поверх полноэкранного окна" : "") }
        else if (ev.cat === "osd") r = { act: "show", why: "отклик на твоё действие — всегда, даже в фокусе и поверх полноэкранного" }
        else if (fsNow()) r = { act: ev.cat === "notif" ? "center" : "drop", why: "полноэкранное окно: бар и остров скрыты, проходит только срочное" }
        else if (ev.cat === "notif") {
            if (focus) r = { act: "summary", why: "Фокус: несрочное не показываю, кладу в сводку" }
            else if (Notifs.dnd) r = { act: "center", why: "«Не беспокоить»: тихо в центр уведомлений, без баннера" }
            else r = { act: "show", why: "обычное уведомление, режимов нет — баннер из острова" }
        } else if (Notifs.dnd && ev.quiet) r = { act: "drop", why: "«Не беспокоить»: мелкий системный пузырь не показываю" }
        else r = { act: "show", why: "системный пузырь — короткий, не мешает" }
        log("«" + ev.name + "» → " + ({ show: "показать", summary: "в сводку", center: "в центр уведомлений", drop: "не показано" })[r.act] + ": " + r.why)
        return r
    }

    // ---------- активности ----------
    // {id, title, sub, trail, icon, tone, priority 1–7, progress (−1 — нет), since, hidden, done, doneUntil, open, primary, primaryLabel, urgent}
    // уровни: 1 срочное/звонок · 2 приватность · 3 таймеры/запись/фокус · 4 прогресс · 5 музыка · 6 покой
    property string micApps: ""             // 30.10: кто пишет микрофон (yumi-island-mic) — только точка у острова
    property var acts: ({})
    property int rev: 0
    property bool swap: false
    property real musicSince: Date.now()
    property Connections musicConn: Connections {
        target: Player
        function onPlayingChanged() {
            if (Player.playing) { root.musicSince = Date.now(); root.pausedLong = false; root.pauseWait.stop(); root.log("музыка играет → активность уровня 5") }
            else { root.pauseWait.restart(); root.log("музыка на паузе → «Продолжить», через минуту — покой (погода, дата, что дальше)") }
        }
        function onTrackKeyChanged() { if (Player.playing) root.kick(0.8) }
    }
    // 30.10: покой — музыка не играет минуту (или трека нет вовсе): погода · дата · что дальше (island-rest).
    // Трек остаётся в центре управления и в раскрытом острове (наведение) — ▶ / бинды / наушники продолжают с места.
    property bool pausedLong: true          // при запуске оболочки музыка не играла — сразу покой
    property Timer pauseWait: Timer { interval: 60000; onTriggered: root.pausedLong = true }
    readonly property bool rest: Quickshell.env("YUMI_ISLAND_REST") === "1" || (!Player.playing && (pausedLong || !Player.shown))   // переменная — проверка
    property var restData: ({})             // {weather:{icon,t,text}|null, next:{icon,text,when}|null}
    property Process restProc: Process {
        command: ["python3", "-I", Quickshell.env("HOME") + "/.local/lib/yumi/qs/island-rest"]
        stdout: StdioCollector { onStreamFinished: { try { root.restData = JSON.parse(text) } catch (e) {} } }
    }
    property Timer restPoll: Timer {          // 5 мин; погоду кэширует сам бэкенд (30 мин)
        interval: 300000; repeat: true; running: true; triggeredOnStart: true
        onTriggered: root.restProc.running = true
    }
    readonly property var ranked: {
        rev; Player.playing; Player.has
        const l = []
        for (const k in acts) { const a = acts[k]; if (!a.hidden) l.push(a) }
        if (Player.has && Player.playing && !musicHidden) l.push({ id: "music", music: true, priority: 5, since: musicSince })
        l.sort((x, y) => (x.priority - y.priority) || (y.since - x.since))
        if (swap && l.length > 1) { const t = l[0]; l[0] = l[1]; l[1] = t }
        return l
    }
    property bool musicHidden: false
    readonly property var main: ranked.length ? ranked[0] : null
    readonly property var second: ranked.length > 1 ? ranked[1] : null
    readonly property int extra: Math.max(0, ranked.length - 2)
    onMainChanged: if (main) log("главная: «" + (main.music ? "Музыка" : main.title) + "» — уровень " + main.priority + (ranked.length > 1 ? "; вторая «" + (ranked[1].music ? "Музыка" : ranked[1].title) + "» — круг рядом" + (extra ? ", ещё " + extra + " — «+" + extra + "»" : "") : "") + (swap ? " (поменяли местами)" : ""))

    readonly property var icons: ({ phone: "󰏲", call: "󰏲", mic: "󰍬", spark: "󰚩", target: "󰓾", focus: "󰓾", timer: "󰔛",
        tomato: "󰔟", hist: "󰁯", backup: "󰁯", upd: "󰚰", update: "󰚰", down: "󰇚", download: "󰇚", eur: "󰞨", bolt: "󱐋", bat: "󰁹",
        cam: "󰄀", usb: "󰕓", shield: "󰒃", moon: "󰖔", play: "󰐊", pause: "󰏤", music: "󰝚", bell: "󰂚", check: "󰄬", wifi: "󰖩",
        code: "󰅩", mail: "󰇮", cal: "󰃭", cloud: "󰖐", cpu: "󰍛", fp: "󰈷", lock: "󰌾", send: "󰒊", record: "󰑊", book: "󰂺" })
    function glyph(n) { n = String(n || ""); return icons[n] || (n.length && n.length <= 2 ? n : "󰋽") }
    function toneColor(t) { return t === "ok" ? Colors.ok : t === "warn" ? Colors.warn : t === "bad" ? Colors.bad : Colors.acc }

    function parse(json) {
        if (!json || json === "-") return {}
        try { const o = JSON.parse(json); return (o && typeof o === "object" && !Array.isArray(o)) ? o : null } catch (e) { return null }
    }
    function clean(o, a) {
        const str = (v, n) => String(v).replace(/[\r\n]+/g, " ").slice(0, n)
        for (const k of ["title", "sub", "trail", "icon", "open", "primary", "primaryLabel"]) if (o[k] !== undefined && o[k] !== null) a[k] = str(o[k], k === "open" || k === "primary" ? 400 : 80)
        if (o.tone !== undefined) a.tone = ["acc", "ok", "warn", "bad"].indexOf(o.tone) >= 0 ? o.tone : "acc"
        if (o.priority !== undefined) { const p = Math.round(Number(o.priority)); if (p >= 1 && p <= 7) a.priority = p }
        if (o.progress !== undefined) { let v = Number(o.progress); if (isNaN(v) || o.progress === null) v = -1; else if (v > 1) v = v / 100; a.progress = v < 0 ? -1 : Math.min(1, v) }
        if (o.urgent !== undefined) a.urgent = !!o.urgent
        return a
    }
    function validId(id) { return /^[\w.:-]{1,40}$/.test(id || "") && id !== "music" }
    function start(id, json, quiet) {
        if (!validId(id)) { log("start: плохой id «" + id + "» — пропущено"); return }
        const o = parse(json); if (o === null) { log("start " + id + ": плохой JSON — пропущено"); return }
        if (acts[id]) { update(id, json); return }
        const a = clean(o, { id: id, title: id, sub: "", trail: "", icon: "", tone: "acc", priority: 5, progress: -1,
                             since: Date.now(), hidden: false, done: "", doneUntil: 0, open: "", primary: "", primaryLabel: "", urgent: false })
        if (o.priority === undefined && a.progress >= 0) a.priority = 4
        const m = Object.assign({}, acts); m[id] = a; acts = m; swap = false; rev++
        log("старт: «" + a.title + "» · уровень " + a.priority)
        if (!quiet) intro(id); else kick(1)
    }
    function update(id, json) {
        const a0 = acts[id]
        if (!a0) { log("update: неизвестная активность «" + id + "» — пропущено"); return }
        const o = parse(json); if (o === null) { log("update " + id + ": плохой JSON — пропущено"); return }
        const a = clean(o, Object.assign({}, a0)); a.hidden = false
        const m = Object.assign({}, acts); m[id] = a; acts = m; rev++
        // 30.10: отскок — только когда сменилось содержание (заголовок, подпись, значок, тон, уровень, скрыта была);
        // тикающий таймер (trail/progress раз в секунду, Pomodoro) не пульсирует
        if (["title", "sub", "icon", "tone", "priority"].some(k => a[k] !== a0[k]) || a0.hidden) kick(0.7)
    }
    function end(id, json) {
        const a0 = acts[id]; if (!a0) return
        const o = parse(json) || {}
        const m = Object.assign({}, acts)
        if (o.done) {
            const a = Object.assign({}, a0, { done: String(o.done).slice(0, 60), doneUntil: Date.now() + 2000, hidden: false, progress: -1 })
            m[id] = a; kick(1.3); log("«" + a.title + "»: готово ✓ — галочка 2 с, затем уходит")
        } else { delete m[id]; log("конец: «" + a0.title + "»") }
        acts = m; rev++
        if (alert && alert.kind === "intro" && alert.data.id === id && !o.done) endAlert("активность закончилась")
    }
    function intro(id) {
        kick(1)
        const a = acts[id]
        if (fsNow()) { log("«" + a.title + "» без показа: полноэкранное окно"); return }
        if (focus && a.priority > 1 && id !== "focus") { log("«" + a.title + "» без раскрытия: идёт Фокус — только компактно"); return }
        pushAlert({ kind: "intro", label: "показ «" + a.title + "»", data: { id: id }, dur: 1500,
                    why: "новая активность: коротко развёрнуто, потом втягивается" })
    }
    // мышь по главной/кругу
    function swapMain() { if (ranked.length > 1) { swap = !swap; kick(0.7); log("главная и круг поменялись местами") } }
    function hideMain() {
        const m = main; if (!m) return
        if (m.music) { musicHidden = true; rev++ }
        else { const x = Object.assign({}, acts); x[m.id] = Object.assign({}, m, { hidden: true }); acts = x; rev++ }
        log("правый клик → «" + (m.music ? "Музыка" : m.title) + "» скрыта до следующего изменения")
    }
    property Connections unhideMusic: Connections { target: Player; function onTrackKeyChanged() { if (root.musicHidden) { root.musicHidden = false; root.rev++ } } }
    function run(cmd, what) {
        if (!cmd) return false
        if (dry) { console.log("[dry-run] остров: " + what + ": " + cmd); return true }
        Quickshell.execDetached(["sh", "-c", cmd]); return true
    }
    function primaryOf(a) { if (!a) return; if (a.music) Player.togglePlaying(); else if (!run(a.primary, "главное действие")) run(a.open, "открыть"); log("средний клик → главное действие: «" + (a.music ? "Музыка" : a.title) + "»") }
    function openOf(a) { if (a && !a.music) run(a.open || a.primary, "открыть") }

    // ---------- пузыри: показ новой активности, системные, сводка ----------
    // {kind: intro|pill|banner|summary|airpods, data, urgent, dur (0 — до закрытия), group, label, why, screen, left}
    property var alert: null
    property var alertQ: []
    property real alertLeft: 0
    function pushAlert(a) {
        a.screen = focusedName(); a.left = a.dur
        const c = alert
        if (a.group) {
            alertQ = alertQ.filter(q => q.group !== a.group)
            if (c && c.group === a.group && !c.urgent) { showAlert(a); log("«" + c.label + "» заменено свежим «" + a.label + "»"); return }
        }
        if (c && c.kind === "intro" && a.kind !== "intro") { showAlert(a); log("показ уступил месту «" + a.label + "»"); return }
        if (c) {
            if (a.urgent && !c.urgent) { if (c.kind !== "intro") alertQ = [c].concat(alertQ); showAlert(a); log("срочное вытеснило «" + c.label + "» — оно вернётся после"); return }
            if (a.kind === "intro") return
            alertQ = alertQ.concat([a]).sort((x, y) => (y.urgent ? 1 : 0) - (x.urgent ? 1 : 0))
            log("«" + a.label + "» ждёт в очереди: сейчас показано «" + c.label + "»"); return
        }
        showAlert(a)
    }
    function showAlert(a) { alert = a; alertLeft = a.left; alertHold = false; breath(); log("показано: " + a.label + " — " + (a.why || "")) }
    function endAlert(why) {
        const a = alert; if (!a) return
        alert = null
        log((a.kind === "intro" ? "показ" : "«" + a.label + "»") + " " + (why || "ушло по времени") + " → втягивается обратно в остров")
        kick(0.7)
        if (alertQ.length) { const n = alertQ[0]; alertQ = alertQ.slice(1); Qt.callLater(() => root.showAlert(n)) }
    }
    // такт 250 мс — только пока есть пузырь или «готово»: время пузыря идёт, пока его видно и курсор не держит
    readonly property bool anyDone: { rev; for (const k in acts) if (acts[k].done) return true; return false }
    property Timer tick: Timer {
        interval: 250; repeat: true; running: root.alert !== null || root.anyDone
        onTriggered: {
            const a = root.alert
            if (a && a.dur > 0) {
                const hidden = root.osdOn || (root.cur && !a.urgent)       // ждёт под OSD / баннером — время стоит
                if (!hidden && !(root.alertHold && a.kind !== "intro")) root.alertLeft -= 250
                if (root.alertLeft <= 0) root.endAlert()
            }
            if (a && a.kind === "intro" && !root.acts[a.data.id]) root.endAlert("активность закончилась")
            const now = Date.now(); let ch = false; const m = Object.assign({}, root.acts)
            for (const k in m) if (m[k].done && m[k].doneUntil <= now) { root.log("«" + m[k].title + "» ушла после галочки"); delete m[k]; ch = true }
            if (ch) { root.acts = m; root.rev++ }
        }
    }
    function sysPill(name, o) {          // o: {l, r, icon, tone, w, dur, group, quiet, urgent}
        const r = route({ cat: o.cat || "sys", urgent: !!o.urgent, quiet: !!o.quiet, name: name })
        if (r.act !== "show") return
        pushAlert({ kind: "pill", label: name, data: o, dur: o.dur || 2000, group: o.group || "", urgent: !!o.urgent, why: r.why })
    }
    function banner(name, o) {           // o: {app, icon, title, text, tone, dur, group, urgent, acts}
        const r = route({ cat: "sys", urgent: !!o.urgent, name: name })
        if (r.act !== "show") return
        pushAlert({ kind: "banner", label: name, data: o, dur: o.dur === undefined ? 4000 : o.dur, group: o.group || "", urgent: !!o.urgent, why: r.why })
    }

    // ---------- системные пузыри: зарядка, батарея 10/5 %, AirPods ----------
    readonly property var bat: UPower.displayDevice
    readonly property int batPct: bat ? Math.round(bat.percentage * 100) : -1
    // 30.10: сеть — по контроллеру питания (macsmc-ac/online, опрос 1 с), UPower — запасной путь; UPower на Asahi
    // сообщал о подключении с задержкой или не сообщал, и пузырь «Зарядка» не появлялся
    property int acLine: -1
    property FileView acFile: FileView { path: "/sys/class/power_supply/macsmc-ac/online"; printErrors: false
                                         onLoaded: root.acLine = text().trim() === "1" ? 1 : 0; onLoadFailed: root.acLine = -1 }
    property Timer acPoll: Timer { interval: 1000; repeat: true; running: true; onTriggered: root.acFile.reload() }
    readonly property bool onAc: acLine >= 0 ? acLine === 1
        : (bat ? (bat.state === UPowerDeviceState.Charging || bat.state === UPowerDeviceState.PendingCharge || bat.state === UPowerDeviceState.FullyCharged) : false)
    property bool sysArmed: false
    property Timer sysArm: Timer { interval: 4000; running: true; onTriggered: root.sysArmed = true }
    property bool warned10: false
    property bool warned5: false
    onOnAcChanged: {
        console.log("остров: питание → " + (onAc ? "сеть" : "батарея") + (sysArmed ? "" : " (старт, без пузыря)"))
        if (!sysArmed || batPct < 0) return
        if (onAc) {
            if (alert && alert.group === "power" && alert.urgent) endAlert("зарядка подключена")
            alertQ = alertQ.filter(q => q.group !== "power")
            warned10 = false; warned5 = false
            sysPill("зарядка подключена", { icon: "󱐋", l: "Зарядка", r: batPct + " %", tone: "ok", w: 260, dur: 2400, group: "power" })
        } else sysPill("зарядка отключена", { icon: "󰁹", l: "От батареи", r: batPct + " %", tone: "", w: 240, dur: 1600, group: "power", quiet: true })
    }
    onBatPctChanged: {
        if (!sysArmed || onAc || batPct < 0) return
        if (batPct <= 5 && !warned5) {
            warned5 = true; warned10 = true
            banner("батарея 5 %", { app: "Питание", icon: "󰂃", title: "Батарея " + batPct + " %", text: "Подключите зарядку — осталось несколько минут", tone: "bad", dur: 0, group: "power", urgent: true })
        } else if (batPct <= 10 && !warned10) {
            warned10 = true
            banner("батарея 10 %", { app: "Питание", icon: "󰁺", title: "Низкий заряд · " + batPct + " %", text: "Подключите зарядку", tone: "warn", dur: 4000, group: "power" })
        }
    }
    // AirPods: служба yumi-airpods зовёт `airpodsPopup show "<имя>"` — пузырь острова; заряд Л/П/кейс — из скрипта бара
    // airpods (запускается на ~3 с, пока ждём первую строку с зарядом)
    property var podsData: ({ name: "AirPods", l: -1, r: -1, c: -1 })
    property Process podsProc: Process {
        command: [Quickshell.env("HOME") + "/.local/lib/yumi/bar/airpods"]
        stdout: SplitParser { onRead: (line) => {
            let j; try { j = JSON.parse(line) } catch (e) { return }
            const t = String(j.tooltip || ""), g = (re) => { const m = t.match(re); return m ? Number(m[1]) : -1 }
            const d = { name: root.podsData.name, l: g(/Левый (\d+) %/), r: g(/Правый (\d+) %/), c: g(/Кейс (\d+) %/) }
            if (d.l < 0) d.l = g(/Наушник (\d+) %/)
            root.podsData = d
            if (d.l >= 0 || d.r >= 0) root.podsProc.running = false
        } }
    }
    property Timer podsStop: Timer { interval: 3000; onTriggered: root.podsProc.running = false }
    property IpcHandler podsIpc: IpcHandler {
        target: "airpodsPopup"
        function show(name: string): void {
            root.podsData = { name: name || "AirPods", l: -1, r: -1, c: -1 }
            root.podsProc.running = true; root.podsStop.restart()
            const r = root.route({ cat: "sys", name: "AirPods подключены" })
            if (r.act === "show") root.pushAlert({ kind: "airpods", label: "AirPods подключены", data: {}, dur: 3600, why: r.why })
        }
        // 30.10: смена режима шумоподавления (ножкой, из меню или с айфона) — yumi-airpods по пакету AAP 0x0D
        function mode(n: int): void {
            const names = { 1: "Выключено", 2: "Шумоподавление", 3: "Прозрачность", 4: "Адаптивный" }
            const icons = { 1: "󰋋", 2: "󰟎", 3: "󰈈", 4: "󰁨" }
            if (!names[n]) return
            root.sysPill("режим AirPods: " + names[n], { pods: true, l: names[n], r: "AirPods", w: 300, dur: 1800, group: "podsmode" })
        }
    }

    property IpcHandler actIpc: IpcHandler {
        target: "island"
        function start(id: string, json: string): void { root.start(id, json, false) }
        function update(id: string, json: string): void { root.update(id, json) }
        function end(id: string, json: string): void { root.end(id, json) }
        function focus(arg: string): void { root.setFocus(arg === "toggle" ? !root.focus : arg === "on" || arg === "1", "IPC") }
        function mic(apps: string): void { root.micApps = apps === "-" ? "" : apps; root.log("микрофон: " + (root.micApps || "свободен") + " → точка, без раскрытия") }
        function summaryNow(): void { root.deliverSummary("Сводка (по запросу)") }
        function state(s: string): void { root.force = (s === "-" ? "" : s) }
        function msg(text: string): void { root.msgText = text; root.msgIcon = "󰋽"; root.startOsd(true) }
        function info(): string {
            return JSON.stringify({ force: root.force, cur: root.cur ? root.cur.summary : null, queue: root.queue.length,
                                    reply: root.replyOpen, osd: root.osdOn, msg: root.osdMsg, playerCard: root.playerCard })
        }
        function list(): string {
            return JSON.stringify({ ranked: root.ranked.map(a => a.music ? "music" : a.id), acts: root.acts, focus: root.focus, dnd: Notifs.dnd,
                                    summary: root.summary.length, alert: root.alert ? root.alert.label : null, queue: root.alertQ.length, fs: root.fsNow() })
        }
    }
}
