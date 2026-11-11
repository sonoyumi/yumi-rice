import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// Карточка меню под баром (16.10): то же, что components/Popup, плюс YUMI_QS_NOKB=1 (проверка без захвата клавиатуры).
// grow: true — «Карточка из пилюли» (вариант 01 страницы статичных меню): карточка
// вырастает из пилюли, которую нажали, — хвостик-указатель на пилюлю, рост из этой точки (по высоте быстрее, чем
// по ширине, с пружиной). Где пилюля: меню из бара открывается кликом, поэтому в момент открытия курсор стоит на ней
// (hyprctl cursorpos); открыто биндом (Menus.centered) или курсор не на баре — по центру / на прежнем месте, без хвостика.
// Закрытие — как у Popup: Esc (если меню не перехватило), клик мимо, курсор далеко (closeOnLeave), holdOpen — не закрывать.
// Клавиатура: Exclusive, YUMI_QS_NOKB=1 — без захвата (проверки на eDP-1 не забирают ввод пользователя).
PanelWindow {
    id: win
    property string name: "card"
    property bool open: false
    property int contentW: Theme.menuW
    property int contentH: 200
    property int fixedH: 0
    property int marginTop: Theme.barH * (Theme.dev ? 2 : 1) + 6
    property int marginRight: 160          // без пилюли: карточка на marginRight + 20 от правого края (как Popup)
    property bool closeOnLeave: true
    property bool holdOpen: false
    property bool grow: true               // false — обычная карточка (как Popup): без хвостика, рост 0.85→1 от центра верха
    readonly property bool byBind: Menus.centered === name
    property int pad: Theme.menuPad       // внутренний отступ карточки (меню «Острова» ставят 18)
    default property alias content: inner.data

    // ---- где пилюля (лог. px окна) ----
    property real pillX: -1
    property bool posReady: false
    readonly property bool shown: open && posReady
    Process {
        id: cursor
        command: ["hyprctl", "cursorpos", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const c = JSON.parse(text), s = win.screen
                    const lx = c.x - (s ? s.x : 0), ly = c.y - (s ? s.y : 0)
                    win.pillX = (lx >= 0 && lx <= win.width && ly >= 0 && ly <= win.marginTop + 4) ? lx : -1
                } catch (e) { win.pillX = -1 }
                win.posReady = true
            }
        }
    }
    Timer { id: posWait; interval: 120; onTriggered: win.posReady = true }   // hyprctl не ответил — открыть как есть
    onOpenChanged: {
        far.reset()
        if (open) {
            closer.stop(); grace.restart()
            if (byBind || !grow) { pillX = -1; posReady = true }
            else if (Quickshell.env("YUMI_QS_PILLX")) { pillX = parseFloat(Quickshell.env("YUMI_QS_PILLX")); posReady = true }   // проверка без курсора
            else { posReady = false; pillX = -1; cursor.running = true; posWait.restart() }
            scope.focus = true
        } else { scope.focus = false; closer.start() }
    }

    visible: open || closer.running
    color: "transparent"
    WlrLayershell.namespace: "yumi-qs-" + name
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: open && Quickshell.env("YUMI_QS_NOKB") !== "1" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    mask: Region { x: card.x; y: card.y - 10; width: card.width; height: card.height + 10 }

    function dismiss() { if (Menus.current === name) Menus.close(name); else if (open) open = false }
    function cardRect() { return Qt.rect(card.x, card.y, card.width, card.height) }
    Component.onCompleted: Menus.cards[name] = win

    Timer { id: closer; interval: Theme.slow }
    Timer { id: grace; interval: 400 }
    readonly property bool settled: open && !grace.running

    FarWatch {
        id: far
        enabled: win.settled && win.closeOnLeave && !win.byBind && !win.holdOpen
        onFar: win.dismiss()
    }

    FocusScope {
        id: scope
        anchors.fill: parent
        Keys.onEscapePressed: win.dismiss()

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            onPressed: if (win.settled) win.dismiss()
            onPositionChanged: (m) => { far.rect = win.cardRect(); far.track(m.x, m.y) }
            onExited: far.reset()
        }

        Item {
            id: card
            readonly property real wantX: win.pillX >= 0 ? win.pillX - width / 2 : win.width - win.marginRight - 20 - width
            x: win.byBind ? Math.round((win.width - width) / 2)
                          : Math.round(Math.max(Theme.screenPad, Math.min(win.width - width - Theme.screenPad, wantX)))
            y: win.byBind ? Math.round((win.height - (win.fixedH > 0 ? win.fixedH : height)) / 2) : win.marginTop + 20
            width: win.contentW; height: win.contentH
            Behavior on height { enabled: win.fixedH > 0; NumberAnimation { duration: Theme.normal; easing.type: Theme.easeSoft } }
            // точка роста: хвостик (пилюля) или центр карточки
            readonly property real tailX: win.pillX >= 0 ? Math.max(28, Math.min(width - 28, win.pillX - x)) : width / 2
            opacity: win.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: win.shown ? Theme.fast : Theme.fast } }
            transform: Scale {
                origin.x: card.tailX
                origin.y: win.byBind ? card.height / 2 : 0
                xScale: win.shown ? 1 : (win.byBind ? 0.9 : win.grow ? 0.18 : 0.85)
                yScale: win.shown ? 1 : (win.byBind ? 0.9 : win.grow ? 0.05 : 0.85)
                // «Остров»: рост пружиной OutBack, как у components/Popup
                Behavior on xScale { NumberAnimation { duration: win.shown ? Theme.menuOpen : Theme.fast; easing.type: win.shown ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.15 } }
                Behavior on yScale { NumberAnimation { duration: win.shown ? Theme.menuOpen : Theme.fast; easing.type: win.shown ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.15 } }
            }

            // хвостик к пилюле — «Остров»: не рисуется (карточка просто растёт из пилюли)
            Rectangle {
                visible: false
                width: 14; height: 14; rotation: 45
                x: card.tailX - width / 2; y: -6
                color: glass.color
                border.width: 1; border.color: glass.border.color
            }
            Rectangle {
                id: glass
                anchors.fill: parent
                radius: Theme.radiusBig
                color: Colors.isl                                  // «Остров»: сплошной остров в оттенке обоев
                border.width: 1; border.color: Colors.edge
                Behavior on color { ColorAnimation { duration: Theme.normal } }
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; hoverEnabled: true; onEntered: far.reset(); property bool kwSkip: true }
                // шов над хвостиком (рамка хвоста не видна поверх карточки)
                Rectangle { visible: false; x: card.tailX - 8; y: 0; width: 16; height: 2; color: parent.color }
            }
            Item {
                id: inner; anchors.fill: parent; anchors.margins: win.pad
                opacity: win.shown ? 1 : 0                     // «Остров»: содержимое проявляется после начала роста
                Behavior on opacity { SequentialAnimation {
                    PauseAnimation { duration: win.shown ? Theme.contentDelay : 0 }
                    NumberAnimation { duration: win.shown ? 260 : 120; easing.type: Easing.OutCubic } } }
            }
        }
    }
}
