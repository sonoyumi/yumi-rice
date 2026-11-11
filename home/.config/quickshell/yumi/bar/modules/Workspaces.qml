import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs

// «Остров» (29.10): рабочие столы 1…10 (как .ws в превью). Ячейка 24×22, номер 12 Onest fgDim; занятый стол — точка снизу;
// активный — капсула акцентом (номер onAcc), при переключении она тянется до нового стола и сжимается к нему:
// 2 фазы — 140 мс растяжение, 320 мс OutBack (goWs в превью). urgent — красная пульсация. Столы с номером > 10
// дописываются справа. Клик — перейти, колесо — соседний стол.
Item {
    id: root
    property string screenName: ""          // экран этого бара: активный стол — его
    readonly property var mon: Hyprland.monitors.values.find(mo => mo.name === screenName) || null
    readonly property int activeId: mon && mon.activeWorkspace ? mon.activeWorkspace.id : -1
    readonly property int cell: 22             // 29.10: было 24 — место для подписей Wi-Fi и режима
    readonly property var live: [...Hyprland.workspaces.values].filter(w => w.id > 0)
    // 29.10 (бар «Два крыла»): только занятые столы и текущий, по номеру; occOnly: false — 1…10 всегда (как раньше)
    property bool occOnly: true
    function busy(w) { return w.toplevels.values.length > 0 || !!(w.lastIpcObject && w.lastIpcObject.windows > 0) }
    readonly property var ids: {
        if (occOnly) {
            const out = live.filter(w => w.id === activeId || busy(w)).map(w => w.id)
            if (activeId > 0 && out.indexOf(activeId) < 0) out.push(activeId)
            return out.sort((a, b) => a - b)
        }
        const out = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        for (const w of live.slice().sort((a, b) => a.id - b.id)) if (w.id > 10) out.push(w.id)
        return out
    }
    function wsOf(id) { return live.find(w => w.id === id) || null }
    function label(id) {
        const w = wsOf(id)
        if (w && w.name.length <= 2 && !/^\d+$/.test(w.name)) return w.name   // своё короткое имя стола — как есть
        return String(id)
    }
    readonly property int activeIdx: ids.indexOf(activeId)
    implicitWidth: ids.length * cell + 4
    implicitHeight: 22

    // ---- капсула активного стола: растяжение → сжатие ----
    property real indX: Math.max(0, activeIdx) * cell + 2
    property real indW: cell
    property int shownIdx: -1
    Component.onCompleted: shownIdx = activeIdx
    onActiveIdxChanged: {
        if (activeIdx < 0) return
        const b = activeIdx * cell + 2
        if (shownIdx < 0) { shownIdx = activeIdx; indX = b; return }
        const a = shownIdx * cell + 2
        shownIdx = activeIdx
        stretch.stop()
        s1x.to = Math.min(a, b); s1w.to = Math.abs(b - a) + cell
        s2x.to = b
        stretch.start()
    }
    SequentialAnimation {
        id: stretch
        ParallelAnimation {
            NumberAnimation { id: s1x; target: root; property: "indX"; duration: 140; easing.type: Easing.OutCubic }
            NumberAnimation { id: s1w; target: root; property: "indW"; duration: 140; easing.type: Easing.OutCubic }
        }
        ParallelAnimation {
            NumberAnimation { id: s2x; target: root; property: "indX"; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
            NumberAnimation { target: root; property: "indW"; to: root.cell; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        }
    }
    Rectangle {
        visible: root.activeIdx >= 0
        x: root.indX; y: 0; width: root.indW; height: 22; radius: 11
        color: Colors.acc
        Behavior on color { ColorAnimation { duration: Theme.normal } }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: (w) => Hyprland.dispatch('hl.dsp.focus({ workspace = "' + (w.angleDelta.y < 0 ? "e+1" : "e-1") + '" })')
    }
    Repeater {
        model: root.ids
        delegate: Item {
            id: btn
            required property var modelData
            required property int index
            readonly property var ws: root.wsOf(modelData)
            readonly property bool on: modelData === root.activeId
            readonly property bool has: !!ws && (ws.toplevels.values.length > 0 || !!(ws.lastIpcObject && ws.lastIpcObject.windows > 0))
            readonly property bool urgent: !!ws && ws.urgent && !on
            x: index * root.cell + 2; width: root.cell; height: 22
            Rectangle {   // urgent: пульсация alpha(bad, 0.15 → 0.60)
                anchors.fill: parent; radius: 11
                visible: btn.urgent
                color: Colors.alpha(Colors.bad, 0.15)
                SequentialAnimation on color {
                    running: btn.urgent; loops: Animation.Infinite
                    ColorAnimation { to: Colors.alpha(Colors.bad, 0.60); duration: 900; easing.type: Easing.InOutSine }
                    ColorAnimation { to: Colors.alpha(Colors.bad, 0.15); duration: 900; easing.type: Easing.InOutSine }
                }
            }
            Text {
                anchors.centerIn: parent
                text: root.label(btn.modelData)
                font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.Medium
                font.features: ({ "tnum": 1 })
                color: btn.on ? Colors.onAcc : (wsMouse.containsMouse || btn.urgent ? Colors.fg : Colors.fgDim)
                Behavior on color { ColorAnimation { duration: 250 } }
            }
            Rectangle {   // занятый стол — точка снизу
                width: 3; height: 3; radius: 1.5
                anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 1
                color: btn.on ? Colors.onAcc : (wsMouse.containsMouse ? Colors.fg : Colors.fgDim)
                opacity: btn.has ? 0.8 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.normal } }
            }
            MouseArea { id: wsMouse; anchors.fill: parent; hoverEnabled: true
                        onClicked: Hyprland.dispatch('hl.dsp.focus({ workspace = ' + btn.modelData + ' })') }
        }
    }
}
