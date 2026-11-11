import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs
import qs.components
import qs.services

// Меню «Питание» — «Остров» (29.10): крупный заряд с полосой, показатели плитками 2×2 (мощность и температура — с живыми
// графиками, точка раз в 2 с, пока меню открыто), профиль и «Зарядка до» — сегменты, рабочие режимы Hyprland — строки
// с переключателем. Enter (или клик) по показателю — он раскрывается на месте до подробностей.
// Клавиши: ←→↑↓ — выбор (плитка, вариант сегмента, режим), Enter — подробнее / применить; в подробностях Esc — назад;
// Esc на панели — закрыть. Закрытие — как раньше (Esc, клик вне, курсор далеко — общий механизм Popup).
// Переключения: yumi-power-profile set (29.10, частота ЦП вместо powerprofilesctl), yumi-workflow set, yumi-battery-limit.
// Открыть/закрыть: qs -c yumi ipc call menu toggle power. Проверка: qs … ipc call power key left|right|up|down|enter|esc · power state
// YP_DRYRUN=1 — команды только пишутся в журнал, меню имитирует результат. YP_POWER_FAKE — см. PowerData,
// YP_POWER_ACT=profile:NAME|workflow:NAME|limit:80 — «нажать» через 0,8 с после открытия (для проверки).
PowerPopup {
    id: win
    name: "power"
    marginRight: Theme.screenPad
    contentW: 390                            // «Остров»: как в превью
    pad: 18
    contentH: col.implicitHeight + pad * 2
    open: Menus.current === "power"
    screen: Menus.screen                     // монитор, где курсор в момент открытия (Menus.pickScreen)

    readonly property string home: Quickshell.env("HOME")
    readonly property string bin: home + "/.local/bin/"
    readonly property bool dry: Quickshell.env("YP_DRYRUN") === "1"
    property bool busy: runner.running
    property string toast: ""
    property bool toastError: false

    // ---- профили (дословно из yumi-menu-power) ----
    readonly property var allProfiles: [
        { key: "power-saver", icon: "󰌪", text: "Эконом",      sub: "экономия заряда" },
        { key: "balanced",    icon: "󰾅", text: "Баланс",      sub: "по умолчанию" },
        { key: "performance", icon: "󱐋", text: "Производит.", sub: "максимум частоты" } ]
    // «Производит.» показывается только там, где драйвер его даёт (на MacBook M1 — нет)
    readonly property var profiles: allProfiles.filter(p => p.key !== "performance")   // 29.10: без PowerProfiles (DBus к power-profiles-daemon вешал загрузку)
    readonly property var workflowInfo: ({   // имя файла → значок, название, имя в Waybar, описание
        "01-default": ["󰍹", "Обычный",        "Main",       "Прозрачность, размытие, анимации"],
        "editing":    ["󰏫", "Редактирование", "Editing",    "Без прозрачности — точные цвета"],
        "gaming":     ["󰊗", "Игры",           "Gaming",     "Без теней и отступов — для скорости"],
        "powersaver": ["󰌪", "Экономия",       "Powersaver", "Без эффектов — бережёт батарею"],
        "snappy":     ["󱐋", "Отзывчивый",     "Snappy",     "Без анимаций — мгновенный отклик"] })

    PowerData { id: bat; active: win.open }
        readonly property int step: Math.round(bat.pct / 5) * 5
    // Полоса заряда: зелёный при 100 % → через жёлтый и оранжевый → красный при 0 % (оттенок HSL 120°→0°),
    // насыщенность и светлота — между Colors.bad и Colors.ok, чтобы читалось на острове. Шаг 5 %, смена — ColorAnimation.
    function chargeTone(p) {
        const k = Math.max(0, Math.min(1, p / 100)), a = Qt.color(Colors.bad), b = Qt.color(Colors.ok)
        return Qt.hsla(k * 120 / 360, a.hslSaturation + (b.hslSaturation - a.hslSaturation) * k, a.hslLightness + (b.hslLightness - a.hslLightness) * k, 1)
    }
    readonly property color tone: chargeTone(step)

    // профиль: живое значение из power-profiles-daemon; в dry-run — «выбранный»
    property string fakeProfile: ""
    // 29.10: режим — yumi-power-profile (частота ЦП); power-profiles-daemon не используем (заглушка на M1, вешал загрузку)
    property string curProfile: ""
    Process { id: profProc; command: [win.bin + "yumi-power-profile", "get"]
              stdout: StdioCollector { onStreamFinished: { const t = text.trim(); if (t) win.curProfile = t } } }
    Connections { target: Signals; function onRefresh(n) { if (n === "ppd") profProc.running = true } }
    readonly property string profile: (dry && fakeProfile) ? fakeProfile : curProfile
    readonly property int profileIndex: profiles.findIndex(p => p.key === profile)
    readonly property var profileInfo: profiles.find(p => p.key === profile) || { icon: "󰾅", text: "—", sub: "" }

    // рабочие режимы: первая строка — текущий (yumi-workflow get), дальше список (yumi-workflow list)
    property var workflows: []
    property string workflow: ""
    property string fakeWorkflow: ""
    property string wfBusy: ""
    property var wfLines: []
    readonly property string wfCur: fakeWorkflow || workflow
    readonly property var wfInfo: workflowInfo[wfCur] || ["󰍹", wfCur || "—", "", ""]
    Process {
        id: wfProc
        command: ["sh", "-c", "w=\"$HOME/.local/bin/yumi-workflow\"; \"$w\" get; \"$w\" list"]
        stdout: SplitParser { onRead: (line) => { if (line.trim()) win.wfLines.push(line.trim()) } }
        onStarted: win.wfLines = []
        onExited: {
            if (win.wfLines.length) { win.workflow = win.wfLines[0]; win.workflows = win.wfLines.slice(1) }
            if (!win.dry) win.fakeWorkflow = ""
        }
    }
    FileView { id: wfState; path: win.home + "/.local/state/yumi/workflow"; watchChanges: true; printErrors: false
               onFileChanged: wfProc.running = true }
    onOpenChanged: {
        if (open) profProc.running = true             // 29.10: текущий режим (yumi-power-profile get)
        if (open) { wfProc.running = true; bat.reload(); zoom = ""; selKey = "bat"; scope.forceActiveFocus(); seedHist(); if (act.what) act.restart() }
        else scope.focus = false
    }
    // для проверки (как YP_POWER_ACT в GTK-меню): через 0,8 с после открытия «нажать» profile:NAME | workflow:NAME | limit:80
    Timer {
        id: act
        interval: 800
        readonly property string what: (Quickshell.env("YP_POWER_ACT") || "").split(":")[0]
        readonly property string arg: (Quickshell.env("YP_POWER_ACT") || "").split(":")[1] || ""
        onTriggered: { if (what === "profile") win.setProfile(arg); else if (what === "workflow") win.setWorkflow(arg); else if (what === "limit") win.setLimit(parseInt(arg)) }
    }

    // ---- выполнение команд (одна за раз) ----
    property var onDone: null
    Process {
        id: runner
        stdout: SplitParser { onRead: (l) => console.log("power:", l) }
        stderr: SplitParser { onRead: (l) => { runner.err = l } }
        property string err: ""
        onExited: (code) => { const cb = win.onDone; win.onDone = null; if (cb) cb(code === 0, runner.err) }
    }
    function run(cmd, cb) {
        if (dry) { console.log("[dry-run] " + cmd.join(" ")); dryTimer.cb = cb; dryTimer.restart(); return }
        runner.err = ""; onDone = cb; runner.command = cmd; runner.running = true
    }
    Timer { id: dryTimer; interval: 600; property var cb: null; onTriggered: { const c = cb; cb = null; if (c) c(true, "") } }
    function say(text, error, hold) { toast = text; toastError = !!error; toastTimer.interval = (hold || 3) * 1000; toastTimer.restart() }
    Timer { id: toastTimer; onTriggered: win.toast = "" }

    function setProfile(key) {
        if (key === profile || busy) return
        const p = profiles.find(x => x.key === key)
        if (dry) fakeProfile = key
        const was = curProfile
        curProfile = key                                   // плашка переезжает сразу; при ошибке — назад
        run([bin + "yumi-power-profile", "set", key],
            (ok, msg) => {
                if (ok) say("Режим: " + p.text + " — " + p.sub)
                else { fakeProfile = ""; curProfile = was; say(msg.indexOf("tmpfiles") >= 0 ? "Нужен один шаг через sudo (правило частоты ЦП)" : "Не удалось: " + (msg.slice(0, 60) || "yumi-power-profile"), true, 6) }
                profProc.running = true
            })
    }
    function setWorkflow(name) {
        if (name === wfCur || busy) return
        const title = (workflowInfo[name] || ["", name])[1]
        wfBusy = name
        say("Применяю «" + title + "»…", false, 30)
        run([bin + "yumi-workflow", "set", name], (ok, msg) => {
            wfBusy = ""
            if (ok && dry) fakeWorkflow = name
            if (ok) say("Workflow: " + title); else say("Не удалось: " + (msg.slice(0, 60) || "yumi-workflow"), true, 6)
            wfProc.running = true
        })
    }
    property int fakeLimit: 0
    // 29.10: FileView не перечитывает sysfs после записи — меню «не видело» нового предела (плашка не ехала, второе нажатие
    // игнорировалось). После успешной записи держим выбранное значение сами, пока чтение sysfs его не подтвердит.
    property int limitSet: 0
    readonly property int limit: (dry && fakeLimit) ? fakeLimit : (limitSet || bat.limit)
    Connections { target: bat; function onLimitChanged() { if (win.limitSet && bat.limit === win.limitSet) win.limitSet = 0 } }
    function setLimit(n) {
        if (n === limit || busy) return
        limitSet = n                                   // плашка переезжает сразу; при ошибке — назад
        run([bin + "yumi-battery-limit", String(n)], (ok) => {
            if (ok && dry) fakeLimit = n
            if (!ok) limitSet = 0
            bat.fLimit.reload()
            say(n === 80 ? "Зарядка до 80 %" : "Зарядка до 100 %", !ok)
        })
    }

    // ---- живые графики: точка раз в 2 с, пока меню открыто (последние 45 = 1,5 мин) ----
    property var hPower: []
    property var hTemp: []
    function pushHist() {
        const p = hPower.slice(-44); p.push(bat.rate || 0); hPower = p
        // температура: пока датчик не прочитан — не рисовать ложный ноль
        if (bat.temp) { const t = hTemp.slice(-44); t.push(bat.temp); hTemp = t }
    }
    function seedHist() { if (hPower.length < 2) { pushHist(); pushHist() } }
    Timer { interval: 2000; repeat: true; running: win.open; onTriggered: win.pushHist() }


    // ---- элементы для клавиатуры: строка r, центр cx (0..1) ----
    readonly property var tiles: {
        const t = [ { key: "bat",    r: 0, cx: 0.5,  title: "Батарея" },
                    { key: "health", r: 1, cx: 0.25, title: "Здоровье" },
                    { key: "power",  r: 1, cx: 0.75, title: "Мощность" },
                    { key: "cap",    r: 2, cx: 0.25, title: "Ёмкость" },
                    { key: "temp",   r: 2, cx: 0.75, title: "Температура" } ]
        profiles.forEach((p, i) => t.push({ key: "p:" + p.key, r: 3, cx: (i + 0.5) / profiles.length, title: p.text }))
        ;[80, 100].forEach((n, i) => t.push({ key: "l:" + n, r: 4, cx: (i + 0.5) / 2, title: n + " %" }))
        workflows.forEach((w, i) => t.push({ key: "w:" + w, r: 5 + i, cx: 0.5, title: (workflowInfo[w] || ["", w])[1] }))
        return t
    }
    readonly property var zoomable: ["bat", "health", "power", "cap", "temp"]
    readonly property var zoomTitle: ({ bat: "Батарея", health: "Здоровье", power: "Мощность", cap: "Ёмкость", temp: "Температура" })
    readonly property int lastRow: tiles.length ? tiles[tiles.length - 1].r : 0
    property string selKey: "bat"
    readonly property int sel: Math.max(0, tiles.findIndex(t => t.key === selKey))
    property string zoom: ""                 // раскрытый показатель ("" — панель)

    function activate(k) {
        selKey = k
        if (zoomable.indexOf(k) >= 0) zoom = k
        else if (k.startsWith("p:")) setProfile(k.slice(2))
        else if (k.startsWith("l:")) setLimit(parseInt(k.slice(2)))
        else if (k.startsWith("w:")) setWorkflow(k.slice(2))
    }
    function rowOf(r) { return tiles.filter(x => x.r === r).sort((a, b) => a.cx - b.cx) }
    function nav(d) {
        const t = tiles[sel]
        if (!t) return
        if (d === "left" || d === "right") {
            const row = rowOf(t.r), k = row.findIndex(x => x.key === t.key) + (d === "right" ? 1 : -1)
            if (k >= 0 && k < row.length) selKey = row[k].key
            else if (d === "right" && t.r < lastRow) selKey = rowOf(t.r + 1)[0].key
            else if (d === "left" && t.r > 0) { const p = rowOf(t.r - 1); selKey = p[p.length - 1].key }
            return
        }
        const r = t.r + (d === "down" ? 1 : -1)
        if (r < 0 || r > lastRow) return
        let best = null, dist = 9
        rowOf(r).forEach(x => { const dd = Math.abs(x.cx - t.cx); if (dd < dist) { dist = dd; best = x } })
        if (best) selKey = best.key
    }
    function key(k) {
        if (zoom) { if (k === "esc" || k === "enter" || k === "space") zoom = ""; return }
        if (k === "esc") Menus.close("power")
        else if (k === "enter" || k === "space") activate(selKey)
        else nav(k)
    }
    function num(v, n) { return v.toFixed(n).replace(".", ",") }

    IpcHandler {
        target: "power"
        function key(name: string): void { win.key(name) }
        function state(): string {
            return JSON.stringify({ open: win.open, sel: win.selKey, zoom: win.zoom, pct: Math.round(bat.pct),
                                    state: bat.state, profile: win.profile, workflow: win.wfCur, limit: win.limit, hist: win.hPower.length })
        }
    }

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true
        Keys.onPressed: (e) => {
            const m = { [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Up]: "up", [Qt.Key_Down]: "down",
                        [Qt.Key_Return]: "enter", [Qt.Key_Enter]: "enter", [Qt.Key_Space]: "space", [Qt.Key_Escape]: "esc" }[e.key]
            if (!m) return
            win.key(m); e.accepted = true
        }

        ColumnLayout {
            id: col
            width: parent.width
            spacing: 12

            CardHead {
                title: "Батарея и питание"; dry: win.dry
                status: win.toast || (Math.round(bat.pct) + " % · " + bat.stateWord + (bat.timeWord ? " · " + bat.timeWord : "") + " · " + win.profileInfo.text)
                statusColor: win.toast ? (win.toastError ? Colors.bad : Colors.acc) : Colors.fgDim
            }

            Item {
                id: board
                Layout.fillWidth: true
                implicitHeight: win.zoom ? zoomCol.implicitHeight + 28 : panel.implicitHeight
                clip: true
                Behavior on implicitHeight { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

                ColumnLayout {
                    id: panel
                    width: parent.width
                    spacing: 12
                    opacity: win.zoom ? 0 : 1
                    scale: win.zoom ? 0.97 : 1
                    Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                    Behavior on scale { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }

                    // ---- заряд крупно и полоса ----
                    Casc {
                        index: 0
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 56; radius: Theme.radius
                            color: win.selKey === "bat" ? Colors.alpha(Colors.acc, 0.10) : (bma.containsMouse ? Colors.isl2 : "transparent")
                            border.width: win.selKey === "bat" ? 1 : 0; border.color: Colors.alpha(Colors.acc, 0.7)
                            Behavior on color { ColorAnimation { duration: Theme.fast } }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6
                                spacing: 14
                                Text { text: Math.round(bat.pct) + "%"; Layout.minimumWidth: 92
                                       font.family: Theme.fontUi; font.pixelSize: 40; font.weight: Font.DemiBold; font.features: ({ "tnum": 1 }); color: Colors.fg }
                                Rectangle {
                                    Layout.fillWidth: true; implicitHeight: 14; radius: 7
                                    color: Colors.alpha(Colors.fg, 0.14)
                                    Rectangle {
                                        height: parent.height; radius: 7
                                        width: Math.max(14, parent.width * (win.open ? Math.max(0, Math.min(100, bat.pct)) / 100 : 0))
                                        color: win.tone
                                        Behavior on width { NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                                        Behavior on color { ColorAnimation { duration: Theme.normal } }
                                    }
                                }
                                Glyph { visible: bat.onAc; text: "󱐋"; font.pixelSize: 16; color: Colors.acc }
                            }
                            MouseArea { id: bma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { win.activate("bat"); scope.forceActiveFocus() } }
                        }
                    }

                    // ---- показатели 2×2 ----
                    Casc {
                        index: 1
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2; columnSpacing: 8; rowSpacing: 8
                            Stat { k: "health"; label: "Здоровье" + (bat.cycles ? " · " + bat.cycles + " циклов" : "")
                                   value: bat.health ? bat.health.toFixed(0) + " %" : "—" }
                            Stat { k: "power"; label: bat.onAc ? "Мощность" : "Расход"; value: bat.sign + win.num(bat.rate, 1) + " Вт"
                                   spark: win.hPower; sparkMax: 30 }
                            Stat { k: "cap"; label: "Ёмкость сейчас / новой"
                                   value: (bat.energyFull && bat.energyDesign) ? win.num(bat.energyFull, 1) + " / " + win.num(bat.energyDesign, 1) + " Вт·ч" : "—" }
                            Stat { k: "temp"; label: "Температура"; value: bat.temp ? bat.temp.toFixed(0) + " °C" : "—"
                                   spark: win.hTemp; sparkMax: 60; sparkRange: true }
                        }
                    }

                    Casc {
                        index: 2
                        ISection { text: "Профиль" }
                        SegKb { model: win.profiles.map(p => p.text); current: win.profileIndex; prefix: "p:"; keys: win.profiles.map(p => p.key) }
                    }

                    Casc {
                        index: 3
                        ISection { text: "Зарядка" }
                        SegKb { model: ["до 80 %", "до 100 %"]; current: win.limit >= 100 ? 1 : 0; prefix: "l:"; keys: ["80", "100"] }
                        Text { Layout.fillWidth: true; text: "80 % бережёт батарею, если подолгу от сети"; elide: Text.ElideRight
                               font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim }
                    }

                    Casc {
                        index: 4
                        spacing: 2
                        ISection { text: "Рабочий режим"; Layout.bottomMargin: 4 }
                        Repeater {
                            model: win.workflows
                            IRow {
                                id: wfRow
                                required property string modelData
                                readonly property var info: win.workflowInfo[modelData] || ["󰍹", modelData, "", ""]
                                readonly property bool current: modelData === win.wfCur
                                icon: info[0]; title: info[1]
                                sub: win.wfBusy === modelData ? "Применяю…" : info[3]
                                sel: current; kb: win.selKey === "w:" + modelData
                                onClicked: { win.activate("w:" + modelData); scope.forceActiveFocus() }
                                Glyph {
                                    visible: win.wfBusy === wfRow.modelData
                                    text: "󰑓"; color: Colors.acc; font.pixelSize: 15
                                    RotationAnimation on rotation { running: win.wfBusy === wfRow.modelData; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                                }
                                IToggle {
                                    on: wfRow.current
                                    // выключить текущий = вернуться к обычному режиму
                                    onToggled: { if (wfRow.current) { if (wfRow.modelData !== "01-default") win.setWorkflow("01-default") }
                                                 else win.activate("w:" + wfRow.modelData)
                                                 scope.forceActiveFocus() }
                                }
                            }
                        }
                    }
                }

                // ---- раскрытый показатель: растёт на месте панели ----
                Rectangle {
                    id: zoomBox
                    anchors.fill: parent
                    radius: Theme.radiusTile
                    color: Colors.isl2
                    visible: opacity > 0.01
                    opacity: win.zoom ? 1 : 0
                    scale: win.zoom ? 1 : 0.92
                    Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                    Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                    MouseArea { anchors.fill: parent; enabled: !!win.zoom }
                    ColumnLayout {
                        id: zoomCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                        spacing: 12
                        CardHead { back: true; title: win.zoomTitle[win.zoom] || ""; onBackClicked: { win.zoom = ""; scope.forceActiveFocus() } }
                        Loader {
                            Layout.fillWidth: true
                            active: !!win.zoom
                            sourceComponent: ({ bat: zBat, power: zPower, health: zHealth, cap: zHealth, temp: zTemp })[win.zoom] || null
                        }
                    }
                }
            }

            CardHints {
                items: win.zoom ? [["Esc", "назад"]] : [["←→↑↓", "выбор"], ["↵", "применить"], ["Esc", "закрыть"]]
            }
        }
    }

    // ================= части =================
    component Casc: ColumnLayout {      // каскад при открытии: opacity + y 8 px, 40 мс на блок
        id: cc
        property int index: 0
        Layout.fillWidth: true
        spacing: 8
        opacity: win.open ? 1 : 0
        property real dy: win.open ? 0 : 8
        transform: Translate { y: cc.dy }
        Behavior on opacity { SequentialAnimation { PauseAnimation { duration: win.open ? Theme.contentDelay + cc.index * Theme.cascade : 0 }
                                                    NumberAnimation { duration: 280; easing.type: Easing.OutCubic } } }
        Behavior on dy { SequentialAnimation { PauseAnimation { duration: win.open ? Theme.contentDelay + cc.index * Theme.cascade : 0 }
                                               NumberAnimation { duration: 280; easing.type: Easing.OutCubic } } }
    }
    component Stat: IStat {             // плитка показателя: клик — подробнее; фокус клавиатуры — кромка; справа внизу — живой график
        id: stt
        property string k: ""
        property var spark: null
        property real sparkMax: 10
        property bool sparkRange: false
        Layout.preferredWidth: 1
        border.width: win.selKey === k ? 1 : 0; border.color: Colors.alpha(Colors.acc, 0.7)
        color: sma.containsMouse ? Colors.hover : Colors.isl2
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        scale: sma.pressed ? 0.97 : 1
        Behavior on scale { NumberAnimation { duration: Theme.fast } }
        Spark { visible: !!stt.spark; anchors { right: parent.right; bottom: parent.bottom; rightMargin: 10; bottomMargin: 10 }
                width: parent.width * 0.36; height: 18; values: stt.spark || []; max: stt.sparkMax; range: stt.sparkRange; tone: Colors.acc }
        MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { win.activate(stt.k); scope.forceActiveFocus() } }
    }
    component SegKb: ISeg {             // сегменты + рамка выбора с клавиатуры
        id: sk
        property string prefix: ""
        property var keys: []
        readonly property int kbi: win.selKey.startsWith(prefix) ? keys.indexOf(win.selKey.slice(prefix.length)) : -1
        onPicked: (i) => { win.activate(prefix + keys[i]); scope.forceActiveFocus() }
        Rectangle {
            visible: sk.kbi >= 0
            x: 4 + Math.max(0, sk.kbi) * (sk.cw + 4); y: 4; width: sk.cw; height: sk.height - 8; radius: 12
            color: "transparent"; border.width: 1.5; border.color: sk.kbi === sk.current ? Colors.onAcc : Colors.acc
            Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
        }
    }
    // строки «название — значение» в два столбца
    component Facts: GridLayout {
        id: facts
        property var rows: []
        columns: 2; columnSpacing: 12; rowSpacing: 8
        Repeater {
            model: facts.rows
            ColumnLayout {
                required property var modelData
                Layout.fillWidth: true; Layout.preferredWidth: 1; spacing: 0
                Text { text: modelData[0]; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: modelData[1]; font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium; font.features: ({ "tnum": 1 })
                       color: Colors.fg; elide: Text.ElideRight; Layout.fillWidth: true }
            }
        }
    }
    Component {
        id: zBat
        RowLayout {
            spacing: 14
            BatteryRing { pct: bat.pct; open: win.open; tone: win.tone; implicitWidth: 84; implicitHeight: 84; thickness: 7; Layout.alignment: Qt.AlignTop }
            Facts { Layout.fillWidth: true
                rows: [ ["Питание",      bat.onAc ? "от сети" : "от батареи"],
                        ["Мощность",     bat.sign + win.num(bat.rate, 1) + " Вт"],
                        ["Напряжение",   bat.voltage ? win.num(bat.voltage, 2) + " В" : "—"],
                        ["Запас энергии", (bat.energy && bat.energyFull) ? win.num(bat.energy, 1) + " из " + win.num(bat.energyFull, 1) + " Вт·ч" : "—"],
                        ["Здоровье",     bat.health ? win.num(bat.health, 1) + " %" : "—"],
                        ["Циклы заряда", bat.cycles ? String(bat.cycles) : "—"],
                        ["Модель",       bat.model || "—"],
                        ["Изготовлена",  bat.made || "—"],
                        ["Температура",  bat.temp ? win.num(bat.temp, 1) + " °C" : "—"],
                        ["Время",        bat.timeWord || "—"] ] }
        }
    }
    Component {
        id: zPower
        ColumnLayout {
            spacing: 10
            Spark { Layout.fillWidth: true; Layout.preferredHeight: 90; values: win.hPower; max: 30; tone: Colors.acc; grid: true }
            Facts { Layout.fillWidth: true
                rows: [ ["Сейчас", bat.sign + win.num(bat.rate, 1) + " Вт"], ["Напряжение", bat.voltage ? win.num(bat.voltage, 2) + " В" : "—"],
                        ["Запас энергии", (bat.energy && bat.energyFull) ? win.num(bat.energy, 1) + " из " + win.num(bat.energyFull, 1) + " Вт·ч" : "—"],
                        ["Время", bat.timeWord || "—"] ] }
        }
    }
    Component {
        id: zHealth
        Facts {
            rows: [ ["Здоровье", bat.health ? win.num(bat.health, 1) + " %" : "—"],
                    ["Ёмкость сейчас / новой", (bat.energyFull && bat.energyDesign) ? win.num(bat.energyFull, 1) + " / " + win.num(bat.energyDesign, 1) + " Вт·ч" : "—"],
                    ["Циклы заряда", bat.cycles ? String(bat.cycles) : "—"], ["Модель", bat.model || "—"], ["Изготовлена", bat.made || "—"] ]
        }
    }
    Component {
        id: zTemp
        ColumnLayout {
            spacing: 10
            Spark { Layout.fillWidth: true; Layout.preferredHeight: 90; values: win.hTemp; max: 60; tone: Colors.acc; grid: true; range: true }
            Facts { Layout.fillWidth: true; rows: [ ["Температура батареи", bat.temp ? win.num(bat.temp, 1) + " °C" : "—"], ["Состояние", bat.stateWord] ] }
        }
    }
    // живой график: заливка акцентом 22 % и линия, шкала от 0 до max (или по разбросу данных)
    component Spark: Canvas {
        id: sp
        property var values: []
        property real max: 10
        property color tone: Colors.acc
        property bool grid: false
        property bool range: false
        onValuesChanged: requestPaint()
        onToneChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d"); ctx.reset()
            const d = values || [], w = width, h = height
            if (w < 2 || h < 2) return
            if (grid) {
                ctx.strokeStyle = Colors.alpha(Colors.fg, 0.06); ctx.lineWidth = 1
                for (let i = 1; i < 4; i++) { const y = Math.round(h * i / 4) + 0.5; ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke() }
            }
            if (d.length < 2) return
            const hi = Math.max.apply(null, d), lo = Math.min.apply(null, d)
            const bot = range ? lo - Math.max(1.5, (hi - lo) * 0.3) : 0
            const top = range ? hi + Math.max(1.5, (hi - lo) * 0.3) : Math.max(sp.max * 0.25, hi * 1.15, 0.1)
            const n = 44, stepX = w / n, x0 = w - (d.length - 1) * stepX
            const pts = d.map((v, i) => [x0 + i * stepX, h - 2 - Math.max(0, Math.min(1, (v - bot) / (top - bot))) * (h - 6)])
            ctx.beginPath(); ctx.moveTo(pts[0][0], h)
            for (const p of pts) ctx.lineTo(p[0], p[1])
            ctx.lineTo(pts[pts.length - 1][0], h); ctx.closePath()
            ctx.fillStyle = Colors.alpha(sp.tone, 0.22); ctx.fill()
            ctx.beginPath(); ctx.moveTo(pts[0][0], pts[0][1])
            for (const p of pts) ctx.lineTo(p[0], p[1])
            ctx.strokeStyle = sp.tone; ctx.lineWidth = 2; ctx.lineJoin = "round"; ctx.stroke()
        }
    }
}
