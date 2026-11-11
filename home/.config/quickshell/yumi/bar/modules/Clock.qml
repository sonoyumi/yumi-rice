import QtQuick
import Quickshell
import qs

// Часы «22:40» (Onest DemiBold, цифры одной ширины), подсказка — дата по-русски, клик — календарь
Mod {
    id: m
    SystemClock { id: clock; precision: SystemClock.Minutes }
    tip: clock.date.toLocaleDateString(Qt.locale("ru_RU"), "dddd, d MMMM yyyy")
    Text {
        text: Qt.formatDateTime(clock.date, "HH:mm")              // «Тушь»: было «HH:mm · dd.MM» жирным моноширинным
        font.family: Theme.fontUi; font.pixelSize: Theme.barFont; font.weight: Font.DemiBold
        font.features: ({ "tnum": 1 })
        color: m.ink
        Behavior on color { ColorAnimation { duration: Theme.normal } }
    }
}
