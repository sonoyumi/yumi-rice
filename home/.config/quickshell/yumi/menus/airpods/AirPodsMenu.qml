import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services
import qs.menus.wifi

// Меню AirPods (18.10) — карточка под пилюлей AirPods в баре (после трея). То же, что раскрытая строка AirPods
// в меню Bluetooth, но сразу: заряд Л/П/кейс, уши, режим шумоподавления, восприятие разговора, профиль звука
// (A2DP / гарнитура), «Отключить», «Все устройства» (меню Bluetooth). Данные — services/Bt (бэкенд qs/bluetooth,
// AAP через сокет службы yumi-airpods). Открыть: qs -c yumi ipc call airpods toggle <x центра пилюли>.
Scope {
    id: menu
    readonly property bool open: Menus.current === "airpods"
    property int anchorX: 1100
    property string toastText: ""
    property bool toastError: false
    // AirPods среди подключённых (по флагу бэкенда), иначе null
    readonly property var dev: {
        for (let i = 0; i < Bt.connectedModel.count; i++) { const d = Bt.connectedModel.get(i); if (d.airpods === true) return d }
        return null
    }
    readonly property string mac: dev ? dev.mac : ""   // без подключённых AirPods — пусто (меню показывает «не подключены»)
    readonly property var ap: Bt.airpods[mac] || null
    readonly property var card: Bt.cards[mac] || null
    readonly property string busyText: Bt.busy[mac] || ""
    readonly property var modes: [{ key: 1, icon: "󰖁", text: "Выкл" }, { key: 2, icon: "󰋋", text: "Шумоподав." },
                                  { key: 3, icon: "󰈈", text: "Прозрачн." }, { key: 4, icon: "󰁨", text: "Адаптив." }]
    readonly property var modeNames: ({ 1: "Выключено", 2: "Шумоподавление", 3: "Прозрачность", 4: "Адаптивный" })

    // Bt.wanted делим с меню Bluetooth: включаем после его onOpenChanged (callLater), выключаем, только если не оно открыто
    onOpenChanged: Qt.callLater(() => {
        if (open) { Bt.wanted = true; start(); if (!dev) connectPods() }
        else { Bt.airpodsSession(mac, false); toastText = ""; if (Menus.current !== "bluetooth") Bt.wanted = false }
    })
    // 30.10: меню открыто, а AirPods не подключены — сразу пробуем подключить сопряжённые (как кнопка «Подключить»)
    function connectPods() {
        toast("Подключаю AirPods…", false)
        Quickshell.execDetached(["sh", "-c", "bluetoothctl power on >/dev/null; for m in $(bluetoothctl devices Paired | awk '/AirPods/ {print $2}'); do bluetoothctl info \"$m\" | grep -q 'Connected: yes' || timeout 15 bluetoothctl connect \"$m\"; done"])
    }
    function start() { if (open && Bt.loaded && dev) { Bt.airpodsSession(mac, true); Bt.card(mac) } }
    Connections { target: Bt; function onLoadedChanged() { menu.start() } function onToast(text, error) { if (menu.open) menu.toast(text, error) } }
    onDevChanged: start()
    // первый запрос профиля может уйти, пока бэкенд ещё поднимается, — повторять, пока не ответит
    Timer { interval: 1500; repeat: true; running: menu.open && Bt.loaded && menu.dev !== null && menu.card === null; onTriggered: Bt.card(menu.mac) }
    Timer { id: toastTimer; interval: 3000; onTriggered: menu.toastText = "" }
    function toast(text, error) { toastText = text; toastError = error; toastTimer.restart() }
    function subtitle() {
        if (toastText) return toastText
        if (busyText) return busyText
        if (!Bt.loaded) return "…"
        if (!dev) return "Не подключены"
        if (!ap || ap.status !== "ok") return ap && ap.message ? ap.message : "Подключено · читаю наушники…"
        return ap.ear || "Подключено"
    }

    IpcHandler {
        target: "airpods"
        function toggle(x: int): void { if (x > 0) menu.anchorX = x; Menus.toggle("airpods") }
        function mode(n: int): void { Bt.airpodsMode(menu.mac, n) }
        function key(name: string): void { menu.key(name) }     // проверка клавиатуры: up|down|left|right|enter|esc
        function state(): string {
            const c = walker.current
            return JSON.stringify({ open: menu.open, mac: menu.mac, dev: !!menu.dev, ap: menu.ap, card: menu.card,
                                    kb: walker.active, ring: c ? [Math.round(c.mapToItem(null, 0, 0).x), Math.round(c.mapToItem(null, 0, 0).y)] : null,
                                    targets: walker.targets().length })
        }
    }
    // клавиатура как в меню Bluetooth: стрелки — по кнопкам (KeyWalker), Enter/пробел — нажать, Esc — закрыть
    function key(k) {
        if (k === "esc") { if (!scope.activeFocus) scope.forceActiveFocus(); else Menus.close("airpods"); return }
        if (!scope.activeFocus) scope.forceActiveFocus()
        if (k === "enter") walker.press()
        else walker.move(k)
    }

    PillCard {
        id: pop
        name: "airpods"
        grow: false
        open: menu.open
        screen: Menus.screen
        contentW: 400
        pad: 18
        readonly property int screenW: Menus.screen ? Menus.screen.width : 1600
        marginRight: Math.max(0, screenW - menu.anchorX - contentW / 2 - 20)     // карточка по центру под пилюлей
        readonly property int maxH: 560
        fixedH: maxH + pad * 2
        contentH: Math.min(col.implicitHeight, maxH - hints.implicitHeight - 8) + hints.implicitHeight + 8 + pad * 2
        holdOpen: menu.busyText !== ""

        FocusScope {
            id: scope
            anchors.fill: parent
            focus: true
            Keys.onPressed: (e) => {
                const m = { [Qt.Key_Up]: "up", [Qt.Key_Down]: "down", [Qt.Key_Left]: "left", [Qt.Key_Right]: "right",
                            [Qt.Key_Return]: "enter", [Qt.Key_Enter]: "enter", [Qt.Key_Space]: "enter", [Qt.Key_Escape]: "esc" }
                const k = m[e.key]
                if (k) { menu.key(k); e.accepted = true }
            }
            Connections { target: menu; function onOpenChanged() { walker.reset(); if (menu.open) scope.forceActiveFocus() } }

            ColumnLayout {
                id: col
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                spacing: 12

                // ---- заголовок («Остров»: как CardHead — имя 16 DemiBold, состояние 12; справа значок в акцентном квадрате) ----
                RowLayout {
                    Layout.fillWidth: true; spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        Text { Layout.fillWidth: true; text: menu.dev ? menu.dev.name : "AirPods"; elide: Text.ElideRight
                               font.family: Theme.fontUi; font.pixelSize: 16; font.weight: Font.DemiBold; color: Colors.fg }
                        Text { Layout.fillWidth: true; text: menu.subtitle(); elide: Text.ElideRight
                               font.family: Theme.fontUi; font.pixelSize: 12
                               color: menu.toastError && menu.toastText ? Colors.bad : Colors.fgDim }
                    }
                    MSpinner { visible: !Bt.loaded || menu.busyText !== "" || (menu.ap && (menu.ap.status === "connecting" || menu.ap.waiting)) }
                    Rectangle {
                        implicitWidth: 34; implicitHeight: 34; radius: 12
                        color: menu.dev ? Colors.acc : Colors.isl2
                        Behavior on color { ColorAnimation { duration: Theme.normal } }
                        PodsGlyph { anchors.centerIn: parent; pixelSize: 20; color: menu.dev ? Colors.onAcc : Colors.fgDim }
                    }
                }

                // ---- заряд: мини-шкалы Левый / Правый / Кейс (как mini() превью; недоступные не показываем) ----
                RowLayout {
                    visible: menu.ap !== null && batRep.count > 0
                    Layout.fillWidth: true; Layout.topMargin: 2; spacing: 0
                    Repeater {
                        id: batRep
                        model: menu.ap ? ["left", "right", "single", "case"].filter(k => menu.ap.battery[k] && menu.ap.battery[k].available) : []
                        delegate: Item {
                            id: tile
                            required property string modelData
                            readonly property var b: menu.ap ? menu.ap.battery[modelData] : null
                            Layout.fillWidth: true; implicitHeight: mm.implicitHeight
                            MMeter {
                                id: mm; anchors.horizontalCenter: parent.horizontalCenter
                                label: ({ left: "Левый", right: "Правый", single: "Наушники", case: "Кейс" })[tile.modelData]
                                value: tile.b ? tile.b.level : -1
                                charging: !!(tile.b && tile.b.status === "charging")
                                stale: !!(tile.b && tile.b.last)          // last — кейс закрыт: последний известный (18.10)
                                note: tile.b && tile.b.last ? tile.b.ago : ""
                            }
                        }
                    }
                }

                // ---- шумоподавление ----
                MSection { visible: menu.ap !== null && menu.ap.mode !== null; text: "Режим"; Layout.fillWidth: true; topPadding: 4 }
                MSegmented {
                    visible: menu.ap !== null && menu.ap.mode !== null
                    Layout.fillWidth: true
                    items: menu.modes; current: menu.ap ? menu.ap.mode : null; enabledKeys: menu.ap ? menu.ap.allowed : null
                    onPicked: key => { Bt.airpodsMode(menu.mac, key); menu.toast("Режим: " + menu.modeNames[key], false) }
                }
                MHint {
                    visible: menu.ap !== null && (menu.ap.pending || menu.ap.stale)
                    text: !menu.ap ? "" : menu.ap.pending ? "Жду подтверждения от наушников…" : "Наушники не подтвердили (часто применяется после переподключения)"
                }
                MOptRow {
                    visible: menu.ap !== null && menu.ap.conv !== null
                    icon: "󰗋"; text: "Восприятие разговора"; sub: "тише музыка, когда вы говорите"
                    checked: menu.ap ? menu.ap.conv === true : false
                    onToggled: on => { Bt.airpodsConv(menu.mac, on); menu.toast("Восприятие разговора: " + (on ? "вкл" : "выкл"), false) }
                }

                // ---- звук: A2DP / гарнитура ----
                MSection { visible: menu.card !== null && (menu.card.a2dp || menu.card.hfp); text: "Звук"; Layout.fillWidth: true; topPadding: 4 }
                MSegmented {
                    visible: menu.card !== null && (menu.card.a2dp || menu.card.hfp)
                    Layout.fillWidth: true
                    items: [{ key: "a2dp", icon: "󰋋", text: "Высокое качество" }, { key: "hfp", icon: "󰋎", text: "Гарнитура + микр." }]
                    current: menu.card ? menu.card.group : ""
                    enabledKeys: menu.card ? ["a2dp", "hfp"].filter(k => menu.card[k]) : []
                    onPicked: key => Bt.profile(menu.mac, key)
                }

                RowLayout {
                    Layout.fillWidth: true; Layout.topMargin: 4; spacing: 8
                    MButton {
                        Layout.fillWidth: true; text: "Отключить"; kind: "plain"
                        enabled: Bt.powered === true && menu.dev !== null && !menu.busyText
                        onClicked: Bt.disconnectDev(menu.mac)
                    }
                    MButton {
                        Layout.fillWidth: true; text: "Все устройства"; kind: "plain"
                        onClicked: Menus.open("bluetooth")
                    }
                }
            }

            // ---- подсказки клавиш капсулами ----
            MFooter {
                id: hints
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                hints: [["←→↑↓", "выбор"], ["Enter", "нажать"], ["Esc", "закрыть"]]
            }
            KeyWalker { id: walker; anchors.fill: parent; root: col }
        }
    }
}
