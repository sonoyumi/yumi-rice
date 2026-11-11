import QtQuick
import qs

// Кружок цвета программы (стиль трея dots, 16.10) — в баре и в меню фоновых программ один и тот же цвет.
// Цвет — из значка программы: средний оттенок насыщенных пикселей → пастель (как акцент бара); серый значок — нейтральный.
// Считается один раз на значок и запоминается в TrayBus.dotColors (Canvas рисуется только при новом значке).
Item {
    id: root
    property url source
    property int size: 10
    property bool attn: false
    property bool hover: false
    readonly property string k: String(source)
    readonly property color dot: { TrayBus.dotRev; const c = TrayBus.dotColors[k]; return c !== undefined ? c : Colors.alpha(Colors.fg, 0.7) }
    implicitWidth: size; implicitHeight: size

    Rectangle {
        anchors.centerIn: parent
        width: root.size; height: root.size; radius: root.size / 2
        color: root.dot
        border.width: 1; border.color: root.attn ? Colors.warn : Colors.alpha("white", 0.22)
        scale: root.hover ? 1.15 : 1
        Behavior on scale { NumberAnimation { duration: Theme.fast } }
        Behavior on color { ColorAnimation { duration: Theme.normal } }
    }
    onKChanged: sample()
    Component.onCompleted: sample()
    function sample() { if (k && TrayBus.dotColors[k] === undefined) sampler.take(source) }

    Canvas {      // невидимый: грузит значок по адресу (image://… тоже), рисует 12×12 и считает цвет
        id: sampler
        width: 12; height: 12; visible: false
        property url src: ""
        function take(u) { if (src.toString()) unloadImage(src); src = u; if (isImageLoaded(u)) requestPaint(); else loadImage(u) }
        onImageLoaded: requestPaint()
        onPaint: {
            if (!src.toString() || !isImageLoaded(src)) return
            const ctx = getContext("2d"); ctx.clearRect(0, 0, 12, 12)
            ctx.drawImage(src, 0, 0, 12, 12)
            const px = ctx.getImageData(0, 0, 12, 12).data
            let x = 0, y = 0, ws = 0, sv = 0, n = 0
            for (let i = 0; i < px.length; i += 4) {
                if (px[i + 3] < 110) continue
                const c = Qt.rgba(px[i] / 255, px[i + 1] / 255, px[i + 2] / 255, 1)
                const s = c.hsvSaturation, v = c.hsvValue, h = c.hsvHue
                n++
                if (s < 0.2 || v < 0.2 || h < 0) continue
                const w = s * (0.4 + v)
                x += Math.cos(h * 2 * Math.PI) * w; y += Math.sin(h * 2 * Math.PI) * w; ws += w; sv += s * w
            }
            if (!n) return
            let col
            if (ws < n * 0.08) col = Colors.alpha(Colors.fg, 0.7)
            else { let hue = Math.atan2(y, x) / (2 * Math.PI); if (hue < 0) hue += 1; col = Qt.hsla(hue, Math.max(0.5, Math.min(0.85, sv / ws)), 0.68, 1) }
            TrayBus.setDot(String(src), col)
        }
    }
}
