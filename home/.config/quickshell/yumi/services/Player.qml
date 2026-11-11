pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

// Плеер для острова и пилюли. Игроки — Quickshell.Services.Mpris; активный выбирается как в yumi-player /
// player-pill: играющий (если текущий играет — он), иначе прежний, иначе тот, что менял состояние последним.
// Python-бэкенд ~/.local/lib/yumi/qs/player: чистые имена треков yumi-music (meta.tsv), текст песни
// (yumilyrics), очередь yumi-music (сокет mpv), плейлисты и ♡ (yumi-music pl-add → added.json),
// панель «Текст / Очередь» (общий файл состояния с yumi-player).
Singleton {
    id: root
    readonly property bool dry: Quickshell.env("YP_DRYRUN") === "1"
    readonly property string backend: Quickshell.env("YUMI_QS_PLAYER_BACKEND") || (Quickshell.env("HOME") + "/.local/lib/yumi/qs/player")   // переменная — для проверки копии
    property bool watching: false          // остров открыт: опрашивать позицию, держать текст свежим
    property bool fullOpen: false          // полноэкранный плеер (player/FullPlayer.qml): qs -c yumi ipc call player full
    property bool lockOpen: false          // экран блокировки (lock/LockSurface.qml) показан: держать позицию и текст свежими
    signal toast(string text, bool error)
    signal showIsland(string mode)        // «Свернуть в окно плеера» из полноэкранного

    // ---------- выбор игрока ----------
    // playerctld — зеркало активного игрока, не отдельный источник (30.10)
    readonly property var players: Mpris.players.values.filter(p => p && !String(p.dbusName || "").endsWith(".playerctld"))
    property var player: null
    // 30.10: выбор источника вручную (чипы в острове, когда игроков больше одного): пока выбранный есть — он,
    // даже если играет другой; исчез — снова автоматически.
    property string pinned: ""
    function choose(p) { if (!p) return; pinned = p.dbusName; touch(p); player = p; refreshTrack() }
    function srcOf(id) {
        const k = String(id || "").toLowerCase()
        if (k.includes("zen")) return "󰖟 Zen"
        if (k.includes("firefox")) return "󰈹 Firefox"
        if (k.startsWith("spotify")) return "󰓇 Spotify"
        if (k.startsWith("mpv")) return ""                  // 30.10: музыка (mpv / yumi-music) — без пометки
        if (k.startsWith("chrom")) return " Chromium"
        if (k.startsWith("vlc")) return "󰕼 VLC"
        return "󰝚 " + id
    }
    function nameOf(p) { return p ? (String(p.identity || "").toLowerCase().startsWith("mpv") ? "󰝚 Моя музыка" : srcOf(p.identity)) : "" }
    property var lastActive: ({})
    function touch(p) { if (p) lastActive[p.dbusName] = Date.now() }
    function pick() {
        const ps = players
        if (!ps.length) { player = null; return }
        if (pinned) { const pp = ps.find(p => p.dbusName === pinned); if (pp) { player = pp; return } pinned = "" }
        const playing = ps.filter(p => p.isPlaying)
        if (player && playing.indexOf(player) >= 0) return
        if (playing.length) { player = playing[0]; return }
        if (player && ps.indexOf(player) >= 0) return
        let best = ps[0], t = -1
        for (const p of ps) { const a = lastActive[p.dbusName] ?? 0; if (a > t) { t = a; best = p } }
        player = best
    }
    onPlayersChanged: { pick(); if (!players.length) trackKey = "" }
    Variants {
        model: root.players
        delegate: QtObject {
            required property var modelData
            readonly property Connections c: Connections {
                target: modelData
                function onPlaybackStateChanged() { root.touch(modelData); debounce.restart() }
                function onPostTrackChanged() { debounce.restart() }
            }
        }
    }
    Timer { id: debounce; interval: 300; onTriggered: { root.pick(); root.refreshTrack() } }   // браузер шлёт пачки событий
    Timer { interval: 2000; running: true; repeat: true; onTriggered: root.pick() }            // playerctld-подобный догон

    // ---------- трек ----------
    // has — живой игрок MPRIS. Нет игрока, но есть сохранённый последний трек (last.json, бэкенд) — stopped:
    // название/обложка/длина/позиция берутся из него, ▶ (togglePlaying) продолжает его с места (resume).
    readonly property bool has: player !== null
    property var last: null
    readonly property bool stopped: !has && !!(last && last.title)
    readonly property bool shown: has || stopped
    readonly property bool canResume: stopped && !!last.resumable     // yumi-music: продолжить; браузер — «Открыть»
    readonly property bool playing: has && player.isPlaying
    readonly property string rawTitle: has ? (player.trackTitle || "") : (stopped ? last.title : "")
    readonly property string rawArtist: has ? (player.trackArtist || "") : (stopped ? (last.artist || "") : "")
    readonly property string url: has ? String(player.metadata["xesam:url"] ?? "") : (stopped ? (last.url || "") : "")
    readonly property string artUrl: has ? (player.trackArtUrl || "") : (stopped ? (last.art || "") : "")
    readonly property real length: has && player.lengthSupported ? player.length : (stopped ? (last.length || 0) : 0)
    readonly property string identity: has ? (player.identity || "") : (stopped ? (last.identity || "") : "")
    readonly property string source: srcOf(identity)
    // чистые имена от бэкенда (yumi-music), пока их нет — как отдаёт MPRIS
    property string trackKey: ""
    property string metaTitle: ""
    property string metaArtist: ""
    readonly property string title: shown ? (metaTitle || rawTitle || "Без названия") : "ничего не играет"
    readonly property string artist: shown ? (metaTitle ? metaArtist : rawArtist) : ""
    property bool queueOk: false
    readonly property bool isMusic: identity.toLowerCase().startsWith("mpv") && queueOk

    onRawTitleChanged: refreshTrack()
    onUrlChanged: refreshTrack()
    function refreshTrack() {
        const key = url + "\x1f" + rawTitle + "\x1f" + rawArtist
        if (key === trackKey) return
        trackKey = key
        metaTitle = ""; metaArtist = ""
        lyrics = []; lyricsMsg = shown ? "Ищу текст…" : "Ничего не играет"; lyricsSynced = false; lyricsSource = ""
        if (!shown) return
        if (has) saveSoon.restart()
        const sink = Pipewire.defaultAudioSink
        send({ cmd: "track", title: rawTitle, artist: rawArtist, length: length, url: url,
               bt: !!(sink && sink.name.startsWith("bluez_")) })
    }

    // ---------- позиция (MPRIS сам не обновляет — опрашиваем, пока остров открыт) ----------
    property real posBase: 0
    property real posAt: 0
    // 30.10: на паузе позиция заморожена — браузер на паузе отдаёт скачущее position. При паузе фиксируем то, что
    // показывали (posBase + прошедшее), и не опрашиваем MPRIS, пока не нажмут ▶; на паузе — один опрос после
    // смены игрока/трека (posFresh), seek() двигает замороженное значение.
    property bool posRun: false             // позиция идёт (posRun, а не playing: при паузе нужно старое значение)
    property bool posFresh: false           // на паузе уже есть позиция этого игрока/трека
    function position() { return has ? posBase + (posRun ? (Date.now() - posAt) / 1000 : 0) : (stopped ? (last.pos || 0) : 0) }
    // После ▶ MPRIS ~1 с отдаёт позицию с забегом, а mpv ещё раскачивает поток — 1,5 с число стоит (resumeHold),
    // потом берём настоящую позицию (она уже не меньше замороженной: время не идёт назад); мелкие расхождения
    // (< 1 с) при игре не применяем: время не дёргается туда-обратно; перемотка (больше 1 с) применяется.
    function poll() {
        if (!has || (!playing && posFresh) || (playing && resumeHold.running)) return
        player.positionChanged()
        const p = player.position
        if (playing && !posRun && posFresh && p < posBase && posBase - p < 3) return   // после ▶ ещё не догнала — стоим
        if (!(playing && posRun && posFresh && Math.abs(p - position()) < 1)) { posBase = p; posAt = Date.now() }
        posRun = playing; posFresh = true
    }
    Timer { id: resumeHold; interval: 1500; onTriggered: { root.poll(); root.posUpdate() } }
    onTrackKeyChanged: posFresh = false
    Timer { interval: 500; running: (root.watching || root.fullOpen || root.lockOpen) && root.has && !posTick.running; repeat: true; triggeredOnStart: true; onTriggered: root.poll() }
    // 29.10: ОДНА позиция для всех, кто показывает время трека (остров бара, меню «Музыка»…): целые секунды (Math.floor),
    // один такт 250 мс (опрос MPRIS — каждый второй, 500 мс), пока трек играет или есть потребители (posUsers).
    property int posUsers: 0                // сколько открытых мест показывают время (меню «Музыка» +1, пока открыто)
    property real posSec: 0                 // позиция, целые секунды — показывать ЕЁ, не считать своё
    property int posN: 0
    function posUpdate() { posSec = Math.floor(position()) }
    Timer {
        id: posTick
        interval: 250; repeat: true; triggeredOnStart: true
        running: root.has && (root.playing || root.posUsers > 0 || root.watching || root.fullOpen || root.lockOpen)
        onTriggered: { if (root.posN++ % 2 === 0) root.poll(); root.posUpdate() }
    }
    onShownChanged: posUpdate()
    function seek(sec) { if (has && player.canSeek) { player.position = Math.max(0, Math.min(length, sec)); posBase = Math.max(0, Math.min(length, sec)); posAt = Date.now(); posUpdate() } }
    // YP_DRYRUN=1 (dry, выше) — next/previous/пауза только печатаются: проверки агентов не трогают плеер пользователя (16.10)
    function togglePlaying() { if (dry) { console.log("[dry-run] плеер: пауза/play"); return } if (has) player.togglePlaying(); else if (stopped) resume() }
    function resume() { send({ cmd: "resume" }) }   // yumi-music с сохранённой очередью и места; браузерный трек — открыть ссылку

    // ---------- последний трек: снимок при смене трека, паузе и раз в 10 с во время игры ----------
    function saveLast() {
        if (!has || !url) return
        poll()
        const d = { title: title, artist: artist, url: url, art: artUrl, length: length, pos: posBase, identity: identity }
        last = Object.assign({}, last || {}, d, { resumable: (last && last.url === url) ? last.resumable : identity.toLowerCase().startsWith("mpv") })
        send(Object.assign({ cmd: "save" }, d))
    }
    Timer { id: saveSoon; interval: 2000; onTriggered: root.saveLast() }        // после смены трека: длина/обложка уже пришли
    Timer { interval: 10000; running: root.playing; repeat: true; onTriggered: root.saveLast() }
    onPlayingChanged: {
        if (has && !playing) { posBase = position(); posAt = Date.now(); posRun = false; posFresh = true; saveLast() }
        else if (has && posFresh && !posRun) resumeHold.restart()      // ▶ — число стоит до настоящей позиции
        else poll()
        posUpdate()
    }   // пауза — снимок; общая позиция — сразу
    function next() { if (dry) { console.log("[dry-run] плеер: next"); return } if (has && player.canGoNext) player.next() }
    function previous() { if (dry) { console.log("[dry-run] плеер: previous"); return } if (has && player.canGoPrevious) player.previous() }

    // ---------- громкость: поток этого плеера в PipeWire (как yumi-player.find_sink) ----------
    // PID игрока — D-Bus GetConnectionUnixProcessID по его имени на шине; поток = узел с application.process.id,
    // иначе по имени бинарника/приложения; не нашли — системный выход (Pipewire.defaultAudioSink).
    property string playerPid: ""
    readonly property string playerName: has ? (player.dbusName || "").replace("org.mpris.MediaPlayer2.", "").split(".")[0].toLowerCase() : ""
    onPlayerChanged: { posFresh = false; posRun = false; poll(); playerPid = ""; if (player && player.dbusName) { pidProc.command = ["busctl", "--user", "call", "org.freedesktop.DBus",
        "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetConnectionUnixProcessID", "s", player.dbusName]; pidProc.running = true } }
    Process { id: pidProc; stdout: SplitParser { onRead: (l) => { const m = /^u (\d+)/.exec(l.trim()); if (m) root.playerPid = m[1] } } }
    onPlayerPidChanged: if (Quickshell.env("YUMI_QS_DEBUG")) console.log("player: pid", playerPid, "→", stream ? stream.name : "поток не найден")
    readonly property var streams: Pipewire.nodes.values.filter(n => n && n.isStream && (n.type & PwNodeType.AudioOutStream) === PwNodeType.AudioOutStream)
    readonly property var stream: {
        const ss = streams
        if (playerPid) { const s = ss.find(n => String(n.properties["application.process.id"] ?? "") === playerPid); if (s) return s }
        if (playerName) { const s = ss.find(n => [n.properties["application.process.binary"], n.properties["application.name"], n.name].join(" ").toLowerCase().includes(playerName)); if (s) return s }
        return null
    }
    readonly property var volNode: stream ?? Pipewire.defaultAudioSink
    onVolNodeChanged: if (Quickshell.env("YUMI_QS_DEBUG")) console.log("player: громкость →", volNode ? volNode.name : "нет", stream ? "(поток)" : "(система)",
        "| pid", playerPid, "| имя", playerName, "| потоки", streams.map(n => n.name + ":" + n.properties["application.process.id"]).join(","))
    readonly property bool volIsStream: stream !== null
    PwObjectTracker { objects: [root.volNode] }
    readonly property real volume: volNode && volNode.audio ? volNode.audio.volume : 0
    readonly property bool muted: !!(volNode && volNode.audio && volNode.audio.muted)
    function setVolume(v) {
        if (!volNode || !volNode.audio) return
        v = Math.max(0, Math.min(1, v))
        const vols = volNode.audio.volumes
        if (vols.length === 2 && Math.abs(vols[0] - vols[1]) > 0.005) { const m = Math.max(vols[0], vols[1]) || 1; volNode.audio.volumes = [v * vols[0] / m, v * vols[1] / m] }
        else volNode.audio.volume = v
    }
    function toggleMute() { if (volNode && volNode.audio) volNode.audio.muted = !volNode.audio.muted }

    // ---------- текст песни ----------
    property var lyrics: []            // [[сек, строка], …]
    property bool lyricsSynced: false
    property real lyricsShift: 0.2
    property string lyricsSource: ""
    property string lyricsMsg: "Ничего не играет"
    function lyricIndex() {
        const t = position() + lyricsShift
        let lo = 0, hi = lyrics.length
        while (lo < hi) { const m = (lo + hi) >> 1; if (lyrics[m][0] <= t) lo = m + 1; else hi = m }
        return lo - 1
    }

    // ---------- очередь, плейлисты, панель ----------
    property var queue: []
    property string queueHead: "Далее"
    property string queueMsg: ""
    property var playlists: []
    property string panel: "lyrics"    // lyrics | queue | off
    function requestQueue() { send({ cmd: "queue" }) }
    function play(n) { send({ cmd: "play", n: n }) }
    function requestPlaylists() { send({ cmd: "playlists" }) }
    function addToPlaylist(pid) { send({ cmd: "pl-add", pid: pid, url: url, title: title, artist: artist, dur: Math.round(length), thumb: artUrl }) }
    function setPanel(v) { panel = v; send({ cmd: "panel", value: v }) }

    Process {
        id: proc
        command: ["python3", "-I", root.backend]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: (line) => {
                let j; try { j = JSON.parse(line) } catch (e) { return }
                switch (j.type) {
                case "panel": root.panel = j.value; root.queueOk = !!j.q_ok; break
                case "last": delete j.type; root.last = j; if (!root.has) root.refreshTrack(); break
                case "meta":
                    if (j.url !== root.url) return
                    root.metaTitle = j.title; root.metaArtist = j.artist; root.queueOk = !!j.q_ok; break
                case "lyrics":
                    if (j.url !== root.url) return
                    root.lyrics = j.lines || []; root.lyricsSynced = !!j.synced; root.lyricsShift = j.shift ?? 0.2
                    root.lyricsSource = j.source || ""; root.lyricsMsg = j.msg || ""; break
                case "queue": {   // 30.10: тот же список — не трогать (раньше раз в 3 с пересоздавались все строки: подсветка сбрасывалась)
                    const items = j.items || []
                    if (JSON.stringify(items) !== JSON.stringify(root.queue)) root.queue = items
                    root.queueHead = j.head || "Далее"; root.queueMsg = j.ok ? "" : (j.msg || ""); break }
                case "playlists": root.playlists = j.items || []; break
                case "toast": root.toast(j.text, !!j.error); break
                }
            }
        }
        stderr: SplitParser { onRead: (line) => { if (line.trim()) console.log("player-backend:", line) } }
        onExited: restart.start()
    }
    Timer { id: restart; interval: 3000; onTriggered: proc.running = true }
    function send(obj) { if (proc.running) proc.write(JSON.stringify(obj) + "\n") }
    Component.onCompleted: pick()
}
