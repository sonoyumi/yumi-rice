import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// Подсказка под модулем бара — как tooltip в user-style.css: фон deep 0.94; «Тушь» (19.10): кромка 1 px нейтральная
// (было 2 px wb-act-bg), radius 6 (было Theme.radius), появление через 500 мс (таймер в Mod) с затуханием 250 мс (fadeIn HyDE), уход — Theme.fast.
// Одно окно на бар: прозрачная полоса под баром без ввода (пустая маска), карточка встаёт под модуль.
PanelWindow {
    id: win
    required property var bar                      // окно бара этого экрана
    readonly property bool shown: Tips.target !== null && Tips.target.win === bar
    property real cx: 0                            // центр модуля в координатах бара

    screen: bar.screen
    anchors { top: true; left: true; right: true }
    margins.top: Theme.barH * (1 + Theme.devLevel)
    implicitHeight: 240
    color: "transparent"
    WlrLayershell.namespace: "yumi-qs-tooltip"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    mask: Region {}                                // клики и наведение проходят сквозь
    visible: shown || fade.running

    onShownChanged: if (shown) {
        const p = Tips.target.mapToItem(null, 0, 0)
        cx = p.x + Tips.target.width / 2
    }

    Rectangle {
        id: card
        readonly property int padX: 12      // «Тушь · B» (19.10): отступы шире, стекло и кромка как у карточек B
        readonly property int padY: 8
        x: Math.round(Math.max(Theme.screenPad, Math.min(win.cx - width / 2, win.width - width - Theme.screenPad)))
        y: 2
        width: label.width + padX * 2 + 4
        height: Math.ceil(label.contentHeight) + padY * 2 + 4
        radius: 14                                  // «Остров» (29.10): сплошной остров isl с кромкой edge
        color: Colors.isl
        border.width: 1
        border.color: Colors.edge
        opacity: win.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { id: fade; duration: win.shown ? 250 : Theme.fast; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: Theme.normal } }
        Behavior on border.color { ColorAnimation { duration: Theme.normal } }
        Text {   // скрытый замер: у RichText contentWidth = заданная ширина, поэтому меряем без переноса
            id: probe
            visible: false
            textFormat: Text.RichText
            text: label.text
            font.family: Theme.fontUi
            font.pixelSize: Theme.barFont
        }
        Text {
            id: label
            x: card.padX + 2; y: card.padY + 2
            width: Math.min(Math.ceil(probe.implicitWidth), 420)
            wrapMode: Text.Wrap
            textFormat: Text.RichText
            text: Tips.text.replace(/\n/g, "<br>")
            font.family: Theme.fontUi
            font.pixelSize: Theme.barFont
            color: Colors.fg
            lineHeight: 1.15
        }
    }
}
