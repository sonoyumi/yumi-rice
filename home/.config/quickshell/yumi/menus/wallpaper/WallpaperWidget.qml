import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import QtQuick.Shapes
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import qs
import qs.components
import qs.services

// Виджет «Обои» (вместо меню-сетки WallpaperMenu, 16.10). «Остров» (29.10): во весь экран — выбранные обои (превью),
// снизу карточка-остров: шапка (название, «стиль · N из M», палитра и акцент), карусель — выбранная миниатюра крупнее
// с кромкой акцентом обоев (пружина), подсказки. Режим стилей (↑): та же карусель обложек стилей с подписями по-русски.
// Два уровня: стили (подпапки ~/Pictures/Wallpapers + «Все обои») и обои выбранного стиля.
//   ← → — листать (по кругу) · ↓ / Enter на стиле — открыть стиль · ↑ — к стилям · Enter — поставить · Esc — закрыть.
// Открывается всегда на стиле текущих обоев (или «Все обои», если смотрели все) — с выделенными текущими обоями.
// Цвета (акцент как Colors.acc — band(xa7, 0.62, 0.80), 9 тонов) — `wallpaper accents` (тот же расчёт, что
// yumi-accent, из его кэша k-means), один раз на запуск оболочки (новые обои — при следующем открытии).
// Применение — `yumi-wallpaper set ФАЙЛ` в фоне: виджет закрывается сразу, переход обоев идёт уже без него.
// Открыть: qs -c yumi ipc call menu center wallpaper (SUPER+SHIFT+W). Проверка: YP_DRYRUN=1 (обои не меняются);
//   qs … ipc call wallpaper left|right|up|down|enter · wallpaper state
Scope {
    id: w
    readonly property bool open: Menus.current === "wallpaper"
    readonly property string home: Quickshell.env("HOME")
    readonly property string backend: home + "/.local/lib/yumi/qs/wallpaper"
    readonly property bool dry: Quickshell.env("YP_DRYRUN") === "1"

    // ---- данные ----
    property var walls: []                  // [{path, name, coll, thumb, big}]
    property var colls: []                  // [{name, preview}]
    property var styles: []                 // [{key, label, n, cover, paths}]
    property string listSig: ""
    property string current: ""
    property var acc: ({})                  // путь → {xa[9], deep, bg, btn, hov, mono}
    property int accRev: 0                  // счётчик — пересчитать привязки цветов, когда пришли новые
    property bool accDone: false
    property string level: "walls"          // "styles" | "walls"
    property string styleKey: ""            // "*" — все обои, "" — ещё не выбирали (откроется стиль текущих)
    property var shown: []                  // обои выбранного стиля

    function fileUrl(p) { return p ? "file://" + p.split("/").map(encodeURIComponent).join("/") : "" }
    function label(c) { return /^\d\d /.test(c) ? c.slice(3) : c }
    function styleOf(path) { const x = walls.find(v => v.path === path); return x ? x.coll : "" }
    function info(path) { accRev; return acc[path] || null }
    // как в Colors.qml: акцент бара, стекло пилюль, глубокий фон
    function accOf(path) { const a = info(path); return a ? Colors.band("#" + a.xa[6], 0.62, 0.80) : Colors.acc }
    function pillOf(path) { const a = info(path); return a ? Colors.capL("#" + a.btn, 0.24) : Colors.bg }
    function deepOf(path) { const a = info(path); return a ? Colors.capL("#" + a.deep, 0.10) : Colors.deep }
    function tonesOf(path) { const a = info(path); return a ? a.xa.map(x => "#" + x) : [] }

    function buildStyles() {
        const pv = {}
        for (const c of colls) pv[c.name] = c.preview
        const names = [...new Set(walls.map(v => v.coll).filter(c => c))].sort()
        const cur = walls.find(v => v.path === current) || walls[0]
        const out = [{ key: "*", label: "Все обои", n: walls.length, cover: cur ? (cur.big || cur.thumb) : "", paths: walls.map(v => v.path) }]
        for (const c of names) {
            const ws = walls.filter(v => v.coll === c)
            out.push({ key: c, label: label(c), n: ws.length, cover: pv[c] || ws[0].big || ws[0].thumb, paths: ws.map(v => v.path) })
        }
        styles = out
    }
    function refilter(focusPath) {
        shown = styleKey === "*" ? walls : walls.filter(v => v.coll === styleKey)
        wallView.jump(Math.max(0, shown.findIndex(v => v.path === focusPath)))
    }
    // при открытии: стиль текущих обоев (если до этого смотрели «Все обои» — остаёмся там), выделены текущие
    function placeOnOpen() {
        const cs = styleOf(current)
        if (styleKey !== "*" || !cs) styleKey = cs || "*"
        level = "walls"
        refilter(current)
        styleView.jump(Math.max(0, styles.findIndex(s => s.key === styleKey)))
    }

    // выбранное сейчас (для подписи и цветов)
    readonly property var selWall: shown.length ? shown[Math.max(0, Math.min(shown.length - 1, wallView.currentIndex))] : null
    readonly property var selStyle: styles.length ? styles[Math.max(0, Math.min(styles.length - 1, styleView.currentIndex))] : null
    readonly property string focusPath: {
        if (level === "walls") return selWall ? selWall.path : current
        if (!selStyle) return current
        return selStyle.paths.indexOf(current) >= 0 ? current : (selStyle.paths[0] || current)
    }
    readonly property color fAcc: accOf(focusPath)

    // ---- бэкенд ----
    Process {
        id: lister
        command: [w.backend, "list"]
        stdout: StdioCollector { onStreamFinished: w.takeList(text) }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) console.log("wallpaper:", text.trim()) }
    }
    function takeList(text) {
        let j
        try { j = JSON.parse(text) } catch (e) { console.log("wallpaper: не JSON"); return }
        current = j.current
        const sig = JSON.stringify(j.items)
        const fresh = sig !== listSig
        if (fresh) { listSig = sig; walls = j.items; colls = j.colls || []; buildStyles() }
        if (open && (fresh || !shown.length)) placeOnOpen()
        if (!accDone && !accer.running) accer.running = true
    }
    // цвета приходят строкой на обои (~80 строк подряд): привязки пересчитываются пачкой, а не на каждую строку
    // (иначе палитра-Repeater пересоздавалась ~80 раз при первом открытии — заминка)
    Timer { id: accBatch; interval: 60; onTriggered: w.accRev++ }
    Process {
        id: accer
        command: [w.backend, "accents"]
        stdout: SplitParser {
            onRead: (line) => {
                try { const j = JSON.parse(line); if (j.type === "acc") { w.acc[j.path] = j; accBatch.start() } } catch (e) {}
            }
        }
        onExited: (code) => { w.accDone = code === 0; w.accRev++ }
    }

    // ---- действия ----
    // «Становится картиной» (19.10; 29.10 — на всех мониторах и быстрее): на Enter подписи и лента гаснут, превью
    // на весь экран остаётся; на ДРУГИХ мониторах в тот же миг своё окно-оверлей (SecondScreen) — та же картинка
    // вырастает из центра экрана по той же кривой. Обои ставятся на ВСЕХ выходах без перехода (YUMI_INSTANT_OUTPUT=all,
    // YUMI_TRANSITION_SEC=0: переход рисуют сами окна, а yumi-wallpaper не ждёт долю перехода до перекраски).
    // Окна и снимки для «пружинки» собираются сразу по Enter (параллельно смене), после выхода yumi-wallpaper
    // (перекраска прошла) — только свежие цвета рамок и сразу пружинка на всех мониторах.
    property bool becoming: false            // 29.10: больше не используется («становление» и «пружинка» убраны по просьбе)
    // 29.10 (решение пользователя): по Enter виджет закрывается сразу, бар остаётся на месте, обои сменяются плавным
    // растворением awww одновременно на ВСЕХ мониторах, цвета бара и меню перетекают сами (ColorAnimation в Colors-потребителях).
    // Прежнее «становится картиной» + «пружинка» окон и бара — в истории git (до 9f8c202 включительно).
    function apply(v) {
        if (!v) return
        if (v.path === current) { close(); return }
        current = v.path
        const cmd = ["env", "YUMI_TRANSITION_SEC=0.6", "YUMI_FLIP_AT=0.2", "YUMI_BEZ=.25,0,.25,1",   // 30.10: цвета — в начале растворения
                     home + "/.local/bin/yumi-wallpaper", "set", v.path, "fade"]
        if (dry) console.log("[dry-run] " + cmd.join(" "))
        else Quickshell.execDetached(cmd)    // отдельно от окна виджета: закрытие его не прерывает
        applied = true                       // бар вернётся, когда придут новые цвета (barBack)
        close()
    }
    // «Пружинка» (19.10, вместо «Свитка» — .bak-spring-20261019): обои поставлены и перекраска прошла — картина остаётся
    // как есть, а окна стола (снимки ScreencopyView поверх своих мест: размытый кусок обоев, прозрачность, скругление и
    // рамка как у Hyprland) и бар (Signals.desktopPop) появляются пружинкой — на каждом мониторе;
    // потом виджет и оверлеи пропадают мгновенно — под снимками уже настоящие окна на тех же местах
    property bool popping: false            // перекраска прошла, ждём снимки/цвета рамок
    property bool popGo: false              // пружинка идёт
    property bool popPrepared: false        // окна собраны (снимки создаются)
    property var popWins: []                // главный экран: [{tl, x, y, w, h, full, floating, special, hist, active, alpha}]
    property bool popSpecial: false         // открыт спецстол (шторка): под ним Hyprland затемняет на dim_special 0.3
    property var popPlan: ({})              // другие экраны: имя → {wins, special}
    property int popReady: 0                // сколько снимков главного экрана уже готово
    property var borderCols: ({ a1: "#f2e6e6e6", a2: "#f2a3a3a3", i1: "#cc454545", i2: "#cc1c1c1c" })
    readonly property int popStagger: 30
    readonly property int popDur: 460
    function hyprCol(s) { return "#" + s }     // Hyprland AARRGGBB → цвет QML #AARRGGBB
    // прозрачность окон — как в look.lua (active 0.75 / inactive 0.65 / fullscreen 1) и правилах rules.lua (override)
    readonly property var popAlphaByClass: ({})
    function collectWins(scr) {             // → {wins, special} для экрана scr
        const mon = scr ? Hyprland.monitorFor(scr) : null
        const ws = mon ? mon.activeWorkspace : null
        if (!mon || !ws) return { wins: [], special: false }
        const specId = w.specByMon[mon.name] || 0
        const res = []
        for (const t of Hyprland.toplevels.values) {
            // места и размеры — свежие из hyprctl (lastIpcObject у Quickshell отстаёт: окно «в 480,319» вместо 1602,40)
            const o = w.popClients[String(t.address).replace(/^0x/, "")]
            if (!o || !o.at || !o.size || o.hidden || !t.wayland || !o.workspace) continue
            const special = specId !== 0 && o.workspace.id === specId
            if (!special && o.workspace.id !== ws.id && !(o.pinned && o.monitor === mon.id)) continue
            // fullscreen: 1 — развёрнуто (рамка и скругление есть), 2 — во весь экран
            const full = (o.fullscreen || 0) >= 2, active = Hyprland.activeToplevel === t
            const alpha = full ? 1 : (w.popAlphaByClass[o.class] !== undefined ? w.popAlphaByClass[o.class] : (active ? 0.75 : 0.65))
            res.push({ tl: t.wayland, x: o.at[0] - mon.x, y: o.at[1] - mon.y, w: o.size[0], h: o.size[1], full: full,
                       floating: !!o.floating, special: special, hist: o.focusHistoryID || 0, active: active, alpha: alpha })
        }
        // порядок как на экране: стол (полноэкранное — одно поверх своих, плитка под плавающими, недавние выше),
        // над ним — спецстол
        const order = (a, b) => (a.full - b.full) || (a.floating - b.floating) || (b.hist - a.hist)
        let base = res.filter(r => !r.special).sort(order)
        const f = base.findIndex(r => r.full)
        if (f >= 0) base = base.slice(f)
        return { wins: base.concat(res.filter(r => r.special).sort(order)), special: specId !== 0 }
    }
    function preparePop() {                 // окна всех мониторов (по ответу stateProc, сразу после Enter)
        if (!becoming || popPrepared) return
        const m = collectWins(win.screen)
        popSpecial = m.special
        popWins = m.wins
        const plan = {}
        for (const sc of otherScreens) plan[sc.name] = sc === win.screen ? m : collectWins(sc)
        popPlan = plan
        popPrepared = true
        popTry()
    }
    function becomeDone() {                 // yumi-wallpaper закончил (перекраска прошла)
        if (!becoming || popping) return
        becomeGuard.stop(); popping = true
        borderProc.running = true           // цвета рамок — уже новые
        popWait.restart()
    }
    function popTry() {
        if (!popping || popGo || !popPrepared || borderProc.running) return
        if (popReady >= popWins.length) popStart()
    }
    function popStart() {
        if (popGo) return
        popWait.stop()
        if (!popPrepared) { popPrepared = true; popWins = [] }
        Signals.desktopPop(win.screen ? win.screen.name : "")
        for (const n in popPlan) if (!win.screen || n !== win.screen.name) Signals.desktopPop(n)
        popGo = true
        let most = popWins.length
        for (const n in popPlan) most = Math.max(most, popPlan[n].wins.length)
        popEnd.interval = popDur + popStagger * Math.max(0, most - 1) + 40
        popEnd.restart()
    }
    onPopReadyChanged: popTry()
    // снимки ещё не пришли — не ждать дольше 300 мс (окно без снимка просто появится в конце)
    Timer { id: popWait; interval: 300; onTriggered: w.popStart() }
    Timer { id: popEnd; onTriggered: w.close() }
    property var specByMon: ({})            // монитор → id открытого спецстола (0 — нет)
    property var popClients: ({})           // адрес окна без 0x → объект из hyprctl -j clients
    function readBorders(parts) {
        const cols = Object.assign({}, w.borderCols)
        for (const k of [0, 1]) {
            try {
                const g = (JSON.parse(parts[k]).gradient || "").split(" ").filter(x => /^[0-9a-f]{8}$/i.test(x))
                if (g.length) { cols[k === 0 ? "a1" : "i1"] = w.hyprCol(g[0]); cols[k === 0 ? "a2" : "i2"] = w.hyprCol(g[g.length - 1]) }
            } catch (e) {}
        }
        w.borderCols = cols
    }
    // одним вызовом: мониторы (спецстол), окна, цвета рамок (lastIpcObject монитора Quickshell не заполняет)
    Process {
        id: stateProc
        command: ["sh", "-c", "hyprctl -j monitors; echo '@@'; hyprctl -j clients; echo '@@'; " +
                  "hyprctl -j getoption general:col.active_border; echo '@@'; hyprctl -j getoption general:col.inactive_border"]
        stdout: StdioCollector {
            onStreamFinished: {
                const part = text.split("@@")
                try {
                    const m = {}
                    for (const x of JSON.parse(part[0])) m[x.name] = x.specialWorkspace ? x.specialWorkspace.id : 0
                    w.specByMon = m
                    const c = {}
                    for (const x of JSON.parse(part[1])) c[String(x.address).replace(/^0x/, "")] = x
                    w.popClients = c
                } catch (e) { w.popClients = {} }
                w.readBorders([part[2], part[3]])
                w.preparePop()
            }
        }
    }
    // после перекраски — только цвета рамок (они новые), ~10 мс
    Process {
        id: borderProc
        command: ["sh", "-c", "hyprctl -j getoption general:col.active_border; echo '@@'; hyprctl -j getoption general:col.inactive_border"]
        stdout: StdioCollector { onStreamFinished: w.readBorders(text.split("@@")) }
        onExited: w.popTry()
    }
    Process { id: setter; onExited: w.becomeDone() }
    Timer { id: becomeSim; interval: 300; onTriggered: w.becomeDone() }    // dry-run: как будто обои поставлены (prepare+commit ≈ 0,3 с)
    Timer { id: becomeGuard; interval: 5000; onTriggered: w.becomeDone() } // страховка: не держать экран дольше 5 с
    // другие мониторы, на которых «становление» рисует свой оверлей. YUMI_QS_SCREEN (проверка на одном экране) — без
    // них (на другой монитор окна не выводить); YUMI_WALL_SIM_SECOND=1 — имитация: оверлей «второго экрана» на этом же
    readonly property var otherScreens: {
        if (!becoming || !win.screen) return []
        if (Quickshell.env("YUMI_WALL_SIM_SECOND") === "1") return [win.screen]
        if (Quickshell.env("YUMI_QS_SCREEN")) return []
        return Quickshell.screens.filter(sc => sc.name !== win.screen.name)
    }
    Variants {
        model: w.otherScreens
        delegate: Component { SecondScreen {} }
    }
    function enterStyle() {
        if (!selStyle) return
        styleKey = selStyle.key
        refilter(selStyle.paths.indexOf(current) >= 0 ? current : "")
        level = "walls"
    }
    function toStyles() {
        styleView.jump(Math.max(0, styles.findIndex(s => s.key === styleKey)))
        level = "styles"
    }
    function view() { return level === "walls" ? wallView : styleView }
    function step(d) { if (becoming) return; const v = view(); if (v.count < 2) return; if (d > 0) v.incrementCurrentIndex(); else v.decrementCurrentIndex() }
    function activate() { if (level === "walls") apply(selWall); else enterStyle() }
    function close() { Menus.close("wallpaper") }

    // 30.10: бар и остров этого экрана уезжают на время выбора; Esc — сразу назад, применение — после перекраски
    property bool applied: false
    property string hidOn: ""
    function barBackNow() { barBack.stop(); if (Signals.wallHide === hidOn) Signals.wallHide = "" }
    Timer { id: barBack; interval: 1600; onTriggered: w.barBackNow() }                 // перекраска не пришла — не ждать дольше
    Timer { id: barBackSoon; interval: 140; onTriggered: w.barBackNow() }              // цвета пришли — дать им лечь
    Connections { target: Colors; function onDChanged() { if (barBack.running) barBackSoon.restart() } }
    onOpenChanged: {
        if (open) {
            applied = false; barBack.stop(); barBackSoon.stop()
            hidOn = Menus.screen ? Menus.screen.name : ""
            Signals.wallHide = hidOn
        } else if (applied) barBack.restart()
        else barBackNow()
        if (open) {
            becoming = false; popping = false; popGo = false; popWins = []; popPlan = ({}); popPrepared = false
            closer.stop()
            Hyprland.refreshToplevels()           // свежие места и размеры окон — для снимков «пружинки»
            lister.running = true
            if (walls.length) placeOnOpen()
        } else closer.restart()
    }
    Timer { id: closer; interval: w.becoming ? 80 : Theme.normal; onTriggered: { w.becoming = false; w.popping = false; w.popGo = false; w.popWins = []; w.popSpecial = false; w.popPlan = ({}); w.popPrepared = false } }

    IpcHandler {
        target: "wallpaper"
        function left(): void { w.step(-1) }
        function right(): void { w.step(1) }
        function up(): void { if (w.level === "walls") w.toStyles() }
        function down(): void { if (w.level === "styles") w.enterStyle() }
        function enter(): void { w.activate() }
        function state(): string {
            return JSON.stringify({ open: w.open, level: w.level, style: w.styleKey, wall: w.selWall ? w.selWall.name : "",
                                    styleSel: w.selStyle ? w.selStyle.label : "", acc: String(w.fAcc), colors: Object.keys(w.acc).length })
        }
    }

    // ---- для вида W2 ----
    // полноэкранная картинка: уменьшенная копия 1920×1080 из кэша (как у прежней большой карточки), иначе оригинал
    function bigOf(path) { const x = walls.find(v => v.path === path); return x ? (x.big || x.path) : path }
    readonly property int styleIdx: Math.max(0, styles.findIndex(s => s.key === styleKey))

    // ---- окно ----
    PanelWindow {
        id: win
        screen: Menus.screen
        visible: w.open || closer.running
        color: "transparent"
        WlrLayershell.namespace: "yumi-wall-w2"      // 19.10: без размытия (правило yumi_wall_fade в rules.lua) — иначе «моргание» при смене
        // 30.10: окно снова на весь экран (полоса под баром мелькала); бар на это время уезжает вверх (Signals.wallHide)
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: w.open && Quickshell.env("YUMI_QS_NOKB") !== "1" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None   // YUMI_QS_NOKB=1 — проверка без захвата клавиатуры
        anchors { top: true; bottom: true; left: true; right: true }

        readonly property real dpr: screen ? screen.devicePixelRatio : 1
        // масштаб от экрана 1920×1080 (eDP-1 в логических пикселях 1600×1000 — чуть мельче)
        readonly property real k: Math.max(0.8, Math.min(width / 1920, height / 1080))
        function px(n) { return Math.round(n * k) }
        readonly property real mX: Math.round(width * 0.05)            // поля слева/справа, как у «Свитка»
        readonly property real thumbW: 150                            // «Остров»: как превью — 150×94, выбранная 230×144
        readonly property real thumbH: 94
        readonly property real selW: 230
        readonly property real selH: 144
        readonly property real gap: 14
        readonly property real pad: 4                                  // запас карусели сверху/снизу под кромку выбранной

        FocusScope {
            id: scope
            anchors.fill: parent
            focus: w.open
            opacity: w.open ? 1 : 0
            // растворение превью после «становления» — медленнее обычного закрытия (картина уже под ним)
            Behavior on opacity { NumberAnimation { duration: w.open ? Theme.normal : (w.becoming ? 0 : Theme.fast); easing.type: Easing.OutCubic } }
            Keys.onPressed: (e) => {
                if (w.becoming) { e.accepted = true; return }
                const k = e.key
                if (k === Qt.Key_Left) w.step(-1)
                else if (k === Qt.Key_Right) w.step(1)
                else if (k === Qt.Key_Up) { if (w.level === "walls") w.toStyles() }
                else if (k === Qt.Key_Down) { if (w.level === "styles") w.enterStyle() }
                else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) w.activate()
                else if (k === Qt.Key_Escape) w.close()
                else return
                e.accepted = true
            }

            // ---- фон: выбранные обои на весь экран, смена — кроссфейд 250 мс ----
            // «пружинка»: полоса бара открыта (обои под ней те же) — бар этого экрана выезжает сам (bar/Bar.qml)
            Item {
                id: bgClip
                width: parent.width
                y: w.popGo ? Theme.devLevel * Theme.barH + Theme.barH : 0
                height: parent.height - y
                clip: true
            Rectangle { y: -bgClip.y; width: win.width; height: win.height; color: Colors.deep }
            Item {
                id: bg
                y: -bgClip.y
                width: win.width; height: win.height
                // 19.10: копия ровно под экран (та же, что ставит awww: scaled/<sha>-ШxВ.jpg) — при «становлении» пиксели
                // совпадают и растворение не видно; нет такой копии — 1920×1080 (fallback)
                readonly property string fallbackUrl: w.open || closer.running ? w.fileUrl(w.bigOf(w.focusPath)) : ""
                readonly property string wantUrl: fallbackUrl.replace(/-\d+x\d+\.jpg$/, "-" + Math.round(win.width * win.dpr) + "x" + Math.round(win.height * win.dpr) + ".jpg")
                property bool frontA: true
                function settle(im) {
                    const s = im.source.toString()
                    if (im.status === Image.Ready && (s === wantUrl || s === fallbackUrl) && (im === imA) !== frontA) frontA = im === imA
                }
                function load() {
                    const front = frontA ? imA : imB, back = frontA ? imB : imA
                    if (!wantUrl || front.source.toString() === wantUrl || (front.source.toString() === fallbackUrl && front.status === Image.Ready && back.source.toString() === wantUrl)) return
                    back.source = wantUrl
                    settle(back)
                }
                onWantUrlChanged: load()
                Image {
                    id: imA
                    width: win.width; height: win.height
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true; cache: false
                    sourceSize.width: Math.min(2560, Math.round(win.width * win.dpr))
                    opacity: bg.frontA ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    onStatusChanged: { if (status === Image.Error && source.toString() !== bg.fallbackUrl) source = bg.fallbackUrl; else bg.settle(imA) }
                }
                Image {
                    id: imB
                    width: win.width; height: win.height
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true; cache: false
                    sourceSize.width: Math.min(2560, Math.round(win.width * win.dpr))
                    opacity: bg.frontA ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    onStatusChanged: { if (status === Image.Error && source.toString() !== bg.fallbackUrl) source = bg.fallbackUrl; else bg.settle(imB) }
                }
                // мягкий градиент к низу (как «Свиток»: верх почти чистый, низ темнее — под подписи и ленту)
                Rectangle {
                    width: win.width; height: win.height
                    opacity: w.becoming ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    gradient: Gradient {
                        GradientStop { position: 0.0;  color: Qt.rgba(0.03, 0.03, 0.04, 0.10) }
                        GradientStop { position: 0.5;  color: Qt.rgba(0.03, 0.03, 0.04, 0.12) }
                        GradientStop { position: 0.7;  color: Qt.rgba(0.03, 0.03, 0.04, 0.4) }
                        GradientStop { position: 1.0;  color: Qt.rgba(0.03, 0.03, 0.04, 0.86) }
                    }
                }
                // щелчок мимо ленты — закрыть (как прежде по затемнению)
                MouseArea { width: win.width; height: win.height; acceptedButtons: Qt.AllButtons; onClicked: if (!w.becoming) w.close() }
            }
            }

            // затемнение под спецстолом (dim_special 0.3) — проявляется вместе с пружинкой; полосу бара не трогает
            Rectangle {
                z: 1
                y: bgClip.y; width: parent.width; height: parent.height - y
                color: "black"
                opacity: w.popGo && w.popSpecial ? 0.3 : 0
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }
            // ---- «пружинка»: снимки окон стола на своих местах (19.10) ----
            // под снимком — кусок картины с размытием как у Hyprland (size 3, passes 2, contrast 0.89, vibrancy 0.17;
            // xray — размыты только обои), сверху окно с прозрачностью 0.75/0.65, скругление 10 и рамка 2 px градиентом
            Repeater {
                model: w.popWins
                delegate: PopWin { srcItem: bg; counts: true }
            }

            // колесо — листать (не чаще раза в 120 мс, тачпад шлёт много мелких событий)
            WheelHandler {
                property real acc: 0
                property double last: 0
                onWheel: (ev) => {
                    acc += ev.angleDelta.y + ev.angleDelta.x
                    const now = Date.now()
                    if (Math.abs(acc) >= 60 && now - last > 120) { w.step(acc < 0 ? 1 : -1); acc = 0; last = now }
                }
            }

            // ---- «Остров» (29.10): снизу карточка-остров — шапка, карусель (выбранная крупнее, кромка акцентом обоев,
            // пружина), подсказки, палитра и акцент. Фон — выбранные обои на весь экран (как прежде) ----
            Rectangle {
                id: low
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(1180, parent.width - 40)
                height: lowCol.implicitHeight + 36
                y: parent.height - height - Math.round(parent.height * 0.05)
                radius: Theme.radiusBig
                color: Colors.isl
                border.width: 1; border.color: Colors.edge
                Behavior on color { ColorAnimation { duration: Theme.normal } }
                // проявление — как у Popup: за первую треть роста. «Становление» гасит отдельным fade (300 мс).
                // НЕ ставить Behavior на opacity: он перезапускался на каждом кадре роста → заминка ~60 мс при открытии
                property real fade: w.becoming ? 0 : 1
                Behavior on fade { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                opacity: fade * Math.min(1, grow * 3)
                property real grow: w.open ? 1 : 0
                Behavior on grow { NumberAnimation { duration: w.open ? Theme.menuOpen : Theme.fast
                                                     easing.type: w.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.15 } }
                transform: Scale { origin.x: low.width / 2; origin.y: low.height
                                   xScale: 0.92 + 0.08 * low.grow; yScale: 0.85 + 0.15 * low.grow }
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }   // клики по карточке не закрывают

                ColumnLayout {
                    id: lowCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
                    spacing: 12

                    CardHead {
                        title: w.level === "walls" ? (w.selWall ? w.selWall.name.replace(/_/g, " ") : "Обои")
                                                   : (w.selStyle ? w.selStyle.label : "Стили")
                        dry: w.dry
                        status: {
                            if (w.level === "walls") {
                                const s = w.label(w.styleKey === "*" ? "Все обои" : w.styleKey)
                                return "Обои · " + s + " · " + (wallView.currentIndex + 1) + " из " + w.shown.length
                                       + (w.selWall && w.selWall.path === w.current ? " · сейчас" : "")
                                       + " · цвета системы берутся из картинки"
                            }
                            return "Стили · " + (styleView.currentIndex + 1) + " из " + w.styles.length
                                   + (w.selStyle ? " · " + w.selStyle.n + " обоев" : "")
                        }
                        // палитра выбранных обоев и акцент
                        Row {
                            spacing: 4
                            Repeater {
                                model: w.tonesOf(w.focusPath)
                                Rectangle {
                                    required property string modelData
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 14; height: 14; radius: 5; color: modelData
                                    border.width: 1; border.color: Colors.edge
                                    Behavior on color { ColorAnimation { duration: Theme.normal } }
                                }
                            }
                        }
                        Rectangle {
                            implicitWidth: accT.implicitWidth + 34; implicitHeight: 26; radius: 13
                            color: Colors.isl2
                            Rectangle { x: 6; anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14; radius: 7; color: w.fAcc
                                        Behavior on color { ColorAnimation { duration: Theme.normal } } }
                            Text { id: accT; x: 26; anchors.verticalCenter: parent.verticalCenter; text: String(w.fAcc).toUpperCase()
                                   font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim; font.features: ({ "tnum": 1 }) }
                        }
                    }

                    // карусели: обои стиля / стили
                    Item {
                        id: strips
                        Layout.fillWidth: true
                        implicitHeight: win.selH + 2 * win.pad

                        Strip {
                            id: wallView
                            model: w.shown
                            shown: w.level === "walls"
                            delegate: Thumb {
                                required property var modelData
                                required property int index
                                strip: wallView
                                src: seen ? w.fileUrl(modelData.thumb || modelData.path) : ""
                                caption: modelData.name.replace(/_/g, " ")
                                now: modelData.path === w.current
                                property bool seen: false
                                readonly property bool near: Math.abs(index - wallView.currentIndex) < 24
                                onNearChanged: if (near) seen = true
                                Component.onCompleted: if (near) seen = true
                                onTapped: { if (index === wallView.currentIndex) w.apply(modelData); else wallView.currentIndex = index }
                            }
                        }
                        Strip {
                            id: styleView
                            model: w.styles
                            shown: w.level === "styles"
                            delegate: Thumb {
                                required property var modelData
                                required property int index
                                strip: styleView
                                src: w.fileUrl(modelData.cover)
                                caption: modelData.label
                                badge: String(modelData.n)
                                now: modelData.paths.indexOf(w.current) >= 0 && modelData.key !== "*"
                                onTapped: { if (index === styleView.currentIndex) w.enterStyle(); else styleView.currentIndex = index }
                            }
                        }
                    }

                    CardHints {
                        items: w.level === "walls" ? [["←→", "обои"], ["↑↓", "стиль"], ["Enter", "поставить"], ["Esc", "закрыть"]]
                                                   : [["←→", "стиль"], ["↓ Enter", "открыть стиль"], ["Esc", "закрыть"]]
                        note: w.dry ? "проверка: обои не меняются" : ""
                    }
                }
            }
        }
    }

    // ---- части ----
    // Карусель: выбранная — по центру и крупнее (пружина), соседи меньше и бледнее; листание — пружина OutBack.
    // Держит currentIndex — его же читает логика выше (count, currentIndex, increment/decrementCurrentIndex по кругу, jump).
    component Strip: Item {
        id: st
        property var model: []
        property Component delegate: null
        property bool shown: false
        property int currentIndex: 0
        property bool instant: false
        readonly property int count: model ? model.length : 0
        readonly property real stepW: win.thumbW + win.gap
        function incrementCurrentIndex() { if (count) currentIndex = (currentIndex + 1) % count }
        function decrementCurrentIndex() { if (count) currentIndex = (currentIndex - 1 + count) % count }
        function jump(i) { instant = true; currentIndex = i; place(); Qt.callLater(() => st.instant = false) }
        // положение ленты — императивно: привязка contentX рвалась, когда ListView сам сбрасывал его при смене
        // модели (вход в стиль) — лента оставалась у начала, а миниатюры вокруг выбранной не создавались до стрелки
        readonly property real targetX: Math.round(currentIndex * stepW + win.selW / 2 - width / 2)
        function place() {
            if (instant || !shown) { slide.stop(); row.contentX = targetX }
            else { slide.to = targetX; slide.restart() }
        }
        onTargetXChanged: place()
        onCountChanged: { slide.stop(); row.contentX = targetX; Qt.callLater(() => { row.contentX = st.targetX }) }
        onWidthChanged: { slide.stop(); row.contentX = targetX }
        NumberAnimation { id: slide; target: row; property: "contentX"; duration: 450; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        anchors.fill: parent
        clip: true
        opacity: shown ? 1 : 0
        enabled: shown
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
        transform: Translate { y: st.shown ? 0 : 10; Behavior on y { NumberAnimation { duration: 380; easing.type: Easing.OutBack } } }
        // (без маски-растворения краёв: постоянный layer на всю ленту дорог на M1 — край просто обрезается)
        // ленивая лента: ListView создаёт только видимые миниатюры (+ запас cacheBuffer); выбранная — по центру,
        // сдвиг — та же пружина OutBack через contentX (до выбранной — currentIndex обычных миниатюр, сама — selW)
        ListView {
            id: row
            anchors.fill: parent
            orientation: ListView.Horizontal
            interactive: false
            spacing: win.gap
            leftMargin: st.width; rightMargin: st.width
            cacheBuffer: Math.round(win.thumbW * 4)
            highlightRangeMode: ListView.NoHighlightRange
            reuseItems: false
            model: st.model
            delegate: st.delegate
            onCountChanged: Qt.callLater(() => { row.contentX = st.targetX })
        }
    }

    // миниатюра карусели: radius 16, обычная 150×94 (бледнее, 0.92), выбранная 230×144 с кромкой акцентом обоев и тенью
    component Thumb: Item {
        id: th
        property Item strip: null
        property string src: ""
        property string caption: ""
        property string badge: ""
        property bool now: false
        signal tapped()
        readonly property bool sel: strip && index === strip.currentIndex
        width: sel ? win.selW : win.thumbW
        height: parent ? parent.height : win.selH
        Behavior on width { enabled: !(th.strip && th.strip.instant); NumberAnimation { duration: 450; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
        // ленивая карусель (29.10): содержимое миниатюры создаётся только около выбранной (±7, видно ±4);
        // дальние — асинхронно, остальные — пустое место нужной ширины (раньше все ~80 строились сразу → заминка 150 мс)
        readonly property int dist: strip ? Math.abs(index - strip.currentIndex) : 0
        Loader {
            anchors.centerIn: parent             // без размера: иначе Loader растягивает миниатюру на всю высоту ленты
            active: th.dist <= 7 && (!th.strip || th.strip.visible)
            asynchronous: th.dist > 2
            sourceComponent: faceC
        }
        Component {
            id: faceC
        Item {
            id: face
            width: th.width; height: th.sel ? win.selH : win.thumbH
            Behavior on height { NumberAnimation { duration: 450; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
            opacity: th.sel ? 1 : (tma.containsMouse ? 0.9 : 0.6)
            Behavior on opacity { NumberAnimation { duration: 300 } }
            scale: tma.pressed ? 0.95 : 1
            Behavior on scale { NumberAnimation { duration: Theme.fast } }
            Rectangle {   // тень — только у выбранной; простой прямоугольник (RectangularShadow компилирует шейдер при первом открытии)
                visible: th.sel
                x: 4; y: 10; width: parent.width - 8; height: parent.height; radius: 16
                color: Qt.rgba(0, 0, 0, 0.35)
            }
            Rectangle {   // кромка акцентом (2 px снаружи)
                anchors.fill: parent; anchors.margins: -2; radius: 18
                color: w.fAcc
                opacity: th.sel ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 250 } }
                /* выбор — без затухания (29.10) */
            }
            // скругление — ClippingRectangle (без MultiEffect-маски на каждую миниатюру); картинка — уменьшенная миниатюра
            ClippingRectangle {
                anchors.fill: parent; radius: 16; color: Colors.isl2
                Image {
                    id: thImg
                    anchors.fill: parent
                    source: th.src
                    sourceSize.width: Math.round(win.selW * win.dpr)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                }
            }
            Rectangle {   // подпись: мягкая тень снизу
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: Math.min(parent.height, 40); radius: 16
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.55) }
                }
            }
            Text {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 10; rightMargin: 10; bottomMargin: 8 }
                text: th.caption; elide: Text.ElideRight
                font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.DemiBold; color: "white"
                style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.4)
            }
            Rectangle {   // «сейчас» — капсула акцентом
                visible: th.now
                x: 8; y: 8; width: nowT.implicitWidth + 14; height: 20; radius: 10
                color: Colors.acc
                Text { id: nowT; anchors.centerIn: parent; text: "сейчас"; font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.Medium; color: Colors.onAcc }
            }
            Rectangle {   // число обоев стиля
                visible: th.badge.length > 0 && !th.now
                anchors.right: parent.right; anchors.rightMargin: 8; y: 8
                width: Math.max(22, bT.implicitWidth + 12); height: 20; radius: 10
                color: Colors.isl
                Text { id: bT; anchors.centerIn: parent; text: th.badge; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim; font.features: ({ "tnum": 1 }) }
            }
        }
        }
        MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: th.tapped() }
    }

    // ---- «становление» на другом мониторе (29.10) ----
    // своё окно поверх стола этого монитора: новые обои вырастают из центра экрана (кривая и длительность — как у
    // карточки виджета: Theme.menuOpen, OutBack), скругление уходит к нулю; под окном awww уже ставит те же обои без
    // перехода. Потом — та же пружинка окон этого монитора и его бара (Signals.desktopPop), и окно пропадает вместе
    // с виджетом. Картинка — готовая копия под разрешение экрана (scaled/<sha>-ШxВ.jpg, её делает yumi-wallpaper scan),
    // нет копии — уменьшенная 1920×1080; загрузка асинхронная, рост начинается, когда картинка готова (не дольше 250 мс).
    // Ввод не перехватывает (пустая маска).
    component SecondScreen: PanelWindow {
        id: sw
        required property var modelData
        screen: modelData
        readonly property string sname: modelData ? modelData.name : ""
        readonly property var plan: w.popPlan[sname] || ({ wins: [], special: false })
        readonly property real dpr: screen ? screen.devicePixelRatio : 1
        visible: w.open
        color: "transparent"
        WlrLayershell.namespace: "yumi-wall-w2"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: true; right: true }
        mask: Region {}

        readonly property string fallbackUrl: w.fileUrl(w.bigOf(w.current))
        readonly property string wantUrl: fallbackUrl.replace(/-\d+x\d+\.jpg$/, "-" + Math.round(width * dpr) + "x" + Math.round(height * dpr) + ".jpg")
        property real grow: 0
        NumberAnimation { id: growAnim; target: sw; property: "grow"; from: 0; to: 1; duration: Theme.menuOpen
                          easing.type: Easing.OutBack; easing.overshoot: 1.05 }
        function startGrow() { if (!growAnim.running && sw.grow === 0) growAnim.start() }
        Timer { interval: 250; running: true; onTriggered: sw.startGrow() }

        Item {
            id: clipTop
            width: parent.width
            y: w.popGo ? Theme.devLevel * Theme.barH + Theme.barH : 0     // пружинка: полоса бара открывается
            height: parent.height - y
            clip: true
            Item {
                id: pic
                y: -clipTop.y
                width: sw.width; height: sw.height
                scale: 0.3 + 0.7 * sw.grow
                opacity: Math.min(1, sw.grow * 4)
                ClippingRectangle {
                    anchors.fill: parent
                    radius: 40 * Math.max(0, 1 - sw.grow)
                    color: Colors.deep
                    Image {
                        anchors.fill: parent
                        source: sw.wantUrl
                        sourceSize.width: Math.min(3840, Math.round(sw.width * sw.dpr))
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true; cache: false
                        onStatusChanged: {
                            if (status === Image.Error && source.toString() !== sw.fallbackUrl) source = sw.fallbackUrl
                            else if (status === Image.Ready) sw.startGrow()
                        }
                    }
                }
            }
        }
        Rectangle {    // затемнение под спецстолом, как на главном экране
            z: 1
            y: clipTop.y; width: parent.width; height: parent.height - y
            color: "black"
            opacity: w.popGo && sw.plan.special ? 0.3 : 0
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }
        Repeater {
            model: sw.plan.wins
            delegate: PopWin { srcItem: pic; counts: false }
        }
    }

    // ---- «пружинка»: снимок окна на своём месте ----
    // под снимком — кусок картины с размытием как у Hyprland (size 3, passes 2, contrast 0.89, vibrancy 0.17;
    // xray — размыты только обои), сверху окно с прозрачностью 0.75/0.65, скругление 10 и рамка 2 px градиентом
    component PopWin: Item {
        id: pw
        property Item srcItem: null           // откуда брать размытый кусок картины под окном
        property bool counts: true            // считать снимок в w.popReady (главный экран)
        required property var modelData
        required property int index
        readonly property real rad: modelData.full ? 0 : 10
        readonly property real bw: modelData.full ? 0 : 2
        x: modelData.x; y: modelData.y; width: modelData.w; height: modelData.h
        z: modelData.special ? 2 : 0          // спецстол — над затемнением, остальные — под ним
        opacity: 0; scale: 0.92
        transformOrigin: Item.Center
        visible: true                           // создаётся заранее (снимок готов к пружинке); до неё opacity 0 — не рисуется

        Item {
            id: body
            anchors.fill: parent
            layer.enabled: !pw.modelData.full
            layer.effect: MultiEffect {
                maskEnabled: true; maskSource: bodyMask
                maskThresholdMin: 0.5; maskSpreadAtMin: 1.0
            }
            ShaderEffectSource {
                id: slice
                visible: false
                sourceItem: pw.srcItem
                sourceRect: Qt.rect(pw.modelData.x - 16, pw.modelData.y - 16, pw.width + 32, pw.height + 32)
                width: pw.width + 32; height: pw.height + 32
                live: false
                // кусок картины — в момент пружинки (на втором экране картина к этому времени уже выросла)
                Connections { target: w; function onPopGoChanged() { if (w.popGo) slice.scheduleUpdate() } }
            }
            MultiEffect {
                visible: !pw.modelData.full
                x: -16; y: -16; width: slice.width; height: slice.height
                source: slice
                autoPaddingEnabled: false
                blurEnabled: true; blur: 0.75; blurMax: 16
                contrast: -0.11; saturation: 0.17
            }
            ScreencopyView {
                anchors.fill: parent
                captureSource: pw.modelData.tl
                live: false
                opacity: pw.modelData.alpha
                property bool counted: false
                onHasContentChanged: if (hasContent && !counted) { counted = true; if (pw.counts) w.popReady++ }
            }
        }
        Rectangle { id: bodyMask; anchors.fill: parent; radius: pw.rad; visible: false; layer.enabled: true }
        // рамка: снаружи окна, как у Hyprland (внешний радиус = скругление + толщина), градиент 45°
        Shape {
            visible: pw.bw > 0
            x: -pw.bw; y: -pw.bw; width: pw.width + 2 * pw.bw; height: pw.height + 2 * pw.bw
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillRule: ShapePath.OddEvenFill
                fillGradient: LinearGradient {
                    x1: 0; y1: 0; x2: pw.width + 2 * pw.bw; y2: pw.height + 2 * pw.bw
                    GradientStop { position: 0; color: pw.modelData.active ? w.borderCols.a1 : w.borderCols.i1 }
                    GradientStop { position: 1; color: pw.modelData.active ? w.borderCols.a2 : w.borderCols.i2 }
                }
                PathRectangle { x: 0; y: 0; width: pw.width + 2 * pw.bw; height: pw.height + 2 * pw.bw; radius: pw.rad + pw.bw }
                PathRectangle { x: pw.bw; y: pw.bw; width: pw.width; height: pw.height; radius: pw.rad }
            }
        }

        SequentialAnimation {
            running: w.popGo
            PauseAnimation { duration: pw.index * w.popStagger }
            ParallelAnimation {
                NumberAnimation { target: pw; property: "scale"; from: 0.92; to: 1; duration: w.popDur; easing.type: Easing.OutBack; easing.overshoot: 1.7 }
                NumberAnimation { target: pw; property: "opacity"; from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic }
            }
        }
    }
}
