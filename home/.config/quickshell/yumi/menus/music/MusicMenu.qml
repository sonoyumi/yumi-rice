import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.components
import qs.services
import qs.player

// «Музыка» — «Остров» (29.10): карточка-остров по центру. Сверху поиск; слева — обложка radius 28, название, ход песни
// (клик/перетаскивание — перемотка), кнопки; справа — сегменты Текст / Очередь / Плейлисты (ISeg) и панель: полки
// фишками (найденное в YouTube Music / SoundCloud, «Далее» — очередь mpv yumi-music, «Недавние»; «Плейлисты» и полка
// каждого плейлиста) с лентой обложек выбранной полки; текст песни (Ctrl+L) — слой поверх полок справа. Логика прежняя — бэкенд ~/.local/lib/yumi/qs/music.
// Клавиши: ←→ — внутри полки, ↑↓ — между полками, Enter — играть (плейлист — слушать с начала), Shift+Enter —
// добавить следующим (плейлист — перемешать и слушать). Печать — поиск: Enter ищет в YouTube Music, Shift+Enter —
// на SoundCloud, ссылка на плейлист + Enter — импорт. Пробел (поле пустое) — пауза, Ctrl+←/→ — трек назад/вперёд,
// Shift+←/→ — перемотка ±10 с (и клик/перетаскивание по полосе), Ctrl+↑/↓ — громкость, Ctrl+L — текст песни (слой поверх полок),
// Ctrl+A — добавить выбранный трек в плейлист (выбор плейлиста или «＋ Новый»), Del (поле пустое) на добавленном вручную —
// убрать из плейлиста (второе нажатие подтверждает), Ctrl+S — перемешать очередь, Ctrl+R — повтор, Ctrl+U — обновить
// плейлист, Ctrl+F — плеер во весь экран, Esc — закрыть выбор / очистить поиск / закрыть.
// Открыть: qs -c yumi ipc call menu center music (SUPER+SHIFT+M) · menu toggle music · music toggle [center]
// Проверка: YP_DRYRUN=1 (play/add/sync/import и команды mpv только печатаются); ipc: music view <lists|queue|recent|yt|sc|pl:ID>,
//   music search <текст>, music key <left|right|up|down|enter>, music state
Scope {
    id: menu
    readonly property bool open: Menus.current === "music"
    readonly property string home: Quickshell.env("HOME")
    readonly property int shelfH: 228
    readonly property int coverS: 124

    // ---- данные ----
    property bool dry: false
    property var lib: []                   // [{id, name, short, src, count, keys, first}]
    property var pls: ({})                 // id → {items, sub, short}
    property var queue: []
    property int curIdx: -1
    property string queueFrom: ""
    property var recent: []
    property var results: ({ yt: null, sc: null })
    property string lastQ: ""
    property var now: ({ has: false })
    property real nowAt: 0
    property real pos: 0
    property string toastText: ""
    property bool toastError: false
    property bool lyricsOn: false
    property var sheetTrack: null          // «Добавить в плейлист»: трек
    property int sheetSel: 0
    property string rmArm: ""              // Del нажат один раз на этом треке — второй убирает

    // полки и выбор
    property var shelves: []               // [{id, title, kind, pid?, items}]
    property string shelfSig: ""
    property int row: 0
    property var cols: ({})                // id полки → выбранный номер
    property int colRev: 0
    function colOf(id, rev) { return cols[id] || 0 }
    readonly property var curShelf: shelves.length ? shelves[Math.max(0, Math.min(shelves.length - 1, row))] : null
    readonly property var curItem: curShelf && curShelf.items.length ? curShelf.items[Math.min(curShelf.items.length - 1, colOf(curShelf.id, colRev))] : null

    function toast(text, hold, error) { toastText = text; toastError = !!error; toastTimer.interval = Math.round((hold || 2) * 1000); toastTimer.restart() }
    Timer { id: toastTimer; onTriggered: menu.toastText = "" }

    // ---- обложки (как в прежнем меню: путь уменьшенной копии; запрос бэкенду один раз, ответы пачкой) ----
    property var covers: ({})
    property var asked: ({})
    property int covRev: 0
    function coverPath(key, px, rev) {
        const k = px + "|" + key
        const p = covers[k]
        if (p) return p
        if (!asked[k]) { asked[k] = true; send({ cmd: "cover", key: key, px: px }) }
        return ""
    }
    Timer { id: covBatch; interval: 40; onTriggered: menu.covRev++ }
    function keyOf(it) { return !it ? "" : (it.keys ? (it.keys[0] || it.first || "") : (it.key || "")) }

    // что показывать «сейчас»: пока бэкенд yumi-music не ответил (запуск python ~1–2 с), — сразу из Player (Mpris /
    // last.json), чтобы с первого кадра были название, исполнитель и обложка; «Ничего не играет» — только если через 1 с
    // правда ничего нет
    // 29.10: тот же трек и то же время, что в острове бара — источник Player (Mpris), позиция — общая Player.posSec;
    // бэкенд `now` — только если Player ничего не знает (перемотка, очередь, команды — по-прежнему через бэкенд)
    readonly property bool useP: Player.shown
    readonly property bool dHas: useP || now.has
    readonly property string dTitle: useP ? Player.title : (now.title || "")
    readonly property string dArtist: useP ? Player.artist : (now.artist || "")
    readonly property bool dPlaying: useP ? Player.playing : !!now.playing
    readonly property real dDur: useP ? Player.length : (now.dur || 0)
    property bool settled: false
    property bool posHeld: false            // меню держит общий такт позиции Player (posUsers)
    Timer { id: settleT; interval: 1000; onTriggered: menu.settled = true }
    Timer { interval: 500; running: menu.open && !menu.useP && menu.now.has; repeat: true; triggeredOnStart: true
            onTriggered: menu.pos = Math.floor(Math.min(menu.now.dur || 0, (menu.now.pos || 0) + (menu.now.playing ? (Date.now() - menu.nowAt) / 1000 : 0))) }
    Connections { target: Player; enabled: menu.open && menu.useP
                  function onPosSecChanged() { if (!pa.pressed) menu.pos = Player.posSec } }

    // ---- полки ----
    function rebuild() {
        const keep = curShelf ? curShelf.id : ""
        const out = []
        const srcName = { yt: "YouTube Music", sc: "SoundCloud" }
        for (const s of ["yt", "sc"]) {
            const r = results[s]
            if (r) out.push({ id: s, title: "󰍉  " + srcName[s] + (lastQ ? " · «" + lastQ + "»" : ""), kind: s,
                              tab: srcName[s] + (lastQ ? " · «" + lastQ + "»" : ""),
                              items: r, empty: "Ничего не найдено" })
        }
        const next = curIdx >= 0 ? queue.slice(curIdx + 1, curIdx + 41) : queue.slice(0, 40)
        if (next.length) out.push({ id: "next", title: "󰲹  Далее" + (queueFrom ? " · из «" + queueFrom + "»" : ""), tab: "Далее", kind: "queue", items: next })
        if (recent.length) out.push({ id: "recent", title: "󰋚  Недавние", tab: "Недавние", kind: "recent", items: recent.slice(0, 40) })
        if (lib.length) out.push({ id: "lists", title: "󰲸  Плейлисты", tab: "Плейлисты · " + lib.length, kind: "lists", items: lib })
        for (const p of lib) {
            const d = pls[p.id]
            out.push({ id: "pl:" + p.id, pid: p.id, tab: p.short, title: "󰲸  " + p.short + "  ·  " + p.src + (d ? "  ·  " + d.sub : ""),
                       kind: "pl", items: d ? d.items : [] })
        }
        // 29.10: полки не пересоздавать, если ничего не изменилось — при каждом открытии бэкенд заново шлёт lib/queue/
        // recent, и замена массива пересоздавала все фишки и ленту обложек (кадр ~30 мс через ~1 с после открытия)
        const sig = JSON.stringify(out.map(x => [x.id, x.title, x.items.length,
                                                 x.items.length ? (x.items[0].key || x.items[0].id || x.items[0].url || "") : "",
                                                 x.items.length ? (x.items[x.items.length - 1].key || x.items[x.items.length - 1].id || "") : ""]))
        if (sig === shelfSig) return
        shelfSig = sig
        shelves = out
        const i = keep ? out.findIndex(s => s.id === keep) : -1
        row = i >= 0 ? i : Math.min(row, Math.max(0, out.length - 1))
    }
    Timer { id: rebuildLater; interval: 30; onTriggered: menu.rebuild() }

    function moveRow(d) { if (!shelves.length) return; row = Math.max(0, Math.min(shelves.length - 1, row + d)) }
    function moveCol(d) {
        const s = curShelf
        if (!s || !s.items.length) return
        const c = cols; c[s.id] = Math.max(0, Math.min(s.items.length - 1, colOf(s.id) + d)); cols = c; colRev++
    }
    // сегменты: 0 — слой текста песни (как Ctrl+L), 1 — «Очередь» (найденное, Далее, Недавние), 2 — «Плейлисты»;
    // 1 и 2 переключают группу полок и закрывают слой текста
    function groupOf(sh) { return sh && (sh.kind === "lists" || sh.kind === "pl") ? 2 : 1 }
    readonly property int seg: lyricsOn ? 0 : groupOf(curShelf)
    function pickSeg(i) {
        if (i === 0) { lyricsOn = !lyricsOn; return }
        lyricsOn = false
        if (groupOf(curShelf) === i) return
        let j = -1
        if (i === 1) { j = shelves.findIndex(x => x.id === "next"); if (j < 0) j = shelves.findIndex(x => groupOf(x) === 1) }
        else j = shelves.findIndex(x => x.kind === "lists")
        if (j >= 0) row = j
    }
    function pick(rowI, colI) { row = rowI; const s = shelves[rowI]; if (s) { const c = cols; c[s.id] = colI; cols = c; colRev++ } }

    // ---- действия ----
    function activate(alt) {
        const s = curShelf, t = curItem
        if (!s || !t) return
        if (s.kind === "lists") { send({ cmd: "play", id: t.id, shuffle: !!alt }); toast((alt ? "Перемешиваю: " : "Слушаю: ") + t.short); return }
        if (alt) {
            const target = s.kind === "pl" ? (t.url || t.id) : s.kind === "recent" || s.kind === "queue" ? t.url : t.target
            if (s.kind !== "queue") { send({ cmd: "add", target: target, now: false }); toast("Следующим: " + (t.title || "")) }
            return
        }
        if (s.kind === "pl") send({ cmd: "play", id: s.pid, n: t.n })
        else if (s.kind === "queue") send({ cmd: "index", n: t.i })
        else if (s.kind === "recent") send({ cmd: "add", target: t.url, now: true })
        else send({ cmd: "add", target: t.target, now: true })
        toast("Играет: " + (t.title || ""))
    }
    function search(alt) {
        const text = field.text.trim()
        if (!text) return false
        if (/(list=|soundcloud\.com\/.+\/sets\/|^https?:\/\/)/.test(text)) { send({ cmd: "import", text: text }); return true }
        const src = alt ? "sc" : "yt"
        lastQ = text
        const r = Object.assign({}, results); r[src] = null; results = r
        send({ cmd: "search", src: src, text: text })
        toast("Ищу на " + (alt ? "SoundCloud" : "YouTube Music") + "…", 4)
        return true
    }
    function seek(d) { if (now.has && now.dur) { const t = Math.max(0, Math.min(now.dur - 1, pos + d)); pos = Math.floor(t); now.pos = t; nowAt = Date.now(); send({ cmd: "seek", t: t }); seekPoll.restart() } }
    // после перемотки (через бэкенд) — сразу перечитать позицию MPRIS, чтобы общее время не откатывалось на полсекунды
    Timer { id: seekPoll; interval: 200; onTriggered: { Player.poll(); Player.posUpdate() } }
    function trackOf(it) { return it ? (it.track || null) : null }
    function openSheet(t) { if (!t) { toast("Выберите трек"); return } sheetTrack = t; sheetSel = 0; sheetField.text = ""; sheetField.forceActiveFocus() }
    function closeSheet() { sheetTrack = null; sheetField.focus = false; field.forceActiveFocus() }
    function sheetAdd() {
        const n = sheetField.text.trim()
        if (n) send({ cmd: "pl-new", name: n, track: sheetTrack })
        else if (lib[sheetSel]) send({ cmd: "pl-add", pid: lib[sheetSel].id, track: sheetTrack })
        closeSheet()
    }
    readonly property string curPid: curShelf ? (curShelf.kind === "pl" ? curShelf.pid : (curShelf.kind === "lists" && curItem ? curItem.id : "")) : ""
    function syncCur() { if (curPid) { send({ cmd: "sync", id: curPid }); toast("Обновляю плейлист…") } else toast("Выберите плейлист") }
    function removeCur() {
        const s = curShelf, t = curItem
        if (!s || s.kind !== "pl" || !t || !t.rm) { toast("Убрать можно только трек, добавленный вручную"); return }
        if (rmArm !== t.key) { rmArm = t.key; rmTimer.restart(); toast("Ещё раз Del — убрать «" + (t.title || "") + "» из плейлиста", 2.5); return }
        rmArm = ""; send({ cmd: "pl-remove", pid: s.pid, key: t.key })
    }
    Timer { id: rmTimer; interval: 2500; onTriggered: menu.rmArm = "" }
    function fmt(x) { x = Math.floor(x || 0); return x > 0 ? Math.floor(x / 60) + ":" + String(x % 60).padStart(2, "0") : "-:--" }
    function full() { Quickshell.execDetached(["qs", "-c", "yumi", "ipc", "call", "player", "full"]); close() }
    // громкость — как в полноэкранном плеере: поток плеера в PipeWire через Player.setVolume, шаги копятся от последнего
    // заданного значения (16.10: от now.vol бэкенда быстрые Ctrl+↑/↓ брали устаревшее число и застревали)
    property real volWant: -1
    Timer { id: volKeep; interval: 700; onTriggered: menu.volWant = -1 }
    function vol(d) {
        const base = volWant >= 0 ? volWant : Player.volume
        volWant = Math.max(0, Math.min(1, base + d / 100))
        Player.setVolume(volWant); volKeep.restart()
    }

    // ---- бэкенд ----
    function send(obj) { if (proc.running) proc.write(JSON.stringify(obj) + "\n") }
    function apply(line) {
        let j
        try { j = JSON.parse(line) } catch (e) { console.log("music: не JSON:", line); return }
        switch (j.type) {
        case "hello": dry = j.dry; if (open && fetchLater.running) break   // при открытии — запросит fetchLater после роста
                      send({ cmd: "lib" }); send({ cmd: "queue" }); send({ cmd: "recent" }); if (open) send({ cmd: "watch", on: true }); break
        case "lib":
            lib = j.playlists
            for (const p of lib) if (!pls[p.id]) send({ cmd: "tracks", id: p.id })
            rebuildLater.restart()
            break
        case "tracks":
            if (j.missing) break
            { const m = Object.assign({}, pls); m[j.id] = { items: j.items, sub: j.sub, short: j.short }; pls = m }
            rebuildLater.restart()
            break
        case "mqueue": queueAt = Date.now(); queue = j.items; curIdx = j.cur; queueFrom = j.from || ""; rebuildLater.restart(); break
        case "recent": recent = j.items; rebuildLater.restart(); break
        case "results": {
            const r = Object.assign({}, results); r[j.src] = j.items === null ? r[j.src] : j.items; results = r
            if (j.items !== null) { toastText = ""; rebuild(); const i = shelves.findIndex(s => s.id === j.src); if (i >= 0) pick(i, 0) }
            break
        }
        case "imported": field.text = ""; break
        case "now": {
            if (pa.pressed) break
            const oldCur = now.cur
            now = j; nowAt = Date.now(); if (!useP) pos = Math.floor(j.pos || 0)
            if (j.cur !== undefined && j.cur >= 0 && j.cur !== oldCur) { curIdx = j.cur; rebuildLater.restart() }
            break
        }
        case "cover": covers[j.px + "|" + j.key] = j.path; covBatch.restart(); break
        case "toast": toast(j.text, j.hold, j.error); break
        case "changed-pl": send({ cmd: "tracks", id: j.id }); break
        }
    }
    Process {
        id: proc
        command: ["python3", "-I", menu.home + "/.local/lib/yumi/qs/music"]
        running: menu.open || grace.running
        stdinEnabled: true
        stdout: SplitParser { onRead: line => menu.apply(line) }
        stderr: SplitParser { onRead: line => { if (line.trim()) console.log("music:", line) } }
        onExited: { menu.asked = ({}) }
    }
    Timer { id: grace; interval: 90000 }
    // 29.10 (плавность): бэкенд шлёт строки по 160–330 КБ (очередь, треки плейлистов) — JSON.parse 4–13 мс каждая
    // и пересборка полок шли прямо во время роста карточки (кадры 30–45 мс). Запросы — после роста; данные с прошлого
    // открытия остаются на экране. Один раз через 15 с после старта оболочки — подгрузка заранее (бэкенд потом сам
    // выходит через 90 с), чтобы и первое открытие было сразу с полками.
    Timer { id: fetchLater; interval: Theme.menuOpen + 60
            onTriggered: if (menu.open) {
                menu.send({ cmd: "watch", on: true }); menu.send({ cmd: "lib" }); menu.send({ cmd: "recent" })
                // очередь (~280 КБ, разбор ~10 мс) — только если старше минуты: сдвиг текущего трека приходит в `now`,
                // а при смене трека, пока меню открыто, бэкенд присылает очередь сам
                if (Date.now() - menu.queueAt > 60000) menu.send({ cmd: "queue" })
            } }
    property real queueAt: 0
    Timer { interval: 15000; running: true; onTriggered: if (!menu.open && !proc.running) grace.restart() }     // после закрытия бэкенд живёт ещё 90 с — повторное открытие мгновенное

    onOpenChanged: {
        if (open) {
            grace.stop(); closer.stop(); settled = false; settleT.restart(); fetchLater.restart()
            if (!posHeld) { posHeld = true; Player.posUsers++ } Player.posUpdate(); if (useP) pos = Player.posSec
            // открыть на «Далее», если играет очередь, иначе на первой полке
            const i = shelves.findIndex(s => s.id === "next")
            row = i >= 0 ? i : 0
            Qt.callLater(() => { Player.watching = true })          // позиция для текста песни (LyricsPane)
            field.forceActiveFocus()
        } else {
            field.focus = false; sheetField.focus = false; sheetTrack = null
            if (Menus.current !== "player") Player.watching = false
            send({ cmd: "watch", on: false })
            toastText = ""; field.text = ""; settleT.stop()
            if (posHeld) { posHeld = false; Player.posUsers = Math.max(0, Player.posUsers - 1) }
            grace.restart(); closer.restart()
        }
    }
    Timer { id: closer; interval: Theme.normal }
    function close() { field.focus = false; sheetField.focus = false; Menus.close("music") }

    IpcHandler {
        target: "music"
        function toggle(mode: string): void { if (mode === "center") Menus.toggleCenter("music"); else Menus.toggle("music") }
        function view(v: string): void {
            const id = v === "queue" ? "next" : v
            const i = menu.shelves.findIndex(s => s.id === id)
            if (i >= 0) menu.row = i
        }
        function search(text: string): void { field.text = text; menu.search(false) }
        function sheet(): void { const s = menu.curShelf; menu.openSheet(menu.trackOf(s && s.kind !== "lists" ? menu.curItem : (s && s.items.length ? s.items[0] : null))) }
        function lyrics(): void { menu.lyricsOn = !menu.lyricsOn }
        function key(name: string): void {
            if (name === "left") menu.moveCol(-1); else if (name === "right") menu.moveCol(1)
            else if (name === "up") menu.moveRow(-1); else if (name === "down") menu.moveRow(1)
            else if (name === "enter") menu.activate(false)
        }
        function state(): string {
            return JSON.stringify({ open: menu.open, shelves: menu.shelves.map(s => s.id + ":" + s.items.length), row: menu.curShelf ? menu.curShelf.id : "",
                                    item: menu.curItem ? (menu.curItem.title || menu.curItem.short || "") : "", now: menu.now.has ? menu.now.title : "" })
        }
    }

    // ---- окно: «Остров» (29.10) — карточка-остров по центру экрана (как превью «Музыка») ----
    PanelWindow {
        id: win
        screen: Menus.screen
        visible: menu.open || closer.running
        color: "transparent"
        WlrLayershell.namespace: "yumi-qs-music"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        // YUMI_QS_NOKB=1 — проверка без захвата клавиатуры
        WlrLayershell.keyboardFocus: menu.open && Quickshell.env("YUMI_QS_NOKB") !== "1" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: true; right: true }
        readonly property real dpr: screen ? screen.devicePixelRatio : 1
        readonly property int cs: 128                                   // обложка на полке

        // щелчок мимо — закрыть; колесо — между полками
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: menu.close() }

        Rectangle {
            id: card
            width: Math.min(860, win.width - 40)          // как превью «Остров»
            height: body.implicitHeight + 36
            x: Math.round((win.width - width) / 2)
            y: Math.round(Math.max(Theme.barH + 16, (win.height - height) * 0.42))
            radius: Theme.radiusBig
            color: Colors.isl
            border.width: 1; border.color: Colors.edge
            Behavior on color { ColorAnimation { duration: Theme.normal } }
            property real grow: menu.open ? 1 : 0
            // открытие — как у Popup: 300 мс от 92 %, пружина мягкая, содержимое сразу
            Behavior on grow { NumberAnimation { duration: menu.open ? Theme.menuOpen : Theme.fast
                                                 easing.type: menu.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 0.8 } }
            transform: Scale { origin.x: card.width / 2; origin.y: card.height / 2
                               xScale: 0.92 + 0.08 * card.grow; yScale: 0.92 + 0.08 * card.grow }
            opacity: Math.min(1, grow * 2.5)
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: field.forceActiveFocus() }
            WheelHandler {
                property real acc: 0
                property double last: 0
                onWheel: (ev) => {
                    acc += ev.angleDelta.y
                    const now = Date.now()
                    if (Math.abs(acc) >= 60 && now - last > 120) { menu.moveRow(acc < 0 ? 1 : -1); acc = 0; last = now }
                }
            }

            ColumnLayout {
                id: body
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
                spacing: 14

                // ---- поиск (как IField); справа — сообщение / DRY-RUN ----
                Rectangle {
                    id: search
                    Layout.fillWidth: true
                    implicitHeight: 40; radius: 20
                    color: Colors.isl2
                    border.width: field.activeFocus && !menu.sheetTrack ? 1.5 : 0; border.color: Colors.acc
                    MouseArea { anchors.fill: parent; onClicked: field.forceActiveFocus() }
                    Glyph { id: lens; x: 14; anchors.verticalCenter: parent.verticalCenter; text: "󰍉"; font.pixelSize: 16; color: Colors.fgDim }
                    TextInput {
                        id: field
                        focus: true
                        anchors { left: lens.right; right: msg.left; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 12 }
                        font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fg; clip: true
                        selectByMouse: true; selectionColor: Colors.alpha(Colors.acc, 0.4); selectedTextColor: Colors.fg
                        Keys.onPressed: (e) => {
                            const k = Latin.key(e), ctrl = e.modifiers & Qt.ControlModifier, shift = e.modifiers & Qt.ShiftModifier
                            if (shift && k === Qt.Key_Left) menu.seek(-10)
                            else if (shift && k === Qt.Key_Right) menu.seek(10)
                            else if (ctrl && k === Qt.Key_L) menu.lyricsOn = !menu.lyricsOn
                            else if (ctrl && k === Qt.Key_A) menu.openSheet(menu.curShelf && menu.curShelf.kind !== "lists" ? menu.trackOf(menu.curItem) : null)
                            else if (ctrl && k === Qt.Key_S) { menu.send({ cmd: "shuffle" }); menu.toast("Очередь перемешана") }
                            else if (ctrl && k === Qt.Key_R) menu.send({ cmd: "repeat" })
                            else if (ctrl && k === Qt.Key_U) menu.syncCur()
                            else if (k === Qt.Key_Delete && !field.text) menu.removeCur()
                            else if (ctrl && k === Qt.Key_Left) menu.send({ cmd: "prev" })
                            else if (ctrl && k === Qt.Key_Right) menu.send({ cmd: "next" })
                            else if (ctrl && k === Qt.Key_Up) menu.vol(5)
                            else if (ctrl && k === Qt.Key_Down) menu.vol(-5)
                            else if (ctrl && k === Qt.Key_F) menu.full()
                            else if (k === Qt.Key_Left) menu.moveCol(-1)
                            else if (k === Qt.Key_Right) menu.moveCol(1)
                            else if (k === Qt.Key_Up) menu.moveRow(-1)
                            else if (k === Qt.Key_Down) menu.moveRow(1)
                            else if (k === Qt.Key_Return || k === Qt.Key_Enter) { if (!menu.search(shift)) menu.activate(shift) }
                            else if (k === Qt.Key_Space && !field.text) menu.send({ cmd: "pause" })
                            else if (k === Qt.Key_Escape) { if (field.text) field.text = ""; else menu.close() }
                            else return
                            e.accepted = true
                        }
                        Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; visible: !field.text; elide: Text.ElideRight
                               font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fgDim
                               text: "Найти песню · Shift+Enter — SoundCloud · ссылка — импорт" }
                    }
                    Text {
                        id: msg
                        anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, search.width * 0.45); elide: Text.ElideRight
                        text: menu.toastText || (menu.dry ? "DRY-RUN" : "")
                        font.family: Theme.fontUi; font.pixelSize: menu.toastText ? 12 : 9
                        font.weight: menu.toastText ? Font.Normal : Font.DemiBold; font.letterSpacing: menu.toastText ? 0 : 1
                        color: menu.toastError ? Colors.bad : Colors.acc
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 22

                    // ---- слева: сейчас играет ----
                    ColumnLayout {
                        id: leftCol
                        Layout.preferredWidth: 300; Layout.maximumWidth: 300
                        Layout.alignment: Qt.AlignTop
                        spacing: 12
                        Item {
                            Layout.preferredWidth: 300; Layout.preferredHeight: 300
                            Rectangle {   // подложка без обложки — градиент акцента, как превью
                                anchors.fill: parent; radius: 28
                                gradient: Gradient {
                                    orientation: Gradient.Vertical
                                    GradientStop { position: 0; color: Colors.acc }
                                    GradientStop { position: 0.45; color: Colors.acc5 }
                                    GradientStop { position: 1; color: Colors.deep }
                                }
                                Glyph { anchors.centerIn: parent; text: "󰝚"; font.pixelSize: 64; color: Colors.alpha(Colors.fg, 0.45) }
                            }
                            // сразу — обложка из Player (Mpris artUrl, асинхронно); когда бэкенд дал свою из кэша — она поверх
                            ClippingRectangle {
                                anchors.fill: parent; radius: 28; color: "transparent"
                                visible: artImg.status === Image.Ready
                                Image {
                                    id: artImg
                                    anchors.fill: parent
                                    source: Player.shown ? Player.artUrl : ""
                                    sourceSize.width: Math.round(300 * win.dpr)
                                    fillMode: Image.PreserveAspectCrop; asynchronous: true
                                }
                            }
                            Cover {
                                anchors.fill: parent
                                visible: menu.now.has && !!menu.now.key && (!menu.useP || Player.isMusic) && menu.coverPath(menu.now.key, Math.round(300 * (Screen.devicePixelRatio || 1)), menu.covRev) !== ""
                                store: menu; key: menu.now.has ? (menu.now.key || "") : ""; size: 300; radius: 28
                                color: "transparent"
                            }
                            scale: menu.dPlaying ? 1 : 0.96
                            Behavior on scale { NumberAnimation { duration: 480; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { Layout.fillWidth: true; elide: Text.ElideRight
                                   text: menu.dHas ? menu.dTitle : (menu.settled ? "Ничего не играет" : " ")
                                   font.family: Theme.fontUi; font.pixelSize: 20; font.weight: Font.DemiBold; color: Colors.fg }
                            Text { Layout.fillWidth: true; elide: Text.ElideRight
                                   text: menu.dHas ? menu.dArtist + (menu.now.has && menu.queueFrom ? (menu.dArtist ? " · " : "") + "из «" + menu.queueFrom + "»" : "") : (menu.settled ? "Музыка" : " ")
                                   font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fgDim }
                        }
                        // ход песни: клик и перетаскивание — перемотка
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: 16
                            Rectangle {
                                id: progTrack
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width; height: pa.containsMouse || pa.pressed ? 6 : 4; radius: height / 2
                                color: Colors.alpha(Colors.fg, 0.16)
                                Behavior on height { NumberAnimation { duration: Theme.fast } }
                                Rectangle {
                                    height: parent.height; radius: parent.radius
                                    width: menu.dDur ? parent.width * Math.min(1, menu.pos / menu.dDur) : 0
                                    color: Colors.acc
                                    Behavior on color { ColorAnimation { duration: Theme.normal } }
                                }
                                Rectangle {
                                    x: (menu.dDur ? parent.width * Math.min(1, menu.pos / menu.dDur) : 0) - width / 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 10; height: 10; radius: 5; color: Colors.fg
                                    visible: menu.dHas && !!menu.dDur
                                    scale: pa.pressed ? 1.3 : 1
                                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                }
                            }
                            MouseArea {
                                id: pa
                                anchors.fill: parent; anchors.topMargin: -4; anchors.bottomMargin: -4
                                hoverEnabled: true; enabled: menu.now.has && !!menu.now.dur
                                cursorShape: Qt.PointingHandCursor
                                function at(x) { return Math.max(0, Math.min(1, x / width)) * menu.now.dur }
                                onPressed: (m) => { menu.pos = at(m.x) }
                                onPositionChanged: (m) => { if (pressed) menu.pos = at(m.x) }
                                onReleased: (m) => { const t = at(m.x); menu.pos = t; menu.now.pos = t; menu.nowAt = Date.now(); menu.send({ cmd: "seek", t: t }); seekPoll.restart(); field.forceActiveFocus() }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true; Layout.topMargin: -6
                            Text { text: menu.dHas && menu.pos >= 1 ? menu.fmt(menu.pos) : "0:00"; Layout.minimumWidth: 40
                                   font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim; font.features: ({ "tnum": 1 }) }
                            Item { Layout.fillWidth: true }
                            Text { text: menu.dHas ? menu.fmt(menu.dDur) : "0:00"; Layout.minimumWidth: 40; horizontalAlignment: Text.AlignRight
                                   font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim; font.features: ({ "tnum": 1 }) }
                        }
                        // кнопки: перемешать · назад · пауза · вперёд · в плейлист
                        Row {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 10
                            IconButton { anchors.verticalCenter: parent.verticalCenter; icon: "󰒝"; size: 36; tooltip: "Перемешать (Ctrl+S)"
                                         onClicked: { menu.send({ cmd: "shuffle" }); menu.toast("Очередь перемешана"); field.forceActiveFocus() } }
                            IconButton { anchors.verticalCenter: parent.verticalCenter; icon: "󰒮"; size: 36; iconSize: 19; tooltip: "Назад (Ctrl+←)"
                                         onClicked: { menu.send({ cmd: "prev" }); field.forceActiveFocus() } }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 52; height: 52; radius: 26
                                color: ppMa.containsMouse ? Colors.mix(Colors.acc, Colors.fg, 0.15) : Colors.acc
                                Behavior on color { ColorAnimation { duration: Theme.fast } }
                                scale: ppMa.pressed ? 0.9 : 1
                                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                                Glyph { anchors.centerIn: parent; text: menu.dPlaying ? "󰏤" : "󰐊"; font.pixelSize: 24; color: Colors.onAcc }
                                MouseArea { id: ppMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: { menu.send({ cmd: "pause" }); field.forceActiveFocus() } }
                            }
                            IconButton { anchors.verticalCenter: parent.verticalCenter; icon: "󰒭"; size: 36; iconSize: 19; tooltip: "Вперёд (Ctrl+→)"
                                         onClicked: { menu.send({ cmd: "next" }); field.forceActiveFocus() } }
                            IconButton { anchors.verticalCenter: parent.verticalCenter; icon: "󰐕"; size: 36; tooltip: "В плейлист (Ctrl+A)"
                                         onClicked: menu.openSheet(menu.curShelf && menu.curShelf.kind !== "lists" ? menu.trackOf(menu.curItem) : null) }
                        }
                    }

                    // ---- справа: сегменты и панель ----
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        Layout.minimumWidth: 0
                        spacing: 12
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            ISeg {
                                model: ["Текст", "Очередь", "Плейлисты"]
                                current: menu.seg
                                onPicked: (i) => { menu.pickSeg(i); field.forceActiveFocus() }
                            }
                            IconButton { icon: "󰑖"; active: !!menu.now.loop; tooltip: "Повтор (Ctrl+R)"; onClicked: { menu.send({ cmd: "repeat" }); field.forceActiveFocus() } }
                            IconButton { icon: "󰑐"; enabled: !!menu.curPid; tooltip: "Обновить плейлист (Ctrl+U)"; onClicked: { menu.syncCur(); field.forceActiveFocus() } }
                            IconButton { icon: "󰊓"; tooltip: "Во весь экран (Ctrl+F)"; onClicked: menu.full() }
                        }

                        Rectangle {
                            id: panel
                            Layout.fillWidth: true
                            Layout.preferredHeight: leftCol.implicitHeight - 36 - 12 - 12 - foot.implicitHeight
                            radius: Theme.radiusTile
                            color: Colors.isl2
                            clip: true

                            // полки: фишки текущего сегмента, лента обложек, выбранный трек
                            Item {
                                anchors.fill: parent; anchors.margins: 16

                                ListView {
                                    id: tabs
                                    width: parent.width; height: 30
                                    orientation: ListView.Horizontal
                                    spacing: 6
                                    clip: true
                                    interactive: false
                                    model: menu.shelves
                                    currentIndex: menu.row
                                    highlightRangeMode: ListView.ApplyRange
                                    preferredHighlightBegin: 40
                                    preferredHighlightEnd: width - 80
                                    highlightMoveDuration: 380
                                    highlightMoveVelocity: -1
                                    delegate: Item {
                                        id: tab
                                        required property var modelData
                                        required property int index
                                        readonly property bool mine: menu.groupOf(modelData) === menu.groupOf(menu.curShelf)
                                        width: mine ? chip.implicitWidth : 0; height: 30
                                        visible: mine
                                        IChip {
                                            id: chip
                                            text: tab.modelData.tab || tab.modelData.title
                                            on: tab.index === menu.row
                                            onClicked: { menu.row = tab.index; field.forceActiveFocus() }
                                        }
                                    }
                                }

                                ListView {
                                    id: rail
                                    y: tabs.height + 14
                                    width: parent.width
                                    height: win.cs + 46
                                    orientation: ListView.Horizontal
                                    spacing: 14
                                    clip: true
                                    interactive: false
                                    reuseItems: false              // 30.10: переиспользованные плитки заново запускали анимации — подсветка прыгала
                                    cacheBuffer: 600
                                    leftMargin: 4; rightMargin: 4
                                    model: menu.curShelf ? menu.curShelf.items : []
                                    currentIndex: menu.curShelf ? menu.colOf(menu.curShelf.id, menu.colRev) : 0
                                    highlightRangeMode: ListView.ApplyRange
                                    preferredHighlightBegin: win.cs + 14
                                    preferredHighlightEnd: width - (win.cs + 14)
                                    highlightMoveDuration: 380
                                    highlightMoveVelocity: -1
                                    readonly property bool isList: !!menu.curShelf && menu.curShelf.kind === "lists"
                                    delegate: Item {
                                        id: tile
                                        required property var modelData
                                        required property int index
                                        readonly property bool on: index === rail.currentIndex
                                        readonly property bool playing: !!menu.now.key && !rail.isList && tile.modelData.key === menu.now.key
                                        width: win.cs; height: rail.height
                                        Item {
                                            id: art
                                            y: 6
                                            width: win.cs; height: win.cs
                                            opacity: tile.on || tile.playing ? 1 : 0.7
                                            scale: tma.pressed ? 0.94 : tile.on ? 1.04 : 1
                                            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                            Rectangle {    // выбранная — кромка акцентом 2 px снаружи; 30.10: без затухания (две подсветки сразу)
                                                anchors.fill: parent; anchors.margins: -3; radius: 17
                                                color: "transparent"; border.width: 2; border.color: Colors.acc
                                                visible: tile.on
                                            }
                                            Cover { visible: !rail.isList; store: menu; key: rail.isList ? "" : (tile.modelData.key || ""); size: win.cs; radius: 14; color: Colors.isl }
                                            Mosaic { visible: rail.isList; store: menu; keys: rail.isList ? (tile.modelData.keys || []) : []; size: win.cs; radius: 14; color: Colors.isl }
                                            Rectangle {    // играет сейчас — капсула акцентом
                                                visible: tile.playing
                                                anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 8
                                                width: 26; height: 26; radius: 13; color: Colors.acc
                                                Glyph { anchors.centerIn: parent; text: menu.now.playing ? "󰏤" : "󰐊"; font.pixelSize: 13; color: Colors.onAcc }
                                            }
                                        }
                                        Column {
                                            anchors.top: art.bottom; anchors.topMargin: 8
                                            width: win.cs; spacing: 1
                                            Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium
                                                   color: tile.on || tile.playing ? Colors.fg : Colors.alpha(Colors.fg, 0.8)
                                                   text: rail.isList ? (tile.modelData.short || "") : (tile.modelData.title || "") }
                                            Text { width: parent.width; elide: Text.ElideRight; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim
                                                   text: rail.isList ? ((tile.modelData.src || "") + " · " + (tile.modelData.count || 0)) : (tile.modelData.artist || "") }
                                        }
                                        MouseArea {
                                            id: tma
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: (m) => {
                                                const was = tile.on
                                                menu.pick(menu.row, tile.index)
                                                if (was) menu.activate(m.modifiers & Qt.ShiftModifier)
                                                field.forceActiveFocus()
                                            }
                                        }
                                    }
                                }
                                Text {
                                    y: rail.y + 50; width: parent.width; horizontalAlignment: Text.AlignHCenter
                                    visible: !!menu.curShelf && menu.curShelf.items.length === 0 || !menu.shelves.length
                                    text: !menu.shelves.length ? "Загружаю…" : menu.curShelf.kind === "pl" ? "Загружаю…" : (menu.curShelf.empty || "Пусто")
                                    font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fgDim
                                }

                                // выбранное: заголовок полки и что сделает Enter
                                Column {
                                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                                    spacing: 2
                                    Text { width: parent.width; elide: Text.ElideRight
                                           text: menu.curShelf ? menu.curShelf.title.replace(/^\S+\s+/, "") : ""
                                           font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim }
                                    Text { width: parent.width; elide: Text.ElideRight
                                           text: !menu.curItem ? " " : menu.curShelf.kind === "lists" ? "Enter — слушать «" + (menu.curItem.short || "") + "» · Shift+Enter — перемешать"
                                                 : "Enter — играть · Shift+Enter — следующим" + (menu.curItem.rm ? " · Del — убрать из плейлиста" : "")
                                           font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.alpha(Colors.fg, 0.8) }
                                }
                            }

                            // ---- текст песни (Ctrl+L): слой поверх полок справа, въезжает пружиной ----
                            Rectangle {
                                id: lyrLayer
                                width: Math.round(parent.width * 0.64); height: parent.height
                                x: parent.width - width + (menu.lyricsOn ? 0 : 28)
                                radius: Theme.radiusTile
                                color: Colors.isl
                                border.width: 1; border.color: Colors.edge
                                opacity: menu.lyricsOn ? 1 : 0
                                visible: opacity > 0
                                Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                                Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                                MouseArea { anchors.fill: parent; onClicked: field.forceActiveFocus() }
                                LyricsPane {
                                    anchors.fill: parent; anchors.margins: 18
                                    px: 18; weight: Font.DemiBold; lineGap: 8; showSource: false
                                    running: menu.lyricsOn && menu.open
                                }
                            }
                        }
                        Text {
                            id: foot
                            Layout.fillWidth: true; elide: Text.ElideRight
                            readonly property var nx: menu.curIdx >= 0 && menu.queue.length > menu.curIdx + 1 ? menu.queue[menu.curIdx + 1] : null
                            text: (Player.lyricsSource ? "Текст: " + Player.lyricsSource : "Текст: YouTube Music → LRCLIB")
                                  + (nx ? " · далее: " + (nx.title || "") + (nx.artist ? " — " + nx.artist : "") : "")
                            font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim
                        }
                    }
                }

                // ---- низ: громкость потока плеера и подсказки ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    Rectangle {    // громкость — капсула 26 со значком (как ISlider), клик/перетаскивание
                        id: volBar
                        Layout.preferredWidth: 220
                        implicitHeight: 26; radius: 13
                        color: Colors.isl2
                        clip: true
                        property real held: -1
                        readonly property real v: held >= 0 ? held : (menu.volWant >= 0 ? menu.volWant : Player.volume)
                        Rectangle {
                            width: Math.max(parent.height, parent.width * Math.min(1, volBar.v)); height: parent.height; radius: parent.radius
                            color: Colors.acc
                            Behavior on width { enabled: volBar.held < 0; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        }
                        Glyph { x: 9; anchors.verticalCenter: parent.verticalCenter; text: "󰕾"; font.pixelSize: 15; color: Colors.onAcc }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor; preventStealing: true
                            function put(x) { const v = Math.max(0, Math.min(1, x / width)); volBar.held = v; volT.want = v; if (!volT.running) volT.start() }
                            onPressed: (m) => put(m.x)
                            onPositionChanged: (m) => { if (pressed) put(m.x) }
                            onReleased: { volUnhold.restart(); field.forceActiveFocus() }
                        }
                        // не чаще раза в 90 мс (поток значений давал треск в Bluetooth-наушниках), последнее доходит всегда
                        Timer { id: volT; property real want: -1; interval: 90; repeat: true; triggeredOnStart: true
                                onTriggered: { if (want >= 0) { Player.setVolume(want); want = -1 } else stop() } }
                        Timer { id: volUnhold; interval: 1200; onTriggered: volBar.held = -1 }
                    }
                    Text {
                        Layout.maximumWidth: 200; elide: Text.ElideRight
                        text: Math.round(volBar.v * 100) + "%" + (Audio.sinkDesc ? " · " + Audio.sinkDesc : "")
                        font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim; font.features: ({ "tnum": 1 })
                    }
                }
                CardHints {
                    Layout.fillWidth: true
                    items: menu.sheetTrack ? [["↑↓", "плейлист"], ["Enter", "добавить"], ["имя Enter", "новый"], ["Esc", "отмена"]]
                         : [["←→", "трек"], ["↑↓", "полка"], ["Enter", "играть"], ["Shift ←→", "±10 с"], ["Пробел", "пауза"],
                            ["Ctrl L", "текст"], ["Ctrl A", "в плейлист"], ["Esc", "закрыть"]]
                }
            }
        }

        // ---- «Добавить в плейлист»: карточка-остров поверх ----
        Rectangle {
            id: sheet
            anchors.horizontalCenter: parent.horizontalCenter
            y: card.y + 90
            width: 400; height: sheetCol.implicitHeight + 36; radius: Theme.radiusBig
            opacity: menu.sheetTrack ? 1 : 0
            scale: menu.sheetTrack ? 1 : 0.92
            visible: opacity > 0
            z: 5
            Behavior on opacity { NumberAnimation { duration: Theme.fast } }
            Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }
            color: Colors.isl
            border.width: 1; border.color: Colors.alpha(Colors.fg, 0.14)
            MouseArea { anchors.fill: parent }
            ColumnLayout {
                id: sheetCol
                x: 18; y: 18; width: parent.width - 36
                spacing: 6
                CardHead {
                    title: "Добавить в плейлист"
                    status: menu.sheetTrack ? (menu.sheetTrack.artist ? menu.sheetTrack.artist + " — " + (menu.sheetTrack.title || "") : (menu.sheetTrack.title || "")) : ""
                }
                Item { implicitHeight: 4 }
                Repeater {
                    model: menu.sheetTrack ? menu.lib : []
                    Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool on: index === menu.sheetSel && !sheetField.text
                        Layout.fillWidth: true
                        implicitHeight: 48; radius: Theme.radius
                        color: on ? Colors.alpha(Colors.acc, 0.16) : (sma.containsMouse ? Colors.isl2 : "transparent")
                        /* выбор — без затухания (29.10) */
                        Mosaic { id: sm; x: 8; anchors.verticalCenter: parent.verticalCenter; store: menu; keys: parent.modelData.keys || []; size: 34; radius: 12; color: Colors.isl2 }
                        Text { anchors.left: sm.right; anchors.leftMargin: 12; anchors.right: scnt.left; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                               elide: Text.ElideRight; text: parent.modelData.short; font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium; color: Colors.fg }
                        Text { id: scnt; anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                               text: parent.modelData.count; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim; font.features: ({ "tnum": 1 }) }
                        MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { menu.sheetSel = parent.index; sheetField.text = ""; menu.sheetAdd() } }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.topMargin: 4
                    implicitHeight: 40; radius: 20
                    color: Colors.isl2
                    border.width: sheetField.activeFocus && sheetField.text ? 1.5 : 0; border.color: Colors.acc
                    TextInput {
                        id: sheetField
                        anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fg; clip: true
                        selectByMouse: true; selectionColor: Colors.alpha(Colors.acc, 0.4)
                        Keys.onPressed: (e) => {
                            const k = e.key
                            if (k === Qt.Key_Down) menu.sheetSel = Math.min(menu.lib.length - 1, menu.sheetSel + 1)
                            else if (k === Qt.Key_Up) menu.sheetSel = Math.max(0, menu.sheetSel - 1)
                            else if (k === Qt.Key_Return || k === Qt.Key_Enter) menu.sheetAdd()
                            else if (k === Qt.Key_Escape) menu.closeSheet()
                            else return
                            e.accepted = true
                        }
                        Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; visible: !sheetField.text
                               text: "Новый плейлист — имя и Enter"; font: sheetField.font; color: Colors.fgDim }
                    }
                }
            }
        }
    }
}
