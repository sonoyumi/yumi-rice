import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services
import qs.menus.wifi
import qs.menus.power
import "Dash.js" as Dash

// «Процессы» / «Монитор системы» — «Остров» (29.10): график процессора (заливка акцентом 22 %, линия акцентом) в подложке,
// под ним загрузка ядер столбиками на пружине (/proc/stat, CoreStat), показатели плитками IStat 2×2 (память, температура,
// нагрузка, время работы), таблица самых тяжёлых приложений (Процесс · ЦП · Память; клик по заголовку — сортировка) и btop.
// Enter (или клик) — датчик увеличивается на месте: графики за ~1,5 мин и подробности; «Приложения» — весь список
// (сортировка «По памяти / По CPU»), Enter на строке — страница приложения: PID, процессы, PSS, CPU, время, потоки,
// команда (Enter — скопировать), «Завершить» (SIGTERM) и «Убить» (SIGKILL, с подтверждением).
// Клавиши: ←→↑↓ — датчик; в списке ↑↓ — строка (↑ с первой — переключатель сортировки), ←→ — сортировка, Enter — открыть;
// на странице ↑↓ (←→) — кнопка, Enter — нажать; Esc — назад, на панели — закрыть.
// Данные — бэкенд ~/.local/lib/yumi/qs/top (только пока меню открыто). Окно — под пилюлей CPU: qs -c yumi ipc call top toggle <x>;
// qs -c yumi ipc call menu toggle top — с прошлым/стандартным положением. Esc и клик вне окна закрывают.
// Проверка: YP_DRYRUN=1 (сигналы не шлются), YP_TOP_SORT=cpu, YP_TOP_PAGE=1 (сразу страница первого),
// YP_TOP_CONFIRM=1 (сразу вопрос «Убить»), YP_TOP_ACT=TERM|KILL (с dry-run: «нажать» через 1,5 с);
// IPC: qs -c yumi ipc call top page <имя> | sort mem|cpu | key left|right|up|down|enter|esc | state.
Scope {
    id: menu
    readonly property bool open: Menus.current === "top"
    property int anchorX: 392                        // середина пилюли CPU (логические px), обновляет Bar через IPC
    property string toast: ""
    property bool toastError: false
    property bool confirm: false
    readonly property bool dry: td.dry
    readonly property string home: Quickshell.env("HOME")

    TopData { id: td; active: menu.open; sort: Quickshell.env("YP_TOP_SORT") === "cpu" ? "cpu" : "mem" }
    Connections {
        target: td
        function onSample(cpu, ram) { if (!menu.cpuHist.length) menu.sampleNow() }
        function onAppsReadyChanged() {
            if (td.appsReady && Quickshell.env("YP_TOP_PAGE") && !menu.autoOpened && td.rows.count) { menu.autoOpened = true; menu.openApp(td.rows.get(0).name) }
        }
        function onResult(sig, name, ok, msg, n, dryRun) {
            menu.confirm = false; menu.asel = 1
            if (ok) menu.say((sig === "TERM" ? "Отправлен сигнал закрытия: " : "Убито: ") + name + " (" + n + " проц.)" + (dryRun ? " — dry-run" : ""))
            else menu.say("Не удалось: " + msg, true, 4)
        }
    }
    property bool autoOpened: false

    // ---- истории для графиков: точка раз в 2 с, только пока меню открыто ----
    property var cpuHist: []
    property var ramHist: []
    property var tempHist: []
    function sampleNow() {
        if (!td.ready) return
        cpuHist = Dash.push(cpuHist, td.cpu)
        ramHist = Dash.push(ramHist, td.ram)
        if (td.temp) tempHist = Dash.push(tempHist, td.temp[0])
    }
    Timer { interval: 2000; repeat: true; running: menu.open; onTriggered: menu.sampleNow() }

    onOpenChanged: {
        if (open) {
            cpuHist = []; ramHist = []; tempHist = []
            confirm = false; toast = ""; zoom = -1; sel = 0; lsel = 0; asel = 1
            if (td.page) td.setPage("")
            scope.forceActiveFocus()
        }
    }
    function say(text, error, hold) { toast = text; toastError = !!error; toastTimer.interval = (hold || 3) * 1000; toastTimer.restart() }
    Timer { id: toastTimer; onTriggered: menu.toast = "" }

    // ---- датчики: строка, столбец, ширина в столбцах ----
    readonly property var tiles: [
        // «Остров»: график (во всю ширину), плитки 2×2, таблица приложений, btop
        { key: "cpu",  r: 0, c: 0, w: 2, title: "Процессор" },
        { key: "ram",  r: 1, c: 0, w: 1, title: "Память" },
        { key: "temp", r: 1, c: 1, w: 1, title: "Температура" },
        { key: "load", r: 2, c: 0, w: 1, title: "Нагрузка" },
        { key: "up",   r: 2, c: 1, w: 1, title: "Работает" },
        { key: "apps", r: 3, c: 0, w: 2, title: "Приложения" },
        { key: "btop", r: 4, c: 0, w: 2, title: "Монитор btop" } ]
    readonly property int appsIdx: 5
    property int sel: 0
    property int zoom: -1                  // увеличенный датчик (-1 — панель)
    readonly property string zkey: zoom >= 0 ? tiles[zoom].key : ""
    property int lsel: 0                   // «Приложения»: строка списка; -1 — переключатель сортировки
    property int asel: 1                   // страница приложения: 0 — команда, 1 — Завершить, 2 — Убить; в вопросе: 0 — Убить, 1 — Отмена
    readonly property var info: td.info
    readonly property bool canAct: !!info && !info.prot && !info.gone

    function openApp(name) {
        confirm = false; asel = 1
        zoom = appsIdx; sel = appsIdx
        td.setPage(name)
        if (Quickshell.env("YP_TOP_CONFIRM")) confirmTimer.restart()
        const act = Quickshell.env("YP_TOP_ACT")
        if ((act === "TERM" || act === "KILL") && dry) { actTimer.sig = act; actTimer.restart() }
    }
    function back() { confirm = false; td.setPage("") }
    Timer { id: confirmTimer; interval: 300; onTriggered: if (td.info && !td.info.prot) { menu.confirm = true; menu.asel = 0 } }
    Timer { id: actTimer; interval: 1500; property string sig: ""; onTriggered: if (td.page) td.signal(td.page, sig) }
    function btop() {
        if (dry) { say("dry-run: btop"); return }
        Quickshell.execDetached(["env", "-u", "LD_PRELOAD", "kitty", "--class", "btop", "-e", "btop"])
        Menus.close("top")
    }
    function copyCmd() { if (info && info.cmd) { Quickshell.execDetached(["wl-copy", info.cmd]); say("Команда скопирована", false, 2) } }
    function pressPage(i) {
        if (i === 0) copyCmd()
        else if (!canAct) say(info && info.prot ? "Системное — закрывать из меню нельзя" : "Процесс уже завершился", true, 2)
        else if (i === 1) { confirm = false; td.signal(td.page, "TERM") }
        else { confirm = true; asel = 0 }
    }
    function activate(i) {
        sel = i
        const k = tiles[i].key
        if (k === "btop") { btop(); return }
        zoom = i
        if (k === "apps") lsel = td.rows.count ? 0 : -1
    }

    function key(k) {
        if (zoom < 0) {
            if (k === "esc") Menus.close("top")
            else if (k === "enter" || k === "space") activate(sel)
            else sel = Dash.nav(tiles, sel, k)
            return
        }
        if (zkey !== "apps") { if (k === "esc" || k === "enter" || k === "space") zoom = -1; return }
        if (td.page) {
            if (confirm) {
                if (k === "left" || k === "right" || k === "up" || k === "down") asel = asel ? 0 : 1
                else if (k === "enter" || k === "space") { if (asel === 0) td.signal(td.page, "KILL"); else { confirm = false; asel = 2 } }
                else if (k === "esc") { confirm = false; asel = 2 }
                return
            }
            if (k === "up") asel = Math.max(0, asel - 1)
            else if (k === "down") asel = Math.min(2, Math.max(1, asel + 1))
            else if (k === "left") asel = asel === 2 ? 1 : asel
            else if (k === "right") asel = asel === 1 ? 2 : asel
            else if (k === "enter" || k === "space") pressPage(asel)
            else if (k === "esc") back()
            return
        }
        if (k === "esc") zoom = -1
        else if (k === "up") lsel = Math.max(-1, lsel - 1)
        else if (k === "down") lsel = Math.min(td.rows.count - 1, lsel + 1)
        else if (k === "left" || k === "right") td.sort = td.sort === "mem" ? "cpu" : "mem"
        else if (k === "enter" || k === "space") { if (lsel < 0) td.sort = td.sort === "mem" ? "cpu" : "mem"; else if (lsel < td.rows.count) openApp(td.rows.get(lsel).name) }
    }

    IpcHandler {
        target: "top"
        function toggle(x: int): void { if (x > 0) menu.anchorX = x; Menus.toggle("top") }
        function page(name: string): void { if (name) menu.openApp(name); else menu.back() }
        function sort(key: string): void { td.sort = key === "cpu" ? "cpu" : "mem" }
        function key(name: string): void { menu.key(name) }
        function state(): string {
            return JSON.stringify({ open: menu.open, sel: menu.tiles[menu.sel].key, zoom: menu.zkey, lsel: menu.lsel, sort: td.sort,
                                    page: td.page, asel: menu.asel, confirm: menu.confirm, rows: td.rows.count,
                                    cpu: Math.round(td.cpu), hist: menu.cpuHist.length, toast: menu.toast })
        }
    }

    function subtitle() {
        if (toast) return toast
        if (td.page) {
            const i = td.info
            if (!i) return "…"
            if (i.gone) return "Завершено"
            return "PID " + i.pid + " · CPU " + Math.round(i.pct) + "% · " + td.fmtSize(i.mem)
        }
        if (!td.ready) return "Нагрузка …"
        return "Нагрузка " + td.load.map(x => x.toFixed(2).replace(".", ",")).join(" · ") + " · ЦП " + Math.round(td.cpu) + " %"
    }
    function tone(lv) { return lv === "crit" ? Colors.bad : lv === "warn" ? Colors.warn : Colors.acc }
    readonly property string tempLv: td.temp ? (td.temp[0] >= 85 ? "crit" : td.temp[0] >= 70 ? "warn" : "") : ""

    CoreStat { id: cores; active: menu.open }

    DashPopup {
        side: "left"
        id: pop
        name: "top"
        open: menu.open
        screen: Menus.screen
        contentW: 440                            // «Остров»: как в превью
        pad: 18
        marginTop: Theme.barH * (Theme.dev ? 2 : 1) + 6
        readonly property int screenW: Menus.screen ? Menus.screen.width : 1600
        marginLeft: Math.max(20, Math.min(menu.anchorX - contentW / 2, screenW - contentW - 20))   // карточка по центру под пилюлей, не вылезая за край
        contentH: col.implicitHeight + pad * 2

        FocusScope {
            id: scope
            anchors.fill: parent
            focus: true
            Keys.onPressed: (e) => {
                const m = { [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Up]: "up", [Qt.Key_Down]: "down",
                            [Qt.Key_Return]: "enter", [Qt.Key_Enter]: "enter", [Qt.Key_Space]: "space", [Qt.Key_Escape]: "esc" }[e.key]
                if (!m) return
                menu.key(m); e.accepted = true
            }

            ColumnLayout {
                id: col
                width: parent.width
                spacing: 12

                CardHead {
                    title: "Монитор системы"; dry: menu.dry
                    status: menu.subtitle()
                    statusColor: menu.toast ? (menu.toastError ? Colors.bad : Colors.acc) : Colors.fgDim
                }

                Item {
                    id: board
                    Layout.fillWidth: true
                    implicitHeight: menu.zoom >= 0 ? zoomCol.implicitHeight + 28 : panel.implicitHeight
                    Behavior on implicitHeight { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.05 } }
                    clip: true

                    ColumnLayout {
                        id: panel
                        width: parent.width
                        spacing: 12
                        opacity: menu.zoom >= 0 ? 0 : 1
                        scale: menu.zoom >= 0 ? 0.97 : 1
                        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                        Behavior on scale { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }

                        // ---- процессор: график и ядра ----
                        Casc {
                            index: 0
                            Sel {
                                k: 0
                                Layout.fillWidth: true
                                implicitHeight: 90
                                color: Colors.isl2
                                clip: true
                                PowerMenu.Spark { anchors.fill: parent; anchors.topMargin: 10; values: menu.cpuHist; max: 100; tone: menu.tone(td.level(td.cpu)) }
                                Text { x: 12; y: 8; text: td.ready ? "ЦП " + Math.round(td.cpu) + " %" : "ЦП …"; font.family: Theme.fontUi; font.pixelSize: 11
                                       font.features: ({ "tnum": 1 }); color: Colors.fgDim }
                            }
                            Cores { Layout.fillWidth: true; Layout.preferredHeight: 44 }
                        }

                        // ---- показатели ----
                        Casc {
                            index: 1
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2; columnSpacing: 8; rowSpacing: 8
                                Stat { k: 1; label: "Память"; value: td.ready ? menu.comma(td.fmtGb(td.used)) + " / " + menu.comma(td.fmtGb(td.total)) + " ГБ" : "…" }
                                Stat { k: 2; label: "Температура"; value: td.temp ? Math.round(td.temp[0]) + " °C" : "—" }
                                Stat { k: 3; label: "Нагрузка 1 / 5 / 15"; value: td.load.map(x => menu.comma(x.toFixed(2))).join(" · ") }
                                Stat { k: 4; label: "Работает"; value: td.ready ? td.fmtDuration(td.up) : "…" }
                            }
                        }

                        // ---- приложения: таблица ----
                        Casc {
                            index: 2
                            Sel {
                                k: menu.appsIdx
                                Layout.fillWidth: true
                                implicitHeight: procCol.implicitHeight + 16
                                color: menu.zoom < 0 && menu.sel === menu.appsIdx ? Colors.alpha(Colors.acc, 0.08) : "transparent"
                                ColumnLayout {
                                    id: procCol
                                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                                    spacing: 2
                                    ProcHead {}
                                    Text { visible: !td.appsReady; leftPadding: 4; text: "Считаю процессы…"; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim }
                                    Repeater {
                                        model: td.rows
                                        ProcRow {
                                            required property var model
                                            required property int index
                                            visible: index < 5
                                            name: model.name; icon: model.icon; pct: model.pct; mem: model.mem; prot: model.prot
                                            onClicked: { menu.sel = menu.appsIdx; menu.lsel = index; menu.openApp(model.name); scope.forceActiveFocus() }
                                        }
                                    }
                                }
                            }
                            IRow {
                                icon: "󰄨"; title: "Монитор btop"
                                sub: td.hidden.length ? "Скрыто системных: " + td.hidden.length : "все процессы в терминале"
                                kb: menu.zoom < 0 && menu.sel === 6
                                onClicked: { menu.activate(6); scope.forceActiveFocus() }
                                Glyph { text: "󰏌"; font.pixelSize: 15; color: Colors.fgDim }
                            }
                        }
                    }

                    // ---- раскрытый показатель / список / страница приложения ----
                    Rectangle {
                        id: zoomBox
                        anchors.fill: parent
                        radius: Theme.radiusTile
                        color: Colors.isl2
                        visible: opacity > 0.01
                        opacity: menu.zoom >= 0 ? 1 : 0
                        scale: menu.zoom >= 0 ? 1 : 0.92
                        Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                        Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                        MouseArea { anchors.fill: parent; enabled: menu.zoom >= 0 }
                        ColumnLayout {
                            id: zoomCol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                            spacing: 12
                            CardHead {
                                back: true
                                title: menu.zkey === "apps" && td.page ? td.page : menu.zoom >= 0 ? menu.tiles[menu.zoom].title : ""
                                onBackClicked: { if (menu.zkey === "apps" && td.page) menu.back(); else menu.zoom = -1; scope.forceActiveFocus() }
                            }
                            Loader {
                                Layout.fillWidth: true
                                active: menu.zoom >= 0
                                sourceComponent: menu.zkey === "apps" ? (td.page ? zPage : zList)
                                               : ({ cpu: zCpu, ram: zRam, temp: zTemp, load: zLoad, up: zUp })[menu.zkey] || null
                            }
                        }
                    }
                }

                CardHints {
                    items: menu.zkey === "apps" && td.page ? (menu.confirm ? [["←→", "выбор"], ["↵", "подтвердить"], ["Esc", "отмена"]] : [["↑↓", "кнопка"], ["↵", "нажать"], ["Esc", "назад"]])
                         : menu.zkey === "apps" ? [["↑↓", "строка"], ["←→", "сортировка"], ["↵", "открыть"], ["Esc", "назад"]]
                         : menu.zoom >= 0 ? [["Esc", "к панели"]] : [["←→↑↓", "выбор"], ["↵", "подробнее"], ["Esc", "закрыть"]]
                    note: menu.zkey === "apps" && td.page && !menu.confirm ? "Завершить — SIGTERM, Убить — SIGKILL" : ""
                }
            }
        }
    }

    function comma(s) { return String(s).replace(".", ",") }

    // ================= части =================
    component Casc: ColumnLayout {      // каскад при открытии: opacity + y 8 px, 40 мс на блок
        id: cc
        property int index: 0
        Layout.fillWidth: true
        spacing: 8
        opacity: menu.open ? 1 : 0
        property real dy: menu.open ? 0 : 8
        transform: Translate { y: cc.dy }
        Behavior on opacity { SequentialAnimation { PauseAnimation { duration: menu.open ? Theme.contentDelay + cc.index * Theme.cascade : 0 }
                                                    NumberAnimation { duration: 280; easing.type: Easing.OutCubic } } }
        Behavior on dy { SequentialAnimation { PauseAnimation { duration: menu.open ? Theme.contentDelay + cc.index * Theme.cascade : 0 }
                                               NumberAnimation { duration: 280; easing.type: Easing.OutCubic } } }
    }
    // выбираемый блок: фокус клавиатуры — кромка акцентом, клик — подробнее
    component Sel: Rectangle {
        id: sb
        property int k: 0
        radius: Theme.radius
        border.width: menu.zoom < 0 && menu.sel === k ? 1 : 0; border.color: Colors.alpha(Colors.acc, 0.7)
        /* выбор — без затухания (29.10) */
        MouseArea { anchors.fill: parent; z: -1; cursorShape: Qt.PointingHandCursor; enabled: menu.zoom < 0; onClicked: { menu.activate(sb.k); scope.forceActiveFocus() } }
    }
    component Stat: IStat {
        id: stt
        property int k: 0
        Layout.preferredWidth: 1
        border.width: menu.zoom < 0 && menu.sel === k ? 1 : 0; border.color: Colors.alpha(Colors.acc, 0.7)
        color: sma.containsMouse ? Colors.hover : Colors.isl2
        /* выбор — без затухания (29.10) */
        scale: sma.pressed ? 0.97 : 1
        Behavior on scale { NumberAnimation { duration: Theme.fast } }
        MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: menu.zoom < 0
                    onClicked: { menu.activate(stt.k); scope.forceActiveFocus() } }
    }
    // ядра столбиками: высота — загрузка, пружина
    component Cores: Item {
        id: cr
        readonly property var v: cores.cores.length ? cores.cores : Array(Math.max(1, td.ncpu)).fill(0)
        Row {
            anchors.fill: parent
            spacing: 5
            Repeater {
                model: cr.v.length
                Item {
                    required property int index
                    width: (cr.width - (cr.v.length - 1) * 5) / cr.v.length; height: cr.height
                    Rectangle {
                        anchors.bottom: parent.bottom; width: parent.width; radius: 5
                        height: Math.max(6, parent.height * (menu.open ? cr.v[index] : 0))
                        color: Colors.acc
                        opacity: 0.55 + 0.45 * cr.v[index]
                        Behavior on height { SpringAnimation { spring: 3; damping: 0.28; epsilon: 0.3 } }
                        Behavior on color { ColorAnimation { duration: Theme.normal } }
                    }
                }
            }
        }
    }
    // таблица: заголовок (клик по ЦП / Память — сортировка)
    component ProcHead: RowLayout {
        Layout.fillWidth: true; Layout.leftMargin: 4; Layout.rightMargin: 4
        spacing: 10
        Text { Layout.fillWidth: true; text: "Процесс"; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim }
        Repeater {
            model: [["ЦП", "cpu", 60], ["Память", "mem", 70]]
            Text {
                required property var modelData
                Layout.preferredWidth: modelData[2]; horizontalAlignment: Text.AlignRight
                text: modelData[0] + (td.sort === modelData[1] ? " ↓" : "")
                font.family: Theme.fontUi; font.pixelSize: 11; font.weight: td.sort === modelData[1] ? Font.DemiBold : Font.Normal
                color: td.sort === modelData[1] ? Colors.fg : Colors.fgDim
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: { td.sort = parent.modelData[1]; scope.forceActiveFocus() } }
            }
        }
    }
    component ProcRow: Rectangle {
        id: pr
        property string name: ""
        property string icon: ""
        property real pct: 0
        property real mem: 0
        property bool prot: false
        property bool kb: false
        signal clicked()
        Layout.fillWidth: true
        implicitHeight: visible ? 30 : 0
        radius: 10
        color: kb ? Colors.alpha(Colors.acc, 0.16) : pma.containsMouse ? Colors.hover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        scale: pma.pressed ? 0.985 : 1
        Behavior on scale { NumberAnimation { duration: Theme.fast } }
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 4
            spacing: 10
            AppIcon { name: pr.name; icon: pr.icon; size: 15 }
            Text { Layout.fillWidth: true; text: pr.name; elide: Text.ElideRight; font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fg }
            Glyph { visible: pr.prot; text: "󰌾"; font.pixelSize: 11; color: Colors.fgDim }
            Text { Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight; text: menu.comma(pr.pct.toFixed(1)) + " %"
                   font.family: Theme.fontUi; font.pixelSize: 12; font.features: ({ "tnum": 1 }); color: td.sort === "cpu" ? Colors.fg : Colors.fgDim }
            Text { Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight; text: td.fmtSize(pr.mem)
                   font.family: Theme.fontUi; font.pixelSize: 12; font.features: ({ "tnum": 1 }); color: td.sort === "mem" ? Colors.fg : Colors.fgDim }
        }
        MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pr.clicked() }
    }
    component Facts: GridLayout {
        id: facts
        property var rows: []
        property int cols: 2
        columns: cols; columnSpacing: 8; rowSpacing: 8
        Repeater {
            model: facts.rows.filter(r => r[0])
            IStat { required property var modelData; Layout.preferredWidth: 1; label: modelData[0]; value: modelData[1]; color: Colors.isl }
        }
    }
    component GBox: Rectangle {
        property alias values: gsp.values
        property alias max: gsp.max
        property alias range: gsp.range
        property alias tone: gsp.tone
        Layout.fillWidth: true; Layout.preferredHeight: 110
        radius: Theme.radius; color: Colors.isl; clip: true
        PowerMenu.Spark { id: gsp; anchors.fill: parent; anchors.topMargin: 8; grid: true }
    }
    component BigNum: Row {
        id: bg
        property string text: ""
        property string unit: ""
        spacing: 4
        Text { id: bt; text: bg.text; font.family: Theme.fontUi; font.pixelSize: 32; font.weight: Font.DemiBold; font.features: ({ "tnum": 1 }); color: Colors.fg }
        Text { anchors.baseline: bt.baseline; text: bg.unit; font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fgDim }
    }

    // ================= увеличенные =================
    Component {
        id: zCpu
        ColumnLayout {
            spacing: 10
            BigNum { text: td.ready ? String(Math.round(td.cpu)) : "…"; unit: "% сейчас" }
            GBox { values: menu.cpuHist; max: 100; tone: menu.tone(td.level(td.cpu)) }
            Facts { Layout.fillWidth: true
                rows: [["Ядер", String(td.ncpu)], ["Нагрузка (1 / 5 / 15)", td.load.map(x => x.toFixed(2)).join(" · ")],
                       ["Работает", td.ready ? td.fmtDuration(td.up) : "…"], ["График", "≈ 1,5 мин, раз в 2 с"]] }
        }
    }
    Component {
        id: zRam
        ColumnLayout {
            spacing: 10
            BigNum { text: td.ready ? String(Math.round(td.ram)) : "…"; unit: "% занято" }
            GBox { values: menu.ramHist; max: 100; tone: menu.tone(td.level(td.ram)) }
            Facts { Layout.fillWidth: true
                rows: [["Занято", td.fmtGb(td.used) + " ГБ"], ["Всего", td.fmtGb(td.total) + " ГБ"],
                       ["Свободно", td.fmtGb(Math.max(0, td.total - td.used)) + " ГБ"], ["Учёт", "как в btop (без кэша)"]] }
        }
    }
    Component {
        id: zTemp
        ColumnLayout {
            spacing: 10
            BigNum { text: td.temp ? String(Math.round(td.temp[0])) : "—"; unit: "°C" }
            GBox { values: menu.tempHist; range: true; tone: menu.tone(menu.tempLv) }
            Facts { Layout.fillWidth: true
                rows: [["Датчик", td.temp ? String(td.temp[1] || "—") : "нет данных"], ["Порог", "70 °C тепло · 85 °C горячо"]] }
        }
    }
    Component {
        id: zLoad
        ColumnLayout {
            spacing: 10
            BigNum { text: td.load[0].toFixed(2); unit: "за 1 мин" }
            Facts { Layout.fillWidth: true; cols: 3
                rows: [["1 минута", td.load[0].toFixed(2)], ["5 минут", td.load[1].toFixed(2)], ["15 минут", td.load[2].toFixed(2)],
                       ["Ядер", String(td.ncpu)], ["На ядро (1 мин)", (td.load[0] / Math.max(1, td.ncpu)).toFixed(2)]] }
        }
    }
    Component {
        id: zUp
        ColumnLayout {
            spacing: 10
            Text { text: td.ready ? td.fmtDuration(td.up) : "…"; font.family: Theme.fontUi; font.pixelSize: 26; font.weight: Font.DemiBold; color: Colors.fg }
            Facts { Layout.fillWidth: true
                rows: [["Включён", td.ready ? Qt.formatDateTime(new Date(Date.now() - td.up * 1000), "dd.MM HH:mm") : "…"], ["Секунд", String(td.up)]] }
        }
    }

    // ---- «Приложения»: весь список ----
    Component {
        id: zList
        ColumnLayout {
            spacing: 8
            ISeg {
                model: ["По памяти", "По CPU"]; current: td.sort === "cpu" ? 1 : 0
                color: Colors.isl
                border.width: menu.lsel < 0 ? 1.5 : 0; border.color: Colors.acc
                onPicked: (i) => { td.sort = i ? "cpu" : "mem"; scope.forceActiveFocus() }
            }
            ProcHead {}
            Text { visible: !td.appsReady; text: "Считаю процессы…"; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim }
            Repeater {
                model: td.rows
                ProcRow {
                    required property var model
                    required property int index
                    name: model.name; icon: model.icon; pct: model.pct; mem: model.mem; prot: model.prot
                    kb: menu.lsel === index
                    onClicked: { menu.lsel = index; menu.openApp(model.name); scope.forceActiveFocus() }
                }
            }
            Text {
                Layout.fillWidth: true; visible: td.hidden.length > 0; elide: Text.ElideRight
                text: "Скрыто (" + td.hidden.length + "): " + td.hidden.join(", ") + " — ~/.config/yumi/top-hide"
                font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim
            }
        }
    }

    // ---- страница приложения ----
    Component {
        id: zPage
        ColumnLayout {
            spacing: 10
            readonly property var info: td.info
            readonly property bool gone: info ? !!info.gone : false
            RowLayout {
                Layout.fillWidth: true; spacing: 12
                Rectangle { implicitWidth: 40; implicitHeight: 40; radius: 13; color: Colors.isl
                            AppIcon { anchors.centerIn: parent; name: td.page; icon: info && info.icon ? info.icon : ""; size: 22 } }
                Text { Layout.fillWidth: true; elide: Text.ElideRight; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim
                       text: !info ? "…" : gone ? "процесс завершился" : (info.prot ? "󰌾 системное · " : "") + info.n + " проц. · " + td.fmtSize(info.mem) }
            }
            Facts {
                Layout.fillWidth: true
                visible: !menu.confirm
                cols: 3
                rows: {
                    const i = info, ok = i && !gone
                    return [["PID", ok ? i.pid + (i.n > 1 ? "  +" + (i.n - 1) : "") : "…"], ["Процессов", ok ? String(i.n) : "…"],
                            ["Память (PSS)", ok ? td.fmtSize(i.mem) : "…"], ["CPU", ok ? i.pct.toFixed(1) + "%" : "…"],
                            ["Работает", ok ? (i.time !== null ? td.fmtDuration(i.time) : "—") : "…"], ["Потоков", ok ? String(i.threads || "—") : "…"]]
                }
            }
            // команда: Enter / клик — скопировать
            Rectangle {
                Layout.fillWidth: true
                visible: !menu.confirm
                implicitHeight: cmdT.implicitHeight + 20; radius: Theme.radius
                color: menu.asel === 0 ? Colors.alpha(Colors.acc, 0.16) : Colors.isl
                border.width: menu.asel === 0 ? 1 : 0; border.color: Colors.alpha(Colors.acc, 0.7)
                Behavior on color { ColorAnimation { duration: Theme.fast } }
                Text {
                    id: cmdT
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
                    text: (info && info.cmd ? info.cmd : "—") + (menu.asel === 0 ? "   ⏎ скопировать" : "")
                    font.family: Theme.fontMono; font.pixelSize: 11; color: Colors.fg
                    wrapMode: Text.WrapAnywhere; maximumLineCount: 2; elide: Text.ElideRight
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { menu.asel = 0; menu.copyCmd(); scope.forceActiveFocus() } }
            }
            Text {
                Layout.fillWidth: true; visible: !!info && !!info.prot && !menu.confirm; wrapMode: Text.Wrap
                text: "󰌾  Системное приложение или чужие процессы — закрывать из меню нельзя."
                font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim
            }
            Text {
                Layout.fillWidth: true; visible: menu.confirm; wrapMode: Text.Wrap
                text: "Убить «" + td.page + "» (" + (info ? info.n : 0) + " проц.)? Несохранённые данные пропадут."
                font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fg
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                IButton { Layout.fillWidth: true; Layout.preferredWidth: 1; visible: !menu.confirm; text: "Завершить"; enabledLook: menu.canAct; kb: menu.asel === 1
                          onClicked: { menu.asel = 1; menu.pressPage(1); scope.forceActiveFocus() } }
                IButton { Layout.fillWidth: true; Layout.preferredWidth: 1; visible: !menu.confirm; text: "Убить"; danger: true; enabledLook: menu.canAct; kb: menu.asel === 2
                          onClicked: { menu.asel = 2; menu.pressPage(2); scope.forceActiveFocus() } }
                IButton { Layout.fillWidth: true; Layout.preferredWidth: 1; visible: menu.confirm; text: "Убить"; danger: true; kb: menu.asel === 0
                          onClicked: { td.signal(td.page, "KILL"); scope.forceActiveFocus() } }
                IButton { Layout.fillWidth: true; Layout.preferredWidth: 1; visible: menu.confirm; text: "Отмена"; kb: menu.asel === 1
                          onClicked: { menu.confirm = false; menu.asel = 2; scope.forceActiveFocus() } }
            }
        }
    }
}
