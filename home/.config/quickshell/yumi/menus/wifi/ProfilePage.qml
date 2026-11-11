import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Страница профиля (как open_profile/build_profile в yumi-menu-wifi): пароль, автоподключение, приоритет, лимитное,
// IP авто/вручную (адрес/маска, шлюз, DNS — проверка в бэкенде), MAC постоянный/случайный/стабильный, «Подключиться», «Забыть».
Flickable {
    id: page
    required property var owner
    readonly property bool shown: owner.page === "profile"
    readonly property int pageH: col.implicitHeight
    readonly property var p: Network.profile
    readonly property bool ready: p !== null && p.uuid === owner.profUuid
    property string ipMode: "auto"         // выбранный сегмент IP (поля раскрываются сразу, сохраняются кнопкой)
    property string ipError: ""
    property string password: ""
    property bool askForget: false
    contentHeight: col.implicitHeight
    clip: true; boundsBehavior: Flickable.StopAtBounds; interactive: contentHeight > height
    visible: opacity > 0; opacity: shown ? 1 : 0
    property real slide: shown ? 0 : 30
    transform: Translate { x: page.slide }
    Behavior on opacity { NumberAnimation { duration: Theme.fast } }
    Behavior on slide { NumberAnimation { duration: Theme.normal; easing.type: Theme.easeSoft } }

    // раскрылся вопрос «Забыть» — докрутить, чтобы он был виден (после раскрытия Reveal)
    onAskForgetChanged: if (askForget) scrollEnd.restart()
    Timer { id: scrollEnd; interval: Theme.normal + 20; onTriggered: page.contentY = Math.max(0, page.contentHeight - page.height) }
    Behavior on contentY { enabled: !page.moving; NumberAnimation { duration: Theme.normal; easing.type: Theme.easeSoft } }
    function reset() { ipError = ""; password = ""; askForget = false; contentY = 0; release() }
    function release() { eAddr.release(); eGw.release(); eDns.release() }
    onShownChanged: if (!shown) release()
    onReadyChanged: if (ready) { ipMode = p.ip; eAddr.text = p.addr; eGw.text = p.gw; eDns.text = p.dns }
    function saveIp() {
        ipError = ""
        Network.pmodify(p.uuid, "ip_manual", true, { addr: eAddr.text, gw: eGw.text, dns: eDns.text })
    }
    function testIp(a) { eAddr.text = a; saveIp() }
    function pickIp(k) {
        const was = ipMode
        ipMode = k
        if (k === "auto" && was === "manual" && p.ip === "manual") Network.pmodify(p.uuid, "ip_auto", true)
    }
    Connections {
        target: Network
        function onResult(cmd, what, ok, msg) {
            if (cmd === "ip" && !ok) { page.ipError = msg; eAddr.bad = what === "addr"; eGw.bad = what === "gw"; eDns.bad = what === "dns" }
            else if (cmd === "pforget" && ok && what === page.owner.profUuid) page.owner.page = "saved"
        }
        function onPassword(text, ok, uuid) { if (page.ready && uuid === page.p.uuid) page.password = ok ? text : "\u0000" }
    }

    ColumnLayout {
        id: col
        width: page.width
        spacing: 8

        RowLayout { visible: !page.ready; spacing: 8; Layout.leftMargin: 6; MSpinner {} MText { text: "Читаю профиль…"; font.pixelSize: 12; color: Colors.fgDim } }

        ColumnLayout {
            visible: page.ready
            Layout.fillWidth: true; spacing: 8

            MText { Layout.fillWidth: true; text: page.ready ? page.p.ssid : ""; font.pixelSize: 15; font.weight: Font.DemiBold; elide: Text.ElideRight; leftPadding: 4 }
            MHint { text: page.ready ? page.p.sub : ""; leftPadding: 4; topPadding: -6 }

            // пароль
            InfoRow { key: "Пароль"; value: page.password && page.password !== "\u0000" ? page.password : ""; copy: true }
            MHint { visible: page.password === "\u0000"; text: "Пароль не сохранён или нет доступа"; color: Colors.bad }
            MButton {
                visible: page.ready && page.p.secured && (!page.password || page.password === "\u0000")
                Layout.fillWidth: true; text: "󰈈  Показать пароль"
                onClicked: Network.showPassword(page.p.uuid)
            }

            // подключение
            MSection { text: "Подключение" }
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                Glyph { text: "󰁪"; font.pixelSize: 15 }
                MText { Layout.fillWidth: true; text: "Подключаться автоматически"; font.weight: Font.Medium }
                MToggle { checked: page.ready && page.p.autoconnect; onToggled: on => Network.pmodify(page.p.uuid, "autoconnect", on) }
            }
            MText { text: "Приоритет среди сохранённых сетей"; font.pixelSize: 12; color: Colors.fgDim; leftPadding: 6 }
            MSegmented {
                Layout.fillWidth: true
                items: [{ key: "low", icon: "󰁅", text: "Низкий" }, { key: "normal", icon: "󰇘", text: "Обычный" }, { key: "high", icon: "󰁝", text: "Высокий" }]
                current: page.ready ? page.p.prio : null
                onPicked: key => { if (key !== page.p.prio) Network.pmodify(page.p.uuid, "prio", key) }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                Glyph { text: "󰾆"; font.pixelSize: 15 }
                MText { Layout.fillWidth: true; text: "Лимитное подключение"; font.weight: Font.Medium }
                MToggle { checked: page.ready && page.p.metered; onToggled: on => Network.pmodify(page.p.uuid, "metered", on) }
            }
            MHint { text: "Лимитное — система бережёт трафик: без фоновых обновлений и больших загрузок." }

            // IP
            MSection { text: "IP-адрес" }
            MSegmented {
                Layout.fillWidth: true
                items: [{ key: "auto", icon: "󰑓", text: "Авто (DHCP)" }, { key: "manual", icon: "󰏫", text: "Вручную" }]
                current: page.ipMode
                onPicked: key => page.pickIp(key)
            }
            Reveal {
                shown: page.ipMode === "manual"
                spacing: 6
                MText { text: "Адрес / маска"; font.pixelSize: 12; color: Colors.fgDim; leftPadding: 6 }
                MField { id: eAddr; Layout.fillWidth: true; placeholder: "Адрес, например 192.168.1.50/24"; onAccepted: page.saveIp() }
                MText { text: "Шлюз"; font.pixelSize: 12; color: Colors.fgDim; leftPadding: 6 }
                MField { id: eGw; Layout.fillWidth: true; placeholder: "Шлюз, например 192.168.1.1"; onAccepted: page.saveIp() }
                MText { text: "DNS"; font.pixelSize: 12; color: Colors.fgDim; leftPadding: 6 }
                MField { id: eDns; Layout.fillWidth: true; placeholder: "DNS через запятую: 1.1.1.1, 8.8.8.8"; onAccepted: page.saveIp() }
                MText { visible: page.ipError.length > 0; Layout.fillWidth: true; wrapMode: Text.Wrap; text: page.ipError; color: Colors.bad; font.pixelSize: 12; leftPadding: 6 }
                MHint { visible: page.ready && page.p.current; text: "Для текущей сети новые настройки IP вступят в силу после переподключения." }
                MButton { Layout.fillWidth: true; text: "Сохранить IP"; kind: "primary"; onClicked: page.saveIp() }
            }

            // MAC
            MSection { text: "MAC-адрес" }
            MSegmented {
                Layout.fillWidth: true
                items: [{ key: "permanent", icon: "󰌆", text: "Постоянный" }, { key: "random", icon: "󰒝", text: "Случайный" }, { key: "stable", icon: "󰒘", text: "Стабильный" }]
                current: page.ready ? page.p.mac : null
                onPicked: key => { if (key !== page.p.mac || page.p.macManual) Network.pmodify(page.p.uuid, "mac", key) }
            }
            MHint { text: "Случайный — новый при каждом подключении, стабильный — свой постоянный для этой сети." }
            MHint { visible: page.ready && page.p.macManual.length > 0; text: page.ready ? "Сейчас задан вручную: " + page.p.macManual : "" }

            // действия
            Item { implicitHeight: 4 }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                MButton { visible: page.ready && !page.p.current; Layout.fillWidth: true; text: "Подключиться"; kind: "primary"
                          enabled: Network.busy === ""; onClicked: { Network.pconnect(page.p.uuid); page.owner.page = "" } }
                MButton { Layout.fillWidth: true; text: "Забыть сеть"; kind: "danger"; onClicked: page.askForget = !page.askForget }
            }
            Reveal {
                shown: page.askForget
                MConfirm {
                    text: page.ready ? "Забыть «" + page.p.ssid + "»? Сохранённый пароль и настройки удалятся."
                                       + (page.p.current ? " Текущее подключение (SSH, Tailscale) оборвётся." : "") : ""
                    yesText: "Забыть"
                    onYes: { page.askForget = false; Network.pforget(page.p.uuid) }
                    onNo: page.askForget = false
                }
            }
            Item { implicitHeight: 4 }
        }
    }
}
