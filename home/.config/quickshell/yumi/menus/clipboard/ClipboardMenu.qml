import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components
import qs.services
import qs.menus.wifi

// «Буфер обмена» — «Остров» (29.10): шапка, поле-капсула поиска, фильтры чипами (Все/Текст/Картинки/Закреп со счётчиками),
// записи строками IRow-вида (значок/образец цвета/миниатюра в квадрате 34, текст, подпись, справа закреп или номер);
// выбранная — подложка акцентом 16 % и раскрывается предпросмотром (длинный текст до 8 строк, ссылка целиком, картинка крупно).
// Внизу позиция и «Очистить всё» (подтверждение MConfirm), подсказки клавиш CardHints. Скопированная/удалённая запись уезжает вправо.
// Логика прежняя — бэкенд ~/.local/lib/yumi/qs/clipboard (cliphist, закреплённые HyDE, миниатюры в кэше).
// Клавиши: печать — поиск, ↑↓ — листать, ←→ / Tab — фильтр (Все/Текст/Картинки/Закреп), Enter — скопировать,
// Delete — убрать из истории, Ctrl+P — закрепить/открепить текст, Esc — очистить поиск / закрыть.
// Открыть/закрыть: qs -c yumi ipc call menu toggle clipboard — под пилюлей буфера (закрывается, когда курсор ушёл далеко);
// qs -c yumi ipc call clipboard toggle center (SUPER+V) — по центру экрана, от курсора не закрывается.
// Поле поиска держит фокус только пока меню открыто — перед закрытием фокус снимается (иначе segfault в Qt).
// Проверка: YP_DRYRUN=1 (изменения только печатаются, окно не закрывается), YP_FAKE_CLIP=1 — выдуманные записи;
//   qs … ipc call clipboard search <текст> · clipboard filter all|text|img|pin · clipboard confirm · clipboard key up|down|left|right|delete · clipboard state
//   YUMI_QS_NOKB=1 — без захвата клавиатуры
Scope {
    id: menu
    readonly property bool open: Menus.current === "clipboard"
    readonly property string home: Quickshell.env("HOME")
    property string mode: "bar"            // bar — под пилюлей буфера; center — по центру (SUPER+V)
    property bool modeSet: false
    readonly property bool centered: mode === "center"
    readonly property int limit: 60
    // ---- данные из бэкенда ----
    property bool loaded: false
    property bool dry: false
    property var items: []                 // [{id, prev, kind, text, meta}]
    property var favs: []                  // [{text, meta}]
    property int images: 0
    property var thumbs: ({})              // id → путь миниатюры
    property string filter: "all"          // all | text | img | pin
    property string query: ""
    property var deck: []                  // записи: [{key, id, text, meta, kind, pinned}]
    property int total: 0
    property int sel: 0
    property bool confirm: false
    property string flying: ""             // ключ записи, которую только что скопировали / удалили — уезжает вправо
    property string toastText: ""
    property bool toastError: false
    readonly property var filters: [{ key: "all", text: "Все" }, { key: "text", text: "Текст" },
                                    { key: "img", text: "Картинки" }, { key: "pin", text: "Закреп" }]
    // счётчики у фильтров (вся история, без поиска; «Все» — как в списке: закреплённые + история)
    function countOf(key) {
        if (key === "pin") return favs.length
        if (key === "img") return images
        if (key === "text") return Math.max(0, items.length - images)
        return items.length + favs.length
    }

    function toast(text, error) { toastText = text; toastError = !!error; toastTimer.restart() }
    Timer { id: toastTimer; interval: 3000; onTriggered: menu.toastText = "" }
    function subtitle() {
        if (toastText) return toastText
        if (!loaded) return "Читаю историю…"
        if (query) return "Найдено " + total
        return "Записей " + items.length + " · картинок " + images + " · закреплено " + favs.length
    }

    // вид записи
    function kindOf(r) {
        if (!r) return "text"
        if (r.kind === "img") return "img"
        const t = (r.text || "").trim()
        if (/^(#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?([0-9a-fA-F]{2})?|rgba?\([^)]*\))$/.test(t)) return "color"
        if (/^https?:\/\/\S+$/.test(t)) return "link"
        return "text"
    }
    function domain(url) { const m = /^https?:\/\/([^\/?#]+)/.exec(url || ""); return m ? m[1].replace(/^www\./, "") : url }
    function rest(url) { const m = /^https?:\/\/[^\/?#]+(.*)$/.exec(url || ""); return m ? m[1] : "" }
    // обычная фраза (с заглавной, из слов, без ключей и знаков кода) — засечками; всё прочее — моноширинным, как код
    function prose(t) {
        t = (t || "").trim()
        return t.split(/\s+/).length >= 3 && /^[A-ZÀ-ÞЀ-Я]/.test(t) && !/\s-{1,2}\w/.test(t)
               && /^[A-Za-zÀ-ɏЀ-ӿ0-9\s.,:;!?«»"'()·—–\-]+$/.test(t)
    }
    function esc(t) { return (t || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }
    function numOf(r) { const m = /№\s*(\d+)/.exec(r && r.meta || ""); return m ? "№" + m[1] : "" }
    function caption(r) { return (r && r.meta || "").replace(/\s*·\s*№\s*\d+\s*$/, "") }

    // ---- список: как render() в GTK-меню, но без разделов ----
    function render(keepKey) {
        const q = query.trim().toLowerCase()
        const out = []
        const fv = (filter === "all" || filter === "pin") ? favs.filter(f => !q || f.text.toLowerCase().indexOf(q) >= 0) : []
        for (const f of fv) out.push({ key: "f:" + f.text, id: "", text: f.text, meta: f.meta, kind: "text", pinned: true })
        let n = fv.length
        if (filter !== "pin") {
            const its = items.filter(h => (filter === "all" || h.kind === filter) && (!q || h.prev.toLowerCase().indexOf(q) >= 0))
            for (const h of its.slice(0, limit)) out.push({ key: "h:" + h.id, id: h.id, text: h.text, meta: h.meta, kind: h.kind, pinned: false })
            n = its.length
        }
        total = n
        deck = out
        const k = out.findIndex(r => r.key === keepKey)
        sel = k >= 0 ? k : Math.min(sel, Math.max(0, out.length - 1))
        if (!keepKey) sel = 0
        wantThumbs()
    }
    function wantThumb(r) { if (r && r.kind === "img" && r.id && !thumbs[r.id]) send({ cmd: "thumb", id: r.id }) }
    function wantThumbs() {                 // миниатюры — около выбранной (видимые строки просят свои сами)
        for (let i = Math.max(0, sel - 8); i < Math.min(deck.length, sel + 9); i++) wantThumb(deck[i])
    }
    onSelChanged: wantThumbs()
    Timer { id: renderLater; interval: 60; onTriggered: menu.render() }
    onQueryChanged: renderLater.restart()
    onFilterChanged: render()

    // ---- бэкенд ----
    function send(obj) { if (proc.running) proc.write(JSON.stringify(obj) + "\n") }
    function apply(line) {
        let j
        try { j = JSON.parse(line) } catch (e) { console.log("clipboard: не JSON:", line); return }
        switch (j.type) {
        case "list": {
            const keep = deck[sel] ? deck[sel].key : ""
            items = j.items; favs = j.favs; images = j.images; dry = j.dry; loaded = true
            render(keep); break
        }
        case "thumb": { const t = Object.assign({}, thumbs); t[j.id] = j.path; thumbs = t; break }
        case "toast": toast(j.text, j.error); break
        case "result": if (j.cmd === "copy" && j.ok && !dry) closeLater.restart(); break
        }
    }
    Timer { id: closeLater; interval: 220; onTriggered: menu.close() }
    Process {
        id: proc
        command: ["python3", "-I", menu.home + "/.local/lib/yumi/qs/clipboard"]
        running: menu.open || grace.running
        stdout: SplitParser { onRead: line => menu.apply(line) }
        stderr: SplitParser { onRead: line => console.log("clipboard:", line) }
        onExited: { menu.loaded = false; menu.thumbs = {} }
    }
    Timer { id: grace; interval: 90000 }
    onOpenChanged: {
        if (open) {
            grace.stop(); closer.stop(); flying = ""
            if (loaded) { render(); send({ cmd: "list" }) }
            field.forceActiveFocus(); Qt.callLater(() => { if (menu.open) field.forceActiveFocus() })
        } else {
            field.focus = false; grace.restart(); closer.restart(); confirm = false; toastText = ""; field.text = ""; modeSet = false
        }
    }
    Timer { id: closer; interval: Theme.slow; onTriggered: if (!menu.open) { menu.deck = []; menu.sel = 0 } }
    Connections { target: Menus; function onOpened(name) { if (name === "clipboard" && !menu.modeSet) menu.mode = "bar" } }

    // ---- действия ----
    function close() { field.focus = false; Menus.close("clipboard") }
    function fly(r) { flying = r.key; flyEnd.restart() }
    Timer { id: flyEnd; interval: 700; onTriggered: menu.flying = "" }
    function copy(r) {
        if (!r) return
        fly(r)
        if (r.pinned) send({ cmd: "copy_text", text: r.text }); else send({ cmd: "copy", id: r.id })
    }
    function remove(r) {
        if (!r || r.pinned || !r.id) { if (r && r.pinned) toast("Закреплённое не удаляется — открепите (Ctrl+P)", false); return }
        fly(r); send({ cmd: "delete", id: r.id })
    }
    function togglePin(r) {
        if (!r) return
        if (r.pinned) send({ cmd: "unpin", text: r.text })
        else if (r.kind === "text") send({ cmd: "pin", id: r.id })
        else toast("Закрепить можно только текст", false)
    }
    function move(d) { if (deck.length) sel = Math.max(0, Math.min(deck.length - 1, sel + d)) }
    function filterStep(d) { const i = filters.findIndex(f => f.key === filter); filter = filters[(i + d + filters.length) % filters.length].key }
    function key(name) {
        if (name === "up") move(-1)
        else if (name === "down") move(1)
        else if (name === "left") filterStep(-1)
        else if (name === "right" || name === "tab") filterStep(1)
        else if (name === "enter") copy(deck[sel])
        else if (name === "delete") remove(deck[sel])
        else if (name === "pin") togglePin(deck[sel])
        else return false
        return true
    }

    IpcHandler {
        target: "clipboard"
        function toggle(mode: string): void { menu.mode = mode === "center" ? "center" : "bar"; menu.modeSet = true; Menus.toggle("clipboard") }
        function open(mode: string): void { menu.mode = mode === "center" ? "center" : "bar"; menu.modeSet = true; Menus.open("clipboard") }
        function search(text: string): void { field.text = text }
        function filter(key: string): void { menu.filter = key }
        function confirm(): void { menu.confirm = true }
        function key(name: string): void { menu.key(name) }
        function state(): string {
            const r = menu.deck[menu.sel]
            return JSON.stringify({ open: menu.open, filter: menu.filter, q: menu.query, sel: menu.sel, cards: menu.deck.length,
                                    front: r ? menu.kindOf(r) + ": " + (r.text || "").slice(0, 40) : "", toast: menu.toastText, dry: menu.dry })
        }
    }

    Popup {
        id: pop
        name: "clipboard"
        open: menu.open
        screen: Menus.screen
        contentW: 400                     // «Остров»: как в превью
        pad: 18
        contentH: body.implicitHeight + 2 * pad
        marginTop: Theme.barH * (Theme.dev ? 2 : 1) + 6
        // из бара — под пилюлей буфера (правый блок, как marginRight 255 до C2); по бинду — по центру экрана
        marginRight: menu.centered ? -1 : 255
        vcenter: menu.centered
        closeOnLeave: !menu.centered
        // YUMI_QS_NOKB=1 — без захвата клавиатуры (проверка, пока человек печатает), как было до C2
        WlrLayershell.keyboardFocus: menu.open && Quickshell.env("YUMI_QS_NOKB") !== "1" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        // список: не выше ~70 % экрана вместе с шапкой, подвалом и полем (≈ 250 px)
        readonly property real listCap: Math.max(180, Math.round((height > 0 ? height : 1000) * 0.7) - 250 - (menu.confirm ? 90 : 0))

        FocusScope {
            anchors.fill: parent
            focus: true

            ColumnLayout {
                id: body
                width: parent.width
                spacing: 12

                CardHead {
                    title: "Буфер обмена"; dry: menu.dry
                    status: menu.subtitle()
                    statusColor: menu.toastText ? (menu.toastError ? Colors.bad : Colors.acc) : Colors.fgDim
                }

                // ---- поиск: капсула 40 (как IField) ----
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40; radius: 20
                    color: Colors.isl2
                    border.width: field.activeFocus && field.text ? 1.5 : 0; border.color: Colors.acc
                    Glyph { id: lens; anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
                            text: "󰍉"; font.pixelSize: 16; color: field.text ? Colors.acc : Colors.fgDim }
                    TextInput {
                        id: field
                        anchors { left: lens.right; right: clear.left; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 6 }
                        font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fg
                        selectByMouse: true; selectionColor: Colors.alpha(Colors.acc, 0.35); selectedTextColor: Colors.fg
                        clip: true
                        onTextChanged: menu.query = text
                        Keys.onPressed: (e) => {
                            const k = Latin.key(e)   // буквы — по физической клавише (RU/UA раскладка)
                            let n = ""
                            if (k === Qt.Key_Up) n = "up"
                            else if (k === Qt.Key_Down) n = "down"
                            else if (k === Qt.Key_Left) n = "left"
                            else if (k === Qt.Key_Right) n = "right"
                            else if (k === Qt.Key_Tab) n = "tab"
                            else if (k === Qt.Key_Backtab) { menu.filterStep(-1); e.accepted = true; return }
                            else if (k === Qt.Key_Return || k === Qt.Key_Enter) n = "enter"
                            else if (k === Qt.Key_Delete) n = "delete"
                            else if (k === Qt.Key_P && (e.modifiers & Qt.ControlModifier)) n = "pin"
                            else if (k === Qt.Key_Escape) { if (field.text) field.text = ""; else if (menu.confirm) menu.confirm = false; else menu.close(); e.accepted = true; return }
                            if (n && menu.key(n)) e.accepted = true
                        }
                        Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; visible: !field.text; text: "Поиск в истории…"
                               font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fgDim }
                    }
                    Glyph {
                        id: clear
                        anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                        text: "󰅖"; font.pixelSize: 14; color: Colors.fgDim
                        opacity: field.text ? 1 : 0; Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                        MouseArea { anchors.fill: parent; anchors.margins: -6; enabled: field.text.length > 0; onClicked: { field.text = ""; field.forceActiveFocus() } }
                    }
                }

                // ---- фильтры: чипы со счётчиками ----
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: menu.filters
                        IChip {
                            required property var modelData
                            text: modelData.text + (menu.loaded ? "  " + menu.countOf(modelData.key) : "")
                            on: menu.filter === modelData.key
                            onClicked: { menu.filter = modelData.key; field.forceActiveFocus() }
                        }
                    }
                }

                // ---- список записей; выбранная раскрывается (предпросмотр) ----
                Item {
                    Layout.fillWidth: true
                    implicitHeight: menu.deck.length === 0 ? 90 : Math.min(Math.ceil(list.contentHeight), pop.listCap)
                    Behavior on implicitHeight { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }

                    ListView {
                        id: list
                        anchors.fill: parent
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        spacing: 2
                        model: menu.deck
                        currentIndex: menu.sel
                        highlightFollowsCurrentItem: false
                        cacheBuffer: 300
                        onCurrentIndexChanged: Qt.callLater(() => { if (list.count) list.positionViewAtIndex(menu.sel, ListView.Contain) })

                        delegate: Item {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property bool sel: index === menu.sel
                            readonly property bool gone: menu.flying !== "" && menu.flying === modelData.key
                            readonly property string kind: menu.kindOf(modelData)
                            readonly property bool mono: kind === "text" && !menu.prose(modelData.text)
                            readonly property string flat: (modelData.text || "").replace(/\s*\n\s*/g, " ⏎ ")
                            readonly property bool longText: kind === "text" && ((modelData.text || "").indexOf("\n") >= 0 || flat.length > 46)
                            readonly property bool expand: sel && (longText || kind === "img" || kind === "link")
                            readonly property string stats: {
                                const t = modelData.text || "", n = t.split("\n").length
                                return "знаков: " + t.length + (n > 1 ? " · строк: " + n : "")
                            }
                            width: ListView.view.width
                            height: 52 + (expand ? prev.height + 10 : 0)
                            // каскад при открытии + уход вправо (скопировано / удалено)
                            property bool ready: false
                            Timer { interval: Math.min(row.index, 10) * Theme.cascade + 20; running: true; onTriggered: row.ready = true }
                            opacity: gone ? 0 : ready ? 1 : 0
                            property real dy: ready ? 0 : 8
                            transform: Translate { x: row.gone ? 60 : 0; y: row.dy
                                                   Behavior on x { NumberAnimation { duration: 350; easing.type: Easing.OutBack } } }
                            Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                            Behavior on dy { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                            Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
                            Component.onCompleted: menu.wantThumb(modelData)
                            clip: true

                            Rectangle {
                                anchors.fill: parent; radius: Theme.radius
                                color: row.sel ? Colors.alpha(Colors.acc, 0.16) : rma.containsMouse ? Colors.isl2 : "transparent"
                                /* выбор — без затухания (29.10) */
                            }
                            scale: rma.pressed ? 0.985 : 1
                            Behavior on scale { NumberAnimation { duration: Theme.fast } }

                            // ---- строка: значок / образец / миниатюра в квадрате 34, текст и подпись, справа закреп или номер ----
                            RowLayout {
                                id: head
                                x: 9; y: 9; width: row.width - 19; height: 34
                                spacing: 12
                                Rectangle {
                                    implicitWidth: 34; implicitHeight: 34; radius: 12
                                    color: row.kind === "color" ? (row.modelData.text || "").trim() : row.sel ? Colors.acc : Colors.isl2
                                    border.width: row.kind === "color" ? 1 : 0; border.color: Colors.edge
                                    /* выбор — без затухания (29.10) */
                                    Glyph {
                                        anchors.centerIn: parent
                                        visible: row.kind === "text" || row.kind === "link"
                                        text: row.modelData.pinned ? "󰐃" : row.kind === "link" ? "󰖟" : row.mono ? "󰆍" : "󰦨"
                                        font.pixelSize: 16
                                        color: row.sel ? Colors.onAcc : Colors.fg
                                    }
                                    Thumb {
                                        anchors.fill: parent
                                        visible: row.kind === "img"
                                        radius: 12
                                        source: row.kind === "img" ? (menu.thumbs[row.modelData.id] || "") : ""
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 1
                                    Text {
                                        Layout.fillWidth: true
                                        textFormat: Text.PlainText
                                        text: row.kind === "link" ? menu.domain(row.modelData.text) + menu.rest(row.modelData.text)
                                            : row.kind === "color" ? (row.modelData.text || "").trim().toUpperCase()
                                            : row.kind === "img" ? "Картинка"
                                            : row.flat
                                        elide: Text.ElideRight; maximumLineCount: 1
                                        font.family: row.mono ? Theme.fontMono : Theme.fontUi; font.pixelSize: row.mono ? 12 : 13; font.weight: row.mono ? Font.Normal : Font.Medium
                                        color: Colors.fg
                                    }
                                    Text {
                                        Layout.fillWidth: true; elide: Text.ElideRight
                                        text: [row.kind === "img" ? (menu.caption(row.modelData) || "картинка") : (menu.caption(row.modelData) || (row.kind === "link" ? "Ссылка" : row.kind === "color" ? "Цвет" : "Текст")),
                                               row.expand && row.kind === "text" ? row.stats : ""].filter(x => x).join(" · ")
                                        font.family: Theme.fontUi; font.pixelSize: 12; color: Colors.fgDim
                                    }
                                }
                                Glyph { visible: row.modelData.pinned; text: "󰐃"; font.pixelSize: 15; color: Colors.acc }
                                Text { visible: !row.modelData.pinned; text: menu.numOf(row.modelData)
                                       font.family: Theme.fontUi; font.pixelSize: 11; font.features: ({ "tnum": 1 }); color: Colors.fgDim }
                            }

                            // ---- предпросмотр выбранной ----
                            Item {
                                id: prev
                                x: 55; y: 52
                                width: row.width - x - 14
                                visible: row.expand
                                opacity: row.expand ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                                height: row.kind === "img" ? big.height : full.implicitHeight
                                Text {
                                    id: full
                                    width: parent.width
                                    visible: row.kind !== "img"
                                    text: row.expand && row.kind !== "img" ? (row.modelData.text || "") : ""
                                    wrapMode: (row.mono || row.kind === "link") ? Text.WrapAnywhere : Text.Wrap
                                    maximumLineCount: 8
                                    elide: Text.ElideRight
                                    font.family: (row.mono || row.kind === "link") ? Theme.fontMono : Theme.fontUi
                                    font.pixelSize: (row.mono || row.kind === "link") ? 11 : 13
                                    lineHeight: 1.15
                                    color: row.kind === "link" ? Colors.fgDim : Colors.fg
                                }
                                Thumb {
                                    id: big
                                    visible: row.kind === "img"
                                    height: row.kind === "img" ? 150 : 0
                                    width: Math.min(parent.width, Math.round(height * 16 / 9))
                                    radius: 12
                                    source: row.kind === "img" && row.expand ? (menu.thumbs[row.modelData.id] || "") : ""
                                }
                            }

                            MouseArea {
                                id: rma
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { if (row.sel) menu.copy(row.modelData); else menu.sel = row.index; field.forceActiveFocus() }
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: menu.loaded && menu.deck.length === 0
                        text: menu.query ? "Ничего не найдено" : (menu.filter === "pin" ? "Закреплённых пока нет — Ctrl+P на записи" : "История пуста")
                        font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fgDim
                    }
                }

                // ---- очистка: подтверждение ----
                MConfirm {
                    visible: menu.confirm
                    text: "Удалить всю историю буфера обмена? Закреплённые останутся."
                    yesText: "Очистить"
                    onYes: { menu.confirm = false; menu.send({ cmd: "wipe" }); field.forceActiveFocus() }
                    onNo: { menu.confirm = false; field.forceActiveFocus() }
                }

                // ---- позиция и «Очистить всё» ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        Layout.fillWidth: true
                        text: menu.deck.length ? (menu.sel + 1) + " / " + menu.deck.length
                                                 + (menu.total > menu.limit ? "  ·  …и ещё " + (menu.total - menu.limit) + " — уточните поиск" : "") : ""
                        elide: Text.ElideRight
                        font.family: Theme.fontUi; font.pixelSize: 11; font.features: ({ "tnum": 1 }); color: Colors.fgDim
                    }
                    IButton {
                        text: "Очистить всё"; danger: true
                        implicitHeight: 30
                        enabledLook: !menu.confirm
                        onClicked: menu.confirm = true
                    }
                }

                CardHints {
                    items: [["↵", "скопировать"], ["Ctrl+P", "закрепить"], ["Del", "удалить"]]
                }
            }
        }
    }
}
