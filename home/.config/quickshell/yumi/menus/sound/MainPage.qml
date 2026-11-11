import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services
import qs.menus.wifi

// Главная страница меню звука — «Микшер-столбцы» (вариант 09 страницы статичных меню, 16.10).
// Прежние: барабан — MainPage.qml.bak-v2-20261016, исходная — MainPage.qml.bak-widget-20261016.
// Столбцы рядом, как на пульте: «Выход» (основное устройство вывода), «Микрофон» (основной вход), каждое приложение.
// Под ними — кнопки «Выход…», «Вход…» (выбор основного устройства, PickPage → Sound.setDefault — та же команда, что в старом
// меню), «Запись», «Расширенные…».
// Клавиши (зовёт SoundMenu через key(имя)): ↑↓ — строка, ←→ — громкость ±5 % (19.10; было наоборот), Enter — меню столбца (выбор устройства /
// перенос потока), Пробел — без звука, «.» — настройки устройства, Tab — к кнопкам и обратно (там ←→ / Enter, ↑ — к столбцам),
// Esc — назад / закрыть.
Item {
    id: root
    property var menu
    readonly property string subtitle: Sound.defaultSink ? "Выход: " + Sound.devName("sink", Sound.defaultSink) : "Нет устройства вывода"
    focus: true
    // высота, которую просит главная страница: строки 52 (+26 подпись «Приложения»), кнопки 32, подвал
    readonly property int wantH: (Sound.dry ? 22 : 0) + 24 + Math.max(2, cols.length) * 56 + (cols.length > 2 ? 26 : 24) + 42 + 58 + 20

    readonly property var cols: [{ type: "out", serial: "" }, { type: "mic", serial: "" }]
                                .concat(Sound.streamSerials.map(s => ({ type: "app", serial: s })))
    property int sel: 0
    onColsChanged: if (sel >= cols.length) sel = Math.max(0, cols.length - 1)
    onSelChanged: strip.positionViewAtIndex(sel, ListView.Contain)
    property string zone: "cols"                 // cols | btns
    property int btn: 0
    readonly property var btns: [
        { t: "󰓃  Выход…", a: "out" }, { t: "󰍬  Вход…", a: "in" },
        { t: Sound.state.mics > 0 ? "󰑊  Запись · " + Sound.state.mics : "󰑊  Запись", a: "rec" }, { t: "󰒓  Расширенные…", a: "adv" }
    ]
    function doBtn(a) {
        if (a === "out") root.menu.push("Выход", "PickPage.qml", { kind: "sink" })
        else if (a === "in") root.menu.push("Вход", "PickPage.qml", { kind: "source" })
        else if (a === "rec") root.menu.push("Запись", "RecPage.qml", {})
        else if (a === "adv") { Sound.openSettings(); root.menu.close() }
    }
    function col() { return strip.itemAtIndex(sel) }
    function reset() { zone = "cols"; sel = 0 }

    function key(k) {
        if (k === "tab") { zone = zone === "cols" ? "btns" : "cols"; return true }
        if (zone === "btns") {
            if (k === "left") btn = Math.max(0, btn - 1)
            else if (k === "right") btn = Math.min(btns.length - 1, btn + 1)
            else if (k === "up") zone = "cols"
            else if (k === "enter" || k === "space") doBtn(btns[btn].a)
            else if (k === "down") {}
            else return false
            return true
        }
        // 19.10 (по просьбе): микшер строками — ↑↓ выбирают строку (с последней ↓ — к кнопкам), ←→ — громкость ±5 %
        const c = col()
        if (k === "up") sel = Math.max(0, sel - 1)
        else if (k === "down") { if (sel < cols.length - 1) sel++; else zone = "btns" }
        else if (k === "right") { if (c) c.vol(0.05) }
        else if (k === "left") { if (c) c.vol(-0.05) }
        else if (k === "enter") { if (c) c.enter() }
        else if (k === "space") { if (c) c.mute() }
        else if (k === "period") { if (c) c.details() }
        else return false
        return true
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        Text { visible: Sound.dry; text: "РЕЖИМ ПРОВЕРКИ · DRY-RUN"; font.family: Theme.fontUi; font.pixelSize: 10; font.weight: Font.DemiBold
               font.letterSpacing: 1; color: Colors.acc; Layout.leftMargin: 4 }
        Section { text: "Устройства"; Layout.topMargin: 0; Layout.leftMargin: 4 }

        // ---- строки микшера (клавиши: ↑↓ — строка, ←→ — громкость) ----
        ListView {
            id: strip
            Layout.fillWidth: true; Layout.fillHeight: true
            orientation: ListView.Vertical
            spacing: 4
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: Theme.normal
            model: root.cols
            delegate: MixCol {
                id: mc
                required property var modelData
                required property int index
                width: strip.width
                menu: root.menu
                type: modelData.type; serial: modelData.serial
                sepAbove: index === 2
                selected: root.zone === "cols" && root.sel === index
                onPicked: { root.sel = index; root.zone = "cols" }
                // каскад: opacity + y 8 px по 40 мс
                opacity: 0
                property real dy: 8
                transform: Translate { y: dy }
                Component.onCompleted: appear.start()
                SequentialAnimation {
                    id: appear
                    PauseAnimation { duration: Math.min(index, 10) * 40 }
                    ParallelAnimation {
                        NumberAnimation { target: mc; property: "opacity"; to: 1; duration: 280; easing.type: Easing.OutCubic }
                        NumberAnimation { target: mc; property: "dy"; to: 0; duration: 280; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
        Text {
            visible: root.cols.length <= 2
            Layout.leftMargin: 6
            text: Sound.ready ? "Приложения сейчас ничего не играют" : "…"
            font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim
        }

        // ---- кнопки-капсулы ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: root.btns
                Chip {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true; Layout.preferredWidth: implicitWidth; implicitHeight: 34
                    text: modelData.t
                    live: modelData.a === "rec" && Sound.state.mics > 0
                    onClicked: { root.btn = index; root.doBtn(modelData.a) }
                    FocusRing { on: root.zone === "btns" && root.btn === index; radius: 17 }
                }
            }
        }
        // ---- подсказки клавиш капсулами ----
        MFooter {
            hints: root.zone === "btns" ? [["←→", "кнопка"], ["Enter", "нажать"], ["↑ / Tab", "к строкам"], ["Esc", "закрыть"]]
                 : [["↑↓", "строка"], ["←→", "громкость"], ["Enter", "устройство"], ["Пробел", "без звука"], ["Tab", "кнопки"]]
        }
    }
}
