import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services

// Меню Wi-Fi на QML. Содержимое и подписи — как у ~/.local/bin/yumi-menu-wifi (GTK-меню остаётся рабочим),
// логика — бэкенд ~/.local/lib/yumi/qs/wifi через services/Network.qml.
// Вид (16.10, вариант 06 «Список и детали» со страницы статичных меню, как у VPN; прежнее — WifiMenu.qml.bak-widget-20261016):
// слева список — текущая сеть, доступные, «Сохранённые сети»; справа подробности выбранного: у текущей — параметры,
// пароль, автоподключение, лимитное, «Отключиться» / «Забыть» с подтверждением; у другой — сигнал, защита и
// подключение (пароль); «Сохранённые сети» и профиль сети (SavedPage / ProfilePage) — тоже справа.
// Клавиатура — KeyWalker: ↑↓ по списку (детали меняются сразу), → в детали, ← обратно, Enter — нажать,
// поле пароля — ввод (Esc из поля — к стрелкам), Esc — назад / закрыть.
// Открыть/закрыть: qs -c yumi ipc call menu toggle wifi. Esc и клик вне окна закрывают.
Scope {
    id: menu
    readonly property bool open: Menus.current === "wifi"
    property string pwSsid: ""            // сеть, у которой открыт ввод пароля (справа)
    property string pwError: ""
    property string doneSsid: ""          // только что подключились — галочка на строке
    property bool confirmRadio: false
    property bool showDetails: true       // справа у текущей сети детали видны всегда
    property string confirmKind: ""       // "down" | "forget" — вопрос в деталях текущей сети
    property string shownPassword: ""
    property string toastText: ""
    property bool toastError: false
    property string page: ""              // "" | "saved" (Сохранённые сети) | "profile" (страница профиля)
    property string profUuid: ""
    property string sel: "cur"            // выбрано слева: "cur" | SSID другой сети | "saved"

    function openSaved() { sel = "saved"; page = "saved"; Network.loadProfiles() }
    function openProfile(uuid) { sel = "saved"; profUuid = uuid; profPage.reset(); Network.loadProfile(uuid); page = "profile" }
    function select(k) {
        if (k === "saved") { if (page === "") openSaved(); return }
        page = ""; confirmKind = ""
        if (sel !== k) { pwError = "" }
        sel = k
        if (k === "cur") Network.requestDetails()
    }
    function back() {
        if (page === "profile") { page = "saved"; Network.loadProfiles() }
        else if (page === "saved") select(Network.cur ? "cur" : firstNet())
        else Menus.close("wifi")
    }
    function firstNet() { return Network.netModel.count ? Network.netModel.get(0).ssid : "cur" }
    function netBy(ssid) { for (let i = 0; i < Network.netModel.count; i++) { const m = Network.netModel.get(i); if (m.ssid === ssid) return m } return null }

    onOpenChanged: {
        Network.wanted = open
        if (open) { sel = "cur"; page = ""; Network.requestDetails() }
        else { pwSsid = ""; pwError = ""; confirmRadio = false; confirmKind = ""; shownPassword = ""; toastText = ""; page = "" }
    }
    onPageChanged: Qt.callLater(() => walker.recheck())
    onSelChanged: Qt.callLater(() => walker.recheck())
    Connections {
        target: Network
        function onToast(text, error) { menu.toastText = text; menu.toastError = error; toastTimer.restart() }
        function onResult(cmd, ssid, ok, msg) {
            if (cmd === "connect") {
                if (ok) { menu.pwSsid = ""; menu.pwError = ""; menu.doneSsid = ssid; doneTimer.restart() }
                else if (msg === "need_password") { menu.sel = ssid; menu.pwSsid = ssid; menu.pwError = "" }
                else if (menu.pwSsid === ssid) menu.pwError = msg
            } else if ((cmd === "disconnect" || cmd === "forget") && ok) { menu.confirmKind = "" }
        }
        function onPassword(text, ok, uuid) { if (menu.page === "") menu.shownPassword = ok ? text : "Пароль не сохранён или нет доступа" }
        function onCurChanged() {
            if (!Network.cur) { menu.shownPassword = ""; if (menu.sel === "cur") menu.sel = menu.firstNet() }
            else if (menu.sel === Network.cur.ssid) { menu.sel = "cur"; Network.requestDetails() }
        }
    }
    Timer { id: toastTimer; interval: 3000; onTriggered: menu.toastText = "" }

    // Для проверки и горячих клавиш: qs -c yumi ipc call wifi details | net <SSID> | password <пароль> | ask down|forget
    IpcHandler {
        target: "wifi"
        function details(): void { menu.select("cur") }
        function net(ssid: string): void { const m = menu.netBy(ssid); if (m) menu.clickNet(m) }
        function password(pw: string): void { pwText = pw; passwordRequested() }
        function ask(kind: string): void { if (kind === "radio") { menu.confirmRadio = true; return } menu.select("cur"); menu.confirmKind = kind }
        // страница профиля: ip <адрес> — «Вручную» + адрес + «Сохранить IP»; forget — открыть вопрос «Забыть»
        function ip(addr: string): void { profPage.pickIp("manual"); profPage.testIp(addr) }
        function forget(yes: bool): void { if (yes) Network.pforget(menu.profUuid); else profPage.askForget = true }
        // page saved | back | profile:<uuid или имя профиля>
        function page(what: string): void {
            if (what === "saved") menu.openSaved()
            else if (what === "back") menu.back()
            else if (what.indexOf("profile:") === 0) {
                const key = what.slice(8)
                for (let i = 0; i < Network.profileModel.count; i++) { const m = Network.profileModel.get(i); if (m.uuid === key || m.name === key) { menu.openProfile(m.uuid); return } }
                menu.openProfile(key)
            }
        }
        function key(name: string): void { menu.key(name) }   // проверка клавиатуры: up|down|left|right|enter|esc
        function state(): string {
            return JSON.stringify({ open: menu.open, sel: menu.sel, page: menu.page, kb: walker.active, targets: walker.targets().length,
                                    focus: walker.current && walker.current.wifiSel !== undefined ? "строка " + walker.current.wifiSel : (walker.current ? "детали" : "") })
        }
    }
    property string pwText: ""
    signal passwordRequested()
    Timer { id: doneTimer; interval: 2500; onTriggered: menu.doneSsid = "" }

    function subtitle() {
        if (toastText) return toastText
        if (Network.busy) return "Подключаюсь к " + Network.busy + "…"
        if (!Network.loaded) return "…"
        if (!Network.radio) return "Wi-Fi выключен"
        if (Network.cur) return Network.cur.signal ? Network.cur.ssid + " · " + Network.cur.signal + "%" : Network.cur.ssid
        return "Не подключено"
    }
    // как раньше: сохранённая или открытая — подключиться сразу; с паролем — открыть ввод (справа)
    function clickNet(m) {
        select(m.ssid)
        if (Network.busy) return
        if (m.saved) { pwSsid = ""; Network.connectTo(m.ssid, null) }
        else if (m.security) { pwError = ""; pwSsid = m.ssid }
        else { pwSsid = ""; Network.connectTo(m.ssid, null) }
    }
    function inside(it, box) { for (let p = it; p; p = p.parent) if (p === box) return true; return false }
    // главное действие в деталях справа: поле пароля → «Подключиться» → верхняя цель панели
    function detailTarget() {
        const ts = walker.targets().filter(it => inside(it, pane))
        if (!ts.length) return null
        if (netFlick.shown) {
            if (netFlick.askPw && ts.indexOf(pwField) >= 0) return pwField
            const b = ts.find(it => inside(it, connectBtn))
            if (b) return b
        }
        ts.sort((a, b) => { const A = walker.centerOf(a), B = walker.centerOf(b); return Math.abs(A.y - B.y) > 6 ? A.y - B.y : A.x - B.x })
        return ts[0]
    }
    function key(k) {
        if (k === "esc") { if (!scope.activeFocus) scope.forceActiveFocus(); else back(); return }
        if (k === "enter" && !(walker.active && walker.current && walker.current.wifiSel !== undefined && walker.current.wifiSel !== "saved")) { walker.press(); return }
        if (!scope.activeFocus) scope.forceActiveFocus()
        // 19.10: → (и Enter) на строке сети — сразу к действию справа: «Подключиться» / поле пароля, у текущей — первая
        // кнопка деталей. Раньше → искал цель в том же ряду, а кнопка внизу панели — стрелка ничего не делала.
        // ← из деталей — обратно на выбранную строку (по рядам она тоже не находилась).
        const cur = walker.active ? walker.current : null
        if (cur && menu.page === "" && (k === "right" || k === "enter") && cur.wifiSel !== undefined && cur.wifiSel !== "saved") {
            const t = detailTarget()
            if (t) { walker.current = t; walker.follow(); if (k === "enter" && walker.isTi(t)) t.forceActiveFocus(); return }
            if (k === "enter") return
        }
        if (cur && menu.page === "" && k === "left" && inside(cur, pane)) {
            const row = walker.targets().find(it => it.wifiSel === menu.sel)
            if (row) { walker.current = row; walker.follow(); return }
        }
        // 19.10: в раскладке B детали справа ближе по геометрии, чем следующая строка, — ↓ уводил в кнопки деталей
        // и не давал дойти до других сетей. ↑↓ на строке сети — строго по списку сетей; за краем списка — как раньше.
        if ((k === "up" || k === "down") && (!walker.current || !walker.active || walker.current.wifiSel !== undefined)) {
            const rows = walker.targets().filter(it => it.wifiSel !== undefined)
                                         .sort((a, b) => walker.centerOf(a).y - walker.centerOf(b).y)
            if (rows.length) {
                let i = walker.active && walker.current ? rows.indexOf(walker.current) : rows.findIndex(it => it.wifiSel === menu.sel)
                const j = i < 0 ? 0 : i + (k === "down" ? 1 : -1)
                if (j >= 0 && j < rows.length) { walker.current = rows[j]; walker.active = true; walker.follow(); return }
            }
        }
        walker.move(k)
    }

    PillCard {
        id: pop
        name: "wifi"
        grow: false
        open: menu.open
        screen: Menus.screen
        marginRight: 160
        contentW: 640
        pad: 18                                // «Остров»: отступ карточки 18
        readonly property int boxH: 624
        fixedH: boxH + 120 + pad * 2
        contentH: (menu.confirmRadio ? boxH + radioAsk.implicitHeight + 8 : boxH) + pad * 2
        holdOpen: Network.busy !== ""          // идёт подключение — от ухода курсора не закрывать

        FocusScope {
            id: scope
            anchors.fill: parent
            focus: true
            Keys.onPressed: (e) => {
                const k = e.key
                if (k === Qt.Key_Escape) menu.key("esc")
                else if (k === Qt.Key_Up) menu.key("up")
                else if (k === Qt.Key_Down) menu.key("down")
                else if ((k === Qt.Key_Left || k === Qt.Key_Right) && scope.activeFocus) menu.key(k === Qt.Key_Left ? "left" : "right")
                else if ((k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) && scope.activeFocus) menu.key("enter")
                else return
                e.accepted = true
            }
            Connections { target: menu; function onOpenChanged() { walker.reset(); if (menu.open) scope.forceActiveFocus() } }

            ColumnLayout {
                id: frame
                anchors.fill: parent
                spacing: 12

                MenuHeader {
                    icon: Network.radio ? "󰖩" : "󰤭"; iconOn: Network.radio
                    title: "Wi-Fi"; subtitle: menu.subtitle(); error: menu.toastError && menu.toastText.length > 0
                    checked: Network.radio; toggleEnabled: Network.loaded; dry: Network.dry
                    onToggled: on => { if (on) { menu.confirmRadio = false; Network.setRadio(true) } else menu.confirmRadio = true }
                }
                // выключение — только после подтверждения: через Wi-Fi идут SSH и Tailscale
                Reveal {
                    id: radioAsk
                    shown: menu.confirmRadio
                    MConfirm {
                        text: "Выключить Wi-Fi? Пропадут SSH, Tailscale и управление с телефона."
                        yesText: "Выключить"
                        onYes: { menu.confirmRadio = false; Network.setRadio(false) }
                        onNo: menu.confirmRadio = false
                    }
                }

                RowLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    spacing: 16

                    // ================= слева: список =================
                    Flickable {
                        id: listFlick
                        Layout.preferredWidth: 262; Layout.fillHeight: true
                        contentHeight: list.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: contentHeight > height
                        ColumnLayout {
                            id: list
                            width: listFlick.width
                            spacing: 2

                            RowLayout { visible: Network.radio && !Network.loaded; spacing: 8; Layout.leftMargin: 6
                                        MSpinner {} MText { text: "Читаю список сетей…"; font.pixelSize: 11; color: Colors.fgDim } }
                            MHint { visible: Network.loaded && !Network.radio; text: "Wi-Fi выключен"; font.pixelSize: 12 }
                            MHint { visible: Network.loaded && Network.radio && !Network.cur; text: "Не подключено — выберите сеть"; font.pixelSize: 12 }

                            // текущая сеть
                            NetRow {
                                visible: Network.radio && Network.cur !== null
                                key: "cur"
                                showPct: true
                                ssid: Network.cur ? Network.cur.ssid : ""
                                signal: Network.cur ? Network.cur.signal : 0
                                sub: Network.cur ? ["Подключено", Network.cur.band].filter(x => x).join(" · ") : ""
                                connected: true
                            }

                            RowLayout {
                                visible: Network.radio
                                Layout.fillWidth: true; Layout.topMargin: 8; Layout.bottomMargin: 4; Layout.leftMargin: 2
                                MSection { text: "Доступные сети"; Layout.fillWidth: true; topPadding: 0 }
                                Rectangle {   // «Остров»: «обновить» — маленькая капсула справа от подписи раздела
                                    implicitHeight: 24; implicitWidth: rrow.implicitWidth + 18; radius: 12
                                    color: rm.containsMouse ? Colors.hover : Colors.isl2
                                    opacity: Network.scanning ? 0.7 : 1
                                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                                    scale: rm.pressed ? 0.95 : 1
                                    Behavior on scale { NumberAnimation { duration: Theme.fast } }
                                    RowLayout {
                                        id: rrow; anchors.centerIn: parent; spacing: 6
                                        MSpinner { visible: Network.scanning; width: 11; height: 11 }
                                        Glyph { visible: !Network.scanning; text: "󰑐"; font.pixelSize: 12; color: Colors.fgDim }
                                        MText { text: Network.scanning ? "ищу…" : "обновить"; font.pixelSize: 12; color: Colors.fgDim; Layout.minimumWidth: 52 }
                                    }
                                    MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; enabled: !Network.scanning; onClicked: Network.scan() }
                                }
                            }
                            MHint { visible: Network.radio && Network.loaded && Network.netModel.count === 0; text: "Других сетей рядом нет — нажмите «Обновить»" }
                            Repeater {
                                model: Network.radio ? Network.netModel : null
                                delegate: NetRow {
                                    required property var model
                                    required property int index
                                    key: model.ssid; ssid: model.ssid; signal: model.signal; secure: !!model.security
                                    sub: [model.saved ? "сохранена" : "", model.security ? (model.secText || "защищена") : "открытая"].filter(x => x).join(" · ")
                                    appearDelay: index * 40
                                }
                            }
                            MHint { visible: Network.radio && Network.hidden > 0; text: "+ скрытых сетей: " + Network.hidden; font.pixelSize: 11 }

                            // «Сохранённые сети»
                            Rectangle {
                                id: savedRow
                                visible: Network.loaded
                                Layout.fillWidth: true; Layout.topMargin: 8
                                implicitHeight: 52; radius: Theme.radius
                                readonly property bool on: menu.sel === "saved"
                                color: on ? Colors.alpha(Colors.acc, 0.16) : savedMouse.containsMouse ? Colors.isl2 : "transparent"
                                /* выбор — без затухания (29.10) */
                                scale: savedMouse.pressed ? 0.985 : 1
                                Behavior on scale { NumberAnimation { duration: Theme.fast } }
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 9; anchors.rightMargin: 10; spacing: 12
                                    Rectangle {
                                        implicitWidth: 34; implicitHeight: 34; radius: 12
                                        color: savedRow.on ? Colors.acc : Colors.isl2
                                        /* выбор — без затухания (29.10) */
                                        Glyph { anchors.centerIn: parent; text: "󰆓"; font.pixelSize: 16; color: savedRow.on ? Colors.onAcc : Colors.fg }
                                    }
                                    MText { Layout.fillWidth: true; text: "Сохранённые сети"; font.weight: Font.Medium }
                                    MText { text: Network.profilesCount >= 0 ? String(Network.profilesCount) : (Network.saved ? String(Network.saved) : "")
                                            font.pixelSize: 12; font.features: ({ "tnum": 1 }); color: Colors.fgDim }
                                    Glyph { text: "󰅂"; color: Colors.fgDim; font.pixelSize: 15 }
                                }
                                MouseArea { id: savedMouse; property string wifiSel: "saved"; anchors.fill: parent; hoverEnabled: true; onClicked: menu.openSaved() }
                            }
                            MText {
                                visible: Network.loaded
                                text: "󰒓  Расширенные настройки…"; font.pixelSize: 12; color: Colors.fgDim
                                Layout.alignment: Qt.AlignHCenter; topPadding: 6; bottomPadding: 4
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: { Quickshell.execDetached(["nm-connection-editor"]); Menus.close("wifi") } }
                            }
                        }
                    }

                    // ================= справа: детали =================
                    Item {
                        id: pane
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true

                        // --- текущая сеть ---
                        Flickable {
                            id: curFlick
                            anchors.fill: parent
                            readonly property bool shown: menu.page === "" && menu.sel === "cur" && Network.radio && Network.cur !== null
                            visible: opacity > 0; opacity: shown ? 1 : 0
                            property real slide: shown ? 0 : 16
                            transform: Translate { x: curFlick.slide }
                            Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                            Behavior on slide { NumberAnimation { duration: Theme.normal; easing.type: Theme.easeSoft } }
                            contentHeight: curCol.implicitHeight
                            clip: true; boundsBehavior: Flickable.StopAtBounds; interactive: contentHeight > height
                            readonly property var det: Network.details
                            readonly property var cur: Network.cur || ({ ssid: "", signal: 0, band: "" })
                            ColumnLayout {
                                id: curCol
                                width: curFlick.width
                                spacing: 10
                                NetHead {
                                    on: true; icon: "󰖩"; level: curFlick.cur.signal; title: curFlick.cur.ssid
                                    sub: ["Подключено", curFlick.cur.band, curFlick.cur.signal ? curFlick.cur.signal + "%" : ""].filter(x => x).join(" · ")
                                }
                                RowLayout { visible: !curFlick.det; spacing: 8; MSpinner {} MText { text: "Читаю параметры…"; font.pixelSize: 12; color: Colors.fgDim } }
                                ISection { visible: !!curFlick.det; text: "Параметры" }
                                IBox {
                                    visible: !!curFlick.det
                                    spacing: 5
                                InfoRow { key: "Диапазон"; value: curFlick.det && curFlick.det.band ? curFlick.det.band + " · канал " + curFlick.det.chan : "" }
                                InfoRow { key: "Частота"; value: curFlick.det && curFlick.det.freq ? curFlick.det.freq + " МГц" : "" }
                                InfoRow { key: "Защита"; value: curFlick.det ? curFlick.det.security : "" }
                                InfoRow { key: "Адрес / маска"; value: curFlick.det ? curFlick.det.ip4 : ""; copy: true }
                                InfoRow { key: "Шлюз"; value: curFlick.det ? curFlick.det.gw : ""; copy: true }
                                InfoRow { key: "DNS"; value: curFlick.det ? curFlick.det.dns : ""; copy: true }
                                InfoRow { key: "Скорость"; value: curFlick.det ? curFlick.det.rate : "" }
                                InfoRow { key: "MAC"; value: curFlick.det ? curFlick.det.mac : ""; copy: true }
                                InfoRow { key: "Tailscale"; value: curFlick.det ? (curFlick.det.ts.state ? "󰄬 подключён · " + curFlick.det.ts.ip : "не подключён") : "" }
                                InfoRow { key: "Пароль"; value: menu.shownPassword; copy: menu.shownPassword.indexOf(" ") < 0 }
                                MText {
                                    visible: curFlick.det && !menu.shownPassword; text: "󰈈  Показать пароль"; font.pixelSize: 12; color: Colors.acc
                                    Layout.alignment: Qt.AlignHCenter; topPadding: 2; bottomPadding: 0
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Network.showPassword() }
                                }
                                }
                                ISection { visible: !!curFlick.det; text: "Подключение" }
                                OptRow {
                                    visible: !!curFlick.det; icon: "󰁪"; text: "Подключаться автоматически"
                                    checked: curFlick.det ? curFlick.det.conf.autoconnect : false; onToggled: on => Network.modify("autoconnect", on)
                                }
                                OptRow {
                                    visible: !!curFlick.det; icon: "󰾆"; text: "Лимитное подключение"
                                    checked: curFlick.det ? curFlick.det.conf.metered : false; onToggled: on => Network.modify("metered", on)
                                }
                                MHint { visible: !!curFlick.det; text: "Лимитное — система бережёт трафик: без фоновых обновлений и больших загрузок." }
                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8; Layout.topMargin: 2
                                    MButton { Layout.fillWidth: true; text: "Отключиться"; onClicked: menu.confirmKind = menu.confirmKind === "down" ? "" : "down" }
                                    MButton { Layout.fillWidth: true; text: "Забыть сеть"; kind: "danger"; onClicked: menu.confirmKind = menu.confirmKind === "forget" ? "" : "forget" }
                                }
                                Reveal {
                                    shown: menu.confirmKind !== ""
                                    MConfirm {
                                        text: menu.confirmKind === "forget"
                                              ? "Забыть «" + curFlick.cur.ssid + "»? Сохранённый пароль удалится, автоподключения больше не будет."
                                              : "Отключиться от «" + curFlick.cur.ssid + "»? Пропадут SSH, Tailscale и управление с телефона."
                                        yesText: menu.confirmKind === "forget" ? "Забыть" : "Отключиться"
                                        onYes: { if (menu.confirmKind === "forget") Network.forget(); else Network.disconnect(); menu.confirmKind = "" }
                                        onNo: menu.confirmKind = ""
                                    }
                                }
                                Item { implicitHeight: 4 }
                            }
                        }

                        // --- другая сеть: сигнал, защита, подключение ---
                        Flickable {
                            id: netFlick
                            anchors.fill: parent
                            readonly property var net: { Network.netModel.count; return menu.page === "" && menu.sel !== "cur" && menu.sel !== "saved" ? menu.netBy(menu.sel) : null }
                            readonly property bool shown: net !== null && Network.radio
                            readonly property bool isBusy: net !== null && Network.busy === net.ssid
                            readonly property bool askPw: net !== null && menu.pwSsid === net.ssid
                            visible: opacity > 0; opacity: shown ? 1 : 0
                            property real slide: shown ? 0 : 16
                            transform: Translate { x: netFlick.slide }
                            Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                            Behavior on slide { NumberAnimation { duration: Theme.normal; easing.type: Theme.easeSoft } }
                            contentHeight: netCol.implicitHeight
                            clip: true; boundsBehavior: Flickable.StopAtBounds; interactive: contentHeight > height
                            onAskPwChanged: if (askPw) pwField.forceActiveFocus(); else { pwField.focus = false; pwField.text = "" }
                            function submit() {
                                const pw = pwField.text
                                if (pw.length < 8 || pw.length > 63) { menu.pwError = "Пароль WPA — от 8 до 63 символов"; return }
                                menu.pwError = ""
                                Network.connectTo(net.ssid, pw)
                            }
                            Connections { target: menu; function onPasswordRequested() { if (netFlick.askPw) { pwField.text = menu.pwText; netFlick.submit() } } }
                            ColumnLayout {
                                id: netCol
                                width: netFlick.width
                                spacing: 10
                                NetHead {
                                    on: false; icon: netFlick.net && netFlick.net.security ? "󰌾" : "󰖩"
                                    level: netFlick.net ? netFlick.net.signal : 0; title: netFlick.net ? netFlick.net.ssid : ""
                                    sub: netFlick.net ? [netFlick.net.signal + "%", netFlick.net.band].filter(x => x).join(" · ") : ""
                                }
                                IBox {
                                spacing: 5
                                InfoRow { key: "Сигнал"; value: netFlick.net ? netFlick.net.signal + "%" : "" }
                                InfoRow { key: "Диапазон"; value: netFlick.net ? netFlick.net.band || "" : "" }
                                InfoRow { key: "Защита"; value: netFlick.net ? (netFlick.net.security ? (netFlick.net.secText || netFlick.net.security) : "открытая сеть") : "" }
                                InfoRow { key: "Профиль"; value: netFlick.net && netFlick.net.saved ? "сохранена — подключится без пароля" : "" }
                                }
                                // пароль (сеть с защитой, ещё не сохранённая)
                                Reveal {
                                    shown: netFlick.askPw
                                    spacing: 6
                                    Rectangle {
                                        Layout.fillWidth: true; implicitHeight: 40; radius: 20   // «Остров»: поле-капсула
                                        color: Colors.isl2
                                        border.width: menu.pwError || pwField.activeFocus ? 1.5 : 0; border.color: menu.pwError ? Colors.bad : Colors.acc
                                        Behavior on border.color { ColorAnimation { duration: Theme.fast } }
                                        TextInput {
                                            id: pwField
                                            anchors { left: parent.left; right: eye.left; verticalCenter: parent.verticalCenter; leftMargin: 16; rightMargin: 6 }
                                            font.family: Theme.fontUi; font.pixelSize: Theme.fontSize; color: Colors.fg
                                            echoMode: eye.shown ? TextInput.Normal : TextInput.Password
                                            passwordCharacter: "•"
                                            selectByMouse: true; selectionColor: Colors.alpha(Colors.acc, 0.35); selectedTextColor: Colors.fg
                                            clip: true
                                            enabled: !netFlick.isBusy
                                            onAccepted: netFlick.submit()
                                            Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; visible: !pwField.text && !pwField.activeFocus
                                                   text: "Пароль сети"; font: pwField.font; color: Colors.fgDim }
                                        }
                                        Glyph {
                                            id: eye; property bool shown: false
                                            anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                                            text: shown ? "󰈈" : "󰈉"; font.pixelSize: 15; color: Colors.fgDim
                                            MouseArea { anchors.fill: parent; onClicked: eye.shown = !eye.shown }
                                        }
                                    }
                                    MText { visible: menu.pwError.length > 0; text: menu.pwError; color: Colors.bad; font.pixelSize: 12; Layout.leftMargin: 6 }
                                }
                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    MSpinner { visible: netFlick.isBusy }
                                    MText { visible: netFlick.isBusy; text: "Подключаюсь…"; font.pixelSize: 12; color: Colors.fgDim; Layout.fillWidth: true }
                                    MText { visible: netFlick.net !== null && menu.doneSsid === netFlick.net.ssid; text: "󰄬  Подключено"; color: Colors.ok; font.pixelSize: 12; Layout.fillWidth: true }
                                    Item { Layout.fillWidth: true; visible: !netFlick.isBusy }
                                    MButton {
                                        id: connectBtn
                                        text: "Подключиться"; kind: "primary"; enabled: !netFlick.isBusy && Network.busy === ""
                                        onClicked: { if (netFlick.askPw) netFlick.submit(); else if (netFlick.net) menu.clickNet(netFlick.net) }
                                    }
                                }
                            }
                        }

                        // --- Сохранённые сети и профиль (общие страницы) ---
                        Item {
                            anchors.fill: parent
                            visible: menu.page !== ""
                            RowLayout {
                                id: subHead
                                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                                spacing: 10
                                Rectangle {   // назад — круглая кнопка isl2
                                    Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 16
                                    color: backArea.containsMouse ? Colors.hover : Colors.isl2
                                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                                    scale: backArea.pressed ? 0.94 : 1
                                    Behavior on scale { NumberAnimation { duration: Theme.fast } }
                                    Glyph { anchors.centerIn: parent; text: "󰅁"; font.pixelSize: 17 }
                                    MouseArea { id: backArea; anchors.fill: parent; hoverEnabled: true; onClicked: menu.back() }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 0
                                    MText { Layout.fillWidth: true; text: menu.page === "saved" ? "Сохранённые сети" : "Сеть"; font.pixelSize: 15; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                    MText {
                                        Layout.fillWidth: true; font.pixelSize: 12; elide: Text.ElideRight
                                        text: menu.page === "saved" ? (Network.profilesLoaded ? Network.profilesText : "…")
                                            : (Network.profile && Network.profile.uuid === menu.profUuid ? Network.profile.ssid : "…")
                                        color: Colors.fgDim
                                    }
                                }
                            }
                            Item {
                                anchors.left: parent.left; anchors.right: parent.right; anchors.top: subHead.bottom; anchors.bottom: parent.bottom; anchors.topMargin: 12
                                clip: true
                                SavedPage { id: savedPage; anchors.fill: parent; owner: menu }
                                ProfilePage { id: profPage; anchors.fill: parent; owner: menu }
                            }
                        }

                        MHint {
                            anchors.centerIn: parent
                            visible: menu.page === "" && !curFlick.shown && !netFlick.shown
                            text: Network.radio ? "Выберите сеть слева" : "Wi-Fi выключен — включите переключателем вверху"
                        }
                    }
                }

                // ---- подсказки клавиш («Остров»: капсулы по центру) ----
                MFooter {
                    hints: [["↑↓", "сеть"], ["→←", "детали / список"], ["Enter", "нажать"], ["Esc", menu.page === "" ? "закрыть" : "назад"]]
                }
            }
            KeyWalker {
                id: walker; anchors.fill: parent; root: frame
                // ↑↓ по списку — детали справа меняются сразу
                onCurrentChanged: if (current && current.wifiSel !== undefined && current.wifiSel !== "saved") menu.select(current.wifiSel)
            }
        }
    }

    // «Остров»: шапка подробностей — значок в квадрате 34 (акцент у текущей), название, подпись, полоски сигнала — в IBox
    component NetHead: IBox {
        id: nh
        property bool on: false
        property string icon: "󰖩"
        property int level: 0
        property string title: ""
        property string sub: ""
        RowLayout {
            Layout.fillWidth: true; spacing: 12
            Rectangle {
                implicitWidth: 34; implicitHeight: 34; radius: 12
                color: nh.on ? Colors.acc : Colors.hover
                /* выбор — без затухания (29.10) */
                Glyph { anchors.centerIn: parent; text: nh.icon; font.pixelSize: 16; color: nh.on ? Colors.onAcc : Colors.fg }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                MText { Layout.fillWidth: true; text: nh.title; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight }
                MText { Layout.fillWidth: true; font.pixelSize: 12; color: Colors.fgDim; text: nh.sub; elide: Text.ElideRight }
            }
            SignalBars { level: nh.level }
        }
    }
    // «Остров»: строка-переключатель (значок в квадрате, подпись, переключатель справа) — как .row с .tg
    component OptRow: RowLayout {
        id: orow
        property string icon: ""
        property string text: ""
        property bool checked: false
        signal toggled(bool on)
        Layout.fillWidth: true; Layout.leftMargin: 4; Layout.rightMargin: 2
        spacing: 12
        Rectangle {
            implicitWidth: 32; implicitHeight: 32; radius: 11; color: Colors.isl2
            Glyph { anchors.centerIn: parent; text: orow.icon; font.pixelSize: 15 }
        }
        MText { Layout.fillWidth: true; text: orow.text; font.weight: Font.Medium; elide: Text.ElideRight }
        MToggle { checked: orow.checked; onToggled: on => orow.toggled(on) }
    }

    // строка списка — «Остров»: вид IRow, значок в квадрате 34 (выбранная/текущая — акцент), справа полоски сигнала;
    // появление каскадом (opacity + y 8 px, OutCubic 280 мс)
    component NetRow: Rectangle {
        id: nr
        property string key: ""
        property string ssid: ""
        property int signal: 0
        property string sub: ""
        property bool connected: false
        property bool secure: false
        property bool showPct: false         // процент сигнала (у текущей сети)
        property int appearDelay: 0
        readonly property bool on: menu.page === "" && menu.sel === key
        readonly property bool isBusy: Network.busy === ssid && ssid !== ""
        readonly property bool done: menu.doneSsid === ssid && ssid !== ""
        Layout.fillWidth: true
        implicitWidth: parent ? parent.width : 0     // 19.10: без этого строка бывала нулевой ширины — стрелки и мышь её не видели
        implicitHeight: 52
        radius: Theme.radius
        color: on ? Colors.alpha(Colors.acc, 0.16) : nrMouse.containsMouse ? Colors.isl2 : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        scale: nrMouse.pressed ? 0.985 : 1
        Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
        opacity: 0
        property real dy: 8
        transform: Translate { y: nr.dy }
        Component.onCompleted: appear.start()
        SequentialAnimation {
            id: appear
            PauseAnimation { duration: Math.min(nr.appearDelay, 480) }
            ParallelAnimation {
                NumberAnimation { target: nr; property: "opacity"; to: 1; duration: 280; easing.type: Easing.OutCubic }
                NumberAnimation { target: nr; property: "dy"; to: 0; duration: 280; easing.type: Easing.OutCubic }
            }
        }
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 9; anchors.rightMargin: 10; spacing: 12
            Rectangle {
                implicitWidth: 34; implicitHeight: 34; radius: 12
                color: nr.on || nr.connected ? Colors.acc : Colors.isl2
                Behavior on color { ColorAnimation { duration: Theme.normal } }
                Glyph { anchors.centerIn: parent; text: nr.secure ? "󰌾" : "󰖩"; font.pixelSize: 16
                        color: nr.on || nr.connected ? Colors.onAcc : Colors.fg }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                MText { Layout.fillWidth: true; text: nr.ssid; elide: Text.ElideRight; font.weight: Font.Medium }
                MText { Layout.fillWidth: true; text: nr.sub; elide: Text.ElideRight; font.pixelSize: 12; color: Colors.fgDim; visible: text.length > 0 }
            }
            Item {
                Layout.preferredWidth: nr.showPct ? 50 : 22; Layout.fillHeight: true
                RowLayout {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                    visible: !nr.isBusy && !nr.done
                    MText { visible: nr.showPct; text: nr.signal + "%"; font.pixelSize: 12; font.features: ({ "tnum": 1 }); color: Colors.fgDim }
                    SignalBars { level: nr.signal }
                }
                MSpinner { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; visible: nr.isBusy }
                Glyph { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: "󰄬"; color: Colors.ok; visible: nr.done; font.pixelSize: 15 }
            }
        }
        // клик — выбрать (детали справа); двойной клик — как прежний клик: подключиться / ввод пароля
        MouseArea {
            id: nrMouse
            property string wifiSel: nr.key
            anchors.fill: parent; hoverEnabled: true
            onClicked: menu.select(nr.key)
            onDoubleClicked: { if (nr.key !== "cur") { const m = menu.netBy(nr.ssid); if (m) menu.clickNet(m) } }
        }
    }
}
