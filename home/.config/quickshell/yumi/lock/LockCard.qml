import QtQuick
import QtQuick.Effects
import qs

// «Остров» (29.10.2026): остров экрана блокировки (.lwi / .pw / .stat в превью) — сплошной Colors.isl, кромка edge,
// тень 0 14 40 чёрная .35. plain — без подложки (часы, дата, подсказка): только каскад.
// Каскад появления: p 0 → 1 с задержкой order × 70 мс, подъём 14 px и пружина (как playBoot в превью).
Item {
    id: card
    property real u: 1                     // масштаб от размера экрана (LockSurface.u)
    property int order: 0                  // номер в каскаде
    property bool shown: false
    property bool plain: false
    property real padX: 18
    property real padY: 16
    property real r: 28                    // радиус острова (лог. px превью)
    property color edgeColor: Colors.edge
    property real edgeW: 1
    property real shiftX: 0                // сдвиг по x (тряска острова пароля)
    default property alias content: body.data

    implicitWidth: body.implicitWidth + (plain ? 0 : Math.round(padX * u) * 2)
    implicitHeight: body.implicitHeight + (plain ? 0 : Math.round(padY * u) * 2)

    property real p: shown ? 1 : 0
    Behavior on p { SequentialAnimation {
        PauseAnimation { duration: card.shown ? card.order * 70 : 0 }
        NumberAnimation { duration: 500; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.34, 1.25, 0.64, 1, 1, 1] } } }
    opacity: Math.max(0, Math.min(1, p))
    transform: Translate { x: card.shiftX; y: Math.round((1 - card.p) * 14 * card.u) }

    RectangularShadow {
        visible: !card.plain
        anchors.fill: bg
        radius: bg.radius; blur: Math.round(40 * card.u); spread: 0
        offset.y: Math.round(14 * card.u)
        color: Qt.rgba(0, 0, 0, 0.35)
    }
    Rectangle {
        id: bg
        visible: !card.plain
        anchors.fill: parent
        radius: Math.min(height / 2, Math.round(card.r * card.u))
        color: Colors.isl
        border.width: card.edgeW; border.color: card.edgeColor
        Behavior on color { ColorAnimation { duration: Theme.normal } }
        Behavior on border.color { ColorAnimation { duration: 300 } }
    }
    Item {
        id: body
        x: card.plain ? 0 : Math.round(card.padX * card.u)
        y: card.plain ? 0 : Math.round(card.padY * card.u)
        width: card.width - x * 2
        height: card.height - y * 2
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }
}
