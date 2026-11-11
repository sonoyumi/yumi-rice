import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services

// «Остров» (29.10): кнопка внутри острова бара (.k в превью): высота 24, radius 12, наведение isl2, нажатие 0.94,
// открытое меню (menu === Menus.current) или active — подложка акцентом 22 % и содержимое акцентом.
// Меню открывается из самой кнопки: Menus.toggleFrom(menu, кнопка) — карточка вырастает из неё.
// Свои команды: cmd/cmdRight/cmdMid/cmdUp/cmdDown (оболочка) или сигналы clicked/rightClicked/middleClicked/scrolled.
// У вложенных Mod свойство lit привязывается к on — значок и текст становятся акцентом.
// tip — подсказка самой кнопки (у Mod — своя, по его области).
Item {
    id: k
    default property alias content: row.data
    property string menu: ""                 // имя меню в Menus: подсветка, пока открыто; клик — toggleFrom (если нет cmd)
    property bool   active: false
    property bool   danger: false            // наведение красноватое (питание системы)
    property string cmd: ""
    property string cmdRight: ""
    property string cmdMid: ""
    property string cmdUp: ""
    property string cmdDown: ""
    property string tip: ""
    // меню, которое открывается через IPC с координатой кнопки (top/tray/airpods: `<ipcX> toggle <x>` ставит anchorX меню):
    // откуда растёт карточка, бар записывает в Menus сам, затем зовёт IPC
    property string ipcX: ""
    property int    padX: 6                 // 29.10: было 8 — подписи Wi-Fi и режима должны помещаться, как в живом баре
    property alias  spacing: row.spacing
    // полоска прогресса по нижнему краю (бэкап): busy — показать; progress 0..1, < 0 — неизвестно (бегущий отрезок)
    property bool   busy: false
    property real   progress: -1
    readonly property bool hovered: hov.hovered
    readonly property bool on: active || (menu !== "" && Menus.current === menu)
    readonly property var win: QsWindow.window      // Tooltip сверяет, его ли это кнопка
    signal clicked()
    signal rightClicked()
    signal middleClicked()
    signal scrolled(int dir)

    function run(c) { if (c) Quickshell.execDetached(["sh", "-c", c]) }
    // открыть своё меню из этой кнопки
    function openMenu() {
        if (!menu) return
        if (!ipcX) { Menus.toggleFrom(menu, k); return }
        const p = k.mapToItem(null, 0, 0)
        Menus.fromName = menu; Menus.fromX = p.x; Menus.fromY = p.y; Menus.fromW = k.width; Menus.fromH = k.height
        Quickshell.execDetached(["qs", "-c", "yumi", "ipc", "call", ipcX, "toggle", String(Math.round(p.x + k.width / 2))])
    }

    implicitHeight: 24
    implicitWidth: Math.max(24, row.implicitWidth + padX * 2)
    Layout.alignment: Qt.AlignVCenter
    Behavior on implicitWidth { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: k.on ? Colors.alpha(Colors.acc, 0.22)
             : k.hovered ? (k.danger ? Colors.mix(Colors.isl2, Colors.bad, 0.3) : Colors.isl2)
             : Colors.alpha(Colors.isl2, 0)
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    Item {   // полоска прогресса: дорожка + заполнение акцентом, внутри скругления кнопки
        id: prog
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 8; rightMargin: 8; bottomMargin: 2 }
        height: 2
        opacity: k.busy ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
        readonly property bool known: k.progress >= 0
        Rectangle { anchors.fill: parent; radius: 1; color: Colors.alpha(Colors.acc, 0.22) }
        Rectangle {
            id: fill
            height: parent.height; radius: 1; color: Colors.acc
            x: prog.known ? 0 : slide.pos * (prog.width - width)
            width: prog.known ? prog.width * Math.min(1, k.progress) : prog.width * 0.3
            Behavior on width { enabled: prog.known; NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        }
        QtObject { id: slide; property real pos: 0 }
        SequentialAnimation {   // неизвестный объём — отрезок ездит туда-обратно
            running: k.busy && !prog.known && prog.visible
            loops: Animation.Infinite
            NumberAnimation { target: slide; property: "pos"; from: 0; to: 1; duration: 900; easing.type: Easing.InOutSine }
            NumberAnimation { target: slide; property: "pos"; from: 1; to: 0; duration: 900; easing.type: Easing.InOutSine }
        }
    }
    scale: ma.pressed ? 0.94 : 1
    Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
    }
    // значки и текст вложенных модулей — акцентом, пока меню открыто
    Component.onCompleted: { for (const c of row.children) if (c.lit !== undefined) c.lit = Qt.binding(() => k.on) }

    HoverHandler { id: hov; onHoveredChanged: { if (hovered) delay.restart(); else { delay.stop(); Tips.hide(k) } } }
    Timer { id: delay; interval: 500; onTriggered: if (k.tip && hov.hovered) Tips.show(k, k.tip) }

    MouseArea {   // под содержимым: у Mod со своей командой клик остаётся у Mod
        id: ma
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: (e) => {
            Tips.hide(k)
            if (e.button === Qt.LeftButton) { k.clicked(); if (k.cmd) k.run(k.cmd); else k.openMenu() }
            else if (e.button === Qt.RightButton) { k.rightClicked(); k.run(k.cmdRight) }
            else { k.middleClicked(); k.run(k.cmdMid) }
        }
        onWheel: (w) => {
            const up = w.angleDelta.y > 0
            k.scrolled(up ? 1 : -1)
            k.run(up ? k.cmdUp : k.cmdDown)
        }
    }
}
