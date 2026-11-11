import QtQuick
import qs
import "PodsIcon.js" as PodsIcon

// Значок наушников (18.10): рисунок — PodsIcon.js; корпус полным цветом, амбушюры тем же цветом на 50 %.
// Раньше — шрифт YumiIcons E900+E901, но E901 нулевой ширины Qt не рисует (амбушюр не было видно).
// Растр SVG — с запасом по плотности, чтобы на dpr 2 края были чёткими.
Item {
    id: root
    property color color: Colors.fg
    property int pixelSize: Theme.barIcon
    property real tipAlpha: 0.5
    readonly property int h: Math.round(pixelSize * 0.85)
    implicitHeight: h
    implicitWidth: Math.round(h * PodsIcon.ASPECT)
    function hex(c) { return "#" + [c.r, c.g, c.b].map(v => Math.round(v * 255).toString(16).padStart(2, "0")).join("") }
    Image {
        anchors.fill: parent
        source: PodsIcon.svg(root.hex(root.color), root.hex(root.color), root.tipAlpha)
        sourceSize: Qt.size(root.implicitWidth * 4, root.h * 4)
        smooth: true; mipmap: true
        fillMode: Image.PreserveAspectFit
        opacity: root.color.a
    }
}
