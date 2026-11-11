import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services

// Меню звука на QML (замена ~/.local/bin/yumi-menu-sound): окно постоянного размера под баром,
// страницы сменяются внутри (главная → устройство / вывод потока / запись / карта).
//   qs -c yumi ipc call menu toggle sound   (общий переключатель Menus; YUMI_QS_OPEN=sound — открыть при старте)
// Esc — назад / закрыть. Пока открыто, живёт бэкенд (Sound.active).
SoundPopup {
    id: win
    name: "sound"
    // микшер строками; на главной высота по числу строк, страницы — 560. «Остров»: карточка 440, отступ 18
    contentW: 440
    pad: 18
    fixedH: 560 + pad * 2
    contentH: (win.stack.length || !pager.item || pager.item.wantH === undefined ? 560
               : Math.min(560, headRow.implicitHeight + 12 + pager.item.wantH)) + pad * 2
    marginRight: 92                       // под пилюлей со звуком (правый блок бара)
    screen: Menus.screen                  // монитор, где курсор при открытии (YUMI_QS_SCREEN — принудительно)
    open: Menus.current === "sound"
    function close() { Menus.close("sound") }
    onOpenChanged: {
        Sound.active = open
        if (!open) stack = []
        else Qt.callLater(() => { if (pager.item && pager.item.reset) pager.item.reset(); win.focusPage() })
    }

    // ---------- клавиатура (16.10): всё меню стрелками ----------
    // Главная страница (key(имя)) ведёт свои зоны сама; на остальных ↑↓ ходят по фокусируемым строкам/ползункам/кнопкам
    // (Kb.js), а сюда доходит то, что они не взяли. Esc — назад / закрыть.
    readonly property var keyNames: ({ [Qt.Key_Up]: "up", [Qt.Key_Down]: "down", [Qt.Key_Left]: "left", [Qt.Key_Right]: "right",
                                       [Qt.Key_Return]: "enter", [Qt.Key_Enter]: "enter", [Qt.Key_Space]: "space",
                                       [Qt.Key_Tab]: "tab", [Qt.Key_Backtab]: "tab", [Qt.Key_Period]: "period", [Qt.Key_Escape]: "esc" })
    function focusPage() {
        const it = pager.item
        if (!it || !win.open) return
        if (it.key) { it.forceActiveFocus(); return }
        const n = it.nextItemInFocusChain(true)   // первая строка / кнопка страницы
        if (n) n.forceActiveFocus(); else it.forceActiveFocus()
    }
    function routeKey(name) {
        if (name === "esc") { win.pop(); return true }
        const it = pager.item
        if (it && it.key) return it.key(name)
        if (name === "up" || name === "down" || name === "tab") { focusPage(); return true }   // фокус потерян — вернуть на страницу
        return false
    }
    IpcHandler {                       // проверка без клавиатуры: qs … ipc call soundmenu key down|up|left|right|enter|space|tab|esc
        target: "soundmenu"
        function key(name: string): void { win.routeKey(name) }
        function state(): string {
            const it = pager.item
            return JSON.stringify({ open: win.open, depth: win.stack.length, tab: it && it.tab, zone: it && it.zone,
                                    btn: it && it.btn, app: it && it.app })
        }
    }

    // ---------- стек страниц ----------
    property var stack: []                // [{title, src, props}]
    function push(title, src, props) { stack = stack.concat([{ title: title, src: src, props: props }]) }
    function pop() { if (stack.length) stack = stack.slice(0, -1); else close() }
    readonly property var top: stack.length ? stack[stack.length - 1] : null
    onTopChanged: pager.show()

    // тост на месте подзаголовка
    property string toastText: ""
    property bool toastError: false
    Timer { id: toastTimer; interval: 3000; onTriggered: win.toastText = "" }
    Connections { target: Sound; function onToast(t, e) { win.toastText = t; win.toastError = e; toastTimer.restart() } }

    FocusScope {
        anchors.fill: parent
        focus: win.open                // без фокуса при закрытии: иначе segfault в clearFocusInScope при уничтожении
        Keys.onPressed: (e) => { const n = win.keyNames[e.key]; if (n && win.routeKey(n)) e.accepted = true }

        ColumnLayout {
            anchors.fill: parent
            spacing: 12

            // ---------- шапка («Остров»: как CardHead — назад-кружок, название 16 DemiBold, состояние 12, закрыть) ----------
            RowLayout {
                id: headRow
                Layout.fillWidth: true
                spacing: 10
                Rectangle {   // назад
                    visible: width > 0
                    Layout.preferredWidth: win.stack.length ? 32 : 0; Layout.preferredHeight: 32
                    radius: 16; clip: true
                    color: backArea.containsMouse ? Colors.hover : Colors.isl2
                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 380; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                    scale: backArea.pressed ? 0.94 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.fast } }
                    Glyph { anchors.centerIn: parent; text: "󰅁"; font.pixelSize: 17 }
                    MouseArea { id: backArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.pop() }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        Layout.fillWidth: true
                        text: win.top && (win.top.title || (pager.item && pager.item.title)) ? (win.top.title || pager.item.title) : "Звук"
                        font.family: Theme.fontUi; font.pixelSize: 16; font.weight: Font.DemiBold; color: Colors.fg; elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: win.toastText ? win.toastText : (pager.item && pager.item.subtitle !== undefined ? pager.item.subtitle : "")
                        font.family: Theme.fontUi; font.pixelSize: 12
                        color: win.toastText ? (win.toastError ? Colors.bad : Colors.acc) : Colors.fgDim
                        elide: Text.ElideRight
                        Behavior on color { ColorAnimation { duration: Theme.fast } }
                    }
                }
                Rectangle {   // закрыть — круглая кнопка
                    Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 16
                    color: closeArea.containsMouse ? Colors.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                    Glyph { anchors.centerIn: parent; text: "󰅖"; font.pixelSize: 15; color: Colors.fgDim }
                    MouseArea { id: closeArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.close() }
                }
            }

            // ---------- страницы ----------
            Item {
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true
                Loader {
                    id: pager
                    anchors.fill: parent
                    focus: true
                    property bool back: false
                    function show() {
                        const t = win.top
                        back = !t || (item && item.depth !== undefined && item.depth > win.stack.length)
                        if (t) setSource(t.src, Object.assign({ menu: win }, t.props))
                        else setSource("MainPage.qml", { menu: win })
                    }
                    Component.onCompleted: show()
                    onLoaded: { item.width = width; item.height = height; Qt.callLater(win.focusPage); slide.from = back ? -30 : 30; slide.restart(); fade.restart() }
                    NumberAnimation { id: slide; target: pager.item; property: "x"; to: 0; duration: Theme.normal; easing.type: Theme.easeSoft }
                    NumberAnimation { id: fade; target: pager.item; property: "opacity"; from: 0; to: 1; duration: Theme.fast }
                }
            }
        }
    }
}
