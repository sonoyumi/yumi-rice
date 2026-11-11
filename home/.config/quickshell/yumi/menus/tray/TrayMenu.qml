import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs
import qs.components
import qs.services
import qs.menus.wifi
import qs.menus.vpn

// Меню «Фоновые программы» — вариант 05 «Аккордеон на месте» (16.10), «Остров» (29.10): программы строками IRow-вида
// (значок в квадрате 34, название, подпись, 󰅂), меню программы раскрывается под строкой. (Прежнее со страницей меню программы —
// TrayMenu.qml.bak-widget-20261016). Элементы — штатный Quickshell.Services.SystemTray через TrayBus (скрытые, глифы
// yumi-tray, одна запись на программу). Каждая программа — раздел: строка сверху, под ней раскрывается на месте её меню
// (dbusmenu, подменю каскадом) и «Показать окно», если своего пункта нет; открыт один раздел, соседи раздвигаются.
// Мышь как раньше: строка — показать окно (Activate; у программ только с меню — раскрыть), правый клик или 󰅂 — меню.
// Клавиши: ↑↓ программа / пункт, → раскрыть и войти в меню (на подменю — войти в подменю), ← назад / свернуть,
// Enter — на строке программы: показать окно, на пункте: выполнить, Пробел — раскрыть/свернуть, Esc — назад / закрыть.
// Окно — под пилюлей трея: Bar передаёт её середину: qs -c yumi ipc call tray toggle <x>;
// qs -c yumi ipc call menu toggle tray — с прошлым/стандартным положением. Клик вне окна закрывает.
// Проверка: YP_DRYRUN=1 (Activate/пункты только в журнал), YUMI_TRAY_OPEN=<часть имени> — сразу раскрыть эту программу,
// YUMI_QS_NOKB=1; qs … ipc call tray key up|down|left|right|enter|space|esc · tray state
Scope {
    id: menu
    readonly property bool open: Menus.current === "tray"
    property int anchorX: 1040
    readonly property bool dry: Quickshell.env("YP_DRYRUN") === "1"
    readonly property string home: Quickshell.env("HOME")
    property string toast: ""
    property bool toastError: false

    // данные трея (элементы, скрытые, описания, свои значки) — общий синглтон TrayBus
    readonly property var list: TrayBus.list
    function describe(it) { return TrayBus.describe(it) }

    // ---- аккордеон ----
    property int sel: 0                        // программа с фокусом
    property string openApp: ""                // ключ (d.app) раскрытой программы; "" — все свёрнуты
    property bool inBody: false                // клавиатура внутри раскрытого раздела
    property bool onShow: false                // …на строке «Показать окно»
    readonly property int openIdx: list.findIndex(e => e.d.app === openApp)
    readonly property var current: openIdx >= 0 ? list[openIdx].item : null     // как раньше: программа, чьё меню открыто
    readonly property var currentDesc: openIdx >= 0 ? list[openIdx].d : null
    onListChanged: { if (sel >= list.length) sel = Math.max(0, list.length - 1); if (openApp && openIdx < 0) back() }

    Connections {
        target: TrayBus
        function onRequestMenu(item, x) {   // правый клик по значку в пилюле: меню сразу раскрыто на этой программе
            if (menu.open && menu.current === item) { Menus.close("tray"); return }
            if (x > 0) menu.anchorX = x
            menu.pending = item                       // открытие сбрасывает раскрытие (back) — применить после него
            if (!menu.open) Menus.open("tray")
            Qt.callLater(menu.applyPending)
        }
    }
    property var pending: null
    function applyPending() { if (pending) { openMenu(pending, TrayBus.describe(pending)); pending = null } }
    function plural(n) { return n + " " + (n % 10 === 1 && n % 100 !== 11 ? "программа" : (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 12 || n % 100 > 14)) ? "программы" : "программ") }
    function say(text, error, hold) { toast = text; toastError = !!error; toastTimer.interval = (hold || 3) * 1000; toastTimer.restart() }
    Timer { id: toastTimer; onTriggered: menu.toast = "" }

    function activate(it, d) {
        if (dry) { console.log("[dry-run] Activate " + d.name); say("dry-run: показать " + d.name); return }
        it.activate()
        Menus.close("tray")
    }
    function clickRow(it, d) { if (it.onlyMenu) openMenu(it, d); else activate(it, d) }
    function openMenu(it, d) {                  // раскрыть раздел программы
        const i = list.findIndex(e => e.item === it || e.d.app === d.app)
        if (i >= 0) sel = i
        openApp = d.app; inBody = false; onShow = false
        Qt.callLater(() => body.show(menu.sel))
    }
    function back() { openApp = ""; inBody = false; onShow = false }
    function toggleSec(i) { const e = list[i]; if (!e) return; if (openApp === e.d.app) back(); else openMenu(e.item, e.d) }
    function picked(label) {
        if (dry) say("dry-run: «" + label + "»")
        else Menus.close("tray")
    }
    function secItem(i) { return secRep.itemAt(i) }
    function enterBody() {                      // войти в раскрытый раздел: «Показать окно» или первый пункт меню
        const s = secItem(openIdx); if (!s) return
        sel = openIdx; inBody = true
        if (s.hasShowRow) { onShow = true; s.entries.focusIdx = -1 }
        else if (s.entries.focusFirst()) onShow = false
        else inBody = false
    }
    function key(k) {
        if (!list.length) { if (k === "esc") Menus.close("tray"); return }
        if (inBody) {
            const s = secItem(openIdx)
            if (!s) { inBody = false; return }
            if (onShow) {
                if (k === "down") { if (s.entries.focusFirst()) onShow = false }
                else if (k === "up" || k === "left" || k === "esc") { inBody = false; onShow = false }
                else if (k === "enter") activate(list[openIdx].item, list[openIdx].d)
                return
            }
            if (s.entries.key(k === "space" ? "enter" : k)) return
            if (k === "up") { if (s.hasShowRow) { onShow = true; s.entries.focusIdx = -1 } else inBody = false }
            else if (k === "left" || k === "esc") { inBody = false; s.entries.focusIdx = -1 }
            else if (k === "down") { inBody = false; s.entries.focusIdx = -1; if (sel < list.length - 1) sel++ }
            body.show(sel)
            return
        }
        if (k === "down") sel = Math.min(list.length - 1, sel + 1)
        else if (k === "up") sel = Math.max(0, sel - 1)
        else if (k === "right") { if (openIdx === sel) enterBody(); else openMenu(list[sel].item, list[sel].d) }
        else if (k === "left") { if (openIdx === sel) back() }
        else if (k === "space") toggleSec(sel)
        else if (k === "enter") clickRow(list[sel].item, list[sel].d)
        else if (k === "esc") { if (openApp) back(); else Menus.close("tray") }
        body.show(sel)
    }

    onOpenChanged: {
        if (open) {
            back(); sel = 0; toast = ""
            const want = (Quickshell.env("YUMI_TRAY_OPEN") || "").toLowerCase()
            if (want) wantTimer.restart()
        }
    }
    Timer { id: wantTimer; interval: 150; onTriggered: {
        const want = (Quickshell.env("YUMI_TRAY_OPEN") || "").toLowerCase()
        for (const e of menu.list) if (e.d.name.toLowerCase().indexOf(want) >= 0) { menu.openMenu(e.item, e.d); return }
    } }

    IpcHandler {
        target: "tray"
        function toggle(x: int): void { if (x > 0) menu.anchorX = x; Menus.toggle("tray") }
        function menuOf(name: string): void { for (const e of menu.list) if (e.d.name.toLowerCase().indexOf(name.toLowerCase()) >= 0) { menu.openMenu(e.item, e.d); return } }
        function back(): void { menu.back() }
        function sub(label: string): void {    // раскрыть подменю в раскрытой программе (проверка)
            const s = menu.secItem(menu.openIdx); if (s) s.entries.openedSub = s.entries.openedSub === label ? "" : label
        }
        function key(name: string): void { menu.key(name) }
        function state(): string {
            const s = menu.secItem(menu.openIdx)
            return JSON.stringify({ open: menu.open, programs: menu.list.map(e => e.d.name), sel: menu.sel, openApp: menu.openApp,
                                    inBody: menu.inBody, onShow: menu.onShow, entryFocus: s ? s.entries.focusIdx : -1,
                                    entries: s ? s.entries.count : 0, subActive: s ? s.entries.subActive : false })
        }
    }

    PillPopup {
        id: pop
        name: "tray"
        open: menu.open
        screen: Menus.screen
        marginTop: Theme.barH * (Theme.dev ? 2 : 1) + 6
        readonly property int screenW: Menus.screen ? Menus.screen.width : 1600
        marginRight: Math.max(0, Math.min(screenW - menu.anchorX - implicitWidth / 2, screenW - implicitWidth))
        contentW: 320                          // «Остров»: как в превью
        pad: 18
        readonly property int maxH: 640
        fixedH: maxH + pad * 2                 // окно постоянного размера; высоту анимирует карточка
        contentH: Math.min(col.implicitHeight, maxH) + pad * 2

        FocusScope {
            anchors.fill: parent
            focus: true
            Keys.onPressed: (e) => {
                const m = { [Qt.Key_Up]: "up", [Qt.Key_Down]: "down", [Qt.Key_Left]: "left", [Qt.Key_Right]: "right",
                            [Qt.Key_Return]: "enter", [Qt.Key_Enter]: "enter", [Qt.Key_Space]: "space", [Qt.Key_Escape]: "esc" }
                const k = m[e.key]
                if (k) { menu.key(k); e.accepted = true }
            }

            Flickable {
                id: body
                anchors.fill: parent
                contentHeight: col.implicitHeight
                clip: true; boundsBehavior: Flickable.StopAtBounds; interactive: contentHeight > height
                Behavior on contentY { NumberAnimation { duration: Theme.normal; easing.type: Theme.easeSoft } }
                function show(i) {                 // держать раздел с фокусом (или его раскрытое меню) в окне
                    const s = menu.secItem(i); if (!s) return
                    const y = s.y + secCol.y, h = Math.min(s.height, height - 40)
                    if (y < contentY + 4) contentY = Math.max(0, y - 8)
                    else if (y + h > contentY + height - 4) contentY = Math.max(0, Math.min(contentHeight - height, y + h - height + 8))
                }

                ColumnLayout {
                    id: col
                    width: body.width
                    spacing: 12

                    CardHead {
                        title: "Трей"; dry: menu.dry
                        status: menu.toast || (menu.list.length ? menu.plural(menu.list.length) + " в фоне" : "")
                        statusColor: menu.toast ? (menu.toastError ? Colors.bad : Colors.acc) : Colors.fgDim
                    }
                    Text { visible: menu.list.length === 0; Layout.fillWidth: true; leftPadding: 10; text: "Сейчас в фоне ничего нет"
                           font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fgDim }

                    // ---- разделы-программы ----
                    ColumnLayout {
                        id: secCol
                        Layout.fillWidth: true
                        spacing: 2
                        Repeater {
                            id: secRep
                            model: menu.list
                            delegate: Rectangle {
                                id: sec
                                required property var modelData
                                required property int index
                                readonly property var it: modelData.item
                                readonly property var d: modelData.d
                                readonly property bool attention: it.status === Status.NeedsAttention
                                readonly property bool isOpen: menu.openApp === d.app
                                readonly property bool kbHead: menu.sel === index && !menu.inBody
                                readonly property bool hasShowRow: isOpen && !it.onlyMenu && !entries.hasShow
                                property alias entries: entries
                                Layout.fillWidth: true
                                implicitHeight: secBody.implicitHeight
                                radius: Theme.radiusTile
                                color: sec.isOpen ? Colors.alpha(Colors.isl2, 0.6) : "transparent"   // раскрытый раздел — тихая подложка
                                Behavior on color { ColorAnimation { duration: Theme.fast } }
                                // каскад: opacity + y 8 px, 40 мс на строку
                                opacity: menu.open ? 1 : 0
                                property real dy: menu.open ? 0 : 8
                                transform: Translate { y: sec.dy }
                                Behavior on opacity { SequentialAnimation { PauseAnimation { duration: menu.open ? Theme.contentDelay + Math.min(sec.index, 12) * Theme.cascade : 0 } NumberAnimation { duration: 280; easing.type: Easing.OutCubic } } }
                                Behavior on dy { SequentialAnimation { PauseAnimation { duration: menu.open ? Theme.contentDelay + Math.min(sec.index, 12) * Theme.cascade : 0 } NumberAnimation { duration: 280; easing.type: Easing.OutCubic } } }

                                ColumnLayout {
                                    id: secBody
                                    anchors.left: parent.left; anchors.right: parent.right
                                    spacing: 0

                                    // строка программы
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 52; radius: Theme.radius
                                        color: sec.isOpen ? Colors.alpha(Colors.acc, 0.16) : rowMa.containsMouse ? Colors.isl2 : "transparent"
                                        border.width: sec.kbHead ? 1 : 0; border.color: Colors.alpha(Colors.acc, 0.7)
                                        Behavior on color { ColorAnimation { duration: Theme.fast } }
                                        scale: rowMa.pressed ? 0.985 : 1
                                        Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
                                        RowLayout {
                                            anchors.fill: parent; anchors.leftMargin: 9; anchors.rightMargin: 6; spacing: 12
                                            Rectangle {   // значок в квадрате 34 (раскрыт — акцент)
                                                implicitWidth: 34; implicitHeight: 34; radius: 12
                                                color: sec.isOpen ? Colors.acc : Colors.isl2
                                                Behavior on color { ColorAnimation { duration: Theme.normal } }
                                                Glyph { anchors.centerIn: parent; visible: TrayBus.style !== "dots"; text: sec.d.glyph; font.pixelSize: 16
                                                        color: sec.attention ? Colors.warn : sec.isOpen ? Colors.onAcc : Colors.fg }
                                                AppDot {   // стиль dots — тот же кружок цвета программы, что в баре (16.10)
                                                    anchors.centerIn: parent; visible: TrayBus.style === "dots"; size: 14
                                                    source: TrayBus.customIcon(sec.it, sec.d) || sec.it.icon
                                                    attn: sec.attention; hover: rowMa.containsMouse
                                                }
                                            }
                                            ColumnLayout {
                                                Layout.fillWidth: true; spacing: 1
                                                Text { Layout.fillWidth: true; text: sec.d.name; elide: Text.ElideRight; font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium; color: Colors.fg }
                                                Text {
                                                    Layout.fillWidth: true; elide: Text.ElideRight; font.family: Theme.fontUi; font.pixelSize: 12
                                                    readonly property string tip: String(sec.it.tooltipDescription || "").replace(/<[^>]*>/g, "").trim()
                                                    text: sec.attention ? "внимание" : (tip || (sec.it.onlyMenu ? "только меню" : "в фоне"))
                                                    color: sec.attention ? Colors.warn : Colors.fgDim
                                                }
                                            }
                                            Rectangle {   // 󰅂 — раскрыть меню программы
                                                visible: sec.it.hasMenu || !sec.it.onlyMenu
                                                implicitWidth: 32; implicitHeight: 32; radius: 16
                                                color: chevMa.containsMouse ? Colors.hover : "transparent"
                                                Behavior on color { ColorAnimation { duration: Theme.fast } }
                                                Glyph { anchors.centerIn: parent; text: "󰅂"; font.pixelSize: 16; color: Colors.fgDim
                                                        rotation: sec.isOpen ? 90 : 0
                                                        Behavior on rotation { NumberAnimation { duration: 320; easing.type: Easing.OutBack } } }
                                                MouseArea { id: chevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                            onClicked: { menu.sel = sec.index; menu.toggleSec(sec.index) } }
                                            }
                                        }
                                        MouseArea {
                                            id: rowMa; anchors.fill: parent; anchors.rightMargin: 38; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            onClicked: (e) => { menu.sel = sec.index; menu.inBody = false
                                                                if (e.button === Qt.RightButton) menu.toggleSec(sec.index); else menu.clickRow(sec.it, sec.d) }
                                        }
                                    }

                                    // раскрытое меню программы
                                    Reveal {   // меню программы под строкой, с отступом (без черты)
                                        shown: sec.isOpen
                                        spacing: 2
                                        Layout.leftMargin: 8; Layout.rightMargin: 6; Layout.topMargin: sec.isOpen ? 4 : 0; Layout.bottomMargin: sec.isOpen ? 6 : 0
                                        Rectangle {   // «Показать окно» — если у программы нет своего пункта
                                            visible: sec.hasShowRow
                                            Layout.fillWidth: true
                                            implicitHeight: 36; radius: 12
                                            readonly property bool kb: menu.inBody && menu.onShow && menu.openIdx === sec.index
                                            color: kb ? Colors.alpha(Colors.acc, 0.16) : showMa.containsMouse ? Colors.isl2 : "transparent"
                                            border.width: kb ? 1 : 0; border.color: Colors.alpha(Colors.acc, 0.7)
                                            Behavior on color { ColorAnimation { duration: Theme.fast } }
                                            RowLayout {
                                                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                                                Text { Layout.fillWidth: true; text: "Показать окно"; font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fg }
                                                Text { text: "↵"; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim }
                                            }
                                            MouseArea { id: showMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                        onClicked: menu.activate(sec.it, sec.d) }
                                        }
                                        Text { visible: sec.isOpen && (!sec.it.hasMenu || entries.count === 0); Layout.fillWidth: true; leftPadding: 10
                                               text: "Программа не отдаёт своё меню"; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim }
                                        TrayEntries {
                                            id: entries
                                            Layout.fillWidth: true
                                            handle: sec.isOpen && sec.it.hasMenu ? sec.it.menu : null
                                            dry: menu.dry
                                            open: sec.isOpen
                                            kbOn: menu.inBody && !menu.onShow && menu.openIdx === sec.index
                                            onPicked: label => menu.picked(label)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ---- подсказки ----
                    CardHints {
                        visible: menu.list.length > 0
                        items: menu.inBody ? [["↑↓", "пункт"], ["↵", "выполнить"], ["←", "назад"]]
                                           : [["↑↓", "программа"], ["↵", "окно"], ["→", "меню"]]
                    }
                }
            }
        }
    }
}
