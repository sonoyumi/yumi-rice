import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services
import qs.menus.wifi

// Сопряжённое устройство: строка (значок, имя, батарея) + раскрывающаяся карточка с действиями.
// Для AirPods — батарея Л/П/кейс, режим шумоподавления, восприятие разговора (AAP через бэкенд).
ColumnLayout {
    id: row
    required property var model
    required property int index
    required property var menu
    readonly property string mac: model.mac || ""
    readonly property bool expanded: menu.expanded === mac
    readonly property string busyText: Bt.busy[mac] || ""
    readonly property var ap: Bt.airpods[mac] || null
    readonly property var card: Bt.cards[mac] || null
    readonly property bool apActive: expanded && model.airpods === true && model.connected === true && Bt.powered === true
    readonly property var modes: [{ key: 1, icon: "󰖁", text: "Выкл" }, { key: 2, icon: "󰋋", text: "Шумоподав." },
                                  { key: 3, icon: "󰈈", text: "Прозрачн." }, { key: 4, icon: "󰁨", text: "Адаптив." }]
    readonly property var modeNames: ({ 1: "Выключено", 2: "Шумоподавление", 3: "Прозрачность", 4: "Адаптивный" })
    Layout.fillWidth: true
    implicitWidth: parent ? parent.width : 0     // 19.10: иначе строка бывала нулевой ширины — стрелки и мышь её не видели
    spacing: 0
    opacity: 0
    Component.onCompleted: appear.start()
    SequentialAnimation {
        id: appear
        PauseAnimation { duration: Math.max(0, Math.min(row.index, 12)) * 40 }
        ParallelAnimation {
            NumberAnimation { target: row; property: "opacity"; to: 1; duration: 280; easing.type: Easing.OutCubic }
            NumberAnimation { target: row; property: "dy"; to: 0; duration: 280; easing.type: Easing.OutCubic }
        }
    }
    property real dy: 8
    transform: Translate { y: row.dy }
    onApActiveChanged: Bt.airpodsSession(mac, apActive)
    onExpandedChanged: if (expanded && model.connected === true && model.audio === true) Bt.card(mac)

    function battIcon(p) { return "󰁺󰁻󰁼󰁽󰁾󰁿󰂀󰂁󰂂󰁹".split("")[Math.min(Math.max(p - 1, 0) / 10 | 0, 9)] }
    function battMeta() {
        if (model.blocked === true) return "заблок."
        // у подключённых AirPods заряд виден сразу — Л/П/кейс, если бэкенд уже прислал
        if (ap && ap.battery) {
            const b = ap.battery, f = (k, n) => b[k] && b[k].available && !b[k].last ? n + " " + b[k].level + "%" : ""
            const t = [f("left", "Л"), f("right", "П"), f("single", ""), f("case", "кейс")].filter(x => x).join(" · ")
            if (t) return t
        }
        return (model.battery !== null && model.battery !== undefined) ? model.battery + "%" : ""
    }

    // строка аккордеона — «Остров»: вид IRow, значок в квадрате 34 (подключено/раскрыто — акцент), нажатие 0.985
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 52
        radius: Theme.radius
        color: row.expanded ? Colors.alpha(Colors.acc, 0.16) : hm.containsMouse ? Colors.isl2 : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        scale: hm.pressed ? 0.985 : 1
        Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 9; anchors.rightMargin: 10; spacing: 12
            MIconSq { icon: row.model.icon || ""; on: row.model.connected === true || row.expanded }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                MText { Layout.fillWidth: true; text: row.model.name || ""; elide: Text.ElideRight; font.weight: Font.Medium }
                MText { Layout.fillWidth: true; elide: Text.ElideRight; font.pixelSize: 12; color: row.model.blocked ? Colors.warn : Colors.fgDim
                        text: row.busyText ? row.busyText : [row.model.blocked === true ? "заблокировано" : row.model.connected === true ? "Подключено" : "не подключено", row.battMeta()].filter(x => x).join(" · ") }
            }
            MSpinner { visible: row.busyText.length > 0 }
            Glyph { text: "󰅂"; color: Colors.fgDim; font.pixelSize: 15; rotation: row.expanded ? 90 : 0
                    Behavior on rotation { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutBack } } }
        }
        MouseArea { id: hm; property string btMac: row.mac; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: row.menu.toggleExpand(row.mac) }
    }

    Reveal {
        shown: row.expanded
        spacing: 10
        Item { implicitHeight: 0 }
        IBox {
            spacing: 5
            MText { Layout.fillWidth: true; visible: text.length > 0; text: row.model.status || ""; wrapMode: Text.Wrap; font.pixelSize: 12 }
            InfoRow { key: "Тип"; value: row.model.kindName || "" }
            InfoRow { key: "Батарея"; value: (row.model.battery !== null && row.model.battery !== undefined) ? row.model.battery + "%" : "" }
            InfoRow { key: "MAC"; value: row.mac; copy: true }
        }

        // ---- AirPods ----
        ColumnLayout {
            visible: row.model.airpods === true && row.ap !== null
            Layout.fillWidth: true; spacing: 8
            MSection { Layout.fillWidth: true; text: "AirPods" + (row.model.modelName ? " · " + row.model.modelName : "") }
            RowLayout {
                visible: row.ap && (row.ap.status !== "ok" || row.ap.waiting)
                Layout.fillWidth: true; spacing: 8
                MSpinner { visible: row.ap && (row.ap.status === "connecting" || row.ap.waiting) }
                MHint { text: row.ap ? row.ap.message : ""; leftPadding: 0 }
            }
            // заряд — мини-шкалы Левый / Правый / Кейс (как mini() превью)
            IBox {
                visible: row.ap && Object.keys(row.ap.battery).length > 0
                RowLayout {
                    Layout.fillWidth: true; spacing: 0
                    Repeater {
                        model: row.ap ? ["left", "right", "single", "case"].filter(k => row.ap.battery[k]) : []
                        delegate: Item {
                            id: tile
                            required property string modelData
                            readonly property var b: row.ap ? row.ap.battery[modelData] : null
                            Layout.fillWidth: true; implicitHeight: mm.implicitHeight
                            MMeter {
                                id: mm; anchors.horizontalCenter: parent.horizontalCenter
                                label: ({ left: "Левый", right: "Правый", single: "Наушники", case: "Кейс" })[tile.modelData]
                                value: tile.b && tile.b.available ? tile.b.level : -1
                                charging: !!(tile.b && tile.b.status === "charging")
                                stale: !!(tile.b && tile.b.last)             // last — кейс закрыт: последний известный (18.10)
                                note: tile.b && tile.b.last ? tile.b.ago : ""
                            }
                        }
                    }
                }
            }
            MHint { visible: row.ap && row.ap.ear.length > 0; text: row.ap ? row.ap.ear : "" }
            MSegmented {
                visible: row.ap && row.ap.mode !== null
                Layout.fillWidth: true
                items: row.modes; current: row.ap ? row.ap.mode : null; enabledKeys: row.ap ? row.ap.allowed : null
                onPicked: key => { Bt.airpodsMode(row.mac, key); row.menu.toast("Режим: " + row.modeNames[key], false) }
            }
            MHint {
                visible: row.ap && row.ap.mode !== null
                text: !row.ap ? "" : "Режим: " + (row.modeNames[row.ap.mode] || "?")
                      + (row.ap.pending ? " · жду подтверждения…" : row.ap.stale ? " · наушники не подтвердили (часто применяется после переподключения)" : "")
            }
            MOptRow {
                visible: row.ap && row.ap.conv !== null
                icon: "󰗋"; text: "Восприятие разговора"; sub: "тише музыка, когда вы говорите"
                checked: row.ap ? row.ap.conv === true : false
                onToggled: on => { Bt.airpodsConv(row.mac, on); row.menu.toast("Восприятие разговора: " + (on ? "вкл" : "выкл"), false) }
            }
        }

        // ---- звук: профиль A2DP / HFP ----
        ColumnLayout {
            visible: row.model.connected === true && row.card !== null && (row.card.a2dp || row.card.hfp)
            Layout.fillWidth: true; spacing: 8
            MSection { Layout.fillWidth: true; text: "Звук" }
            MSegmented {
                Layout.fillWidth: true
                items: [{ key: "a2dp", icon: "󰋋", text: "Высокое качество" }, { key: "hfp", icon: "󰋎", text: "Гарнитура + микр." }]
                current: row.card ? row.card.group : ""
                enabledKeys: row.card ? ["a2dp", "hfp"].filter(k => row.card[k]) : []
                onPicked: key => Bt.profile(row.mac, key)
            }
            MHint { text: "Высокое качество (A2DP) — стерео без микрофона. Гарнитура (HFP) — работает микрофон, звук проще." }
        }

        RowLayout { visible: row.busyText.length > 0; spacing: 8; MSpinner {} MText { text: row.busyText; font.pixelSize: 12; color: Colors.fgDim } }
        MButton {
            Layout.fillWidth: true
            text: row.model.connected === true ? "Отключить" : "Подключить"
            kind: row.model.connected === true ? "plain" : "primary"
            enabled: Bt.powered === true && !row.busyText && row.model.blocked !== true
            onClicked: row.model.connected === true ? Bt.disconnectDev(row.mac) : Bt.connectDev(row.mac)
        }
        MHint { visible: row.model.blocked === true; text: "Устройство заблокировано — снимите блокировку, чтобы подключить." }
        MOptRow { icon: "󰒘"; text: "Доверять · автоподключение"; checked: row.model.trusted === true; enabled: !row.busyText; onToggled: on => Bt.trust(row.mac, on) }
        MOptRow { icon: "󰂭"; text: "Заблокировать"; checked: row.model.blocked === true; enabled: !row.busyText; onToggled: on => Bt.block(row.mac, on) }
        MButton {
            visible: row.menu.confirmMac !== row.mac
            Layout.fillWidth: true; text: "Удалить устройство"; kind: "danger"; enabled: !row.busyText
            onClicked: row.menu.confirmMac = row.mac
        }
        Reveal {
            shown: row.menu.confirmMac === row.mac
            MConfirm {
                text: "Удалить «" + (row.model.name || "") + "»? Чтобы подключить его снова, придётся заново выполнить сопряжение."
                onYes: { row.menu.confirmMac = ""; Bt.remove(row.mac) }
                onNo: row.menu.confirmMac = ""
            }
        }
        Item { implicitHeight: 4 }
    }
}
