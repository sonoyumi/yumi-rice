import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs
import qs.components
import qs.menus.workspaces
import "Expose.js" as Expose

// Mission Control («Остров», 30.10): все окна текущего стола монитора в фокусе — живыми миниатюрами (ScreencopyView окна
// Hyprland), сверху — полоса столов этого монитора (миниатюры с окнами) и «+» (первый пустой стол).
// Открытие: миниатюры вылетают из настоящих мест окон в сетку Exposé (Expose.js), закрытие — обратно.
// Мышь: клик по окну — перейти к нему; перетащить окно на стол в полосе — перенести (без перехода), на «+» — на пустой стол;
// средняя кнопка или «×» — закрыть окно; клик по столу — показать его окна (стол переключается), двойной — перейти и выйти;
// клик мимо окон — выйти. Клавиши: ←→↑↓ — выбор, Enter — к окну, Del — закрыть окно, 1…9 — стол, Tab — следующий стол, Esc — выйти.
//   qs -c yumi ipc call mission toggle | open | close | state
// YUMI_QS_SCREEN=eDP-1 — всегда этот монитор; YP_DRYRUN=1 — команды Hyprland только в журнал; YUMI_QS_NOKB=1 — без клавиатуры.
Scope {
    id: mission
    property bool open: false              // запрошено открытие
    property bool shown: false             // окно на экране (вкл. анимацию закрытия)
    property bool spread: false            // миниатюры в сетке (иначе — на местах окон)
    property bool animate: false           // анимации миниатюр включены (первый кадр — без них)
    readonly property bool dry: Quickshell.env("YP_DRYRUN") === "1"
    readonly property string home: Quickshell.env("HOME")
    property var screen: Quickshell.screens.length ? Quickshell.screens[0] : null
    readonly property var mon: screen ? Hyprland.monitorFor(screen) : null
    readonly property int deskId: mon && mon.activeWorkspace ? mon.activeWorkspace.id : -1
    property var slots: ({ order: [] })    // адрес → место в сетке
    property var desks: []                 // столы монитора в полосе: [{ id, n }]
    property int freeDesk: 1               // «+»: первый пустой стол монитора
    property string sel: ""                // выбранное окно (адрес)
    property int dropDesk: -1              // стол под перетаскиваемым окном (0 — «+»)
    property var deskItems: ({})
    property Item plusItem: null
    property real mx: -1
    property real my: -1

    function toggle() { if (open) close(); else show() }
    function show() {
        if (open) return
        const want = Quickshell.env("YUMI_QS_SCREEN") || (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "")
        let s = null
        for (const sc of Quickshell.screens) if (sc.name === want) s = sc
        screen = s || (Quickshell.screens.length ? Quickshell.screens[0] : null)
        Hyprland.refreshToplevels(); Hyprland.refreshWorkspaces(); Hyprland.refreshMonitors()
        closer.stop(); spread = false; animate = false; sel = ""; dropDesk = -1; mx = -1; my = -1
        open = true; shown = true
        prep.restart()
    }
    function close() {
        if (!open) return
        open = false; spread = false; dropDesk = -1
        closer.restart()
    }
    // первый кадр — миниатюры точно на местах окон, затем включаем анимацию и раскладываем
    Timer { id: prep; interval: 60; onTriggered: { mission.relayout(); go.restart() } }
    Timer { id: go; interval: 70; onTriggered: { if (!mission.open) return; mission.animate = true; mission.spread = true
                                                  if (!mission.sel && mission.slots.order.length) mission.sel = mission.slots.order[0] } }
    Timer { id: closer; interval: 340; onTriggered: { mission.shown = false; mission.animate = false } }

    // ---- данные ----
    function addr(tl) { return "0x" + tl.address }
    function onDesk(tl, id) {
        const o = tl.lastIpcObject || {}
        return !!tl.workspace && tl.workspace.id === id && o.mapped !== false && !o.hidden
    }
    function homeRect(tl) {
        const o = tl.lastIpcObject || {}, at = o.at || [0, 0], sz = o.size || [win.width / 2, win.height / 2]
        const mxo = mon ? mon.x : 0, myo = mon ? mon.y : 0
        return { x: at[0] - mxo, y: at[1] - myo, w: Math.max(40, sz[0]), h: Math.max(30, sz[1]) }
    }
    function deskWins(id) { return Hyprland.toplevels.values.filter(t => onDesk(t, id)) }
    function relayout() {
        if (!shown) return
        const items = deskWins(deskId).map(t => { const r = homeRect(t); return { key: addr(t), w: r.w, h: r.h, cx: r.x + r.w / 2, cy: r.y + r.h / 2 } })
        const top = 18 + strip.height + 30
        const area = { x: 64, y: top, w: win.width - 128, h: win.height - top - 74 }
        slots = Expose.layout(items, area, 34, 34, 0.8)
        if (sel && !slots[sel]) sel = slots.order.length ? slots.order[0] : ""
        // столы монитора: занятые и текущий; «+» — первый пустой (иначе следующий номер)
        const name = screen ? screen.name : ""
        const all = Hyprland.workspaces.values.filter(w => w.id > 0)
        const mine = all.filter(w => w.monitor && w.monitor.name === name).map(w => ({ id: w.id, n: deskWins(w.id).length }))
        desks = mine.filter(d => d.n > 0 || d.id === deskId).sort((a, b) => a.id - b.id)
        const empty = mine.filter(d => d.n === 0 && d.id !== deskId).map(d => d.id).sort((a, b) => a - b)
        freeDesk = empty.length ? empty[0] : (Math.max.apply(null, all.map(w => w.id).concat([0])) + 1)
    }
    Timer { id: relayoutSoon; interval: 40; onTriggered: mission.relayout() }
    function queueRelayout() { if (shown) relayoutSoon.restart() }
    // после команды Hyprland перестраивает окна — перечитать геометрию
    Timer { id: refetch; interval: 160; property int left: 0
            onTriggered: { Hyprland.refreshToplevels(); Hyprland.refreshWorkspaces(); mission.queueRelayout(); if (--left > 0) restart() } }
    function refetchSoon() { refetch.left = 3; refetch.restart() }
    Connections { target: Hyprland.toplevels; function onValuesChanged() { mission.queueRelayout() } }
    Connections { target: Hyprland.workspaces; function onValuesChanged() { mission.queueRelayout() } }
    onDeskIdChanged: { if (shown) { Hyprland.refreshToplevels(); refetchSoon(); queueRelayout() } }

    // ---- действия ----
    function hypr(expr) {
        if (dry) { console.log("[dry-run] hyprctl dispatch", expr); return }
        Quickshell.execDetached(["hyprctl", "dispatch", expr])
    }
    function focusWin(a) { hypr(`hl.dsp.focus({ window = "address:${a}" })`); close() }
    function closeWin(a) { hypr(`hl.dsp.window.close({ window = "address:${a}" })`); refetchSoon() }
    function moveWin(a, id) { hypr(`hl.dsp.window.move({ workspace = ${id}, follow = false, window = "address:${a}" })`); refetchSoon() }
    function switchDesk(id) { if (id !== deskId) hypr(`hl.dsp.focus({ workspace = ${id} })`) }
    function deskAt(px, py) {
        const hit = (it) => { if (!it || !it.visible) return false; const p = it.mapToItem(null, 0, 0); return px >= p.x - 6 && px <= p.x + it.width + 6 && py >= p.y - 6 && py <= p.y + it.height + 6 }
        for (const d of desks) if (hit(deskItems[d.id])) return d.id
        if (hit(plusItem)) return 0
        return -1
    }
    function deskRect(id) {
        const it = id === 0 ? plusItem : deskItems[id]
        if (!it) return null
        const p = it.mapToItem(null, 0, 0)
        return { x: p.x + it.width * 0.3, y: p.y + it.height * 0.3, w: it.width * 0.4, h: it.height * 0.4 }
    }
    // выбор стрелками — ближайшее окно в сторону нажатия
    function step(dx, dy) {
        const o = slots.order
        if (!o.length) return
        const c = slots[sel]
        if (!c) { sel = o[0]; return }
        const cx = c.x + c.w / 2, cy = c.y + c.h / 2
        let best = "", bd = 1e9
        for (const k of o) {
            if (k === sel) continue
            const r = slots[k], ex = r.x + r.w / 2 - cx, ey = r.y + r.h / 2 - cy
            const along = dx ? ex * dx : ey * dy, across = dx ? Math.abs(ey) : Math.abs(ex)
            if (along <= 4) continue
            const d = along + across * 2
            if (d < bd) { bd = d; best = k }
        }
        if (best) sel = best
    }
    function nextDesk(d) {
        if (!desks.length) return
        const i = desks.findIndex(x => x.id === deskId)
        switchDesk(desks[(i + d + desks.length) % desks.length].id)
    }
    function mouseAt(x, y) {
        const moved = mx >= 0 && Math.abs(x - mx) + Math.abs(y - my) > 3
        mx = x; my = y
        return moved
    }

    IpcHandler {
        target: "mission"
        function toggle(): void { mission.toggle() }
        function open(): void { mission.show() }
        function close(): void { mission.close() }
        function state(): string {
            return JSON.stringify({ open: mission.open, spread: mission.spread, screen: mission.screen ? mission.screen.name : "",
                                    desk: mission.deskId, sel: mission.sel, free: mission.freeDesk, desks: mission.desks,
                                    windows: mission.slots.order.map(k => ({ address: k, slot: mission.slots[k] })) })
        }
        // для проверки без мыши — те же действия, что у кликов
        function focus(address: string): void { mission.focusWin(address) }
        function closeWindow(address: string): void { const t = mission.tiles[address]; if (t) t.closeIt(); else mission.closeWin(address) }
        function move(address: string, desk: int): void { const t = mission.tiles[address]; if (t) t.dropTo(desk); else mission.moveWin(address, desk) }
        function desk(id: int): void { mission.switchDesk(id) }
        function key(name: string): void { mission.key(name) }
    }
    property var tiles: ({})
    function key(k) {
        if (k === "left") step(-1, 0)
        else if (k === "right") step(1, 0)
        else if (k === "up") step(0, -1)
        else if (k === "down") step(0, 1)
        else if (k === "enter") { if (sel) focusWin(sel); else close() }
        else if (k === "delete") { const t = tiles[sel]; if (t) t.closeIt() }
        else if (k === "tab") nextDesk(1)
        else if (k === "backtab") nextDesk(-1)
        else if (k === "escape") close()
    }

    PanelWindow {
        id: win
        screen: mission.screen
        visible: mission.shown
        color: "transparent"
        WlrLayershell.namespace: "yumi-qs-mission"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: mission.open && Quickshell.env("YUMI_QS_NOKB") !== "1" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: true; right: true }
        onWidthChanged: mission.queueRelayout()
        onHeightChanged: mission.queueRelayout()

        // ---- фон: размытые обои (wall.blur) + тень острова ----
        Item {
            id: bg
            anchors.fill: parent
            opacity: mission.spread ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: mission.open ? 320 : 260; easing.type: Easing.OutCubic } }
            Image {
                anchors.fill: parent
                source: mission.shown ? "file://" + mission.home + "/.cache/yumi/theme/wall.blur" : ""
                fillMode: Image.PreserveAspectCrop; cache: false; asynchronous: false; smooth: true
            }
            Rectangle { anchors.fill: parent; color: Colors.deep; opacity: 0.55 }
            Rectangle {   // мягкое затемнение к краям
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Colors.alpha(Colors.deep, 0.35) }
                    GradientStop { position: 0.4; color: "transparent" }
                    GradientStop { position: 1.0; color: Colors.alpha(Colors.deep, 0.45) }
                }
            }
        }
        MouseArea {   // клик мимо окон — выйти
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: mission.close()
        }

        FocusScope {
            id: scope
            anchors.fill: parent
            focus: mission.open
            Keys.onPressed: (e) => {
                const k = Latin.key(e)
                if (k >= Qt.Key_1 && k <= Qt.Key_9 && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) mission.switchDesk(k - Qt.Key_0)
                else if (k === Qt.Key_0) mission.switchDesk(10)
                else if (k === Qt.Key_Left) mission.key("left")
                else if (k === Qt.Key_Right) mission.key("right")
                else if (k === Qt.Key_Up) mission.key("up")
                else if (k === Qt.Key_Down) mission.key("down")
                else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) mission.key("enter")
                else if (k === Qt.Key_Delete || k === Qt.Key_Q || k === Qt.Key_W) mission.key("delete")
                else if (k === Qt.Key_Backtab || (k === Qt.Key_Tab && (e.modifiers & Qt.ShiftModifier))) mission.key("backtab")
                else if (k === Qt.Key_Tab) mission.key("tab")
                else if (k === Qt.Key_Escape) mission.key("escape")
                else return
                e.accepted = true
            }

            // ---- полоса столов (остров сверху) ----
            Rectangle {
                id: strip
                anchors.horizontalCenter: parent.horizontalCenter
                y: mission.spread ? 18 : -height - 10
                Behavior on y { NumberAnimation { duration: mission.open ? 420 : 240; easing.type: mission.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 0.9 } }
                opacity: mission.spread ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 220 } }
                readonly property real deskW: Math.round(Math.max(96, Math.min(176, (win.width - 260) / Math.max(4, mission.desks.length + 1) - 14)))
                readonly property real deskH: Math.round(deskW * win.height / Math.max(1, win.width))
                width: deskRow.implicitWidth + 28
                height: deskH + 50
                radius: Theme.radiusBig
                color: Colors.isl
                border.width: 1; border.color: Colors.edge
                Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: Theme.normal } }
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }   // не «мимо»

                Row {
                    id: deskRow
                    x: 14; y: 12
                    spacing: 14
                    Repeater {
                        model: mission.desks
                        Desk {
                            required property var modelData
                            num: modelData.id
                            count: modelData.n
                            w: strip.deskW; h: strip.deskH
                        }
                    }
                    // «+» — первый пустой стол: клик — перейти туда, бросить окно — перенести
                    Column {
                        id: plus
                        spacing: 6
                        Component.onCompleted: mission.plusItem = plusCard
                        Rectangle {
                            id: plusCard
                            width: Math.round(strip.deskH * 0.9); height: strip.deskH
                            radius: 12
                            readonly property bool drop: mission.dropDesk === 0
                            color: drop ? Colors.alpha(Colors.acc, 0.22) : (pma.containsMouse ? Colors.hover : Colors.isl2)
                            border.width: drop ? 2 : 1; border.color: drop ? Colors.acc : Colors.edge
                            Behavior on color { ColorAnimation { duration: Theme.fast } }
                            scale: drop ? 1.08 : pma.pressed ? 0.95 : 1
                            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
                            Glyph { anchors.centerIn: parent; text: "󰐕"; font.pixelSize: 22; color: plusCard.drop ? Colors.acc : Colors.fgDim }
                            MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: mission.switchDesk(mission.freeDesk) }
                        }
                        Text {
                            width: plusCard.width; horizontalAlignment: Text.AlignHCenter
                            text: "Стол " + mission.freeDesk
                            font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim; elide: Text.ElideRight
                        }
                    }
                }
            }

            // ---- пустой стол ----
            Column {
                anchors.centerIn: parent
                spacing: 6
                visible: mission.spread && mission.slots.order.length === 0
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 240 } }
                Glyph { anchors.horizontalCenter: parent.horizontalCenter; text: "󰹑"; font.pixelSize: 40; color: Colors.fgDim }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "На столе " + mission.deskId + " нет окон"
                       font.family: Theme.fontUi; font.pixelSize: 16; font.weight: Font.DemiBold; color: Colors.fg }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Esc — остаться здесь · 1…9 — другой стол"
                       font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim }
            }

            // ---- окна ----
            Repeater {
                model: Hyprland.toplevels
                Tile {}
            }

            // ---- подсказки ----
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: win.height - height - 18
                width: hints.implicitWidth + 30; height: 32; radius: 16
                color: Colors.alpha(Colors.isl, 0.92); border.width: 1; border.color: Colors.edge
                opacity: mission.spread ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: mission.open ? 400 : 150 } }
                Row {
                    id: hints
                    anchors.centerIn: parent
                    spacing: 14
                    Repeater {
                        model: [["Клик", "к окну"], ["Тащить", "на стол"], ["Ср. кнопка", "закрыть"], ["←→↑↓", "выбор"], ["Tab 1…9", "стол"], ["Esc", "выйти"]]
                        Row {
                            required property var modelData
                            spacing: 6
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: kt.implicitWidth + 12; height: 18; radius: 7
                                color: Colors.isl2; border.width: 1; border.color: Colors.edge
                                Text { id: kt; anchors.centerIn: parent; text: modelData[0]; font.family: Theme.fontUi; font.pixelSize: 11; font.weight: Font.Medium; color: Colors.fg }
                            }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: modelData[1]; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim }
                        }
                    }
                }
            }
        }
    }

    // ---- стол в полосе: миниатюра (обои + окна снимками), подпись «Стол N · окон» ----
    component Desk: Column {
        id: desk
        property int num: 1
        property int count: 0
        property real w: 160
        property real h: 100
        readonly property bool current: num === mission.deskId
        readonly property bool drop: mission.dropDesk === num
        spacing: 6
        Component.onCompleted: { mission.deskItems[num] = card }
        onNumChanged: mission.deskItems[num] = card
        Item {
            width: desk.w; height: desk.h
            Rectangle {   // кромка: текущий — акцент, цель перетаскивания — акцент толще
                anchors.fill: card; anchors.margins: -3
                radius: 15; color: "transparent"
                border.width: desk.drop ? 3 : 2; border.color: Colors.acc
                opacity: desk.current || desk.drop ? 1 : 0
                scale: card.scale
                Behavior on opacity { NumberAnimation { duration: 180 } }
            }
            ClippingRectangle {
                id: card
                anchors.fill: parent
                radius: 12
                color: Colors.isl2
                scale: desk.drop ? 1.08 : dma.pressed ? 0.96 : dma.containsMouse ? 1.04 : 1
                Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
                Image {
                    anchors.fill: parent
                    source: mission.shown ? "file://" + mission.home + "/.cache/yumi/theme/wall.thmb" : ""
                    sourceSize.width: 360
                    fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false
                    opacity: 0.9
                }
                Repeater {
                    model: Hyprland.toplevels
                    Item {
                        id: mini
                        required property var modelData
                        readonly property bool here: mission.shown && mission.onDesk(modelData, desk.num)
                        readonly property var r: here ? mission.homeRect(modelData) : ({ x: 0, y: 0, w: 1, h: 1 })
                        readonly property real k: desk.w / Math.max(1, win.width)
                        visible: here
                        readonly property var o: modelData.lastIpcObject || ({})
                        z: (o.floating ? 100 : 0) + 50 - Math.min(50, o.focusHistoryID || 0)   // плавающие сверху, недавние выше
                        x: r.x * k; y: r.y * k; width: r.w * k; height: r.h * k
                        ClippingRectangle {
                            anchors.fill: parent; radius: 3
                            color: Colors.alpha(Colors.deep, 0.9)
                            WsIcon { anchors.centerIn: parent; visible: !msc.hasContent; cls: mini.modelData.lastIpcObject ? (mini.modelData.lastIpcObject.class || "") : ""
                                     icon: mission.iconFor(cls); size: Math.max(8, Math.min(16, Math.round(Math.min(parent.width, parent.height) * 0.5))) }
                            ScreencopyView {
                                id: msc
                                anchors.fill: parent
                                captureSource: mini.here ? mini.modelData.wayland : null
                                live: false
                            }
                        }
                    }
                }
                Rectangle { anchors.fill: parent; radius: 12; color: "transparent"; border.width: 1; border.color: Colors.edge }
            }
            MouseArea {
                id: dma
                anchors.fill: parent
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: mission.switchDesk(desk.num)
                onDoubleClicked: { mission.switchDesk(desk.num); mission.close() }
            }
        }
        Text {
            width: desk.w; horizontalAlignment: Text.AlignHCenter
            text: "Стол " + desk.num + (desk.count ? " · " + desk.count : "")
            font.family: Theme.fontUi; font.pixelSize: 11; font.weight: desk.current ? Font.DemiBold : Font.Normal
            color: desk.current ? Colors.fg : Colors.fgDim
            elide: Text.ElideRight
        }
    }

    // значок программы по классу окна (.desktop → имя значка)
    function iconFor(cls) {
        if (!cls) return ""
        const e = DesktopEntries.heuristicLookup(cls)
        return e && e.icon ? e.icon : ""
    }

    // ---- миниатюра окна: живой снимок, подпись, «×»; летит из места окна в сетку и обратно ----
    component Tile: Item {
        id: tile
        required property var modelData
        readonly property string key: mission.addr(modelData)
        readonly property var ipc: modelData.lastIpcObject || ({})
        readonly property string cls: ipc.class || (modelData.wayland ? modelData.wayland.appId : "")
        readonly property string title: modelData.title || cls
        readonly property var slot: mission.slots[key] || null
        readonly property var homeR: mission.shown ? mission.homeRect(modelData) : ({ x: 0, y: 0, w: 100, h: 100 })
        readonly property bool inGrid: slot !== null
        readonly property bool hot: mission.sel === key && mission.spread
        property bool instant: true
        property bool dragging: false
        property bool closing: false
        property var leaveR: null            // перенос на стол: летит в его миниатюру
        property real px: 0
        property real py: 0
        property real gfx: 0.5
        property real gfy: 0.5
        Component.onCompleted: mission.tiles[key] = tile
        Component.onDestruction: if (mission.tiles[key] === tile) delete mission.tiles[key]

        visible: mission.shown && (inGrid || leaveR !== null)
        z: dragging ? 100 : leaveR ? 90 : hot ? 2 : 1
        readonly property real dw: slot ? Math.min(slot.w, 240) : 200
        readonly property real dh: slot ? dw * slot.h / Math.max(1, slot.w) : 120
        x: dragging ? px - gfx * width : leaveR ? leaveR.x : (mission.spread && slot) ? slot.x : homeR.x
        y: dragging ? py - gfy * height : leaveR ? leaveR.y : (mission.spread && slot) ? slot.y : homeR.y
        width: dragging ? dw : leaveR ? leaveR.w : (mission.spread && slot) ? slot.w : homeR.w
        height: dragging ? dh : leaveR ? leaveR.h : (mission.spread && slot) ? slot.h : homeR.h
        readonly property int dur: mission.open ? 420 : 300
        Behavior on x { enabled: mission.animate && !tile.instant && !tile.dragging; NumberAnimation { duration: tile.dur; easing.type: mission.open ? Easing.OutQuint : Easing.InOutCubic } }
        Behavior on y { enabled: mission.animate && !tile.instant && !tile.dragging; NumberAnimation { duration: tile.dur; easing.type: mission.open ? Easing.OutQuint : Easing.InOutCubic } }
        Behavior on width { enabled: mission.animate && !tile.instant; NumberAnimation { duration: tile.dragging ? 180 : tile.dur; easing.type: mission.open ? Easing.OutQuint : Easing.InOutCubic } }
        Behavior on height { enabled: mission.animate && !tile.instant; NumberAnimation { duration: tile.dragging ? 180 : tile.dur; easing.type: mission.open ? Easing.OutQuint : Easing.InOutCubic } }
        opacity: closing || leaveR ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        scale: closing ? 0.85 : (hot && !dragging && ma.containsMouse && ma.pressed) ? 0.97 : hot && !dragging ? 1.02 : 1
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

        // окно появилось в сетке, когда она уже разложена (смена стола) — без перелёта, проявляется на месте
        onInGridChanged: {
            if (!inGrid) return
            instant = true
            if (mission.spread) appear.restart()
            Qt.callLater(() => tile.instant = false)
        }
        NumberAnimation { id: appear; target: tile; property: "opacity"; from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }

        function closeIt() { closing = true; mission.closeWin(key); undo.restart() }
        Timer { id: undo; interval: 1500; onTriggered: tile.closing = false }   // программа спросила «сохранить?» — окно осталось
        function dropTo(id) {
            const target = id === 0 ? mission.freeDesk : id
            if (target === mission.deskId) return
            const r = mission.deskRect(id)
            leaveR = r || { x: tile.x + tile.width / 2, y: tile.y, w: 1, h: 1 }
            mission.moveWin(key, target)
            leaveDone.restart()
        }
        Timer { id: leaveDone; interval: 450; onTriggered: tile.leaveR = null }

        // тень
        RectangularShadow {
            anchors.fill: thumb
            radius: thumb.radius
            blur: 28; spread: 0; offset.y: 8
            color: Qt.rgba(0, 0, 0, 0.45)
            opacity: mission.spread ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }
        Rectangle {   // кромка выбора
            anchors.fill: thumb; anchors.margins: -4
            radius: thumb.radius + 4; color: "transparent"
            border.width: 3; border.color: Colors.acc
            opacity: tile.hot && !tile.dragging ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }
        ClippingRectangle {
            id: thumb
            anchors.fill: parent
            radius: mission.spread ? 12 : 10
            color: "transparent"
            // запасной вид: снимка нет — значок и название программы
            Rectangle {
                anchors.fill: parent
                visible: !sc.hasContent && fallbackTimer.done
                color: Colors.isl2
                Column {
                    anchors.centerIn: parent; spacing: 8
                    WsIcon { anchors.horizontalCenter: parent.horizontalCenter; cls: tile.cls; icon: mission.iconFor(tile.cls)
                             size: Math.max(24, Math.min(64, Math.round(Math.min(thumb.width, thumb.height) * 0.3))) }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; width: Math.min(implicitWidth, thumb.width - 20); elide: Text.ElideRight
                           text: tile.cls; font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fgDim }
                }
            }
            Timer { id: fallbackTimer; property bool done: false; interval: 700; running: tile.visible && !sc.hasContent; onTriggered: done = true }
            ScreencopyView {
                id: sc
                anchors.fill: parent
                captureSource: mission.shown && tile.inGrid ? tile.modelData.wayland : null
                live: mission.open
                paintCursor: false
            }
            Rectangle { anchors.fill: parent; radius: thumb.radius; color: "transparent"; border.width: 1; border.color: Colors.alpha(Colors.fg, 0.10)
                        opacity: mission.spread ? 1 : 0 }
        }

        // «×» — закрыть окно (при наведении)
        Rectangle {
            id: xbtn
            x: -10; y: -10
            width: 26; height: 26; radius: 13
            color: xma.containsMouse ? Colors.bad : Colors.isl
            border.width: 1; border.color: Colors.edge
            visible: opacity > 0
            opacity: mission.spread && !tile.dragging && (ma.containsMouse || xma.containsMouse) ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
            Behavior on color { ColorAnimation { duration: Theme.fast } }
            scale: xma.pressed ? 0.9 : 1
            Text { anchors.centerIn: parent; text: "✕"; font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.DemiBold
                   color: xma.containsMouse ? Colors.deep : Colors.fg }
            z: 5
            MouseArea { id: xma; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tile.closeIt() }
        }

        // подпись: значок + заголовок
        Rectangle {
            id: label
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height + 10
            readonly property real maxW: Math.max(140, tile.width + 24)
            width: Math.min(lrow.implicitWidth + 24, maxW)
            height: 26; radius: 13
            color: tile.hot ? Colors.acc : Colors.alpha(Colors.isl, 0.92)
            border.width: tile.hot ? 0 : 1; border.color: Colors.edge
            Behavior on color { ColorAnimation { duration: 160 } }
            opacity: mission.spread && !tile.dragging && !tile.leaveR ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: mission.open ? 360 : 100 } }
            Row {
                id: lrow
                anchors.centerIn: parent
                spacing: 7
                WsIcon { anchors.verticalCenter: parent.verticalCenter; cls: tile.cls; icon: mission.iconFor(tile.cls); size: 15 }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, label.maxW - 24 - 22)
                    text: tile.title; elide: Text.ElideRight
                    font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium
                    color: tile.hot ? Colors.onAcc : Colors.fg
                }
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            enabled: mission.spread
            hoverEnabled: true; cursorShape: tile.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            property real sx: 0
            property real sy: 0
            property bool dragged: false
            onPressed: (m) => { const p = mapToItem(null, m.x, m.y); sx = p.x; sy = p.y; dragged = false; tile.gfx = m.x / tile.width; tile.gfy = m.y / tile.height }
            onPositionChanged: (m) => {
                const p = mapToItem(null, m.x, m.y)
                if (!pressed) { if (mission.mouseAt(p.x, p.y)) mission.sel = tile.key; return }
                if (!(pressedButtons & Qt.LeftButton)) return
                if (!tile.dragging && Math.abs(p.x - sx) + Math.abs(p.y - sy) > 10) { tile.px = p.x; tile.py = p.y; tile.dragging = true; dragged = true }
                if (tile.dragging) { tile.px = p.x; tile.py = p.y; mission.dropDesk = mission.deskAt(p.x, p.y) }
            }
            onReleased: (m) => {
                if (!tile.dragging) return
                const d = mission.dropDesk
                tile.dragging = false; mission.dropDesk = -1
                if (d >= 0) tile.dropTo(d)
            }
            onClicked: (m) => {
                if (dragged) return
                if (m.button === Qt.MiddleButton) tile.closeIt()
                else mission.focusWin(tile.key)
            }
        }
    }
}
