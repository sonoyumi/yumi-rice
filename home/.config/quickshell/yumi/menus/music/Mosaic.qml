import QtQuick
import Quickshell.Widgets
import qs

// Мозаика плейлиста 2×2 из одинаковых квадратных плиток; меньше 4 обложек — повторяются; одна — на всю карточку.
ClippingRectangle {
    id: root
    property var store: null
    property var keys: []
    property int size: 150
    readonly property var ks: (keys || []).filter(k => !!k).slice(0, 4)
    width: size; height: size
    radius: 6                              // «Тушь»: было 10
    color: Colors.isl2
    Cover { visible: root.ks.length <= 1; store: root.store; key: root.ks.length ? root.ks[0] : ""; size: root.size; radius: 0 }
    Grid {
        visible: root.ks.length > 1
        columns: 2
        Repeater {
            model: root.ks.length > 1 ? 4 : 0
            Cover { required property int index; store: root.store; key: root.ks[index % root.ks.length]; size: root.size / 2; radius: 0 }
        }
    }
}
