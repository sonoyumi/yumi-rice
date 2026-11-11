import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.menus.wifi
import qs.menus.mouse

// Страница «Клавиатура» в «Устройствах» (как open_keyboard в yumi-menu-devices): подсветка вкл/выкл, яркость,
// цвет «По обоям» / «Свой» и девять готовых цветов. kb — KbData.
ColumnLayout {
    id: root
    property KbData kb
    spacing: 10
    readonly property var presets: ["FFFFFF", "FF2D2D", "FF8A00", "FFD400", "3DFF6E", "00C8FF", "2D6BFF", "B04DFF", "FF4DC4"]
    readonly property var s: kb ? kb.state : ({})
    property int slide: -1                 // пока тянут ползунок — его значение
    Timer { id: slideTimer; interval: 250; property int v: 0; onTriggered: root.kb.setBrightness(v) }   // одна команда в конце
    Timer { id: slideClear; interval: 1500; onTriggered: root.slide = -1 }

    ToggleRow { icon: "󰌌"; text: "Подсветка"; checked: !!root.s.on; onToggled: on => root.kb.setOn(on) }

    MSection { text: "Яркость"; Layout.fillWidth: true }
    HSlider {
        icon: "󰃠"
        from: 0; to: 100; step: 1
        value: root.s.brightness !== undefined ? root.s.brightness : 100
        label: (root.slide >= 0 ? root.slide : (root.s.brightness !== undefined ? root.s.brightness : 100)) + "%"
        labelWidth: 44
        onMoved: v => { root.slide = v; slideClear.stop(); slideTimer.v = v; slideTimer.restart() }
        onReleased: v => { slideTimer.v = v; slideTimer.restart(); slideClear.restart() }
    }

    MSection { text: "Цвет"; Layout.fillWidth: true }
    MSegmented {
        Layout.fillWidth: true
        items: [{ key: "wall", icon: "󰸉", text: "По обоям" }, { key: "fixed", icon: "󰏘", text: "Свой" }]
        current: root.s.source || "wall"
        onPicked: key => { if (key === "wall") root.kb.setWall(); else root.kb.setColor(root.s.color || "FFFFFF") }
    }
    Row {
        Layout.alignment: Qt.AlignHCenter
        spacing: 8
        Repeater {
            model: root.presets
            Rectangle {
                required property string modelData
                readonly property bool active: root.s.source === "fixed" && root.s.color === modelData
                width: 26; height: 26; radius: 9                      // «Остров»: образец цвета — скруглённый квадрат, выбранный — кромка цветом текста
                color: "#" + modelData
                border.width: active ? 2.5 : 0; border.color: Colors.fg
                Behavior on border.color { ColorAnimation { duration: Theme.fast } }
                scale: sm.pressed ? 0.9 : (sm.containsMouse ? 1.08 : 1)
                Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
                MouseArea { id: sm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.kb.setColor(parent.modelData) }
            }
        }
    }
    MHint { text: "«По обоям» — цвет меняется вместе с обоями. Яркость сохраняется и после смены обоев." }
}
