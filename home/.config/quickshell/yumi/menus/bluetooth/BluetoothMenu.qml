import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services
import qs.menus.wifi

// Меню Bluetooth на QML. Содержимое и подписи — как у ~/.local/bin/yumi-menu-bluetooth (GTK-меню остаётся рабочим),
// логика — бэкенд ~/.local/lib/yumi/qs/bluetooth через services/Bt.qml (D-Bus BlueZ, bluetoothctl, AirPods по AAP).
// Вид (16.10, вариант 05 «Аккордеон на месте»; прежнее — BluetoothMenu.qml.bak-widget-20261016): устройства строками
// высотой 44 со сводкой (статус, батарея), строка раскрывается на месте (открыта одна) — подключить/отключить,
// AirPods, профиль звука, доверие, блокировка, удаление; найденные — сопряжение под строкой, как было.
// Клавиатура — KeyWalker: ↑↓ строка/элемент, Enter или → раскрыть, ← свернуть, Esc — свернуть/закрыть.
// Открыть/закрыть: qs -c yumi ipc call menu toggle bluetooth. Esc и клик вне окна закрывают.
Scope {
    id: btMenu
    readonly property bool open: Menus.current === "bluetooth"
    property string expanded: ""         // MAC раскрытого устройства
    property string confirmMac: ""       // «Удалить устройство?»
    property string toastText: ""
    property bool toastError: false

    onOpenChanged: {
        Bt.wanted = open
        if (!open) { expanded = ""; confirmMac = ""; toastText = ""; Bt.scan(false); Bt.pairCancel() }
    }
    Connections {
        target: Bt
        function onToast(text, error) { btMenu.toast(text, error) }
        function onResult(cmd, mac, ok, msg) { if (cmd === "remove" && ok && mac === btMenu.expanded) btMenu.expanded = "" }
    }
    Timer { id: toastTimer; interval: 3000; onTriggered: btMenu.toastText = "" }
    function toast(text, error) { toastText = text; toastError = error; toastTimer.restart() }
    function toggleExpand(mac) { expanded = (expanded === mac) ? "" : mac; confirmMac = "" }
    onExpandedChanged: Qt.callLater(() => walker.recheck())
    function back() {
        if (confirmMac) confirmMac = ""
        else if (expanded) { const m = expanded; expanded = ""; focusRow(m) }
        else Menus.close("bluetooth")
    }
    // фокус на строку устройства (после сворачивания)
    function focusRow(mac) { Qt.callLater(() => { for (const t of walker.targets()) if (t.btMac === mac) { walker.current = t; walker.active = true; walker.follow(); return } }) }
    function key(k) {
        if (k === "esc") { if (!scope.activeFocus) scope.forceActiveFocus(); else back(); return }
        if (k === "enter") { walker.press(); return }
        if (!scope.activeFocus) scope.forceActiveFocus()
        walker.move(k)
    }
    // → у строки без соседа справа — раскрыть; ← без соседа слева — свернуть
    function edge(dir) {
        const c = walker.current
        if (dir === "right" && c && c.btMac && expanded !== c.btMac) toggleExpand(c.btMac)
        else if (dir === "left" && expanded) back()
    }
    function subtitle() {
        if (toastText) return toastText
        if (!Bt.loaded) return "…"
        if (Bt.powered === null) return "Служба Bluetooth недоступна"
        if (!Bt.powered) return "Выключен"
        if (Bt.scanning) return "Поиск… " + Bt.scanLeft + " с"
        return Bt.connectedCount ? "Включён · " + Bt.connectedCount + " подключено" : "Включён · нет подключений"
    }

    // Для проверки и горячих клавиш: qs -c yumi ipc call bluetooth expand <MAC> | scan | pair <MAC> | reply yes|no | ask <MAC> | mode <n>
    IpcHandler {
        target: "bluetooth"
        function expand(mac: string): void { btMenu.toggleExpand(mac.toUpperCase()) }
        function scan(): void { Bt.scan(!Bt.scanning) }
        function pair(mac: string): void { Bt.pair(mac.toUpperCase()) }
        function reply(text: string): void { Bt.pairReply(text) }
        function ask(mac: string): void { btMenu.confirmMac = mac.toUpperCase() }
        function mode(n: int): void { if (btMenu.expanded) Bt.airpodsMode(btMenu.expanded, n) }
        function key(name: string): void { btMenu.key(name) }     // проверка клавиатуры: up|down|left|right|enter|esc
        function state(): string {
            const c = walker.current
            return JSON.stringify({ open: btMenu.open, expanded: btMenu.expanded, kb: walker.active, row: c && c.btMac ? c.btMac : "", targets: walker.targets().length })
        }
    }

    PillCard {
        id: pop
        name: "bluetooth"
        grow: false
        open: btMenu.open
        screen: Menus.screen
        marginRight: 140
        marginTop: Theme.barH * (Theme.dev ? 2 : 1) + 6
        contentW: 400                          // «Остров»: карточка 400, отступ 18
        pad: 18
        readonly property int maxH: 760
        // окно постоянного размера (fixedH), высоту анимирует карточка внутри Popup — иначе слой переконфигурируется каждый кадр
        fixedH: maxH + pad * 2
        contentH: Math.min(body.implicitHeight, maxH - hints.implicitHeight - 8) + hints.implicitHeight + 8 + pad * 2
        holdOpen: Object.keys(Bt.busy).length > 0 || Bt.pairMac !== ""   // подключение/сопряжение — от ухода курсора не закрывать

        FocusScope {
            id: scope
            anchors.fill: parent
            focus: true
            Keys.onPressed: (e) => {
                const k = e.key
                if (k === Qt.Key_Escape) btMenu.key("esc")
                else if (k === Qt.Key_Up) btMenu.key("up")
                else if (k === Qt.Key_Down) btMenu.key("down")
                else if ((k === Qt.Key_Left || k === Qt.Key_Right) && scope.activeFocus) btMenu.key(k === Qt.Key_Left ? "left" : "right")
                else if ((k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) && scope.activeFocus) btMenu.key("enter")
                else return
                e.accepted = true
            }
            Connections { target: btMenu; function onOpenChanged() { walker.reset(); if (btMenu.open) scope.forceActiveFocus() } }

            Flickable {
                id: flick
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.bottom: hints.top; anchors.bottomMargin: 8
                contentHeight: body.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                ColumnLayout {
                    id: body
                    width: flick.width
                    spacing: 4

                    MenuHeader {
                        icon: Bt.powered ? "󰂯" : "󰂲"; iconOn: Bt.powered === true
                        title: "Bluetooth"; subtitle: btMenu.subtitle(); error: btMenu.toastError && btMenu.toastText.length > 0
                        checked: Bt.powered === true; toggleEnabled: Bt.loaded && Bt.powered !== null; dry: Bt.dry
                        onToggled: on => Bt.setPower(on)
                    }
                    RowLayout { visible: !Bt.loaded; spacing: 8; Layout.leftMargin: 6; MSpinner {} MText { text: "Читаю устройства…"; font.pixelSize: 12; color: Colors.fgDim } }
                    MHint { visible: Bt.loaded && !Bt.powered; text: "Bluetooth выключен — включите, чтобы увидеть устройства"; Layout.topMargin: 4 }

                    // ---- подключены ----
                    MSection { visible: Bt.powered === true; text: "Подключены"; Layout.fillWidth: true; Layout.leftMargin: 2; topPadding: 12; bottomPadding: 4; trail: String(Bt.connectedModel.count) }
                    Repeater {
                        model: Bt.powered === true ? Bt.connectedModel : null
                        delegate: DeviceRow { menu: btMenu }
                    }
                    MHint { visible: Bt.powered === true && Bt.connectedModel.count === 0; text: "Нет подключённых устройств" }

                    // ---- сопряжённые ----
                    MSection { visible: Bt.powered === true; text: "Сопряжённые"; Layout.fillWidth: true; Layout.leftMargin: 2; topPadding: 12; bottomPadding: 4; trail: String(Bt.pairedModel.count) }
                    Repeater {
                        model: Bt.powered === true ? Bt.pairedModel : null
                        delegate: DeviceRow { menu: btMenu }
                    }
                    MHint { visible: Bt.powered === true && Bt.pairedModel.count === 0
                            text: Bt.connectedModel.count ? "Больше сопряжённых устройств нет" : "Нет сопряжённых устройств" }

                    // ---- найдены (поиск — всегда настоящий) ----
                    RowLayout {
                        visible: Bt.powered === true
                        Layout.fillWidth: true; Layout.topMargin: 10; Layout.bottomMargin: 4; Layout.leftMargin: 2
                        MSection { text: "Найдены"; Layout.fillWidth: true; topPadding: 0 }
                        Rectangle {
                            // «Остров»: «сканировать» — капсула isl2 справа от подписи раздела
                            implicitHeight: 26; implicitWidth: srow.implicitWidth + 20; radius: 13
                            color: sm.containsMouse ? Colors.hover : Colors.isl2
                            Behavior on color { ColorAnimation { duration: Theme.fast } }
                            scale: sm.pressed ? 0.95 : 1
                            Behavior on scale { NumberAnimation { duration: Theme.fast } }
                            Behavior on implicitWidth { NumberAnimation { duration: Theme.normal; easing.type: Theme.easeSoft } }
                            RowLayout {
                                id: srow; anchors.centerIn: parent; spacing: 6
                                MSpinner { visible: Bt.scanning; width: 11; height: 11 }
                                Glyph { visible: !Bt.scanning; text: "󰍉"; font.pixelSize: 13; color: Colors.fgDim }
                                MText { text: Bt.scanning ? "ищу… " + Bt.scanLeft + " с" : "Сканировать"; font.pixelSize: 12; font.features: ({ "tnum": 1 }); color: Colors.fgDim; Layout.minimumWidth: Bt.scanning ? 70 : 0 }
                            }
                            MouseArea { id: sm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Bt.scan(!Bt.scanning) }
                        }
                    }
                    MHint { visible: Bt.powered === true && (Bt.scanning || Bt.foundModel.count === 0); font.pixelSize: 12
                            text: Bt.scanning ? "Переведите устройство в режим сопряжения — оно появится в списке." : "Пока ничего не найдено — нажмите «Сканировать»" }
                    Repeater {
                        model: Bt.powered === true ? Bt.foundModel : null
                        delegate: FoundRow { menu: btMenu }
                    }

                    MText {
                        visible: Bt.loaded && Bt.adapter.alias !== undefined
                        text: "Адаптер «" + (Bt.adapter.alias || "") + "» · " + (Bt.adapter.discoverable ? "видим для других" : "скрыт от других устройств")
                        font.pixelSize: 12; color: Colors.fgDim; Layout.alignment: Qt.AlignHCenter; topPadding: 8
                    }
                }
            }

            // ---- подсказки клавиш («Остров»: капсулы по центру) ----
            MFooter {
                id: hints
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                hints: btMenu.expanded ? [["↑↓", "выбор"], ["Enter", "нажать"], ["←", "свернуть"], ["Esc", "назад"]]
                                       : [["↑↓", "строка"], ["Enter →", "раскрыть"], ["Esc", "закрыть"]]
            }
            KeyWalker { id: walker; anchors.fill: parent; root: flick; flick: flick; onEdge: (dir) => btMenu.edge(dir) }
        }
    }
}
