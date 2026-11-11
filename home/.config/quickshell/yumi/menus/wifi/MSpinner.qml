import QtQuick
import qs

// Крутящаяся дуга (вместо Gtk.Spinner)
Canvas {
    id: c
    property color color: Colors.acc
    width: 14; height: 14
    onPaint: {
        const ctx = getContext("2d"); ctx.reset()
        ctx.lineWidth = 2; ctx.lineCap = "round"    // «Остров»: круглые концы
        ctx.strokeStyle = color
        ctx.beginPath(); ctx.arc(width / 2, height / 2, width / 2 - 2, 0, Math.PI * 1.5); ctx.stroke()
    }
    onColorChanged: requestPaint()
    RotationAnimation on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: c.visible }
}
