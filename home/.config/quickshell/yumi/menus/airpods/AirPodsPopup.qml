import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components

// Уведомление «AirPods подключены» (18.10): пилюля сверху по центру, как попап громкости, — значок AirPods из бара,
// имя и «Подключено»; появляется пружиной, через ~3 с уходит. Без действий и виджетов.
// Зовёт служба yumi-airpods при подключении: qs -c yumi ipc call -- airpodsPopup show "<имя>".
Scope {
    id: root
    property string name: "AirPods"

    IpcHandler {
        target: "airpodsPopup"
        function show(name: string): void { if (name) root.name = name; win.open = true; hide.restart() }
    }
    Timer { id: hide; interval: 3200; onTriggered: win.open = false }

    PanelWindow {
        id: win
        property bool open: false
        visible: open || closer.running
        color: "transparent"
        WlrLayershell.namespace: "yumi-qs-airpods"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors.top: true
        margins.top: Theme.barH + 6 + (Theme.dev ? Theme.barH : 0)
        implicitWidth: 420                           // окно постоянного размера — анимируется только пилюля
        implicitHeight: 60 + 40
        mask: Region {}                              // мышь проходит сквозь

        Timer { id: closer; interval: Theme.slow }
        onOpenChanged: if (!open) closer.start()

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 10
            height: 56
            width: row.implicitWidth + 32             // «Остров»: остров-капсула isl, кромка edge
            radius: height / 2
            color: Colors.isl
            border.width: 1; border.color: Colors.edge
            transformOrigin: Item.Top
            property real grow: win.open ? 1 : 0
            Behavior on grow { NumberAnimation { duration: win.open ? Theme.menuOpen : Theme.fast
                                                 easing.type: win.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.15 } }
            opacity: Math.min(1, grow * 3)
            scale: 0.6 + 0.4 * grow

            RowLayout {
                id: row
                anchors.centerIn: parent
                spacing: 12
                Rectangle {
                    implicitWidth: 38; implicitHeight: 38; radius: 19; color: Colors.acc
                    PodsGlyph { anchors.centerIn: parent; pixelSize: 24; color: Colors.onAcc }
                }
                ColumnLayout {
                    spacing: 1
                    Text { text: root.name; font.family: Theme.fontUi; font.pixelSize: 14; font.weight: Font.DemiBold; color: Colors.fg }
                    Text { text: "подключено"; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim }
                }
            }
        }
    }
}
