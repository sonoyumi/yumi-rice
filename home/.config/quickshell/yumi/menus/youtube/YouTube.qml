import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

// YumiTube (11.11): YouTube-клиент в стиле «Острова». Отдельный экземпляр qs (app-youtube.qml), окно — обычное
// xdg-окно Hyprland (title «YumiTube»). Данные — бэкенд ~/.local/lib/yumi/qs/youtube (yt-dlp + RSS).
// Видео — ВНУТРИ окна: libmpv через плагин Yumi.Mpv (~/.local/src/yumi-mpv → ~/.local/lib/yumi/qml; нужен
// QML_IMPORT_PATH и QSG_RHI_BACKEND=opengl — их ставит ~/.local/bin/yumi-youtube). Плеер: страница «watch»,
// мини-плеер в углу при уходе в другие разделы, «кино» (во всё окно + полноэкранный режим Hyprland).
// Разделы: лента подписок, поиск, канал, «Смотреть позже», история, подписки.
//   qs ipc -p ~/.config/quickshell/yumi/app-youtube.qml call youtube search <запрос> | page <имя> | state
// Тест (только eDP-1): YUMI_YT_PANEL=1 YUMI_QS_SCREEN=eDP-1 — вместо xdg-окна слой на этом экране.
Scope {
    id: yt
    readonly property string backend: Quickshell.env("HOME") + "/.local/lib/yumi/qs/youtube"
    readonly property string home: Quickshell.env("HOME")
    readonly property bool panelMode: (Quickshell.env("YUMI_YT_PANEL") || "") !== ""

    property string page: "feed"          // rec | feed | search | channel | later | history | subs | watch
    property string lastPage: "feed"      // куда вернуться со страницы просмотра
    property var items: []
    property bool loading: false
    property string error: ""
    property string query: ""
    property var chan: null               // { id, name, subscribed }
    property var subs: []
    property var laterIds: ({})
    property var settings: ({ quality: "1080", shorts: false, account: "", volume: 100, autoplay: true })
    // ---- плеер ----
    property var current: null            // видео, которое играет
    property var queue: []                // «Далее»: остаток списка, из которого открыто видео
    property string playerMode: ""        // "" | watch | mini | theater
    property bool audioOnly: false
    property real resumeAt: 0
    signal playRequested(string url, real start)
    signal reloadRequested()              // смена качества: перезагрузить с той же позиции
    signal stopRequested()
    property bool busy: false             // импорт / подключение аккаунта идёт
    property string toast: ""
    property int seq: 0

    readonly property var shown: settings.shorts ? items : items.filter(v => !v.short)
    readonly property var qualities: ["720", "1080", "1440", "2160"]

    // ---- бэкенд: один Process на запрос, ответ — одна JSON-строка ----
    Component {
        id: procComp
        Process {
            id: p
            property var cb: null
            stdout: StdioCollector {
                onStreamFinished: {
                    let j = null
                    try { j = JSON.parse(text) } catch (e) { j = { ok: false, error: "Бэкенд не ответил" } }
                    if (p.cb) p.cb(j)
                    Qt.callLater(() => p.destroy())
                }
            }
            stderr: StdioCollector { onStreamFinished: if (text.trim()) console.log("youtube:", text.trim()) }
        }
    }
    function run(args, cb) {
        const p = procComp.createObject(yt, { command: [backend].concat(args), cb: cb })
        p.running = true
    }

    function go(pg, arg) {
        if (pg === "watch") { if (current) { page = "watch"; playerMode = "watch" } return }
        if (playerMode === "watch" || playerMode === "theater") playerMode = "mini"
        lastPage = pg
        const s = ++seq
        page = pg; error = ""; loading = true
        if (pg !== "search" && pg !== "channel") items = []
        const done = j => {
            if (s !== seq) return
            loading = false
            if (!j.ok) { error = j.error || "Ошибка"; return }
            if (pg === "channel") chan = { id: j.id, name: j.name, subscribed: j.subscribed }
            if (pg === "subs") subs = j.items
            if (pg === "feed" && j.errors && j.errors.length) flash("Не обновились: " + j.errors.length + " кан.")
            items = pg === "subs" ? [] : j.items
        }
        if (pg === "rec") run(["rec"], done)
        else if (pg === "feed") run(arg === "refresh" ? ["feed", "--refresh"] : ["feed"], done)
        else if (pg === "search") { query = arg; items = []; run(["search", arg], done) }
        else if (pg === "channel") { items = []; chan = { id: arg, name: "", subscribed: false }; run(["channel", arg], done) }
        else if (pg === "later") run(["later"], j => { if (j.ok) setLater(j.items); done(j) })
        else if (pg === "history") run(["history"], done)
        else if (pg === "subs") run(["subs"], done)
    }
    function refresh() { if (page === "rec") return go("rec"); go(page, page === "feed" ? "refresh" : page === "search" ? query : page === "channel" && chan ? chan.id : "") }

    function setLater(lst) { const m = {}; for (const v of lst) m[v.id] = true; laterIds = m }
    function slim(v) { return { id: v.id, title: v.title, channel: v.channel, channelId: v.channelId, duration: v.duration,
                                views: v.views, ts: v.ts, thumb: v.thumb, short: v.short, live: v.live } }

    // открыть видео во встроенном плеере; list — список, из которого открыли (для «Далее»)
    function play(v, audio, list) {
        if (current && current.id !== v.id) saveProgress()
        const src = list || shown
        const i = src.findIndex(x => x.id === v.id)
        queue = i >= 0 ? src.slice(i + 1).filter(x => !x.live).slice(0, 40) : queue.filter(x => x.id !== v.id)
        current = v
        audioOnly = !!audio
        if (page !== "watch") lastPage = page
        page = "watch"
        if (playerMode !== "theater") playerMode = "watch"
        run(["watched", JSON.stringify(slim(v))], j => {
            if (!current || current.id !== v.id) return
            resumeAt = j.ok ? j.pos : 0
            playRequested("https://www.youtube.com/watch?v=" + v.id, resumeAt)
            if (resumeAt > 0) flash("Продолжаю с " + fmtTime(resumeAt))
        })
    }
    // «кино»: видео во всё окно; в обычном окне ещё и полноэкранный режим Hyprland
    function toggleTheater() {
        const on = playerMode !== "theater"
        playerMode = on ? "theater" : "watch"
        page = "watch"
        // Hyprland на Lua-конфиге: dispatch — выражение Lua; окно — активное (клавиша/кнопка нажата в YumiTube)
        const st = on ? 2 : 0
        if (!panelMode) Quickshell.execDetached(["hyprctl", "dispatch",
            "hl.dsp.window.fullscreen_state({ internal = " + st + ", client = " + st + " })"])
    }
    function playNext() { if (queue.length) play(queue[0], audioOnly, queue) }
    function closePlayer() {
        saveProgress()
        stopRequested()
        current = null; playerMode = ""
        if (page === "watch") go(lastPage || "feed")
    }
    function back() { if (page === "watch") go(lastPage || "feed") }
    // позицию пишет плеер (YtView) через этот хук: pos/dur — текущие
    property real curPos: 0
    property real curDur: 0
    property int curDrop: 0
    function saveProgress() {
        if (current && curDur > 0 && curPos > 5)
            run(["progress", current.id, String(curPos), String(curDur)], j => {})
    }
    Timer { interval: 15000; repeat: true; running: !!yt.current; onTriggered: yt.saveProgress() }
    function fmtTime(s) {
        s = Math.max(0, Math.floor(s || 0))
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), x = s % 60
        const p = n => (n < 10 ? "0" : "") + n
        return h ? h + ":" + p(m) + ":" + p(x) : m + ":" + p(x)
    }
    function fmtCount(n, unit) {
        if (!n) return ""
        if (n >= 1e9) return (n / 1e9).toFixed(1).replace(".0", "").replace(".", ",") + " млрд " + unit
        if (n >= 1e6) return (n / 1e6).toFixed(1).replace(".0", "").replace(".", ",") + " млн " + unit
        if (n >= 1e3) return Math.round(n / 1e3) + " тыс. " + unit
        return n + " " + unit
    }
    function ytFormat(q) {
        return q === "2160" ? "bestvideo[height<=?2160][vcodec^=av01]+bestaudio/bestvideo+bestaudio/best"
             : "bestvideo[height<=?" + q + "][vcodec^=av01]+bestaudio/bestvideo[height<=?" + q + "]+bestaudio/best"
    }
    function toggleLater(v) {
        const on = !!laterIds[v.id]
        run(on ? ["later", "rm", v.id] : ["later", "add", JSON.stringify(slim(v))], j => {
            if (!j.ok) return flash(j.error)
            setLater(j.items)
            if (page === "later") items = j.items
            flash(on ? "Убрано из «Позже»" : "Добавлено в «Позже»")
        })
    }
    function subscribe(id, name) {
        run(["sub", "add", id, name || ""], j => {
            if (!j.ok) return flash(j.error)
            subs = j.items
            if (chan && chan.id === j.added.id) chan = Object.assign({}, chan, { subscribed: true })
            flash("Подписка: " + j.added.name)
        })
    }
    function unsubscribe(id) {
        run(["sub", "rm", id], j => {
            if (!j.ok) return flash(j.error)
            subs = j.items
            if (chan && chan.id === id) chan = Object.assign({}, chan, { subscribed: false })
            flash("Подписка отменена")
        })
    }
    function addChannel(text, cb) {
        run(["sub", "add", text], j => { if (cb) cb(j.ok); if (!j.ok) return flash(j.error); subs = j.items; flash("Подписка: " + j.added.name) })
    }
    function setSetting(k, val) {
        const o = {}; o[k] = val
        settings = Object.assign({}, settings, o)
        if (k === "quality" && current) reloadRequested()
        run(["settings", JSON.stringify(o)], j => {})
    }
    // ---- аккаунт и импорт ----
    function connectAccount(browser) {
        busy = true
        setSetting("account", browser)
        flash("Проверяю вход в YouTube…")
        run(["account", "check"], j => {
            if (!j.ok) { busy = false; setSetting("account", ""); return flash("Не вышло: " + j.error) }
            flash("Аккаунт подключён. Забираю историю, «Позже» и каналы…")
            run(["account", "import"], k => {
                busy = false
                if (!k.ok) return flash("Импорт: " + k.error)
                afterImport(k)
                go("rec")
            })
        })
    }
    function disconnectAccount() { setSetting("account", ""); if (page === "rec") go("feed"); flash("Аккаунт отключён") }
    function importTakeout(path) {
        busy = true; flash("Импортирую…")
        run(["import", path], j => { busy = false; if (!j.ok) return flash("Импорт: " + j.error); afterImport(j) })
    }
    function afterImport(j) {
        flash("Добавлено: каналов " + (j.subs || 0) + ", в историю " + (j.history || 0) + ", в «Позже» " + (j.later || 0))
        run(["subs"], k => { if (k.ok) subs = k.items })
        run(["later"], k => { if (k.ok) setLater(k.items) })
    }
    function qLabel(q) { return q === "2160" ? "4K" : q + "p" }

    function flash(t) { toast = t; toastTimer.restart() }
    Timer { id: toastTimer; interval: 2600; onTriggered: yt.toast = "" }

    Component.onCompleted: {
        run(["settings"], j => { if (j.ok) settings = j.settings; go(settings.account ? "rec" : "feed") })
        run(["subs"], j => { if (j.ok) subs = j.items })
        run(["later"], j => { if (j.ok) setLater(j.items) })
    }

    IpcHandler {
        target: "youtube"
        function search(q: string): void { yt.go("search", q) }
        function page(name: string): void { yt.go(name) }
        function channel(id: string): void { yt.go("channel", id) }
        function play(id: string): void { yt.play({ id: id, title: "", channel: "", thumb: "https://i.ytimg.com/vi/" + id + "/mqdefault.jpg" }, false, []) }
        function playIndex(i: int): void { if (i >= 0 && i < yt.shown.length) yt.play(yt.shown[i], false, yt.shown) }
        function player(mode: string): void { if (mode === "close") yt.closePlayer(); else if (yt.current) { yt.playerMode = mode; if (mode !== "mini") yt.page = "watch"; else yt.go(yt.lastPage) } }
        function state(): string {
            return JSON.stringify({ page: yt.page, player: yt.playerMode, drop: yt.curDrop, pos: Math.round(yt.curPos), dur: Math.round(yt.curDur), loading: yt.loading, error: yt.error, items: yt.items.length,
                                    shown: yt.shown.length, subs: yt.subs.length, quality: yt.settings.quality })
        }
    }

    // ---- обычное окно ----
    FloatingWindow {
        id: win
        visible: !yt.panelMode
        title: "YumiTube"
        implicitWidth: 1240; implicitHeight: 800
        minimumSize: Qt.size(720, 480)
        color: Colors.isl
        Behavior on color { ColorAnimation { duration: Theme.normal } }
        YtView { anchors.fill: parent; app: yt }
        onVisibleChanged: if (!visible && !yt.panelMode) {
            if (yt.current && yt.curDur > 0) Quickshell.execDetached([yt.backend, "progress", yt.current.id, String(yt.curPos), String(yt.curDur)])
            Qt.quit()
        }
    }

    // ---- тестовый режим: слой на выбранном экране ----
    Loader {
        active: yt.panelMode
        sourceComponent: PanelWindow {
            screen: {
                const want = Quickshell.env("YUMI_QS_SCREEN") || "eDP-1"
                for (const s of Quickshell.screens) if (s.name === want) return s
                return Quickshell.screens[0]
            }
            color: "transparent"
            WlrLayershell.namespace: "yumi-qs-youtube-test"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            exclusionMode: ExclusionMode.Ignore
            implicitWidth: parseInt((Quickshell.env("YUMI_YT_SIZE") || "1240x800").split("x")[0])
            implicitHeight: parseInt((Quickshell.env("YUMI_YT_SIZE") || "1240x800").split("x")[1])
            Rectangle {
                anchors.fill: parent; radius: Theme.radiusBig; color: Colors.isl; clip: true
                YtView { anchors.fill: parent; app: yt }
            }
        }
    }
}
