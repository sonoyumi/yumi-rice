import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.menus.wifi

// Содержимое меню «Мышь» (как класс Mouse в yumi-menu-mouse) — общее для MouseMenu и страницы «Мышь» в «Устройствах».
// Карточка заряда, DPI (плитки 400/800/1600/3200 + точный ползунок 100–6400, шаг 50), частота опроса, встроенный профиль,
// «Открыть Solaar». md — MouseData; shown — для каскада при открытии; solaarOpened — меню закрыть.
ColumnLayout {
    id: root
    property MouseData md
    property bool shown: true
    signal solaarOpened()
    spacing: 8
    readonly property var dpis: [400, 800, 1600, 3200]
    readonly property var rates: [500, 1000, 2000, 4000, 8000]
    // пока тянут ползунок — плитки и подпись показывают его значение
    property int slideDpi: 0
    readonly property int dpiShown: slideDpi || (md && md.st.dpi) || 0
    readonly property string onboard: md && md.st.onboard !== undefined ? md.st.onboard : ""
    readonly property bool onboardOn: onboard !== "" && onboard.toLowerCase() !== "disabled"

    Timer { id: slideTimer; interval: 500; property int v: 0     // писать, когда ползунок отпустили (как slider_timer)
            onTriggered: { root.md.setDpi(v); clear.restart() } }
    Timer { id: clear; interval: 1500; onTriggered: root.slideDpi = 0 }

    // ---- карточка заряда ----
    Casc2 {
        index: 0; shown: root.shown
        // «Остров» (29.10): заряд — подложка isl2: значок в квадрате, число 16 DemiBold, состояние, шкала 8 px акцентом
        IBox {
        RowLayout {
            id: card
            Layout.fillWidth: true
            spacing: 12
            readonly property var b: root.md ? root.md.bat : null
            readonly property bool off: b === null
            readonly property bool chg: root.md ? root.md.charging : false
            readonly property color tone: off ? Colors.alpha(Colors.fgDim, 0.5) : chg ? Colors.ok
                                        : b.pct <= 15 ? Colors.bad : b.pct <= 30 ? Colors.warn : Colors.fg
            readonly property string batIcon: {
                if (off) return "󰍾"
                const i = Math.min(Math.floor(Math.max(b.pct - 1, 0) / 10), 9)
                return (chg ? ["󰢜","󰂆","󰂇","󰂈","󰢝","󰂉","󰢞","󰂊","󰂋","󰂅"] : ["󰁺","󰁻","󰁼","󰁽","󰁾","󰁿","󰂀","󰂁","󰂂","󰁹"])[i]
            }
            MIconSq { icon: root.md && !root.md.batKnown ? "󰍽" : card.batIcon; on: !card.off; base: Colors.hover }
            Text {
                text: !root.md || !root.md.batKnown ? "…" : card.off ? "—" : card.b.pct + "%"
                font.family: Theme.fontUi; font.pixelSize: 16; font.weight: Font.DemiBold; font.features: ({ "tnum": 1 }); color: card.tone
                Layout.minimumWidth: 44
                Behavior on color { ColorAnimation { duration: Theme.normal } } }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                MText { Layout.fillWidth: true; font.pixelSize: 13; font.weight: Font.Medium; elide: Text.ElideRight
                        text: !root.md || !root.md.batKnown ? "" : card.off ? "не на связи" : card.b.state === "charging" ? "заряжается" : card.b.state === "full" ? "заряжена" : "от батареи" }
                MText { Layout.fillWidth: true; font.pixelSize: 12; color: Colors.fgDim; elide: Text.ElideRight
                        text: !root.md || !root.md.batKnown ? "" : card.off ? "мышь выключена или нет приёмника" : (card.b.maker || "Logitech") + " " + (card.b.model || "PRO X 2") }
            }
            Rectangle {   // шкала заряда
                Layout.preferredWidth: 70; implicitHeight: 8; radius: 4
                color: Colors.alpha(Colors.fg, 0.14)
                Rectangle {
                    height: 8; radius: 4
                    width: card.off ? 0 : parent.width * card.b.pct / 100
                    color: card.chg ? Colors.ok : card.b && card.b.pct <= 15 ? Colors.bad : Colors.acc
                    Behavior on width { NumberAnimation { duration: Theme.slow; easing.type: Theme.easeSoft } }
                    Behavior on color { ColorAnimation { duration: Theme.normal } }
                }
            }
        }
        }
    }

    Casc2 {
        index: 1; shown: root.shown
        MSection { text: "Чувствительность · DPI"; Layout.fillWidth: true; trail: root.dpiShown ? String(root.dpiShown) : "" }
        MSegmented {
            Layout.fillWidth: true
            items: root.dpis.map(d => ({ key: d, icon: String(d), text: "DPI" }))
            current: root.dpiShown
            onPicked: key => { slideTimer.stop(); root.slideDpi = 0; root.md.setDpi(key) }
        }
        HSlider {
            icon: "󰆤"
            from: 100; to: 6400; step: 50
            value: root.dpiShown || 800
            label: root.dpiShown ? String(root.dpiShown) : "…"
            labelWidth: 52
            marks: root.dpis
            onMoved: v => { root.slideDpi = v; clear.stop() }
            onReleased: v => { slideTimer.v = v; slideTimer.restart() }
        }
    }

    // ---- частота ----
    Casc2 {
        index: 2; shown: root.shown
        MSection { text: "Частота опроса"; Layout.fillWidth: true; trail: root.md && root.md.st.rate_hz ? (root.md.st.rate_hz < 1000 ? root.md.st.rate_hz + " Гц" : root.md.st.rate_hz / 1000 + " кГц") : "" }
        MSegmented {
            Layout.fillWidth: true
            items: root.rates.map(h => ({ key: h, icon: h < 1000 ? String(h) : (h / 1000) + "K", text: "Гц" }))
            current: root.md ? (root.md.st.rate_hz || null) : null
            onPicked: key => root.md.setRate(key)
        }
        MHint { text: "Чем выше частота, тем плавнее курсор и тем быстрее садится батарея." }
    }

    // ---- профиль ----
    Casc2 {
        index: 3; shown: root.shown
        MSection { text: "Профиль"; Layout.fillWidth: true }
        ToggleRow {
            icon: "󰓹"; text: "Профиль в памяти мыши"
            checked: root.onboardOn
            toggleEnabled: root.onboard !== ""
            onToggled: on => root.md.setOnboard(on)
        }
        RowLayout {
            visible: root.md ? root.md.loading : true
            Layout.leftMargin: 12; spacing: 10
            MSpinner {}
            MText { text: "Читаю настройки из Solaar…"; font.pixelSize: 12; color: Colors.fgDim }
        }
        MHint { visible: root.onboardOn; text: "Пока профиль включён, DPI и частоту задаёт он — изменения отсюда могут не подействовать." }
        RowBtn { icon: "󰒓"; text: "Открыть Solaar"; onClicked: { root.md.openSolaar(); root.solaarOpened() } }
    }

    // каскад блоков (40 мс на блок), как Casc в меню «Система»
    component Casc2: Item {
        id: c
        property int index: 0
        property bool shown: true
        default property alias content: inner.data
        Layout.fillWidth: true
        implicitHeight: inner.implicitHeight
        opacity: shown ? 1 : 0
        property real slide: shown ? 0 : 8
        transform: Translate { y: c.slide }
        Behavior on opacity { SequentialAnimation { PauseAnimation { duration: c.shown ? 110 + c.index * 40 : 0 } NumberAnimation { duration: 280; easing.type: Easing.OutCubic } } }
        Behavior on slide { SequentialAnimation { PauseAnimation { duration: c.shown ? 110 + c.index * 40 : 0 } NumberAnimation { duration: 280; easing.type: Easing.OutCubic } } }
        ColumnLayout { id: inner; width: parent.width; spacing: 8 }
    }
    // строка-кнопка (yp.row_button): значок, текст, пометка, стрелка
    component RowBtn: Rectangle {
        id: rb
        property string icon: ""
        property string text: ""
        property string meta: ""
        property bool chevron: false
        signal clicked()
        Layout.fillWidth: true
        implicitHeight: 48; radius: Theme.radius             // «Остров»: вид IRow
        color: rbm.containsMouse ? Colors.isl2 : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        scale: rbm.pressed ? 0.985 : 1
        Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 10; spacing: 12
            MIconSq { icon: rb.icon; size: 32 }
            MText { text: rb.text; Layout.fillWidth: true; elide: Text.ElideRight; font.weight: Font.Medium }
            Text { visible: rb.meta.length > 0; text: rb.meta; font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim }
            Glyph { visible: rb.chevron; text: "󰅂"; color: Colors.fgDim; font.pixelSize: 14 }
        }
        MouseArea { id: rbm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rb.clicked() }
    }
}
