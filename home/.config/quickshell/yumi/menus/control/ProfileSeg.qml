import QtQuick
import Quickshell.Services.UPower
import qs
import qs.components

// Профиль питания (имя ProfileSeg: PowerProfile занято перечислением UPower): сегменты с бегунком (подписи — как в
// yumi-menu-power). Снаружи: current, сигнал picked(name). «Остров» (29.10): как components/ISeg — капсула isl2,
// акцентная плашка переезжает пружиной, выбранный — onAcc.
Rectangle {
    id: seg
    property string current: "balanced"
    property string kb: ""             // фокус клавиатуры центра: id профиля
    signal picked(string name)
    // «Производит.» только если профиль есть (PowerProfiles.hasPerformanceProfile; на этом ноутбуке его нет → два сегмента)
    readonly property var items: {
        const all = [
            { id: "power-saver", icon: "󰌪", name: "Эконом" },
            { id: "balanced",    icon: "󰾅", name: "Баланс" },
            { id: "performance", icon: "󱐋", name: "Производит." }
        ]
        return all.slice(0, 2)   // 29.10: без PowerProfiles (yumi-power-profile)
    }
    readonly property int index: Math.max(0, items.findIndex(i => i.id === current))
    readonly property real segW: (width - 8 - (items.length - 1) * 4) / items.length

    implicitHeight: 36
    radius: 16
    color: Colors.isl2

    Rectangle {   // бегунок
        x: 4 + seg.index * (seg.segW + 4); y: 4
        width: seg.segW; height: parent.height - 8
        radius: 12
        color: Colors.acc
        Behavior on x { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }
        Behavior on color { ColorAnimation { duration: Theme.normal } }
    }
    Row {
        x: 4; y: 4; spacing: 4
        Repeater {
            model: seg.items
            delegate: Item {
                required property var modelData
                required property int index
                width: seg.segW; height: seg.height - 8
                readonly property bool active: index === seg.index
                Row {
                    anchors.centerIn: parent; spacing: 6
                    Glyph { text: modelData.icon; font.pixelSize: 13; color: active ? Colors.onAcc : Colors.fgDim; anchors.verticalCenter: parent.verticalCenter
                            /* выбор — без затухания (29.10) */ }
                    Text { text: modelData.name; font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium
                           color: active ? Colors.onAcc : Colors.fgDim; anchors.verticalCenter: parent.verticalCenter
                           Behavior on color { ColorAnimation { duration: 200 } } }
                }
                KbRing { on: seg.kb === modelData.id; inset: 0; radius: 12 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: seg.picked(modelData.id) }
            }
        }
    }
}
