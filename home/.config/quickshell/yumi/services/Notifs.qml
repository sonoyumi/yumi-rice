pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs

// Уведомления вместо swaync: сервер org.freedesktop.Notifications, записи (Entry) для всплывашек и центра,
// журнал ~/.cache/yumi-notify/history.json в формате yumi-notify-log (его читает yumi-menu-control),
// правила ~/.config/yumi/notify/ignore.json, IPC «notif» вместо swaync-client.
// Для пилюли бара: Notifs.count / Notifs.dnd / Notifs.visible — то же, что печатал cc-bar из swaync-client -s.
//   qs -c yumi ipc call notif toggle | open | close | closeAll | dnd | dndOn | dndOff | state
Singleton {
    id: root

    // ---- параметры как в ~/.config/swaync/config.json ----
    readonly property int timeoutNormal: 6000       // timeout 6 с
    readonly property int timeoutLow: 4000          // timeout-low 4 с
    readonly property int timeoutCritical: 0        // timeout-critical 0 — не исчезает
    readonly property int cardW: 360                // notification-window-width = control-center-width
    readonly property int centerH: 740              // control-center-height
    readonly property int centerMargin: 8           // control-center-margin-*
    readonly property int maxCenter: 50             // сколько держать в центре/журнале (YNL_MAX у yumi-notify-log)
    readonly property color red: "#ed8796"          // цвет critical — фиксированный, как yn-red в user-style.css
    // Центр = журнал history.json: при старте записи файла поднимаются как «архивные» карточки (notif = null,
    // действия запускают приложение по desktop-entry), новые ложатся поверх; удаление из центра удаляет из файла.
    // hints «прогресса» (громкость/яркость) — в журнал не пишутся (как у yumi-notify-log)
    readonly property var progressHints: ["value", "synchronous", "x-canonical-private-synchronous", "x-dunst-stack-tag"]

    // ---- состояние (как swaync-client -s: count, dnd, visible) ----
    property alias dnd: persist.dnd
    property bool visible: false                    // центр открыт
    property bool replyArmed: false                 // 19.10: курсор на карточке с быстрым ответом / в поле текст — всплывашкам можно клавиатуру
    readonly property int count: center.length
    property real now: Date.now()                   // для относительного времени на карточках

    property var entries: []                        // все живые записи, новые в начале
    readonly property var popups: entries.filter(e => e.popup)
    readonly property var center: entries.filter(e => e.inCenter)
    readonly property var popupApps: apps(popups)
    readonly property var centerApps: apps(center)
    function apps(list) { const out = []; for (const e of list) if (!out.includes(e.app)) out.push(e.app); return out }
    function popupsFor(app) { return popups.filter(e => e.app === app) }
    function centerFor(app) { return center.filter(e => e.app === app) }
    function touch() { root.entriesChanged() }      // флаги записей изменились — пересчитать списки

    PersistentProperties { id: persist; property bool dnd: false; reloadableId: "yumi-notifs" }

    // ---- запись ----
    Component { id: entryComp; QtObject {
        id: e
        property Notification notif
        property int nid: 0
        property string key: ""
        property string app: ""
        property string appIcon: ""
        property string desktopEntry: ""
        property string summary: ""
        property string body: ""
        property int urgency: 1                     // 0 low, 1 normal, 2 critical
        property string image: ""                   // как пришло: путь, file://, image:// (image-data)
        property string imageFile: ""               // для журнала: png в кэше или image-path
        property var actions: []                    // [{id, text}]
        property bool hasInlineReply: false
        property string replyPlaceholder: ""
        property string category: ""
        property int expireTimeout: -1
        property var hints: ({})
        property real time: Date.now()
        property real first: 0
        property bool popup: false
        property bool inCenter: false
        property bool journaled: false
        property bool saved: false                  // уже записана в history.json
        property bool progress: false
        property bool transientHint: false
        property bool resident: false
        readonly property bool alive: notif !== null
        property Timer timer: Timer { onTriggered: root.hidePopup(e) }
        property Connections conn: Connections {
            target: e.notif
            function onClosed(reason) { root.onClosed(e, reason) }
            // replaces_id: приложение обновило уведомление — перечитать и показать заново
            function onSummaryChanged() { Qt.callLater(root.refresh, e) }
            function onBodyChanged() { Qt.callLater(root.refresh, e) }
            function onImageChanged() { Qt.callLater(root.refresh, e) }
            function onActionsChanged() { Qt.callLater(root.refresh, e) }
            function onHintsChanged() { Qt.callLater(root.refresh, e) }
            function onUrgencyChanged() { Qt.callLater(root.refresh, e) }
        }
    } }

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        inlineReplySupported: true
        onNotification: (n) => root.add(n)
    }

    function fill(e) {
        const n = e.notif
        if (!n) return
        const h = n.hints || {}
        e.nid = n.id
        e.app = n.appName || ""
        e.appIcon = n.appIcon || ""
        e.desktopEntry = n.desktopEntry || ""
        e.summary = n.summary || ""
        e.body = n.body || ""
        e.urgency = n.urgency === NotificationUrgency.Critical ? 2 : (n.urgency === NotificationUrgency.Low ? 0 : 1)
        e.image = n.image || ""
        e.actions = Array.from(n.actions || []).map(a => ({ id: a.identifier, text: a.text }))
        e.hasInlineReply = n.hasInlineReply
        e.replyPlaceholder = n.inlineReplyPlaceholder || ""
        e.category = h["category"] || ""
        e.expireTimeout = n.expireTimeout
        e.hints = h
        e.resident = n.resident
        e.transientHint = n.transient || h["transient"] === true || h["transient"] === 1
        e.progress = progressHints.some(k => k in h)
        const ip = h["image-path"] || h["image_path"] || ""
        if (e.image.startsWith("image://")) { if (!e.imageFile.endsWith(".png")) e.imageFile = "" }   // png сохранит карточка (saveImage)
        else e.imageFile = ip
    }

    readonly property bool debug: Quickshell.env("YUMI_NOTIF_DEBUG") === "1"
    function add(n) {
        n.tracked = true
        checkSrv()
        const e = entryComp.createObject(root, { notif: n })
        fill(e)
        e.key = srv ? srv + "/" + e.nid : ""
        e.journaled = !e.progress && !e.transientHint && !ruleFor(e)
        e.inCenter = e.journaled                      // в центре то же, что в журнале
        e.popup = !dnd
        entries = [e].concat(entries)
        if (debug) console.log("Notifs: +", e.nid, e.app, JSON.stringify(e.summary), "popup", e.popup, "center", e.inCenter, "journal", e.journaled, "| entries", entries.length, "center", center.length, "count", count, "srv", srv)
        if (e.popup) armTimer(e)
        else if (!e.inCenter) n.expire()              // «Не беспокоить» + служебное: некому показывать
        trimCenter()
        if (e.journaled) journalPut(e)
    }

    function refresh(e) {
        if (!e || !e.alive) return
        fill(e)
        e.journaled = !e.progress && !e.transientHint && !ruleFor(e)
        e.inCenter = e.journaled
        if (!dnd) { e.popup = true; armTimer(e) }
        e.time = Date.now()
        touch()
        if (e.journaled) journalPut(e)
    }

    function armTimer(e) {
        const ms = e.expireTimeout > 0 ? e.expireTimeout
                 : (e.urgency === 2 ? timeoutCritical : (e.urgency === 0 ? timeoutLow : timeoutNormal))
        e.timer.stop()
        if (ms > 0) { e.timer.interval = ms; e.timer.start() }
    }

    // всплывашка истекла: NotificationClosed(reason 1), как у swaync (иначе notify-send --wait/-A висят);
    // в центре остаётся копия — её действия запускают приложение по desktop-entry
    function hidePopup(e) {
        if (debug) console.log("Notifs: popup истёк", e.nid, e.app)
        e.timer.stop()
        e.popup = false
        if (e.notif) e.notif.expire(); else touch()
    }

    function trimCenter() {
        const extra = center.slice(maxCenter)
        for (const e of extra) { e.inCenter = false; if (e.notif) e.notif.expire(); else remove(e) }
        if (extra.length) touch()
    }

    function onClosed(e, reason) {
        if (debug) console.log("Notifs: closed", e.nid, e.app, "reason", reason)
        e.notif = null
        e.timer.stop()
        e.popup = false
        if (reason !== NotificationCloseReason.Expired) {        // закрыл пользователь / приложение: из центра и журнала
            e.inCenter = false
            journalRemove(e)
        }
        if (!e.inCenter) remove(e); else touch()
    }

    function remove(e) {
        entries = entries.filter(x => x !== e)
        e.destroy()
    }

    // закрыть: живое — через сервер (придёт closed), копия — просто убрать
    function dismiss(e) {
        if (e.notif) e.notif.dismiss()
        else { e.inCenter = false; journalRemove(e); remove(e) }
    }
    function closeAll() { for (const e of entries.slice()) dismiss(e) }

    // действие: живое уведомление — ActionInvoked (после — закрыть, как hide-on-action у swaync, кроме resident);
    // копия (истекла) — запустить приложение по desktop-entry
    function invoke(e, id) {
        if (e.notif) {
            const a = Array.from(e.notif.actions || []).find(x => x.identifier === id)
            if (a) { if (Quickshell.env("YP_DRYRUN") === "1") console.log("[dry-run] уведомление: действие", id); else a.invoke() }
            if (!e.resident) dismiss(e)
        } else launch(e)
        visible = false
    }
    function activate(e) {
        if (e.alive && e.actions.some(a => a.id === "default")) invoke(e, "default")
        else { launch(e); visible = false }
    }
    function launch(e) {
        if (Quickshell.env("YP_DRYRUN") === "1") { console.log("[dry-run] уведомление: запуск", e.app); return }   // 16.10: проверки не запускают программы
        let d = e.desktopEntry ? DesktopEntries.byId(e.desktopEntry) : null
        if (!d && e.app) d = DesktopEntries.heuristicLookup(e.app)
        if (d) d.execute()
    }
    function reply(e, text) { if (e.notif && text.length) { e.notif.sendInlineReply(text); if (!e.resident) dismiss(e) } }

    // значок: картинка уведомления → app_icon → .desktop → по имени приложения → "" (карточка покажет глиф)
    function iconFor(e, big) {
        if (big && e.image) {
            if (e.image.startsWith("/")) return "file://" + e.image
            if (e.image.includes("://")) return e.image
            const p = Quickshell.iconPath(e.image, true); if (p) return p
        }
        if (e.appIcon) {
            if (e.appIcon.startsWith("/")) return "file://" + e.appIcon
            if (e.appIcon.startsWith("file://")) return e.appIcon
            const p = Quickshell.iconPath(e.appIcon, true); if (p) return p
        }
        let d = e.desktopEntry ? DesktopEntries.byId(e.desktopEntry) : null
        if (!d && e.app) d = DesktopEntries.heuristicLookup(e.app)
        if (d && d.icon) { const p = Quickshell.iconPath(d.icon, true); if (p) return p }
        if (e.app) { const p = Quickshell.iconPath(e.app.toLowerCase().replace(/ /g, "-"), true); if (p) return p }
        return ""
    }

    // относительное время, как relative-timestamps у swaync
    function ago(t) {
        const s = Math.max(0, (now - t) / 1000)
        if (s < 60) return "сейчас"
        if (s < 3600) return Math.floor(s / 60) + " мин"
        if (s < 86400) return Math.floor(s / 3600) + " ч"
        return Qt.formatDateTime(new Date(t), "dd.MM HH:mm")
    }
    Timer { interval: 30000; repeat: true; running: root.visible || root.popups.length > 0; onTriggered: root.now = Date.now() }
    onVisibleChanged: now = Date.now()

    // ================= журнал (формат yumi-notify-log) =================
    readonly property string home: Quickshell.env("HOME")
    readonly property string histPath: (Quickshell.env("YNL_HISTORY") || (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/yumi-notify/history.json")
    readonly property string imgDir: histPath.substring(0, histPath.lastIndexOf("/")) + "/img"
    readonly property string rulesPath: (Quickshell.env("YNL_IGNORE") || (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/yumi/notify/ignore.json")
    property string srv: ""                          // уникальное имя нашего соединения на шине — ключ записи «srv/id»
    property var items: []                           // items из history.json, новые в начале
    property string lastWritten: ""
    property int fakeId: 0

    FileView {
        id: hist
        path: root.histPath
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.histLoaded(text())
        onLoadFailed: root.items = []
    }
    function histLoaded(t) {
        if (t === lastWritten) return                // наша же запись
        let data
        try { data = JSON.parse(t) } catch (err) { return }
        items = (data.items || []).filter(i => i && typeof i === "object" && "key" in i)
        // центр управления убрал карточку / «Очистить всё» — закрыть и у нас
        const keys = new Set(items.map(i => i.key))
        if (debug) console.log("Notifs: журнал изменён извне, записей", items.length)
        for (const e of entries.slice()) if (e.journaled && e.saved && !keys.has(e.key)) dismiss(e)
        // записи файла, которых у нас нет (старт, запись другого процесса) — архивные карточки центра
        const have = new Set(entries.map(e => e.key))
        let added = false
        for (const i of items) if (i.key && !have.has(i.key)) { entries.push(fromItem(i)); added = true }
        if (added) { entries = entries.slice().sort((a, b) => b.time - a.time); trimCenter() }
    }
    function fromItem(i) {
        const img = typeof i.image === "string" ? i.image : ""
        return entryComp.createObject(root, {
            notif: null, nid: Number(i.id) || 0, key: i.key, app: i.app || "", appIcon: i.app_icon || "",
            desktopEntry: i.desktop_entry || "", summary: i.summary || "", body: i.body || "",
            urgency: Number(i.urgency) === 2 ? 2 : (Number(i.urgency) === 0 ? 0 : 1),
            image: img, imageFile: img, category: i.category || "",
            actions: Array.isArray(i.actions) ? i.actions.filter(a => Array.isArray(a) && a.length === 2).map(a => ({ id: String(a[0]), text: String(a[1]) })) : [],
            expireTimeout: Number(i.expire) || -1, time: (Number(i.time) || 0) * 1000, first: Number(i.first) || 0,
            inCenter: true, journaled: true, saved: true
        })
    }
    function toItem(e) {
        return {
            app: e.app, app_icon: e.appIcon, summary: e.summary, body: e.body, desktop_entry: e.desktopEntry,
            urgency: e.urgency, category: e.category, image: e.imageFile || null,
            actions: e.actions.map(a => [a.id, a.text]), expire: e.expireTimeout, replaces: 0,
            id: e.nid, srv: srv, key: e.key, time: e.time / 1000
        }
    }
    function journalPut(e) {
        if (!srvOk) return                           // имя на шине ещё не подтверждено — допишем в onSrvChanged
        if (!e.key) e.key = srv + "/" + e.nid
        const item = toItem(e)
        const old = items.find(i => i.key === e.key)
        if (old) item.first = old.first !== undefined ? old.first : old.time
        else if (e.first) item.first = e.first
        items = [item].concat(items.filter(i => i.key !== e.key))
        saveTimer.restart()
    }
    function journalRemove(e) {
        if (!e.key) return
        const n = items.length
        items = items.filter(i => i.key !== e.key)
        if (items.length !== n) saveTimer.restart()
    }
    // image-data: карточка отрисовала картинку и сохранила png в кэш — дописать путь в журнал
    function setImageFile(e, p) { e.imageFile = p; if (e.journaled) journalPut(e) }
    function imageName(e) { return imgDir + "/" + Qt.md5(e.key + ":" + e.time).substring(0, 20) + ".png" }

    Timer { id: saveTimer; interval: 150; onTriggered: root.save() }   // не чаще раза в 150 мс
    function save() {
        items = items.slice(0, maxCenter)
        const text = JSON.stringify({ version: 1, updated: Date.now() / 1000, server: srv, items: items }, null, 1)
        lastWritten = text
        hist.setText(text)
        const keys = new Set(items.map(i => i.key))
        for (const e of entries) if (e.journaled && keys.has(e.key)) e.saved = true
        if (!cleanGuard.running) { cleanGuard.start(); imgClean.running = true }
    }
    Timer { id: cleanGuard; interval: 60000 }
    Process { id: imgClean; command: ["python3", "-I", root.home + "/.local/lib/yumi/qs/notif-img-clean"] }

    // имя соединения на шине (как server/srv у yumi-notify-log). Берём только когда имя держит НАШ процесс
    // (пока им владеет swaync, имя чужое) — проверка при старте и при первом уведомлении.
    property bool srvOk: false
    Process {
        id: busName
        command: ["sh", "-c", "n=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus GetNameOwner s org.freedesktop.Notifications 2>/dev/null | sed 's/^s \"\\(.*\\)\"$/\\1/'); [ -n \"$n\" ] || exit 1; p=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus GetConnectionUnixProcessID s \"$n\" 2>/dev/null | awk '{print $2}'); echo \"$n $p\""]
        stdout: StdioCollector { onStreamFinished: {
            const parts = text.trim().split(" ")
            if (parts.length === 2 && Number(parts[1]) === Quickshell.processId) { root.srvOk = true; root.srv = parts[0] }
        } }
    }
    function checkSrv() { if (!srvOk && !busName.running) busName.running = true }
    Timer { interval: 400; running: true; onTriggered: root.checkSrv() }
    onSrvChanged: if (srv) for (const e of entries.slice().reverse()) if (e.journaled && !e.key) journalPut(e)

    // ================= правила ignore.json (keep сильнее ignore) =================
    property var rules: ({ keep: [], ignore: [] })
    FileView {
        path: root.rulesPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.compileRules(text())
        onLoadFailed: root.rules = { keep: [], ignore: [] }
    }
    function compileRules(t) {
        const comp = (list) => (Array.isArray(list) ? list : []).filter(r => r && typeof r === "object").map(r => {
            const cond = []
            for (const k in r) {
                if (k === "name") continue
                const v = r[k]
                try { cond.push({ k: k, v: typeof v === "string" ? new RegExp(v, "i") : v }) }
                catch (err) { console.log("Notifs: правило", r.name, "пропущено:", err) }
            }
            return { name: r.name || "?", cond: cond }
        })
        try { const d = JSON.parse(t); rules = { keep: comp(d.keep), ignore: comp(d.ignore) } }
        catch (err) { console.warn("Notifs: плохой JSON в", rulesPath, err) }
    }
    function hit(cond, e) {
        for (const c of cond) {
            if (c.k === "replaces") { if (0 !== Number(c.v)) return false; continue }   // replaces_id сервер не отдаёт
            if (c.k === "urgency") { if (e.urgency !== Number(c.v)) return false; continue }
            if (!(c.v instanceof RegExp)) return false
            const val = c.k === "icon" ? e.appIcon + " " + (e.hints["image-path"] || e.hints["image_path"] || "")
                      : c.k === "app" ? e.app : c.k === "summary" ? e.summary : c.k === "body" ? e.body : ""
            if (!c.v.test(val)) return false
        }
        return true
    }
    function ruleFor(e) {
        if (rules.keep.some(r => hit(r.cond, e))) return null
        const r = rules.ignore.find(r => hit(r.cond, e))
        return r ? r.name : null
    }

    // ================= IPC вместо swaync-client =================
    IpcHandler {
        target: "notif"
        function toggle(): void { root.visible = !root.visible }          // -t
        function open(): void { root.visible = true }                     // -op
        function close(): void { root.visible = false }                   // -cp
        function closeAll(): void { root.closeAll() }                     // -C
        function closeMatching(pattern: string): void {                   // закрыть всё, где app/summary/body ~ regex
            const re = new RegExp(pattern, "i")
            for (const e of root.entries.slice()) if (re.test(e.app) || re.test(e.summary) || re.test(e.body)) root.dismiss(e)
        }
        function dnd(): void { root.dnd = !root.dnd }                      // -d
        function dndOn(): void { root.dnd = true }                         // -dn
        function dndOff(): void { root.dnd = false }                       // -df
        // отладка вида без шины (YUMI_NOTIF_DEBUG=1): qs ipc call notif fake Telegram "Марко" "текст" 1
        function fake(app: string, summary: string, body: string, urgency: int): void {
            if (!root.debug) return
            const e = entryComp.createObject(root, { notif: null, app: app, summary: summary, body: body, urgency: urgency,
                nid: ++fakeId, key: "fake/" + fakeId, popup: !root.dnd, inCenter: true,
                actions: app === "Zen" ? [{ id: "ok", text: "Открыть" }, { id: "later", text: "Позже" }] : [] })
            entries = [e].concat(entries)
            if (e.popup) armTimer(e)
        }
        function state(): string { return JSON.stringify({ count: root.count, dnd: root.dnd, visible: root.visible }) }   // -s
    }
}
