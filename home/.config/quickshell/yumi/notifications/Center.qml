import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// Центр уведомлений («шторка»): выезжает с правого края пружиной, ширина 360, отступ сверху 8 под баром.
// «Остров» (29.10): сплошной остров isl radius 26; шапка CardHead с «Не беспокоить» (IToggle) справа; фишки IChip-вида;
// группы — подпись приложения и число (без черт), карточки Card (inCenter); внизу «Журнал» (развернуть/свернуть все стопки)
// и «Очистить всё» (второе нажатие — подтверждение; карточки уходят вправо каскадом, потом закрываются).
// Журнал-список (16.10):
//   фишки-фильтры «Все · N» / приложения / «Скрытые · K»; в «Все» — группы по приложению (свёрнуты стопкой, если > 1),
//   в фильтре приложения и в «Скрытых» — всё списком. Клавиши:
//   ↑↓ — уведомление (↑ с первого — к фишкам; там ←→ фильтр, ↓/Enter — назад в список), Tab — следующий фильтр;
//   Enter/→ — развернуть стопку, ещё раз — открыть целиком (весь текст, дата, кнопки действий ←→, Enter — нажать;
//   без выбранной кнопки Enter — как клик: действие «default» или запуск приложения); ← — свернуть;
//   Del — удалить (из центра и журнала), H — скрыть (уходит в «Скрытые», в журнале остаётся; в «Скрытых» H — вернуть),
//   Shift+Del или «Очистить» — очистить всё (второе нажатие в течение 3 с — подтверждение), D — «Не беспокоить», Esc — назад/закрыть.
//   Скрытые хранятся в hidden.json рядом с журналом (history.json, YNL_HISTORY). Счётчик пилюли бара — все уведомления, как раньше.
// Закрывается как все меню из бара: Esc, клик вне карточки, уход курсора дальше Theme.menuFar (FarWatch; без уведомлений — нет).
// Открыть: qs -c yumi ipc call notif toggle (бинд SUPER+CTRL+N). Проверка клавиш без захвата клавиатуры:
//   YUMI_QS_NOKB=1 … qs ipc call notifcenter key up|down|left|right|enter|del|hide|clear|dnd|tab|esc · notifcenter state
PanelWindow {
    id: win
    screen: Menus.screen
    readonly property bool open: Notifs.visible
    readonly property int m: Notifs.centerMargin
    readonly property int top: Theme.barH + m
    readonly property int cardH: Math.min(Notifs.centerH, height - top - m)
    property var expanded: ({})                      // app → развёрнута ли группа (в «Все»)

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "yumi-qs-notif-center"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    // Окно существует ТОЛЬКО пока шторка открыта или идёт анимация закрытия (15.10: «вечное» окно перехватывало ввод).
    visible: open || closer.running
    Timer { id: closer; interval: Theme.slow }
    // YUMI_QS_NOKB=1 — проверка без захвата клавиатуры
    WlrLayershell.keyboardFocus: open && Quickshell.env("YUMI_QS_NOKB") !== "1" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    onOpenChanged: {
        far.reset(); scope.focus = open
        if (open) { clearing = false; expanded = {}; filter = "*"; zone = "list"; selIdx = 0; fullEntry = null; actSel = -1; kbUsed = false; confirmClear = false }
        else closer.restart()
    }
    Connections { target: Notifs; function onVisibleChanged() { if (Notifs.visible) Menus.open("notif"); else Menus.close("notif") } }
    Connections { target: Menus; function onClosed(name) { if (name === "notif") Notifs.visible = false } }

    // ================= скрытые (hidden.json рядом с журналом) =================
    property var hidden: []                          // ключи записей (srv/id)
    readonly property string hiddenPath: Notifs.histPath.substring(0, Notifs.histPath.lastIndexOf("/")) + "/hidden.json"
    FileView {
        id: hiddenFile
        path: win.hiddenPath
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { const d = JSON.parse(text()); win.hidden = Array.isArray(d.keys) ? d.keys.filter(k => typeof k === "string") : [] } catch (err) {} }
        onLoadFailed: win.hidden = []
    }
    function isHidden(e) { return !!e && !!e.key && hidden.indexOf(e.key) >= 0 }
    function setHidden(e, on) {
        if (!e || !e.key) return
        const live = new Set(Notifs.center.map(x => x.key))  // ключи ушедших из журнала — выбросить
        let h = hidden.filter(k => k !== e.key && live.has(k))
        if (on) h.push(e.key)
        hidden = h
        hiddenFile.setText(JSON.stringify({ version: 1, keys: h }))
    }

    // ================= фильтр, группы, порядок для клавиш =================
    property string filter: "*"                      // "*" все · имя приложения · "hidden"
    readonly property bool forced: filter !== "*"    // в фильтре — всё списком, без стопок
    readonly property var shownEntries: Notifs.center.filter(e => filter === "hidden" ? isHidden(e) : (!isHidden(e) && (filter === "*" || e.app === filter)))
    readonly property var groupApps: { const out = []; for (const e of shownEntries) if (!out.includes(e.app)) out.push(e.app); return out }
    function entriesFor(app) { return shownEntries.filter(e => e.app === app) }
    function isCollapsed(app, n) { return n > 1 && !forced && !expanded[app] }
    readonly property var navList: {
        const out = []
        for (const a of groupApps) { const es = entriesFor(a); if (isCollapsed(a, es.length)) out.push(es[0]); else for (const e of es) out.push(e) }
        return out
    }
    readonly property var chips: {
        const vis = Notifs.center.filter(e => !isHidden(e))
        const out = [{ key: "*", text: "Все", n: vis.length }]
        const apps = []
        for (const e of vis) if (!apps.includes(e.app)) apps.push(e.app)
        for (const a of apps) out.push({ key: a, text: a.length ? a : "Уведомление", n: vis.filter(e => e.app === a).length })
        const h = Notifs.center.filter(e => isHidden(e)).length
        if (h) out.push({ key: "hidden", text: "󰘓 Скрытые", n: h })
        return out
    }
    onChipsChanged: if (!chips.some(c => c.key === filter)) filter = "*"
    onFilterChanged: { selIdx = 0; fullEntry = null; actSel = -1; list.positionViewAtBeginning() }

    // ================= клавиатура =================
    property string zone: "list"                     // list | chips
    property int selIdx: 0
    property QtObject fullEntry: null                // раскрыта целиком
    property int actSel: -1
    property bool kbUsed: false                      // выделение показываем, только когда начали ходить клавишами
    property bool confirmClear: false
    Timer { id: clearArm; interval: 3000; onTriggered: win.confirmClear = false }
    readonly property QtObject selEntry: zone === "list" && navList.length ? navList[Math.max(0, Math.min(navList.length - 1, selIdx))] : null
    onNavListChanged: { if (selIdx >= navList.length) selIdx = Math.max(0, navList.length - 1); if (fullEntry && navList.indexOf(fullEntry) < 0) { fullEntry = null; actSel = -1 } }
    onSelEntryChanged: if (selEntry && kbUsed) Qt.callLater(win.reveal)
    function reveal() {
        if (!selEntry) return
        const gi = groupApps.indexOf(selEntry.app)
        if (gi >= 0) list.positionViewAtIndex(gi, ListView.Contain)
    }
    function actsOf(e) { return e ? e.actions.filter(a => a.id !== "default" && a.id !== "inline-reply") : [] }
    function chipStep(d) { const i = Math.max(0, chips.findIndex(c => c.key === filter)); filter = chips[(i + d + chips.length) % chips.length].key }
    property bool clearing: false                    // «Очистить всё»: карточки уходят каскадом, потом closeAll
    Timer { id: clearDone; onTriggered: { Notifs.closeAll(); win.clearing = false } }
    function clearAll() {
        if (!confirmClear) { confirmClear = true; clearArm.restart(); return }
        confirmClear = false; clearArm.stop()
        if (clearing) return
        clearing = true
        clearDone.interval = 300 + Math.min(groupApps.length, 10) * Theme.cascade + 60
        clearDone.restart()
    }
    // «Журнал»: развернуть все стопки (весь журнал списком) / свернуть обратно
    readonly property bool allExpanded: groupApps.length > 0 && groupApps.every(a => entriesFor(a).length < 2 || expanded[a])
    function toggleJournal() {
        const x = {}
        if (!allExpanded) for (const a of groupApps) x[a] = true
        expanded = x
    }
    function press(n, shift) {
        kbUsed = true
        if (n === "esc") { if (fullEntry) { fullEntry = null; actSel = -1 } else if (confirmClear) confirmClear = false; else Notifs.visible = false; return true }
        if (n === "dnd") { Notifs.dnd = !Notifs.dnd; return true }
        if (n === "tab") { chipStep(shift ? -1 : 1); return true }
        if (n === "clear" || (n === "del" && shift)) { clearAll(); return true }
        if (zone === "chips") {
            if (n === "left") chipStep(-1)
            else if (n === "right") chipStep(1)
            else if (n === "down" || n === "enter") { zone = "list"; selIdx = 0 }
            else return false
            return true
        }
        const e = selEntry
        if (n === "down") { if (selIdx < navList.length - 1) { selIdx++; fullEntry = null; actSel = -1 } return true }
        if (n === "up") { if (selIdx > 0) { selIdx--; fullEntry = null; actSel = -1 } else { zone = "chips"; fullEntry = null } return true }
        if (!e) return n === "enter" || n === "right" || n === "left" || n === "del" || n === "hide"
        const es = entriesFor(e.app)
        if (n === "right" || n === "enter") {
            if (isCollapsed(e.app, es.length)) { const x = Object.assign({}, expanded); x[e.app] = true; expanded = x; return true }
            if (fullEntry !== e) { fullEntry = e; actSel = -1; Qt.callLater(win.reveal); return true }
            const acts = actsOf(e)
            if (n === "right") { if (acts.length) actSel = Math.min(acts.length - 1, actSel + 1); return true }
            if (actSel >= 0 && acts[actSel]) Notifs.invoke(e, acts[actSel].id); else Notifs.activate(e)
            return true
        }
        if (n === "left") {
            if (fullEntry) { if (actSel >= 0) actSel--; else fullEntry = null }
            else if (!forced && es.length > 1 && expanded[e.app]) { const x = Object.assign({}, expanded); x[e.app] = false; expanded = x; selIdx = navList.indexOf(es[0]) }
            return true
        }
        if (n === "del") { Notifs.dismiss(e); return true }
        if (n === "hide") { setHidden(e, !isHidden(e)); return true }
        return false
    }
    function keyName(k) {
        switch (k) {
        case Qt.Key_Up: return "up"
        case Qt.Key_Down: return "down"
        case Qt.Key_Left: return "left"
        case Qt.Key_Right: return "right"
        case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: return "enter"
        case Qt.Key_Delete: case Qt.Key_Backspace: return "del"
        case Qt.Key_H: return "hide"
        case Qt.Key_D: return "dnd"
        case Qt.Key_Tab: case Qt.Key_Backtab: return "tab"
        case Qt.Key_Escape: return "esc"
        }
        return ""
    }

    IpcHandler {
        target: "notifcenter"
        function key(name: string): void { win.press(name, false) }
        function shiftKey(name: string): void { win.press(name, true) }
        function state(): string {
            return JSON.stringify({ open: win.open, filter: win.filter, zone: win.zone, sel: win.selEntry ? win.selEntry.app + ": " + win.selEntry.summary : "",
                                    full: win.fullEntry ? win.fullEntry.summary : "", actSel: win.actSel, nav: win.navList.length,
                                    hidden: win.hidden.length, chips: win.chips.map(c => c.text + "·" + c.n), confirmClear: win.confirmClear })
        }
    }

    // клик мимо — закрыть; движение курсора по полю — правило «ушёл далеко» (FarWatch)
    readonly property rect cardRect: Qt.rect(width - Notifs.cardW - m, top, Notifs.cardW, cardH)
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        onPressed: Notifs.visible = false
        onPositionChanged: (m) => { far.rect = win.cardRect; far.track(m.x, m.y) }
        onExited: far.reset()
    }
    // пустую шторку курсор не закрывает (18.10): открыл сам или очистил всё — остаётся до Esc, клика мимо или бинда
    FarWatch { id: far; enabled: win.open && Notifs.count > 0; onFar: Notifs.visible = false }
    FocusScope {
        id: scope; anchors.fill: parent
        Keys.onPressed: (ev) => { const n = win.keyName(Latin.key(ev)); if (n && win.press(n, ev.modifiers & Qt.ShiftModifier)) ev.accepted = true }
    }

    Rectangle {
        id: card
        width: Notifs.cardW; height: win.cardH
        y: win.top
        x: win.open ? win.width - width - win.m : win.width + 20
        Behavior on x { NumberAnimation { duration: win.open ? Theme.menuOpen : Theme.normal; easing.type: win.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 0.9 } }
        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: win.open ? Theme.fast : Theme.normal } }
        radius: Theme.radiusBig
        color: Colors.isl
        border.width: 1; border.color: Colors.edge
        Behavior on color { ColorAnimation { duration: Theme.normal } }
        clip: true
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; hoverEnabled: true; onEntered: far.reset() }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            // ---- шапка: «Уведомления», число; справа «Не беспокоить» ----
            CardHead {
                title: "Уведомления"
                status: Notifs.count === 0 ? "нет новых" : Notifs.count + " " + win.plural(Notifs.count, "новое", "новых", "новых")
                        + (win.hidden.length ? " · скрытых " + win.hidden.length : "")
                Text { text: "Не беспокоить"; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim
                       MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Notifs.dnd = !Notifs.dnd } }
                IToggle { on: Notifs.dnd; onToggled: Notifs.dnd = !Notifs.dnd }
            }

            // ---- фишки-фильтры ----
            ListView {
                id: chipRow
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                visible: Notifs.count > 0
                orientation: ListView.Horizontal
                spacing: 6
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: win.chips
                currentIndex: Math.max(0, win.chips.findIndex(c => c.key === win.filter))
                highlightFollowsCurrentItem: false
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                delegate: IChip {
                    required property var modelData
                    readonly property bool kb: win.kbUsed && win.zone === "chips" && on
                    text: modelData.text + "  " + modelData.n
                    on: win.filter === modelData.key
                    border.width: kb ? 1.5 : 0; border.color: Colors.fg
                    onClicked: win.filter = modelData.key
                }
            }

            // ---- список ----
            ListView {
                id: list
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true
                spacing: 14
                model: ScriptModel { values: win.groupApps }
                delegate: Group { width: list.width }
                boundsBehavior: Flickable.StopAtBounds
                remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Theme.fast } }
                displaced: Transition { NumberAnimation { properties: "y"; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }

                Text {
                    x: 10; y: 6
                    visible: win.groupApps.length === 0
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                    text: Notifs.count === 0 ? "Нет уведомлений" : (win.filter === "hidden" ? "Скрытых нет" : "Здесь пусто")
                    font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fgDim
                }
            }

            // ---- «Журнал» и «Очистить всё» ----
            RowLayout {
                visible: Notifs.count > 0
                Layout.fillWidth: true
                spacing: 8
                IButton { Layout.fillWidth: true; Layout.preferredWidth: 1; text: win.allExpanded ? "Свернуть" : "Журнал"
                          onClicked: win.toggleJournal() }
                IButton { Layout.fillWidth: true; Layout.preferredWidth: 1; text: win.confirmClear ? "Точно? Ещё раз" : "Очистить всё"
                          danger: win.confirmClear; onClicked: win.clearAll() }
            }
            CardHints {
                items: Notifs.count === 0 ? [["D", "тишина"], ["Esc", "закрыть"]]
                     : win.zone === "chips" ? [["←→", "фильтр"], ["↓", "к списку"], ["Esc", "закрыть"]]
                     : win.fullEntry ? [["←→", "кнопка"], ["↵", "нажать"], ["Del", "удалить"], ["H", win.filter === "hidden" ? "вернуть" : "скрыть"]]
                     : [["↑↓", "выбор"], ["↵", "открыть"], ["Del", "убрать"], ["H", win.filter === "hidden" ? "вернуть" : "скрыть"]]
            }
        }
    }
    function plural(n, one, few, many) {
        const a = n % 10, b = n % 100
        return a === 1 && b !== 11 ? one : (a >= 2 && a <= 4 && (b < 12 || b > 14)) ? few : many
    }

    // ---- группа приложения ----
    component Group: Item {
        id: group
        required property var modelData
        required property int index
        readonly property string app: modelData
        readonly property var entries: win.entriesFor(app)
        readonly property bool collapsed: win.isCollapsed(app, entries.length)
        readonly property var shown: collapsed ? entries.slice(0, 1) : entries
        readonly property int tail: collapsed ? Math.min(2, entries.length - 1) : 0
        implicitHeight: Math.ceil(col.implicitHeight)

        // каскад при открытии: opacity + y 8 px, 40 мс на группу
        opacity: 0
        property real dy: 8
        transform: Translate { y: group.dy }
        Component.onCompleted: appear.restart()
        Connections { target: win; function onOpenChanged() { if (win.open) appear.restart() } }
        SequentialAnimation {
            id: appear
            PauseAnimation { duration: win.open ? Theme.contentDelay + Math.min(12, Math.max(0, group.index)) * Theme.cascade : 0 }   // у уходящей группы index = -1
            ParallelAnimation {
                NumberAnimation { target: group; property: "opacity"; from: 0; to: 1; duration: 280; easing.type: Easing.OutCubic }
                NumberAnimation { target: group; property: "dy"; from: 8; to: 0; duration: 280; easing.type: Easing.OutCubic }
            }
        }
        // «Очистить всё»: уход вправо каскадом
        Connections { target: win; function onClearingChanged() { if (win.clearing) leave.restart() } }
        SequentialAnimation {
            id: leave
            PauseAnimation { duration: Math.min(12, Math.max(0, group.index)) * Theme.cascade }
            ParallelAnimation {
                NumberAnimation { target: group; property: "x"; to: 60; duration: 300; easing.type: Easing.InCubic }
                NumberAnimation { target: group; property: "opacity"; to: 0; duration: 260 }
            }
        }

        ColumnLayout {
            id: col
            width: parent.width
            spacing: 6

            // заголовок группы: значок, имя, число, закрыть группу; клик — свернуть/развернуть
            Item {
                id: hdr
                Layout.fillWidth: true; Layout.leftMargin: 0; Layout.rightMargin: 0
                implicitHeight: 22
                MouseArea {
                    anchors.fill: parent
                    enabled: group.entries.length > 1 && !win.forced
                    onClicked: { const x = Object.assign({}, win.expanded); x[group.app] = !x[group.app]; win.expanded = x }
                }
                Image {
                    id: gicon
                    x: 0; y: 3; width: 16; height: 16
                    source: group.entries.length ? Notifs.iconFor(group.entries[0], false) : ""
                    sourceSize.width: Math.ceil(16 * Screen.devicePixelRatio); sourceSize.height: Math.ceil(16 * Screen.devicePixelRatio); smooth: true
                    fillMode: Image.PreserveAspectFit; asynchronous: true
                    visible: status === Image.Ready
                }
                Text {
                    id: gname
                    x: gicon.visible ? 22 : 0; y: Math.round((hdr.height - height) / 2)
                    width: Math.max(0, gcount.x - x - 8)
                    text: group.app.length ? group.app : "Уведомление"
                    font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium
                    color: Colors.fgDim; elide: Text.ElideRight
                }
                Text {
                    id: gcount
                    visible: group.entries.length > 1
                    x: gclose.x - (visible ? width + 8 : 0); y: Math.round((hdr.height - height) / 2)
                    text: group.entries.length + (win.forced ? "" : (group.collapsed ? "  󰅀" : "  󰅃"))
                    font.family: Theme.fontUi; font.pixelSize: 12; font.features: ({ "tnum": 1 }); color: Colors.fgDim
                }
                Rectangle {
                    id: gclose
                    x: hdr.width - width; y: 0
                    width: 22; height: 22; radius: 11
                    color: gm.containsMouse ? Colors.hover : "transparent"
                    border.width: 0
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                    Glyph { x: Math.round((parent.width - width) / 2); y: Math.round((parent.height - height) / 2); text: "󰅖"; font.pixelSize: 12; color: gm.containsMouse ? Colors.fg : Colors.fgDim }
                    MouseArea { id: gm; anchors.fill: parent; hoverEnabled: true
                                onClicked: { for (const e of group.entries.slice()) Notifs.dismiss(e) } }
                }
            }

            // карточки (в свёрнутой группе — одна + «хвост»)
            Item {
                Layout.fillWidth: true
                implicitHeight: cards.implicitHeight + group.tail * 6
                Repeater {
                    model: group.tail
                    delegate: Rectangle {
                        required property int index
                        readonly property int k: index + 1
                        y: cards.height + k * 6 - height
                        x: k * 8; width: parent.width - k * 16; height: cards.height
                        radius: Theme.radiusTile
                        color: Colors.mix(Colors.isl2, Colors.isl, 0.35 + k * 0.25)      // хвост стопки — тише к низу
                        z: -k
                    }
                }
                Column {
                    id: cards
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: ScriptModel { values: group.shown }
                        delegate: Card {
                            required property var modelData
                            entry: modelData; inCenter: true; width: cards.width
                            selected: win.kbUsed && win.selEntry === modelData
                            full: win.fullEntry === modelData
                            actSel: win.fullEntry === modelData ? win.actSel : -1
                            hiddenMark: win.filter === "hidden"
                        }
                    }
                }
                MouseArea {      // свёрнутая стопка: клик по хвосту разворачивает
                    anchors.fill: parent; z: -1
                    enabled: group.collapsed
                    onClicked: { const x = Object.assign({}, win.expanded); x[group.app] = true; win.expanded = x }
                }
            }
        }
    }
}
