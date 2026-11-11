import QtQuick
import QtQuick.Layouts
import qs
import "Kb.js" as Kb
import qs.services

// Список устройств (ВЫХОД / ВХОД): клик — сделать основным, 󰇙 / правый клик / долгое нажатие — страница
// устройства. Подсветка основного — одна плашка, переезжает к выбранной строке с пружиной.
// Снизу — выключенные карты (профиль «Выкл.»), чтобы их можно было включить обратно.
ColumnLayout {
    id: root
    property string kind: "sink"
    readonly property var nodes: kind === "sink" ? Sound.sinks : Sound.sources
    readonly property var current: kind === "sink" ? Sound.defaultSink : Sound.defaultSource
    readonly property var offCards: kind === "sink" ? Sound.state.cards.filter(c => c.off) : []
    signal openDevice(string kind, string name)
    signal openCard(string card)
    spacing: 4

    Item {
        Layout.fillWidth: true
        implicitHeight: column.implicitHeight
        readonly property int activeIndex: root.nodes.indexOf(root.current)
        Rectangle {   // ползущая подсветка основного
            visible: parent.activeIndex >= 0
            width: parent.width - 46; height: 48; radius: Theme.radius   // «Остров»: подложка акцентом 0.16, переезжает пружиной
            y: Math.max(0, parent.activeIndex) * 52
            color: Colors.alpha(Colors.acc, 0.16)
            Behavior on y { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
            Behavior on color { ColorAnimation { duration: Theme.normal } }
        }
        Column {
            id: column
            width: parent.width
            spacing: 4
            Repeater {
                model: root.nodes
                delegate: RowLayout {
                    id: row
                    required property var modelData
                    width: column.width
                    spacing: 6
                    RowButton {
                        icon: Sound.devIcon(root.kind, row.modelData)
                        text: Sound.devName(root.kind, row.modelData)
                        active: row.modelData === root.current
                        ownHighlight: false
                        tooltip: row.modelData.description
                        onClicked: Sound.setDefault(root.kind, row.modelData)
                        onSecondary: root.openDevice(root.kind, row.modelData.name)
                    }
                    Rectangle {   // 󰇙 — настройки устройства
                        id: moreBtn
                        Layout.preferredWidth: 40; Layout.preferredHeight: 40
                        activeFocusOnTab: true
                        Keys.onPressed: (e) => { if (Kb.nav(moreBtn, e)) return; if (Kb.activate(e)) { root.openDevice(root.kind, row.modelData.name); e.accepted = true } }
                        FocusRing { on: moreBtn.activeFocus; radius: 20 }
                        radius: 20                                  // «Остров»: круглая кнопка isl2
                        color: more.containsMouse ? Colors.hover : Colors.isl2
                        Behavior on color { ColorAnimation { duration: Theme.fast } }
                        Text { anchors.centerIn: parent; text: "󰇙"; font.family: Theme.fontIcon; font.pixelSize: 15
                               color: more.containsMouse ? Colors.fg : Colors.fgDim }
                        MouseArea { id: more; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openDevice(root.kind, row.modelData.name) }
                    }
                }
            }
        }
    }
    Repeater {
        model: root.offCards
        delegate: RowButton {
            required property var modelData
            icon: "󰖁"; text: modelData.desc; meta: "выкл."; dim: true
            onClicked: root.openCard(modelData.name)
        }
    }
    Text {
        visible: root.nodes.length === 0 && root.offCards.length === 0
        text: "Нет устройств"; font.family: Theme.fontUi; font.pixelSize: Theme.fontSize; color: Colors.fgDim
        Layout.leftMargin: 6; Layout.topMargin: 4; Layout.bottomMargin: 4
    }
}
