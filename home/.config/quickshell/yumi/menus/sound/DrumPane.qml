import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Барабан устройств (16.10) для вкладок «Выход» (kind "sink") и «Вход» (kind "source"): колесо выбора с наклоном
// по расстоянию от центра, справа — вертикальная полоса громкости основного устройства и «без звука».
// Клик по любому устройству — сразу сделать его основным (как строка старого меню; Sound.setDefault — та же
// команда, что в DeviceList.qml), правый клик — его настройки. Выключенные карты (только выход) — тусклые, Enter — их страница.
// Клавиатурой управляет MainPage через step/vol/activate/mute/details; focused — показать рамку выбора.
Item {
    id: root
    property var menu
    property string kind: "sink"
    property bool focused: false
    readonly property var nodes: kind === "sink" ? Sound.sinks : Sound.sources
    readonly property var current: kind === "sink" ? Sound.defaultSink : Sound.defaultSource
    readonly property var items: nodes.map(n => ({ node: n })).concat(kind === "sink" ? Sound.state.cards.filter(c => c.off).map(c => ({ card: c })) : [])
    property int sel: 0
    property real pos: sel
    // анимация прокрутки — только после первой расстановки (присваивать pos нельзя: это рвёт привязку pos: sel,
    // и барабан перестаёт крутиться — так было в первой версии)
    property bool animate: false
    Behavior on pos { enabled: root.animate; NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }   // «Остров»: пружина
    property bool picked: false                 // листали руками — не прыгать к основному при обновлении списка
    readonly property bool atTop: sel <= 0
    readonly property bool atBottom: sel >= items.length - 1

    function toCurrent() { const i = items.findIndex(x => x.node && x.node === current); if (i >= 0) sel = i }
    onItemsChanged: { if (sel >= items.length) sel = Math.max(0, items.length - 1); if (!picked) toCurrent() }
    onCurrentChanged: if (!picked) toCurrent()
    Component.onCompleted: { toCurrent(); Qt.callLater(() => root.animate = true) }
    function reset() { picked = false; toCurrent() }

    function step(d) { if (!items.length) return; picked = true; sel = Math.max(0, Math.min(items.length - 1, sel + d)) }
    function activate(i) {
        if (i === undefined) i = sel
        const it = items[i]
        if (!it) return
        if (it.card) root.menu.push("Звуковая карта", "CardPage.qml", { card: it.card.name })
        else { Sound.setDefault(kind, it.node); picked = false }
    }
    function details(i) {
        if (i === undefined) i = sel
        const it = items[i]
        if (it && it.node) root.menu.push("", "DevicePage.qml", { kind: kind, name: it.node.name })
    }
    function vol(d) { if (current) Sound.setVolume(current, Math.max(0, Math.min(1, Sound.vol(current) + d))) }
    function mute() { if (current) Sound.toggleMute(current) }

    Item {
        id: drum
        anchors.left: parent.left; anchors.right: volCol.left; anchors.rightMargin: 14
        anchors.top: parent.top; anchors.bottom: parent.bottom
        readonly property int rowH: 44
        clip: true

        Rectangle {     // рамка выбора в центре: тихая, ярче, когда барабан в фокусе клавиатуры
            anchors.left: parent.left; anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: drum.rowH; radius: Theme.radius    // «Остров»: выбор — подложка акцентом, в фокусе — кромка
            color: Colors.alpha(Colors.acc, root.focused ? 0.20 : 0.12)
            border.width: root.focused ? 1.5 : 0; border.color: Colors.acc
            Behavior on color { ColorAnimation { duration: Theme.fast } }
            Behavior on border.color { ColorAnimation { duration: Theme.fast } }
        }
        Repeater {
            model: root.items
            delegate: Item {
                id: dItem
                required property var modelData
                required property int index
                readonly property real d: index - root.pos
                readonly property bool isDef: !!modelData.node && modelData.node === root.current
                readonly property bool mid: Math.abs(d) < 0.5
                width: drum.width; height: drum.rowH
                y: drum.height / 2 - height / 2 + d * (drum.rowH - 4)
                visible: Math.abs(d) < 4
                opacity: Math.max(0, 1 - Math.abs(d) * 0.28)
                scale: 1 - Math.min(Math.abs(d), 3) * 0.06
                z: 10 - Math.abs(d)
                transform: Rotation {
                    origin.x: dItem.width / 2; origin.y: dItem.height / 2
                    axis { x: 1; y: 0; z: 0 }
                    angle: Math.max(-70, Math.min(70, -dItem.d * 22))
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 12
                    spacing: 10
                    Glyph {
                        text: dItem.modelData.card ? "󰖁" : Sound.devIcon(root.kind, dItem.modelData.node)
                        font.pixelSize: 17
                        color: dItem.mid ? Colors.acc : Colors.fgDim
                    }
                    Text {
                        Layout.fillWidth: true
                        text: dItem.modelData.card ? dItem.modelData.card.desc : Sound.devName(root.kind, dItem.modelData.node)
                        font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium
                        color: dItem.mid ? Colors.fg : Colors.fgDim
                        elide: Text.ElideRight
                    }
                    Text {
                        text: dItem.modelData.card ? "выкл." : (dItem.isDef ? "󰄬 основной" : "")
                        font.family: dItem.isDef ? Theme.fontIcon : Theme.fontUi; font.pixelSize: 10
                        color: dItem.isDef ? Colors.acc : Colors.fgDim
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (e) => {
                        if (e.button === Qt.RightButton) { root.details(dItem.index); return }
                        root.picked = true; root.sel = dItem.index
                        root.activate(dItem.index)              // один клик — сразу основным (как раньше)
                    }
                    onPressAndHold: root.details(dItem.index)
                }
            }
        }
        Text {
            anchors.centerIn: parent
            visible: root.items.length === 0
            text: "Нет устройств"; font.family: Theme.fontUi; font.pixelSize: Theme.fontSize; color: Colors.fgDim
        }
        WheelHandler {
            property real acc: 0
            onWheel: (ev) => { acc += ev.angleDelta.y; if (Math.abs(acc) >= 60) { root.step(acc < 0 ? 1 : -1); acc = 0 } }
        }
    }

    // громкость основного устройства
    Column {
        id: volCol
        anchors.right: parent.right; anchors.top: parent.top
        width: 56; spacing: 8
        readonly property real v: Sound.vol(root.current)
        readonly property bool m: Sound.muted(root.current)
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(volCol.v * 100) + "%"
            font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.DemiBold; font.features: ({ "tnum": 1 }); color: volCol.m ? Colors.fgDim : Colors.fg
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 26; height: Math.max(100, root.height - 80); radius: 13   // «Остров»: капсула isl2
            color: vma.containsMouse ? Colors.hover : Colors.isl2
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: Math.max(parent.radius * 2, parent.height * Math.min(1, volCol.v))
                radius: parent.radius
                color: volCol.m ? Colors.alpha(Colors.fg, 0.3) : Colors.acc
                Behavior on height { enabled: !vma.pressed; NumberAnimation { duration: Theme.normal; easing.type: Theme.easeSoft } }
                Behavior on color { ColorAnimation { duration: Theme.fast } }
            }
            MouseArea {
                id: vma
                anchors.fill: parent; hoverEnabled: true
                function at(y) { if (root.current) Sound.setVolume(root.current, Math.max(0, Math.min(1, 1 - y / height))) }
                onPressed: (e) => at(e.y)
                onPositionChanged: (e) => { if (pressed) at(e.y) }
                onWheel: (w) => root.vol(w.angleDelta.y > 0 ? 0.05 : -0.05)
            }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 34; height: 34; radius: 17          // «Остров»: круг; без звука — акцент
            color: volCol.m ? Colors.acc : (mma.containsMouse ? Colors.hover : Colors.isl2)
            Behavior on color { ColorAnimation { duration: Theme.fast } }
            Glyph { anchors.centerIn: parent; font.pixelSize: 16; color: volCol.m ? Colors.onAcc : Colors.fg
                    text: root.kind === "sink" ? (volCol.m ? "󰖁" : "󰕾") : (volCol.m ? "󰍭" : "󰍬") }
            MouseArea { id: mma; anchors.fill: parent; hoverEnabled: true; onClicked: root.mute() }
        }
    }
}
