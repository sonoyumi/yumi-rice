import QtQuick
import QtQuick.Layouts
import qs
import qs.services

// Выбор основного устройства (16.10, из столбца микшера «Выход» / «Микрофон»): список — тот же DeviceList, что в прежней
// главной странице (клик / Enter — Sound.setDefault, «󰇙» / «.» — настройки устройства, выключенные карты — их страница).
// Клавиатура: ↑↓ по строкам и кнопкам (Kb.js), Enter — выбрать, Esc — назад.
Flickable {
    id: root
    property var menu
    property string kind: "sink"
    readonly property string subtitle: kind === "sink"
        ? (Sound.defaultSink ? "Сейчас: " + Sound.devName("sink", Sound.defaultSink) : "Нет устройства вывода")
        : (Sound.defaultSource ? "Сейчас: " + Sound.devName("source", Sound.defaultSource) : "Нет микрофона")
    contentHeight: col.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: col
        width: root.width
        spacing: 6
        Section { text: root.kind === "sink" ? "Выход — куда идёт звук" : "Вход — какой микрофон"; Layout.topMargin: 0 }
        DeviceList {
            kind: root.kind; Layout.fillWidth: true
            onOpenDevice: (k, n) => root.menu.push("", "DevicePage.qml", { kind: k, name: n })
            onOpenCard: (c) => root.menu.push("Звуковая карта", "CardPage.qml", { card: c })
        }
        RowLayout {
            Layout.topMargin: 10; spacing: 8
            Chip { visible: root.kind === "source"; text: Sound.state.mics > 0 ? "󰑊 Запись · " + Sound.state.mics : "󰑊 Запись"; live: Sound.state.mics > 0
                   onClicked: root.menu.push("Запись", "RecPage.qml", {}) }
            Chip { text: "󰒓 Расширенные…"; onClicked: { Sound.openSettings(); root.menu.close() } }
        }
    }
}
