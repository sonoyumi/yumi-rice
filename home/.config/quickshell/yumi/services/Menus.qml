pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Общий переключатель меню на QML. Открыто не больше одного: меню привязывается к `Menus.current === "<имя>"`.
//   qs -c yumi ipc call menu toggle wifi|bluetooth|…   открыть / закрыть (повторный вызов закрывает)
//   qs -c yumi ipc call menu open <имя> | close <имя> | closeAll | rect (карточка открытого меню на экране — для проверок)
// Новое меню регистрировать не нужно — достаточно использовать своё имя (open: Menus.current === "<имя>").
// Совместимость: register(name, win) — окно со свойством open; тогда open/close выставляют win.open сами. YUMI_QS_OPEN=<имя> — открыть при старте (для проверки).
// screen — монитор, на котором показывать меню: где курсор в момент открытия (YUMI_QS_SCREEN=eDP-1 — всегда этот).
Singleton {
    id: root
    property string current: ""
    property var screen: Quickshell.screens.length ? Quickshell.screens[0] : null   // никогда не null после старта: окно с пустым экраном роняет Qt (QWindow::setScreen) при перезагрузке
    signal opened(string name)
    signal closed(string name)
    property var items: ({})                                   // register(): имя → окно (необязательно)
    function register(name, win) { items[name] = win }
    property var cards: ({})                                   // Popup: имя → окно (cardRect())
    function isOpen(name) { return current === name }

    function toggle(name) { if (current === name) close(name); else open(name) }
    // «Остров» (29.10): откуда открыто — меню вырастает из этой пилюли. item — элемент бара (окно бара у верхнего края экрана,
    // координаты окна = координаты экрана по x). Без toggleFrom меню растёт из своей верхней середины.
    property string fromName: ""
    property real fromX: 0; property real fromY: 0; property real fromW: 0; property real fromH: 0
    function toggleFrom(name, item) {
        if (item) { const p = item.mapToItem(null, 0, 0); fromName = name; fromX = p.x; fromY = p.y; fromW = item.width; fromH = item.height }
        else fromName = ""
        toggle(name)
    }
    // меню по бинду: по центру экрана в фокусе, от курсора не закрывается (как yumi-menu-* --center)
    property string centered: ""
    function toggleCenter(name) { if (current === name) close(name); else open(name, true) }
    // Сначала экран, открыть — следующим кадром: иначе окно открывается на прежнем мониторе и тут же переезжает,
    // а при переезде ловит ложный «клик/уход курсора» и закрывается (меню с MSI после меню на макбуке).
    function open(name, center) {
        centered = center ? name : ""
        pickScreen()
        Qt.callLater(() => { if (current && current !== name) closed(current); current = name; opened(name); sync() })
    }
    function pickScreen() {
        const want = Quickshell.env("YUMI_QS_SCREEN") || (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "")
        let s = null
        for (const sc of Quickshell.screens) if (sc.name === want) s = sc
        screen = s || (Quickshell.screens.length ? Quickshell.screens[0] : null)
    }
    Component.onCompleted: { const o = Quickshell.env("YUMI_QS_OPEN"); if (o) open(o); else pickScreen() }
    function close(name) { if (!name || current === name) { const was = current; current = ""; if (was) closed(was); sync() } }
    function sync() { for (const k in items) if (items[k] && items[k].open !== (k === current)) items[k].open = (k === current) }

    IpcHandler {
        target: "menu"
        function toggle(name: string): void { root.toggle(name) }
        function center(name: string): void { root.toggleCenter(name) }
        function open(name: string): void { root.open(name) }
        function close(name: string): void { root.close(name) }
        function closeAll(): void { root.close("") }
        function current(): string { return root.current }
        function rect(): string { const w = root.cards[root.current]; if (!w) return ""; const r = w.cardRect(); return [r.x, r.y, r.width, r.height].join(" ") }
    }
}
