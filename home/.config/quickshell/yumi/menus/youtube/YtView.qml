import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs
import qs.components

// YumiTube: содержимое окна — боковая панель (складывается до значков на узком окне), шапка (на узком окне поиск
// уходит на вторую строку), сетка карточек, страница просмотра со встроенным плеером, мини-плеер в углу.
// Клавиши: / или Ctrl+F — поиск, F5 — обновить; плеер: Пробел/K — пауза, ←→ ±5 с, J/L ±10 с, ↑↓ громкость,
// F — во весь экран, M — без звука, N — следующее, Esc — выйти из «кино» / назад.
Item {
    id: view
    property var app

    readonly property bool compact: width < 1000          // боковая панель — только значки
    readonly property bool wideHead: main.width >= 900     // шапка в одну строку
    readonly property bool hasPlayer: !!app.current
    readonly property bool typing: search.input.activeFocus || addField.input.activeFocus || takeoutField.input.activeFocus

    function plural(n, one, few, many) {
        const a = n % 10, b = n % 100
        return n + " " + (a === 1 && b !== 11 ? one : a >= 2 && a <= 4 && (b < 12 || b > 14) ? few : many)
    }
    readonly property var titles: ({ rec: "Рекомендации", feed: "Подписки", search: "Поиск", channel: "Канал",
                                     later: "Смотреть позже", history: "История", subs: "Мои каналы", watch: "Просмотр" })

    // ---- клавиши ----
    Shortcut { sequences: ["Ctrl+F", "/"]; onActivated: { if (view.app.playerMode === "theater") view.app.toggleTheater(); search.input.forceActiveFocus(); search.input.selectAll() } }
    Shortcut { sequences: ["F5", "Ctrl+R"]; onActivated: view.app.refresh() }
    Shortcut {
        sequence: "Esc"
        onActivated: {
            if (view.typing) { search.input.focus = false; addField.input.focus = false; takeoutField.input.focus = false }
            else if (view.app.playerMode === "theater") view.app.toggleTheater()
            else if (view.app.page === "watch") view.app.back()
        }
    }
    Shortcut { sequences: ["Space", "K"]; enabled: view.hasPlayer && !view.typing; onActivated: player.togglePause() }
    Shortcut { sequence: "Left"; enabled: view.hasPlayer && !view.typing; onActivated: player.seekBy(-5) }
    Shortcut { sequence: "Right"; enabled: view.hasPlayer && !view.typing; onActivated: player.seekBy(5) }
    Shortcut { sequence: "J"; enabled: view.hasPlayer && !view.typing; onActivated: player.seekBy(-10) }
    Shortcut { sequence: "L"; enabled: view.hasPlayer && !view.typing; onActivated: player.seekBy(10) }
    Shortcut { sequence: "Up"; enabled: view.hasPlayer && !view.typing && view.app.page === "watch"; onActivated: player.setVol(player.mpv.volume + 5) }
    Shortcut { sequence: "Down"; enabled: view.hasPlayer && !view.typing && view.app.page === "watch"; onActivated: player.setVol(player.mpv.volume - 5) }
    Shortcut { sequence: "F"; enabled: view.hasPlayer && !view.typing; onActivated: view.app.toggleTheater() }
    Shortcut { sequence: "M"; enabled: view.hasPlayer && !view.typing; onActivated: { player.mpv.muted = !player.mpv.muted; player.osd(player.mpv.muted ? "Без звука" : "Звук") } }
    Shortcut { sequence: "N"; enabled: view.hasPlayer && !view.typing; onActivated: view.app.playNext() }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ================= боковая панель =================
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: view.compact ? 68 : 232
            Behavior on Layout.preferredWidth { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
            color: Colors.mix(Colors.isl, Colors.deep, 0.5)
            Behavior on color { ColorAnimation { duration: Theme.normal } }
            clip: true

            ColumnLayout {
                anchors.fill: parent; anchors.margins: view.compact ? 10 : 14; anchors.topMargin: 18
                spacing: 4

                RowLayout {   // логотип
                    Layout.leftMargin: view.compact ? 4 : 6; Layout.bottomMargin: 14
                    spacing: 10
                    Rectangle {
                        implicitWidth: 40; implicitHeight: 40; radius: 14; color: Colors.acc
                        Behavior on color { ColorAnimation { duration: Theme.normal } }
                        Glyph { anchors.centerIn: parent; text: String.fromCodePoint(0xf05c3); font.pixelSize: 21; color: Colors.onAcc }
                    }
                    ColumnLayout {
                        visible: !view.compact
                        spacing: 0
                        Text { text: "YumiTube"; font.family: Theme.fontUi; font.pixelSize: 16; font.weight: Font.DemiBold; color: Colors.fg }
                        Text { text: view.app.qLabel(view.app.settings.quality) + " · AV1"; font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim }
                    }
                }

                NavItem { compact: view.compact; visible: !!view.app.settings.account; icon: String.fromCodePoint(0xf0238); text: "Рекомендации"
                          sel: view.app.page === "rec"; onClicked: view.app.go("rec") }
                NavItem { compact: view.compact; icon: String.fromCodePoint(0xf02dc); text: "Подписки"; sel: view.app.page === "feed"; onClicked: view.app.go("feed") }
                NavItem { compact: view.compact; icon: String.fromCodePoint(0xf0349); text: "Поиск"; sel: view.app.page === "search"
                          onClicked: view.app.query ? view.app.go("search", view.app.query) : search.input.forceActiveFocus() }
                NavItem { compact: view.compact; icon: String.fromCodePoint(0xf0150); text: "Смотреть позже"; sel: view.app.page === "later"
                          badge: { const n = Object.keys(view.app.laterIds).length; return n ? String(n) : "" }
                          onClicked: view.app.go("later") }
                NavItem { compact: view.compact; icon: String.fromCodePoint(0xf02da); text: "История"; sel: view.app.page === "history"; onClicked: view.app.go("history") }
                NavItem { compact: view.compact; icon: String.fromCodePoint(0xf0849); text: "Мои каналы"; sel: view.app.page === "subs"
                          badge: view.app.subs.length ? String(view.app.subs.length) : ""; onClicked: view.app.go("subs") }
                NavItem { compact: view.compact; visible: view.hasPlayer; icon: String.fromCodePoint(0xf040a); text: "Сейчас играет"
                          sel: view.app.page === "watch"; onClicked: view.app.go("watch") }

                ISection { text: "Каналы"; Layout.topMargin: 16; Layout.leftMargin: 8; visible: view.app.subs.length > 0 && !view.compact }
                ListView {
                    visible: !view.compact
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true; spacing: 2
                    model: view.app.subs
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: NavItem {
                        required property var modelData
                        width: ListView.view.width
                        implicitHeight: 34
                        text: modelData.name
                        sel: view.app.page === "channel" && view.app.chan && view.app.chan.id === modelData.id
                        onClicked: view.app.go("channel", modelData.id)
                    }
                }
                Item { Layout.fillHeight: true; visible: view.compact }
            }
        }

        // ================= основная часть =================
        ColumnLayout {
            id: main
            Layout.fillWidth: true; Layout.fillHeight: true
            spacing: 0

            // ---- шапка: широкое окно — [заголовок][поиск][кнопки]; узкое — [заголовок][кнопки] / [поиск] ----
            GridLayout {
                id: head
                Layout.fillWidth: true
                Layout.margins: 18; Layout.bottomMargin: 12
                columnSpacing: 12; rowSpacing: 12
                columns: view.wideHead ? 3 : 2

                CardHead {
                    Layout.row: 0; Layout.column: 0
                    Layout.fillWidth: !view.wideHead
                    Layout.preferredWidth: view.wideHead ? 210 : -1
                    Layout.minimumWidth: 0
                    back: view.app.page === "watch"
                    onBackClicked: view.app.back()
                    title: view.app.page === "channel" && view.app.chan && view.app.chan.name ? view.app.chan.name
                         : view.app.page === "search" && view.app.query ? "«" + view.app.query + "»"
                         : view.titles[view.app.page] || ""
                    status: view.app.page === "watch" ? (view.app.current ? view.app.current.channel || "" : "")
                          : view.app.loading ? "Загрузка…"
                          : view.app.error ? view.app.error
                          : view.app.page === "subs" ? view.plural(view.app.subs.length, "канал", "канала", "каналов")
                          : view.app.shown.length + " видео"
                    statusColor: view.app.error && view.app.page !== "watch" ? Colors.bad : Colors.fgDim
                }
                IField {
                    id: search
                    Layout.row: view.wideHead ? 0 : 1; Layout.column: view.wideHead ? 1 : 0
                    Layout.columnSpan: view.wideHead ? 1 : 2
                    Layout.fillWidth: true
                    Layout.minimumWidth: 160
                    placeholder: "Поиск на YouTube"
                    onAccepted: if (text.trim()) { view.app.go("search", text.trim()); input.focus = false }
                    Rectangle {   // подсказка клавиши «/»
                        anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                        visible: !search.input.activeFocus && search.text.length === 0
                        width: 24; height: 22; radius: 7; color: Colors.alpha(Colors.fg, 0.08)
                        Text { anchors.centerIn: parent; text: "/"; font.family: Theme.fontMono; font.pixelSize: 12; color: Colors.fgDim }
                    }
                }
                RowLayout {
                    Layout.row: 0; Layout.column: view.wideHead ? 2 : 1
                    Layout.alignment: Qt.AlignRight
                    spacing: 8
                    ISeg {
                        Layout.fillWidth: false
                        Layout.preferredWidth: 216
                        model: view.app.qualities.map(q => view.app.qLabel(q))
                        current: view.app.qualities.indexOf(view.app.settings.quality)
                        onPicked: i => view.app.setSetting("quality", view.app.qualities[i])
                    }
                    IChip {
                        text: "Shorts"; on: view.app.settings.shorts
                        onClicked: view.app.setSetting("shorts", !view.app.settings.shorts)
                    }
                    IButton {
                        icon: String.fromCodePoint(0xf0450)
                        onClicked: view.app.refresh()
                        RotationAnimator on rotation { running: view.app.loading; from: 0; to: 360; duration: 900; loops: Animation.Infinite
                                                       onRunningChanged: if (!running) parent.rotation = 0 }
                    }
                }
            }

            // ---- шапка канала ----
            RowLayout {
                visible: view.app.page === "channel" && !!view.app.chan
                Layout.fillWidth: true; Layout.leftMargin: 18; Layout.rightMargin: 18; Layout.bottomMargin: 6
                spacing: 10
                IButton {
                    primary: !(view.app.chan && view.app.chan.subscribed)
                    icon: view.app.chan && view.app.chan.subscribed ? String.fromCodePoint(0xf012c) : String.fromCodePoint(0xf0415)
                    text: view.app.chan && view.app.chan.subscribed ? "Вы подписаны" : "Подписаться"
                    onClicked: view.app.chan.subscribed ? view.app.unsubscribe(view.app.chan.id) : view.app.subscribe(view.app.chan.id, view.app.chan.name)
                }
                Item { Layout.fillWidth: true }
            }

            // ================= страница просмотра =================
            Item {
                id: watchPage
                visible: view.app.page === "watch"
                Layout.fillWidth: true; Layout.fillHeight: true
                readonly property bool side: width >= 1050           // «Далее» справа
                readonly property real colW: side ? width - 36 - 360 - 20 : width - 36
                readonly property real vidH: Math.min(colW * 9 / 16, height * (side ? 0.78 : 0.58))
                readonly property real vidW: vidH * 16 / 9

                Item {   // место под плеер (сам плеер — поверх всего, см. ниже)
                    id: slot
                    x: 18 + (watchPage.colW - watchPage.vidW) / 2; y: 0
                    width: watchPage.vidW; height: watchPage.vidH
                }
                WatchInfo {
                    id: info
                    app: view.app
                    x: watchPage.side ? 18 : slot.x; y: slot.height + 16
                    width: watchPage.side ? watchPage.colW : slot.width
                }
                ColumnLayout {   // «Далее»
                    x: watchPage.side ? watchPage.width - 18 - 360 : slot.x
                    y: watchPage.side ? 0 : info.y + info.height + 18
                    width: watchPage.side ? 360 : slot.width
                    height: watchPage.height - y
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        ISection { text: "Далее" + (view.app.queue.length ? " · " + view.app.queue.length : ""); Layout.topMargin: 0 }
                        IChip { text: "Автовоспроизведение"; on: view.app.settings.autoplay; onClicked: view.app.setSetting("autoplay", !view.app.settings.autoplay) }
                    }
                    ListView {
                        Layout.fillWidth: true; Layout.fillHeight: watchPage.side
                        Layout.preferredHeight: watchPage.side ? -1 : 100
                        clip: true; spacing: 6
                        boundsBehavior: Flickable.StopAtBounds
                        orientation: watchPage.side ? ListView.Vertical : ListView.Horizontal
                        model: view.app.queue
                        delegate: QueueItem {
                            required property var modelData
                            required property int index
                            v: modelData
                            width: watchPage.side ? ListView.view.width : 360
                            height: 96
                        }
                    }
                }
            }

            // ================= «Мои каналы» =================
            ColumnLayout {
                visible: view.app.page === "subs"
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.leftMargin: 18; Layout.rightMargin: 18
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true; Layout.maximumWidth: 720
                    spacing: 10
                    IField {
                        id: addField
                        icon: String.fromCodePoint(0xf0415)
                        placeholder: "Ссылка на канал, @имя или ID канала"
                        onAccepted: addBtn.clicked()
                    }
                    IButton {
                        id: addBtn; primary: true; text: "Подписаться"
                        enabledLook: addField.text.trim().length > 0
                        onClicked: if (addField.text.trim()) { const t = addField.text.trim(); addField.text = ""; view.app.addChannel(t) }
                    }
                }
                ISection { text: "Аккаунт YouTube"; Layout.topMargin: 10 }
                RowLayout {
                    Layout.fillWidth: true; Layout.maximumWidth: 720
                    spacing: 10
                    Text {
                        Layout.fillWidth: true; wrapMode: Text.Wrap
                        font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim
                        text: view.app.settings.account
                            ? "Подключён через вход в Chromium — рекомендации живые. «Импорт» подтянет новую историю, «Позже» и каналы."
                            : "Вход берётся из Chromium (там должен быть открыт YouTube под твоим аккаунтом). Пароль сюда не нужен."
                    }
                    IButton {
                        visible: !view.app.settings.account; primary: true; enabledLook: !view.app.busy
                        icon: String.fromCodePoint(0xf0004); text: "Подключить"
                        onClicked: view.app.connectAccount("chromium+gnomekeyring")
                    }
                    IButton {
                        visible: !!view.app.settings.account; enabledLook: !view.app.busy
                        icon: String.fromCodePoint(0xf0450); text: "Импорт"
                        onClicked: view.app.connectAccount(view.app.settings.account)
                    }
                    IButton {
                        visible: !!view.app.settings.account; danger: true; text: "Отключить"
                        onClicked: view.app.disconnectAccount()
                    }
                }
                ISection { text: "Google Takeout"; Layout.topMargin: 6 }
                RowLayout {
                    Layout.fillWidth: true; Layout.maximumWidth: 720
                    spacing: 10
                    IField {
                        id: takeoutField
                        icon: String.fromCodePoint(0xf024b)
                        placeholder: "Папка Takeout или файл"
                        text: "~/Downloads/Takeout"
                        onAccepted: takeoutBtn.clicked()
                    }
                    IButton {
                        id: takeoutBtn; text: "Импорт"; enabledLook: !view.app.busy && takeoutField.text.trim().length > 0
                        onClicked: view.app.importTakeout(takeoutField.text.trim())
                    }
                }
                ISection { text: "Каналы"; Layout.topMargin: 6 }
                ListView {
                    Layout.fillWidth: true; Layout.fillHeight: true; Layout.maximumWidth: 720
                    clip: true; spacing: 2
                    model: view.app.page === "subs" ? view.app.subs : []
                    delegate: IRow {
                        required property var modelData
                        width: ListView.view.width
                        icon: String.fromCodePoint(0xf05c3)
                        title: modelData.name
                        sub: modelData.id
                        onClicked: view.app.go("channel", modelData.id)
                        IButton { icon: String.fromCodePoint(0xf01b4); danger: true; implicitHeight: 32; onClicked: view.app.unsubscribe(modelData.id) }
                    }
                }
            }

            // ================= сетка видео =================
            Item {
                visible: view.app.page !== "subs" && view.app.page !== "watch"
                Layout.fillWidth: true; Layout.fillHeight: true

                GridView {
                    id: grid
                    anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 6
                    clip: true
                    readonly property int cols: Math.max(1, Math.floor((width - 12) / 270))
                    cellWidth: Math.floor((width - 12) / cols)
                    cellHeight: (cellWidth - 18) * 9 / 16 + 92
                    model: view.app.shown
                    boundsBehavior: Flickable.StopAtBounds
                    flickDeceleration: 4000
                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: grid.cellWidth; height: grid.cellHeight
                        VideoCard {
                            anchors.fill: parent; anchors.rightMargin: 18; anchors.bottomMargin: 14
                            app: view.app; v: parent.modelData; index: parent.index
                            onChannelClicked: id => view.app.go("channel", id)
                        }
                    }
                    footer: Item { width: 1; height: view.app.playerMode === "mini" ? 240 : 12 }
                }

                // пустые состояния
                ColumnLayout {
                    anchors.centerIn: parent
                    width: Math.min(420, parent.width - 40)
                    visible: !view.app.loading && view.app.shown.length === 0
                    spacing: 10
                    Glyph {
                        Layout.alignment: Qt.AlignHCenter
                        text: view.app.error ? String.fromCodePoint(0xf0028) : String.fromCodePoint(0xf05c3)
                        font.pixelSize: 44; color: view.app.error ? Colors.bad : Colors.alpha(Colors.fg, 0.25)
                    }
                    Text {
                        Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                        font.family: Theme.fontUi; font.pixelSize: 14; font.weight: Font.Medium; color: Colors.fg
                        text: view.app.error ? "Не получилось загрузить"
                            : view.app.page === "feed" && view.app.subs.length === 0 ? "Подписок пока нет"
                            : view.app.page === "later" ? "Список «Позже» пуст"
                            : view.app.page === "history" ? "История пуста"
                            : view.app.page === "search" && !view.app.query ? "Что посмотрим?"
                            : view.app.page === "rec" ? "Рекомендаций нет"
                            : "Ничего не нашлось"
                    }
                    Text {
                        Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                        font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim
                        text: view.app.error ? view.app.error
                            : view.app.page === "feed" && view.app.subs.length === 0 ? "Найди канал и нажми «Подписаться», или добавь его в «Мои каналы»"
                            : view.app.page === "later" ? "Наведи на видео и нажми значок часов (или средняя кнопка мыши)"
                            : ""
                        visible: text.length > 0
                    }
                }
                // скелет загрузки
                Grid {
                    visible: view.app.loading && view.app.shown.length === 0
                    x: 18; y: 0
                    columns: grid.cols; spacing: 0
                    Repeater {
                        model: grid.cols * 2
                        Item {
                            width: grid.cellWidth; height: grid.cellHeight
                            Column {
                                width: parent.width - 18; spacing: 10
                                Rectangle { width: parent.width; height: width * 9 / 16; radius: Theme.radius; color: Colors.isl2 }
                                Rectangle { width: parent.width * 0.85; height: 12; radius: 6; color: Colors.isl2 }
                                Rectangle { width: parent.width * 0.5; height: 10; radius: 5; color: Colors.isl2 }
                            }
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite; running: view.app.loading
                                NumberAnimation { to: 0.45; duration: 700; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                }
            }
        }
    }

    // ================= плеер (один на окно, летает между местами) =================
    readonly property rect slotRect: {
        // зависимости, чтобы пересчитывалось при раскладке
        slot.width; slot.height; slot.x; watchPage.y; watchPage.width; head.height; main.x; view.width; view.height
        const p = slot.mapToItem(view, 0, 0)
        return Qt.rect(p.x, p.y, slot.width, slot.height)
    }
    readonly property real miniW: Math.min(380, view.width * 0.32)
    Player {
        id: player
        app: view.app
        visible: view.app.playerMode !== "" && !!view.app.current
        z: 10
        readonly property rect target: view.app.playerMode === "theater" ? Qt.rect(0, 0, view.width, view.height)
            : view.app.playerMode === "mini" ? Qt.rect(view.width - view.miniW - 20, view.height - view.miniW * 9 / 16 - 20, view.miniW, view.miniW * 9 / 16)
            : view.slotRect
        x: target.x; y: target.y; width: target.width; height: target.height
        Behavior on x { enabled: player.visible; NumberAnimation { duration: Theme.menuOpen; easing.type: Easing.OutCubic } }
        Behavior on y { enabled: player.visible; NumberAnimation { duration: Theme.menuOpen; easing.type: Easing.OutCubic } }
        Behavior on width { enabled: player.visible; NumberAnimation { duration: Theme.menuOpen; easing.type: Easing.OutCubic } }
        Behavior on height { enabled: player.visible; NumberAnimation { duration: Theme.menuOpen; easing.type: Easing.OutCubic } }
    }
    Rectangle {   // тень мини-плеера
        visible: view.app.playerMode === "mini" && player.visible
        z: 9
        x: player.x - 1; y: player.y - 1; width: player.width + 2; height: player.height + 2
        radius: 19; color: "transparent"; border.width: 1; border.color: Colors.alpha(Colors.acc, 0.35)
    }

    // ---- всплывающая подсказка снизу ----
    Rectangle {
        z: 20
        anchors.horizontalCenter: parent.horizontalCenter
        y: view.app.toast ? parent.height - height - 22 : parent.height + 10
        Behavior on y { NumberAnimation { duration: Theme.menuOpen; easing.type: Theme.easeSpring; easing.overshoot: Theme.overshoot } }
        width: Math.min(toastT.implicitWidth + 36, parent.width - 80); height: 40; radius: 20
        color: Colors.deep
        border.width: 1; border.color: Colors.alpha(Colors.acc, 0.3)
        Text { id: toastT; anchors.centerIn: parent; width: parent.width - 36; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
               text: view.app.toast; font.family: Theme.fontUi; font.pixelSize: 13; font.weight: Font.Medium; color: Colors.fg }
    }

    // ---- строка «Далее» ----
    component QueueItem: Rectangle {
        id: q
        property var v: ({})
        radius: 14
        color: qm.containsMouse ? Colors.isl2 : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        scale: qm.pressed ? 0.98 : 1
        Behavior on scale { NumberAnimation { duration: Theme.fast } }
        RowLayout {
            anchors.fill: parent; anchors.margins: 6
            spacing: 10
            ClippingRectangle {
                Layout.preferredWidth: (q.height - 12) * 16 / 9; Layout.fillHeight: true
                radius: 10; color: Colors.isl2
                Image { anchors.fill: parent; source: q.v.thumb || ""; asynchronous: true; fillMode: Image.PreserveAspectCrop; sourceSize.width: 320 }
                Rectangle {
                    visible: !!q.v.duration
                    anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 5
                    width: qd.implicitWidth + 10; height: 18; radius: 6; color: Colors.alpha(Colors.deep, 0.85)
                    Text { id: qd; anchors.centerIn: parent; text: view.app.fmtTime(q.v.duration); font.family: Theme.fontUi; font.pixelSize: 10; font.weight: Font.DemiBold; color: Colors.fg }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text { Layout.fillWidth: true; text: q.v.title || ""; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                       font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.DemiBold; color: Colors.fg }
                Text { Layout.fillWidth: true; text: q.v.channel || ""; elide: Text.ElideRight
                       font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim }
                Item { Layout.fillHeight: true }
            }
        }
        MouseArea { id: qm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: view.app.play(q.v, false, view.app.queue) }
    }
}
