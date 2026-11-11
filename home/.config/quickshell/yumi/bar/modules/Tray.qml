import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs
import qs.components
import qs.menus.tray

// Трей бара на штатном Quickshell.Services.SystemTray (вместо одноцветного yumi-tray bar).
// Значки родные цветные (размер Theme.barIcon, sourceSize × devicePixelRatio — без мыла); свой значок —
// ~/.config/yumi/tray/icons/<ключ>.svg|.png (ключи — TrayBus.keys: Id, программа, имя значка, Title, имя);
// ~/.config/yumi/tray/style = mono — глифы Nerd Font yumi-tray вместо значков. Порядок и скрытые — как в yumi-tray.
// Клик — показать окно (Activate; у ItemIsMenu — меню), средний — SecondaryActivate, правый — меню программы
// в TrayMenu (сразу на её странице), колесо — Scroll. Требует внимания — мягкая пульсация.
// YP_DRYRUN=1 — действия только в журнал.
RowLayout {
    id: root
    readonly property int count: rep.count
    readonly property bool attention: TrayBus.list.some(e => e.item.status === Status.NeedsAttention)
    readonly property bool dry: Quickshell.env("YP_DRYRUN") === "1"
    readonly property int size: Theme.barIcon
    spacing: 6

    Repeater {
        id: rep
        model: TrayBus.list
        delegate: Item {
            id: cell
            required property var modelData
            readonly property var it: modelData.item
            readonly property var d: modelData.d
            readonly property bool attn: it.status === Status.NeedsAttention
            readonly property string own: TrayBus.customIcon(it, d)
            readonly property bool mono: TrayBus.style === "mono" && !own
            // dots: вместо значка — кружок цвета программы. Цвет берётся из её значка один раз при загрузке:
            // средний оттенок насыщенных пикселей → пастель в коридоре светлоты акцента бара; серый значок — нейтральный кружок
            readonly property bool dots: TrayBus.style === "dots"
            readonly property var win: QsWindow.window          // Tooltip сверяет, его ли это модуль
            implicitWidth: root.size + 2; implicitHeight: Math.max(root.size + 2, Theme.pillH - 4)

            Item {
                id: face
                anchors.centerIn: parent
                width: root.size; height: root.size
                opacity: ma.containsMouse ? 1 : 0.92
                scale: ma.pressed ? 0.88 : 1
                Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Theme.easeSpring } }
                Image {
                    id: icon
                    anchors.fill: parent
                    visible: !cell.mono && !cell.dots
                    source: cell.own || cell.it.icon
                    // родной PNG/SVG рисуется в физических пикселях экрана (scale 1.6) — без мыла
                    readonly property real dpr: (cell.win && cell.win.screen) ? cell.win.screen.devicePixelRatio : 1
                    sourceSize.width: Math.ceil(root.size * dpr); sourceSize.height: Math.ceil(root.size * dpr)
                    fillMode: Image.PreserveAspectFit
                    smooth: true; mipmap: true
                    asynchronous: true
                    cache: false
                }
                AppDot {     // dots: кружок цвета программы (общий с меню фоновых программ)
                    anchors.centerIn: parent
                    visible: cell.dots
                    source: cell.own || cell.it.icon
                    attn: cell.attn; hover: ma.containsMouse
                }
                Glyph {
                    anchors.centerIn: parent
                    visible: cell.mono
                    text: cell.d.glyph; font.pixelSize: root.size
                    color: cell.attn ? Colors.warn : Colors.fg
                }
            }
            // требует внимания: лёгкая пульсация (прозрачность + чуть масштаб)
            SequentialAnimation {
                running: cell.attn
                loops: 4      // несколько вдохов и стоп (цвет warn остаётся): вечная пульсация перерисовывала бар каждый кадр (16.10)
                onRunningChanged: if (!running) { face.opacity = Qt.binding(() => ma.containsMouse ? 1 : 0.92) }
                NumberAnimation { target: face; property: "opacity"; to: 0.45; duration: 700; easing.type: Easing.InOutSine }
                NumberAnimation { target: face; property: "opacity"; to: 1; duration: 700; easing.type: Easing.InOutSine }
            }
            Rectangle {   // точка-метка внимания под значком
                visible: cell.attn
                width: 4; height: 4; radius: 2
                anchors.horizontalCenter: parent.horizontalCenter; anchors.top: face.bottom; anchors.topMargin: 1
                color: Colors.warn
            }

            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                function x0() { return Math.round(cell.mapToItem(null, cell.width / 2, 0).x) }
                onClicked: (e) => {
                    Tips.hide(cell)
                    // как было в Waybar: левый — меню-список фоновых программ, средний и правый — показать окно программы
                    if (e.button === Qt.LeftButton) { Quickshell.execDetached(["qs", "-c", "yumi", "ipc", "call", "tray", "toggle", String(x0())]); return }
                    if (cell.it.onlyMenu) { TrayBus.requestMenu(cell.it, x0()); return }
                    if (root.dry) { console.log("[dry-run] Activate " + cell.d.name); return }
                    cell.it.activate()
                }
                onWheel: (w) => {
                    const horiz = Math.abs(w.angleDelta.x) > Math.abs(w.angleDelta.y)
                    const delta = horiz ? w.angleDelta.x : w.angleDelta.y
                    if (root.dry) console.log("[dry-run] Scroll " + cell.d.name + " " + delta); else cell.it.scroll(delta, horiz)
                }
                onEntered: delay.restart()
                onExited: { delay.stop(); Tips.hide(cell) }
            }
            Timer {
                id: delay; interval: 500
                onTriggered: if (ma.containsMouse) Tips.show(cell, cell.d.name + (cell.attn ? "  · требует внимания" : "")
                                                              + (cell.it.tooltipDescription ? "<br>" + cell.it.tooltipDescription : ""))
            }
        }
    }
}
