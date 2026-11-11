import QtQuick
import QtQuick.Layouts
import qs

// Кольцо заряда: рисуется при открытии (shown 0→pct), цвет по состоянию. В центре — проценты.
Item {
    id: ring
    property real pct: 0
    property bool open: false
    property color tone: Colors.acc
    property int thickness: 9
    implicitWidth: 104; implicitHeight: 104

    property real shown: open ? pct : 0
    Behavior on shown { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
    Behavior on tone { ColorAnimation { duration: Theme.normal } }
    onShownChanged: canvas.requestPaint()
    onToneChanged: canvas.requestPaint()
    Connections { target: Colors; function onFgChanged() { canvas.requestPaint() } }

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d")
            const w = width, h = height, r = Math.min(w, h) / 2 - ring.thickness / 2 - 1
            ctx.reset()
            ctx.lineWidth = ring.thickness
            ctx.lineCap = "round"
            ctx.strokeStyle = Colors.alpha(Colors.fg, 0.13)
            ctx.beginPath(); ctx.arc(w / 2, h / 2, r, 0, Math.PI * 2); ctx.stroke()
            const a = Math.max(0, Math.min(ring.shown, 100)) / 100 * Math.PI * 2
            if (a > 0.001) {
                ctx.strokeStyle = ring.tone
                ctx.beginPath(); ctx.arc(w / 2, h / 2, r, -Math.PI / 2, -Math.PI / 2 + a); ctx.stroke()
            }
        }
    }
    RowLayout {
        anchors.centerIn: parent
        spacing: 1
        Text { text: Math.round(ring.shown); font.family: Theme.fontUi; font.pixelSize: 28; font.weight: Font.ExtraBold
               color: ring.tone; Layout.alignment: Qt.AlignBaseline; Behavior on color { ColorAnimation { duration: Theme.normal } } }
        Text { text: "%"; font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Bold; color: Colors.fgDim
               Layout.alignment: Qt.AlignBaseline }
    }
}
