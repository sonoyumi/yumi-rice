import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// Всплывающее меню под баром (меню на QML). «Остров» (29.10): сплошной остров radius 26, растёт из пилюли (Menus.toggleFrom). Слой overlay, своё пространство имён yumi-qs-<name> — на него в Hyprland
// действуют правила размытия/анимации (rules.lua: yumi_qs_*). Открытие/закрытие — scale+opacity плавно, без пружины («Тушь», 19.10);
// само окно живёт, пока открыто или идёт анимация закрытия.
// Окно — НА ВЕСЬ ЭКРАН, прозрачное, карточка внутри (как у GTK-меню yumipanel.py). Так единое закрытие работает у всех
// меню одним механизмом: клавиатура у меню Exclusive (как rofi/GTK-меню), а слой с Exclusive в Hyprland получает весь ввод
// указателя («forced above all»), поэтому клик и движение курсора мимо карточки приходят в это же окно — отдельный слой
// под меню ввода не получил бы. Прозрачные пиксели для ввода сквозные (layerrule ignore_alpha), размытие — только карточка.
// Положение карточки: side "right" (marginRight — отступ карточки от правого края экрана минус 20, как раньше у окна),
// "left" (marginLeft — левый край карточки), "center" (по центру; это же даёт marginRight: -1); vcenter — по центру по вертикали.
// Закрытие (единое для всех меню): Esc (если его не перехватило само меню — назад/страницы), клик вне карточки,
// при closeOnLeave — курсор дальше Theme.menuFar от карточки на Theme.menuLeaveMs (возврат отменяет; меню по центру экрана
// ставят closeOnLeave: false; holdOpen — не закрывать от курсора, пока идёт операция). Всё — через dismiss():
// Menus.close(name), если меню открыто через Menus, иначе open = false.
PanelWindow {
    id: win
    property string name: "popup"
    property bool open: false
    property int contentW: Theme.menuW
    property int contentH: 200
    property int fixedH: 0                // >0: наибольшая высота карточки (меню со страницами); используется для vcenter.
                                          // Окно и так постоянного размера (весь экран), меняется только карточка.
    property int marginTop: Theme.barH + 8
    property int marginRight: -1          // -1 = по центру экрана; иначе карточка на marginRight + 20 от правого края
    property int marginLeft: Theme.screenPad   // side "left": левый край карточки на экране
    property string side: marginRight >= 0 ? "right" : "center"
    property bool vcenter: false          // карточка по центру экрана по вертикали (меню по бинду)
    property int origin: Item.Top         // откуда растёт карточка при открытии (Item.TopLeft — от пилюли у левого края)
    property bool closeOnLeave: true      // закрывать, когда курсор ушёл далеко (меню из бара); center — false
    property bool holdOpen: false         // идёт операция — от курсора не закрывать
    // открыто по бинду (Menus.toggleCenter) — по центру экрана, без закрытия от курсора
    readonly property bool byBind: Menus.centered === name   // сбрасывается при следующем открытии из бара — при закрытии карточка не прыгает
    readonly property string place: byBind ? "center" : side
    property int pad: Theme.menuPad       // «Тушь · B» (19.10): внутренний отступ карточки (меню B ставят 18)
    default property alias content: inner.data

    visible: open || closer.running
    color: "transparent"
    WlrLayershell.namespace: "yumi-qs-" + name
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    readonly property bool nokb: Quickshell.env("YUMI_QS_NOKB") === "1"   // проверка снимками: клавиатуру не забирать
    WlrLayershell.keyboardFocus: open && !nokb ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    mask: Region { x: card.x; y: card.y; width: card.width; height: card.height }

    function dismiss() { if (Menus.current === name) Menus.close(name); else if (open) open = false }
    function cardRect() { return Qt.rect(card.x, card.y, card.width, card.height) }   // карточка на экране (лог. px)
    Component.onCompleted: Menus.cards[name] = win                                  // для проверки: qs … ipc call menu rect

    Timer { id: closer; interval: Theme.slow }
    // первые 0,4 с после открытия мышь не закрывает меню (окно только что встало на экран / переехало)
    Timer { id: grace; interval: 400 }
    readonly property bool settled: open && !grace.running
    onOpenChanged: {
        far.reset()
        if (open) grace.restart()
        if (open) scope.focus = true
        else { scope.focus = false; closer.start() }   // снять фокус до скрытия — иначе Qt падает, уничтожая элемент с фокусом
    }

    FarWatch {
        id: far
        enabled: win.settled && win.closeOnLeave && !win.byBind && !win.holdOpen
        onFar: win.dismiss()
    }

    FocusScope {
        id: scope
        anchors.fill: parent
        Keys.onEscapePressed: win.dismiss()     // Esc, который не перехватило меню (назад/страницы — в самом меню)

        // поле вокруг карточки: клик — закрыть, движение — правило «курсор ушёл далеко»
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            onPressed: if (win.settled) win.dismiss()
            onPositionChanged: (m) => { far.rect = win.cardRect(); far.track(m.x, m.y) }
            onExited: far.reset()               // курсор над карточкой (её кнопками) или ушёл с экрана — не «далеко»
        }

        Rectangle {
            id: card
            x: win.place === "left" ? win.marginLeft : win.place === "right" ? win.width - win.marginRight - 20 - width : Math.round((win.width - width) / 2)
            y: (win.vcenter || win.byBind) ? Math.round((win.height - (win.fixedH > 0 ? win.fixedH : height)) / 2) : win.marginTop
            width: win.contentW; height: win.contentH
            Behavior on height { enabled: win.fixedH > 0; NumberAnimation { duration: Theme.normal; easing.type: Theme.easeSoft } }
            radius: Theme.radiusBig
            color: Colors.isl                                  // «Остров»: сплошной остров в оттенке обоев
            border.width: 1; border.color: Colors.edge
            Behavior on color { ColorAnimation { duration: Theme.normal } }

            // «Остров» (29.10): карточка вырастает из пилюли, по которой открыта (Menus.toggleFrom), пружиной OutBack;
            // по бинду / без пилюли — из верхней середины (по центру — из центра). Закрытие — быстро внутрь.
            readonly property bool fromPill: Menus.fromName === win.name && !win.byBind && win.screen === Menus.screen
            readonly property real ax: fromPill ? Math.max(0, Math.min(width, Menus.fromX + Menus.fromW / 2 - x)) : width / 2
            readonly property real ay: fromPill ? Menus.fromY + Menus.fromH / 2 - y : (win.byBind || win.vcenter ? height / 2 : 0)
            readonly property real s0x: fromPill ? Math.max(0.6, Math.min(1, Menus.fromW / Math.max(1, width))) : 0.92   // 29.10: от 60 %, не из точки
            readonly property real s0y: fromPill ? Math.max(0.6, Math.min(1, Menus.fromH / Math.max(1, height))) : 0.92
            property real grow: win.open ? 1 : 0
            Behavior on grow { NumberAnimation { duration: win.open ? Theme.menuOpen : Theme.fast
                                                 easing.type: win.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 0.8 } }
            transform: Scale { origin.x: card.ax; origin.y: card.ay
                               xScale: card.s0x + (1 - card.s0x) * card.grow; yScale: card.s0y + (1 - card.s0y) * card.grow }
            opacity: Math.min(1, grow * 2.5)
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; hoverEnabled: true; onEntered: far.reset() }   // клики по карточке — не «мимо»
            Item {
                id: inner; anchors.fill: parent; anchors.margins: win.pad
                opacity: win.open ? 1 : 0                       // содержимое проявляется после начала роста
                Behavior on opacity { SequentialAnimation {
                    PauseAnimation { duration: win.open ? Theme.contentDelay : 0 }
                    NumberAnimation { duration: win.open ? 150 : 100; easing.type: Easing.OutCubic } } }
            }
        }
    }
}
