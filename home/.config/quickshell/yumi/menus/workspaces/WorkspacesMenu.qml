import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.components
import qs.services

// «Рабочие столы» — мозаика столов; «Остров» (29.10): карточка-остров, миниатюры 16:10 radius 14, номер в капсуле. Слой поверх размытого стола: столы 1–10 рядами по мониторам, каждый —
// уменьшенный экран (миниатюра текущих обоев) с окнами-прямоугольниками по настоящей геометрии и значками программ.
// Клавиши: ←→↑↓ — выбор стола, Enter — перейти (стол приближается на весь экран), Пробел / Tab — окна стола
// (тот же стол крупно, ←→ — окно, Enter — перейти к окну, ↑ / Esc — назад), N — новый стол, 1…9, 0 — стол 1…10,
// Esc — закрыть. Мышь: клик — перейти, правый клик (долгое нажатие) — окна стола.
// Данные и переходы — бэкенд ~/.local/lib/yumi/qs/workspaces (hyprctl -j, socket2; rect окна — доли монитора).
//   qs -c yumi ipc call menu center workspaces    (бинд SUPER+TAB, жест) · menu toggle workspaces
//   qs -c yumi ipc call workspaces page <N> | go <N> | key left|right|up|down|enter|space|back | state
// YP_DRYRUN=1 — переходы не выполняются (команда hyprctl в журнал), меню не закрывается. YUMI_QS_NOKB=1 — без захвата клавиатуры.
Scope {
    id: menu
    readonly property bool open: Menus.current === "workspaces"
    readonly property bool dry: Quickshell.env("YP_DRYRUN") === "1"
    readonly property string wallThumb: "file://" + Quickshell.env("HOME") + "/.cache/yumi/theme/wall.thmb"
    property var data: null                // {active, free, groups, ws, nwin, busy}
    property int page: 0                   // 0 — мозаика; N — окна стола N
    property int sel: 1                    // выбранный стол (номер)
    property int wsel: 0                   // выбранное окно на подстранице
    property string wallSrc: wallThumb     // миниатюра обоев; при открытии сбрасывается и ставится снова — ссылка wall.thmb меняется со сменой обоев
    property string toastText: ""
    property bool toastError: false
    property string hoverTip: ""
    property var tiles: ({})               // номер → плитка мозаики (откуда начинать приближение)
    // мышь выбирает стол только при НАСТОЯЩЕМ движении курсора: при открытии он стоит над какой-то плиткой, а Qt шлёт
    // синтетические hover-события, пока плитки масштабируются, — без этого выбор с клавиатуры возвращался на плитку
    // под курсором и Enter вёл туда (обычно на текущий стол — «перехода нет»)
    property real mx: -1
    property real my: -1
    function mouseAt(x, y) {
        const moved = mx >= 0 && Math.abs(x - mx) + Math.abs(y - my) > 3
        mx = x; my = y
        return moved
    }

    function toast(t, err) { toastText = t; toastError = !!err; toastTimer.restart() }
    Timer { id: toastTimer; interval: 3000; onTriggered: menu.toastText = "" }
    function ws(i) { return data && data.ws ? (data.ws[String(i)] || null) : null }
    function wins(i) { const w = ws(i); return w ? w.wins : [] }
    // порядок плиток: ряды по мониторам, как группы бэкенда
    readonly property var rows: data ? data.groups.map(g => g.ids) : [[1, 2, 3, 4, 5], [6, 7, 8, 9, 10]]
    readonly property var order: rows.reduce((a, r) => a.concat(r), [])
    readonly property string sub: {
        if (toastText) return toastText
        if (hoverTip) return hoverTip
        if (!data) return "Читаю столы…"
        if (page) {
            const w = ws(page), mon = w ? (w.monLabel || "") : ""
            const st = page === data.active ? "активный" : (w && w.visible) ? "на экране" : "в фоне"
            return (mon || "не создан") + " · " + st + " · окон " + wins(page).length
        }
        return "Сейчас: стол " + data.active + " · окон " + data.nwin + " на " + data.busy + " стол."
    }
    readonly property var busyIds: {
        if (!data) return []
        const out = []
        for (const k in data.ws) if (data.ws[k].exists && data.ws[k].wins.length) out.push(parseInt(k))
        return out.sort((a, b) => a - b)
    }
    readonly property string selInfo: {
        const w = ws(sel)
        if (!w || !w.wins.length) return "Стол " + sel + " · пусто"
        return "Стол " + sel + " · " + w.classes.map(c => c.short).join(", ")
    }

    // ---- бэкенд ----
    Process {
        id: backend
        command: [Quickshell.env("HOME") + "/.local/lib/yumi/qs/workspaces"]
        running: menu.open || grace.running
        stdinEnabled: true
        stdout: SplitParser { onRead: line => menu.apply(line) }
        stderr: SplitParser { onRead: line => console.log("workspaces:", line) }
        onExited: menu.data = null
    }
    Timer { id: grace; interval: 30000 }      // после закрытия бэкенд живёт ещё 30 с — повторное открытие мгновенное
    function send(o) { if (backend.running) backend.write(JSON.stringify(o) + "\n") }
    function apply(line) {
        let j; try { j = JSON.parse(line) } catch (e) { return }
        if (j.t === "state") { const first = !data; data = j; if (first && open) sel = j.active || 1 }
        else if (j.t === "done") { toast(j.text, !j.ok); if (j.quit) close() }
    }

    onOpenChanged: {
        if (open) {
            grace.stop(); closer.stop(); page = 0; zoom.stop(); mx = -1; my = -1; wallSrc = ""; Qt.callLater(() => menu.wallSrc = menu.wallThumb)
            if (data) sel = data.active || 1
            send({ cmd: "refresh" })
        } else { grace.restart(); closer.restart(); page = 0; hoverTip = ""; toastText = "" }
    }
    onPageChanged: { send({ cmd: "titles", on: page > 0 }); wsel = 0; hoverTip = "" }
    Timer { id: closer; interval: Theme.normal }

    function close() { Menus.close("workspaces") }
    function go(i) { send({ cmd: "go", id: i }) }
    function focusWin(w) { send({ cmd: "focus", address: w.address, short: w.short }) }
    // переход с приближением: плитка растёт на весь экран, потом команда (меню закроет ответ бэкенда)
    function zoomGo(i) { zoom.start(i, () => menu.go(i)) }

    function move(dx, dy) {
        if (page) {
            const n = wins(page).length
            if (n && (dx || dy)) wsel = (wsel + (dx || dy) + n) % n
            return
        }
        let r = rows.findIndex(row => row.indexOf(sel) >= 0), c = r >= 0 ? rows[r].indexOf(sel) : 0
        if (r < 0) r = 0
        if (dx) { c = (c + dx + rows[r].length) % rows[r].length }
        if (dy) { r = Math.max(0, Math.min(rows.length - 1, r + dy)); c = Math.min(c, rows[r].length - 1) }
        sel = rows[r][c]
    }
    function key(k) {
        if (k === "left") move(-1, 0)
        else if (k === "right") move(1, 0)
        else if (k === "up") { if (page) page = 0; else move(0, -1) }
        else if (k === "down") { if (!page) move(0, 1) }
        else if (k === "enter") {
            if (page) { const w = wins(page)[wsel]; if (w) focusWin(w); else zoomGo(page) }
            else zoomGo(sel)
        }
        else if (k === "space") { if (!page) page = sel; else page = 0 }
        else if (k === "back") { if (page) page = 0; else close() }
        else if (k === "new") { if (data) go(data.free) }
    }

    IpcHandler {
        target: "workspaces"
        function page(n: int): void { menu.page = n }
        function go(n: int): void { menu.go(n) }
        function key(name: string): void { menu.key(name) }
        function state(): string {
            return JSON.stringify({ open: menu.open, page: menu.page, sel: menu.sel, wsel: menu.wsel, active: menu.data ? menu.data.active : 0,
                                    nwin: menu.data ? menu.data.nwin : 0, sub: menu.sub })
        }
    }

    // ---- окно ----
    PanelWindow {
        id: win
        screen: Menus.screen
        visible: menu.open || closer.running
        color: "transparent"
        WlrLayershell.namespace: "yumi-qs-workspaces"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        // YUMI_QS_NOKB=1 — проверка без захвата клавиатуры
        // во время перехода (приближение) клавиатуру отпускаем ДО команды: пока слой держит её Exclusive, Hyprland после смены
        // стола возвращал фокус последнему окну (kitty на столе 8) — и тут же прыгал обратно на его стол (16.10, «возвращает на 6»)
        WlrLayershell.keyboardFocus: menu.open && !zoom.running && Quickshell.env("YUMI_QS_NOKB") !== "1" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: true; right: true }

        readonly property real tileW: Math.round(Math.min(210, (width - 160) / 5 - 18))

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: menu.close() }   // клик мимо карточки — закрыть

        FocusScope {
            id: scope
            anchors.fill: parent
            focus: menu.open
            Keys.onPressed: (e) => {
                const k = Latin.key(e)   // буквы — по физической клавише (RU/UA раскладка)
                if (zoom.running) { e.accepted = true; return }
                if (k >= Qt.Key_0 && k <= Qt.Key_9 && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                    const n = (k - Qt.Key_0) || 10; menu.sel = n; menu.zoomGo(n)
                }
                else if (k === Qt.Key_Left) menu.key("left")
                else if (k === Qt.Key_Right) menu.key("right")
                else if (k === Qt.Key_Up) menu.key("up")
                else if (k === Qt.Key_Down) menu.key("down")
                else if (k === Qt.Key_Return || k === Qt.Key_Enter) menu.key("enter")
                else if (k === Qt.Key_Space || k === Qt.Key_Tab) menu.key("space")
                else if (k === Qt.Key_N) menu.key("new")
                else if (k === Qt.Key_Escape) menu.key("back")
                else return
                e.accepted = true
            }

            // ===== «Остров» (29.10): карточка-остров по центру — мозаика миниатюр 16:10 рядами по мониторам, ниже окна стола =====
            Rectangle {
                id: card
                anchors.centerIn: parent
                width: Math.min(1100, parent.width - 40)
                height: body.implicitHeight + 36
                radius: Theme.radiusBig
                color: Colors.isl
                border.width: 1; border.color: Colors.edge
                Behavior on color { ColorAnimation { duration: Theme.normal } }
                Behavior on height { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.05 } }
                property real grow: menu.open ? 1 : 0
                Behavior on grow { NumberAnimation { duration: menu.open ? Theme.menuOpen : Theme.fast
                                                     easing.type: menu.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.15 } }
                transform: Scale { origin.x: card.width / 2; origin.y: card.height / 2
                                   xScale: 0.92 + 0.08 * card.grow; yScale: 0.92 + 0.08 * card.grow }
                opacity: Math.min(1, grow * 3)
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }   // клики по карточке — не «мимо»

                ColumnLayout {
                    id: body
                    x: 18; y: 18; width: parent.width - 36
                    spacing: 12
                    opacity: menu.open ? 1 : 0
                    Behavior on opacity { SequentialAnimation {
                        PauseAnimation { duration: menu.open ? Theme.contentDelay : 0 }
                        NumberAnimation { duration: menu.open ? 260 : 120; easing.type: Easing.OutCubic } } }

                    CardHead {
                        title: menu.page ? "Стол " + menu.page : "Рабочие столы"; dry: menu.dry
                        back: menu.page > 0
                        onBackClicked: menu.page = 0
                        status: menu.sub
                        statusColor: menu.toastText ? (menu.toastError ? Colors.bad : Colors.acc) : Colors.fgDim
                        IButton {
                            visible: menu.data !== null && menu.page === 0
                            implicitHeight: 32
                            icon: "󰐕"; text: "Новый стол " + (menu.data ? menu.data.free : "")
                            onClicked: menu.key("new")
                        }
                    }

                    // ---- мозаика: миниатюры столов рядами по мониторам ----
                    Repeater {
                        model: menu.data ? menu.data.groups : []
                        ColumnLayout {
                            id: grp
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            spacing: 8
                            ISection { text: grp.modelData.label; visible: (menu.data ? menu.data.groups.length : 0) > 1 }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                Repeater {
                                    model: grp.modelData.ids
                                    Cell {
                                        required property int modelData
                                        required property int index
                                        Layout.fillWidth: true; Layout.preferredWidth: 1
                                        num: modelData
                                        order: grp.index * 5 + index
                                        selected: menu.sel === modelData
                                        onPicked: { menu.sel = modelData; menu.zoomGo(modelData) }
                                        onMore: { menu.sel = modelData; menu.page = modelData }
                                    }
                                }
                                Repeater {   // неполный ряд — пустые места, чтобы миниатюры были одного размера
                                    model: Math.max(0, 5 - grp.modelData.ids.length)
                                    Item { Layout.fillWidth: true; Layout.preferredWidth: 1 }
                                }
                            }
                        }
                    }
                    Text { visible: !menu.data; text: "Читаю столы…"; font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fgDim }

                    // ---- окна стола (на странице стола — ←→ выбор, Enter — к окну) ----
                    ISection {
                        readonly property int n: menu.page || menu.sel
                        text: "Окна на столе " + n + (menu.wins(n).length ? " · " + menu.wins(n).length : " — пусто")
                    }
                    GridLayout {
                        id: wgrid
                        Layout.fillWidth: true
                        columns: 2; columnSpacing: 8; rowSpacing: 2
                        readonly property int n: menu.page || menu.sel
                        Repeater {
                            model: menu.wins(wgrid.n).slice(0, 6)
                            Rectangle {
                                id: wrow
                                required property var modelData
                                required property int index
                                readonly property bool kb: menu.page > 0 && menu.wsel === index
                                Layout.fillWidth: true; Layout.preferredWidth: 1
                                implicitHeight: 52; radius: Theme.radius
                                color: kb ? Colors.alpha(Colors.acc, 0.16) : (wma.containsMouse ? Colors.isl2 : "transparent")
                                /* выбор — без затухания (29.10) */
                                scale: wma.pressed ? 0.985 : 1
                                Behavior on scale { NumberAnimation { duration: Theme.fast } }
                                Rectangle {
                                    id: wi; x: 9; anchors.verticalCenter: parent.verticalCenter
                                    width: 34; height: 34; radius: 12; color: Colors.isl2
                                    WsIcon { anchors.centerIn: parent; cls: wrow.modelData.class; icon: wrow.modelData.icon; size: 20 }
                                }
                                Column {
                                    anchors { left: wi.right; leftMargin: 12; right: wtail.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                    spacing: 1
                                    Text { width: parent.width; elide: Text.ElideRight; text: wrow.modelData.short; font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium; color: Colors.fg }
                                    Text { width: parent.width; elide: Text.ElideRight; text: wrow.modelData.title || ""; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim }
                                }
                                Text {
                                    id: wtail
                                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                                    text: [wrow.modelData.floating ? "плав." : "", wrow.modelData.fullscreen ? "весь экран" : "",
                                           wrow.modelData.xwayland ? "X11" : "", wrow.kb ? "Enter — к окну" : ""].filter(x => x).join(" · ")
                                    font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim
                                }
                                MouseArea { id: wma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onPositionChanged: (m) => { const p = mapToItem(null, m.x, m.y); if (menu.mouseAt(p.x, p.y) && menu.page) menu.wsel = wrow.index }
                                            onClicked: { if (menu.page) menu.wsel = wrow.index; menu.focusWin(wrow.modelData) } }
                            }
                        }
                    }
                    Text { visible: menu.wins(wgrid.n).length > 6; leftPadding: 9; text: "…и ещё " + (menu.wins(wgrid.n).length - 6)
                           font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim }
                    IButton {   // на странице стола — «Перейти на стол N» (как прежде)
                        visible: menu.page > 0
                        Layout.alignment: Qt.AlignHCenter
                        text: "Перейти на стол " + menu.page; primary: true
                        onClicked: menu.zoomGo(menu.page)
                    }

                    CardHints {
                        items: menu.page
                            ? [["←→", "окно"], ["Enter", "к окну"], ["↑ Esc", "назад"]]
                            : [["←→↑↓", "стол"], ["Enter", "перейти"], ["Пробел", "окна"], ["N", "новый"], ["1…0", "стол"], ["Esc", "закрыть"]]
                    }
                }
            }
        }

        // ---- приближение стола при переходе ----
        Item {
            id: zoom
            property int num: 0
            property var after: null
            property bool running: anim.running || hold.running
            visible: running
            z: 50
            Rectangle {
                anchors.fill: parent; radius: zoomR.r
                color: Colors.deep
                clip: true
                Image { anchors.fill: parent; source: menu.wallSrc; fillMode: Image.PreserveAspectCrop; cache: false; asynchronous: true; opacity: 0.9 }
                Text { anchors.centerIn: parent; text: "Стол " + zoom.num; font.family: Theme.fontUi; font.pixelSize: 24; font.weight: Font.DemiBold; color: Colors.fg
                       style: Text.Outline; styleColor: Colors.alpha(Colors.deep, 0.5) }
            }
            QtObject { id: zoomR; property real r: 14 }
            function start(n, then) {
                const w = menu.ws(n)
                const asp = w && w.aspect ? w.aspect : 1.6
                // откуда: плитка в мозаике (или крупный стол на подстранице) — по центру сцены, размер плитки
                const t = menu.tiles[n]
                if (t) {
                    const p = t.mapToItem(null, t.width / 2, t.height / 2), tw = t.width * t.scale, th = t.height * t.scale
                    x = p.x - tw / 2; y = p.y - th / 2; width = tw; height = th
                } else {
                    const tw = win.tileW, th = tw / asp, p = card.mapToItem(null, card.width / 2, card.height / 2)
                    x = p.x - tw / 2; y = p.y - th / 2; width = tw; height = th
                }
                zoomR.r = 14                                    // «Остров»: как угол миниатюры
                num = n; after = then
                anim.start()
            }
            function stop() { anim.stop(); hold.stop() }
            ParallelAnimation {
                id: anim
                NumberAnimation { target: zoom; property: "x"; to: 0; duration: 300; easing.type: Easing.InOutCubic }
                NumberAnimation { target: zoom; property: "y"; to: 0; duration: 300; easing.type: Easing.InOutCubic }
                NumberAnimation { target: zoom; property: "width"; to: win.width; duration: 300; easing.type: Easing.InOutCubic }
                NumberAnimation { target: zoom; property: "height"; to: win.height; duration: 300; easing.type: Easing.InOutCubic }
                NumberAnimation { target: zoomR; property: "r"; to: 0; duration: 300 }
                onFinished: { if (zoom.after) zoom.after(); hold.start() }
            }
            Timer { id: hold; interval: menu.dry ? 500 : 900 }   // в проверке меню не закрывается — приближение уходит
        }
    }

    // ---- миниатюра стола («Остров»): 16:10, radius 14, обои + окна прямоугольниками по настоящей геометрии,
    // номер в капсуле Colors.isl (текущий стол — акцентом), выбранный — кромка акцентом; наведение — пружина 1.03 ----
    component Cell: Item {
        id: cell
        property int num: 1
        property int order: 0
        property bool selected: false
        signal picked()
        signal more()
        readonly property var info: menu.ws(num)
        readonly property var dwins: info ? info.wins : []
        readonly property bool active: menu.data !== null && menu.data.active === num
        readonly property bool onScreen: info ? info.visible : false
        Component.onCompleted: menu.tiles[num] = cell
        implicitHeight: Math.round(width / 1.6)
        scale: cma.pressed ? 0.97 : (cma.containsMouse || selected) ? 1.03 : 1
        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }
        z: selected ? 2 : 1
        // каскад при открытии
        opacity: 0
        property real dy: 8
        transform: Translate { y: cell.dy }
        states: State { when: menu.open; PropertyChanges { cell.opacity: 1; cell.dy: 0 } }
        transitions: Transition {
            SequentialAnimation {
                PauseAnimation { duration: menu.open ? Theme.contentDelay + 40 + cell.order * Theme.cascade : 0 }
                NumberAnimation { properties: "opacity,dy"; duration: 280; easing.type: Easing.OutCubic } } }

        Rectangle {   // кромка выбора — снаружи
            anchors.fill: parent; anchors.margins: -3
            radius: 17; color: "transparent"
            border.width: 2; border.color: Colors.acc
            opacity: cell.selected ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
        ClippingRectangle {        // скругление без MultiEffect-маски; обои — уменьшенная миниатюра wall.thmb
            id: thumb
            anchors.fill: parent
            radius: 14
            color: Colors.isl2
            Image {
                anchors.fill: parent
                source: menu.wallSrc
                sourceSize.width: 320
                fillMode: Image.PreserveAspectCrop; asynchronous: true
                opacity: cell.dwins.length || cell.active ? 0.95 : 0.55
                Behavior on opacity { NumberAnimation { duration: Theme.normal } }
            }
            // окна — прямоугольники по долям монитора
            Repeater {
                model: cell.dwins
                Rectangle {
                    required property var modelData
                    readonly property var r: modelData.rect || [0.05, 0.08, 0.9, 0.84]
                    x: thumb.width * r[0]; y: thumb.height * r[1]
                    width: Math.max(8, thumb.width * r[2]); height: Math.max(6, thumb.height * r[3])
                    radius: 4
                    color: Colors.alpha(Colors.deep, 0.85)
                    border.width: 1; border.color: Colors.alpha(Colors.fg, 0.16)
                    WsIcon { anchors.centerIn: parent; visible: parent.width > 22 && parent.height > 18; cls: modelData.class; icon: modelData.icon
                             size: Math.min(18, Math.round(Math.min(parent.width, parent.height) * 0.5)) }
                }
            }
            Rectangle {   // внутренняя кромка
                anchors.fill: parent; radius: 14; color: "transparent"
                border.width: 1; border.color: cell.onScreen && !cell.active ? Colors.alpha(Colors.acc, 0.45) : Colors.edge
            }
            Rectangle {   // номер в капсуле
                x: 8; y: 6
                width: Math.max(22, numT.implicitWidth + 16); height: 20; radius: 10
                color: cell.active ? Colors.acc : Colors.isl
                Behavior on color { ColorAnimation { duration: Theme.normal } }
                Text { id: numT; anchors.centerIn: parent; text: String(cell.num); font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.DemiBold
                       color: cell.active ? Colors.onAcc : Colors.fg; font.features: ({ "tnum": 1 }) }
            }
            Rectangle {   // число окон
                visible: cell.dwins.length > 0
                anchors.right: parent.right; anchors.rightMargin: 8; y: 6
                width: Math.max(20, cntT.implicitWidth + 12); height: 20; radius: 10
                color: Colors.isl
                Text { id: cntT; anchors.centerIn: parent; text: String(cell.dwins.length); font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim
                       font.features: ({ "tnum": 1 }) }
            }
        }
        MouseArea {
            id: cma
            anchors.fill: parent
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (e) => { if (e.button === Qt.RightButton) cell.more(); else cell.picked() }
            onPressAndHold: cell.more()
            onPositionChanged: (m) => { const p = mapToItem(null, m.x, m.y); if (menu.mouseAt(p.x, p.y)) menu.sel = cell.num }
            onEntered: menu.hoverTip = "Стол " + cell.num + ": " + ((cell.info ? cell.info.classes.map(c => c.short).join(", ") : "") || "пусто")
            onExited: menu.hoverTip = ""
        }
    }
}
