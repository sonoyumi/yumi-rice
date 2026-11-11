import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services
import qs.menus.wifi
import "Cal.js" as Cal

// Меню «Календарь» на QML. Содержимое и подписи — как у ~/.local/bin/yumi-menu-calendar (GTK-меню остаётся рабочим),
// хранилище планов — бэкенд ~/.local/lib/yumi/qs/calendar (calstore, напоминания шлёт yumi-calendar-remind).
// «Остров» (29.10): месяц сеткой 7 колонок (пн…вс, листается со слайдом), сегодня — акцентная плашка, дни с планами — точка;
// ниже — планы выбранного дня и ближайшие 7 дней. Клик по дню — выбрать, повторный — страница дня.
// Страницы дня и записи (новый план / правка) выезжают на месте главной (Reveal).
// Клавиши: стрелки — дни, PageUp/PageDown — месяцы, Home или T — сегодня, Enter — открыть день,
// N — новый план на выбранный день, Esc — назад/закрыть. В записи Ctrl+Enter — сохранить.
// Открыть/закрыть: qs -c yumi ipc call menu toggle calendar. Esc и клик вне окна закрывают.
// Проверка: YP_DRYRUN=1 — файл планов не трогается; YP_CAL_FILE, YP_CAL_NOW — как у GTK-меню;
// qs -c yumi ipc call calendar page day|add|edit — открыть страницу, keys Right,Down,Page_Down — «нажать» клавиши.
Scope {
    id: menu
    readonly property bool open: Menus.current === "calendar"
    readonly property int maxDayRows: 3
    readonly property int maxUpcoming: 4

    CalData { id: data; wanted: menu.open; hold: openHold.running }
    Timer { id: openHold; interval: Theme.menuOpen + 120 }   // карточка растёт — тяжёлое (бэкенд, строки планов) после
    SystemClock { id: clock; precision: SystemClock.Minutes }

    // ---- состояние ----
    readonly property string today: data.today || Cal.iso(clock.date)
    property string prevToday: ""
    property string sel: ""                      // выбранный день (iso)
    property date view: Cal.firstOfMonth(new Date())   // показанный месяц (первое число)
    property string page: "main"                 // main | day | edit
    property string dayDate: ""                  // день открытой страницы дня
    property string toastText: ""
    property bool toastError: false

    // запись (страница edit)
    property string edId: ""                     // "" — новый план
    property string edDate: ""
    property bool edAllday: false
    property string edRemind: "10"
    property bool edDone: false
    property bool edFromDay: false               // вернуться на страницу дня после сохранения
    property bool confirmDelete: false

    readonly property var byDay: {               // iso → { on, done }
        const m = {}
        for (const e of data.events) {
            const x = m[e.date] || (m[e.date] = { on: true, done: true })
            if (!e.done) x.done = false
        }
        return m
    }
    readonly property var selEvents: data.dayEvents(sel)
    readonly property var upcoming: {            // ближайшие 7 дней без выбранного дня — он уже выше
        const lo = today, hi = Cal.iso(Cal.addDays(Cal.fromIso(today), 6))
        return data.events.filter(e => e.date >= lo && e.date <= hi && !e.done && e.date !== sel)
    }
    readonly property var dayEvents: data.dayEvents(dayDate)
    property bool atToday: true                  // выбран сегодняшний день и показан его месяц (кнопка «Сегодня» не нужна)
    function recalcToday() { const t = Cal.fromIso(today); atToday = sel === today && view.getMonth() === t.getMonth() && view.getFullYear() === t.getFullYear() }
    onViewChanged: Qt.callLater(recalcToday)

    // ---- лента времени (главная) ----
    property bool monthMode: false               // сетка месяца раскрыта («уровень выше»: ↑ над первой карточкой)
    property int tsel: -1                        // выбранная карточка нити (-1 — нет)
    property date spanBase: Cal.addDays(new Date(), -120)   // первый день полосы
    readonly property int spanDays: 420
    readonly property int selIdx: sel ? Cal.daysBetween(spanBase, Cal.fromIso(sel)) : 0
    onSelChanged: { Qt.callLater(recalcToday); tsel = -1; if (sel && (selIdx < 10 || selIdx > spanDays - 10)) spanBase = Cal.addDays(Cal.fromIso(sel), -120) }
    // карточки выбранного дня: только планы по времени (весь день — сверху)
    readonly property var dayItems: {
        const out = []
        for (const e of data.dayEvents(sel)) {
            const lines = (e.text || "").trim().split("\n")
            const r = e.remind === null || e.remind === undefined ? "" : (Cal.REMIND_TEXT[e.remind] || "")
            out.push({ kind: "plan", ev: e, key: e.time || "00:00", label: e.time || "весь день",
                       meta: (r ? "󰂚 " + r : "") + (e.done ? (r ? " · " : "") + "выполнено" : ""), text: lines[0] || "", body: lines.slice(1).join(" ") })
        }
        out.sort((a, b) => (a.kind === "plan" && !a.ev.time ? "" : a.key) < (b.kind === "plan" && !b.ev.time ? "" : b.key) ? -1 : 1)
        return out
    }

    onTodayChanged: {
        if (!sel || sel === prevToday) { sel = today; view = Cal.firstOfMonth(Cal.fromIso(today)) }
        prevToday = today
        Qt.callLater(recalcToday)
    }
    Connections {   // перешли через полночь — бэкенд пересчитает «сегодня»
        target: clock
        function onDateChanged() { if (data.loaded && !Quickshell.env("YP_CAL_NOW") && Cal.iso(clock.date) !== data.today) data.refresh() }
    }
    onOpenChanged: {
        if (open) { openHold.restart(); page = "main"; monthMode = false; tsel = -1; confirmDelete = false; toastText = ""; if (sel === prevToday || !sel) select(today); if (act.what) act.restart() }
        else { page = "main"; confirmDelete = false }
    }
    Connections {
        target: data
        function onResult(cmd, ok, msg, date) {
            if (!ok) { menu.toast(msg, true, 4); if (cmd === "save") textEdit.forceActiveFocus(); return }
            if (cmd === "save" || cmd === "delete") menu.afterChange(date, msg)
        }
    }
    Timer { id: toastTimer; interval: 3000; onTriggered: menu.toastText = "" }
    function toast(text, error, hold) { toastText = text; toastError = !!error; toastTimer.interval = (hold || 2) * 1000; toastTimer.restart() }

    // ---- навигация ----
    function select(isoDate) {
        sel = isoDate
        const m = Cal.firstOfMonth(Cal.fromIso(isoDate))
        const diff = (m.getFullYear() - view.getFullYear()) * 12 + (m.getMonth() - view.getMonth())
        if (diff === 0) return
        if (Math.abs(diff) === 1) slideTo(diff); else view = m
    }
    function shiftMonth(n) {
        const nv = Cal.addMonths(view, n)
        const d = Cal.fromIso(sel)
        if (d.getFullYear() !== nv.getFullYear() || d.getMonth() !== nv.getMonth())
            sel = Cal.iso(new Date(nv.getFullYear(), nv.getMonth(), Math.min(d.getDate(), Cal.daysInMonth(nv)), 12))
        slideTo(n)
    }
    property int slideDir: 0
    function slideTo(n) {
        if (slideAnim.running) slideAnim.complete()
        slideDir = n
        slideAnim.to = -strip.width * (1 + n)
        slideAnim.restart()
    }
    function onCell(isoDate) { if (isoDate === sel) openDay(isoDate); else select(isoDate) }
    function openDay(isoDate) { dayDate = isoDate; page = "day" }
    function back() {
        if (page === "main" && monthMode) { monthMode = false; return }
        if (page === "edit") { confirmDelete = false; page = edFromDay ? "day" : "main" }
        else if (page === "day") page = "main"
        else Menus.close("calendar")
    }
    function edit(ev, isoDate) {
        const now = clock.date
        edId = ev ? ev.id : ""
        edDate = ev ? ev.date : isoDate
        edAllday = !!ev && !ev.time
        edRemind = ev ? (ev.remind === null || ev.remind === undefined ? "none" : String(ev.remind)) : "10"
        if (!Cal.REMIND.some(r => r.key === menu.edRemind)) edRemind = "10"
        edDone = !!(ev && ev.done)
        if (ev && ev.time) { hours.set(parseInt(ev.time.split(":")[0])); minutes.set(parseInt(ev.time.split(":")[1])) }
        else if (edDate === today) { hours.set((now.getHours() + 1) % 24); minutes.set(0) }
        else { hours.set(9); minutes.set(0) }
        textEdit.text = ev ? (ev.text || "") : ""
        confirmDelete = false
        edFromDay = page === "day"
        page = "edit"
        textEdit.forceActiveFocus()
        textEdit.cursorPosition = textEdit.length
    }
    function save() {
        const text = textEdit.text.trim()
        if (!text) { toast("Напишите, что запланировано", true, 3); textEdit.forceActiveFocus(); return }
        const ev = { date: edDate, text: text, remind: edRemind === "none" ? null : parseInt(edRemind), done: edDone,
                     time: edAllday ? null : Cal.pad2(hours.value) + ":" + Cal.pad2(minutes.value) }
        if (edId) ev.id = edId
        data.save(ev)
    }
    function afterChange(date, msg) {   // после сохранения/удаления: назад на страницу дня (или главную) и обновить
        confirmDelete = false
        if (edFromDay && dayDate === date) page = "day"
        else { page = "main"; if (date) select(date) }
        toast(msg, false, 2)
    }
    readonly property string edTitle: edId ? "Изменить план" : "Новый план"
    readonly property string edSub: edId ? Cal.longDate(Cal.fromIso(edDate)) : "Запись на " + Cal.longDate(Cal.fromIso(edDate), false).toLowerCase()
    readonly property string dayTitle: dayDate ? "" + Cal.fromIso(dayDate).getDate() + " " + Cal.MONTHS_GEN[Cal.fromIso(dayDate).getMonth()] : ""

    // для проверки и горячих клавиш: qs -c yumi ipc call calendar page day|add|edit | keys Right,Down | month 1|-1
    IpcHandler {
        target: "calendar"
        function page(p: string): void { menu.openPage(p) }
        function keys(list: string): void { for (const k of list.split(",")) if (k) menu.pressKey(k) }
        function month(n: int): void { menu.shiftMonth(n) }
        function state(): string { return JSON.stringify({ open: menu.open, page: menu.page, sel: menu.sel, monthMode: menu.monthMode, tsel: menu.tsel, items: menu.dayItems.length, today: menu.today, view: Cal.iso(menu.view), clock: Cal.iso(clock.date), events: data.events.length }) }
        function text(t: string): void { textEdit.text = t }               // проверка: вписать текст (как YP_CAL_AUTOSAVE)
        function save(): void { menu.save() }
        function ask(): void { menu.confirmDelete = true }                  // проверка: показать «Удалить?» (как YP_CAL_CONFIRM)
        function del(): void { if (menu.edId) data.remove(menu.edId) }
    }
    Timer {   // YP_CAL_PAGE=day|add|edit — открыть страницу через 0,4 с после открытия (как в GTK-меню)
        id: act
        interval: 400
        readonly property string what: Quickshell.env("YP_CAL_PAGE") || ""
        onTriggered: menu.openPage(what)
    }
    function openPage(p) {
        if (p === "add") edit(null, sel)
        else if (p === "day") openDay(sel)
        else if (p === "edit") { const evs = data.dayEvents(sel); if (evs.length) edit(evs[0], ""); else openDay(sel) }
        else if (p === "main") page = "main"
    }
    function pressKey(name) {   // клавиши главной по именам (как YP_CAL_KEYS в GTK-меню)
        if (page !== "main") return
        if (monthMode) {   // сетка месяца: стрелки — дни (±1, ±7), Enter — к ленте
            const step = { Left: -1, Right: 1, Up: -7, Down: 7 }[name]
            if (step) { select(Cal.iso(Cal.addDays(Cal.fromIso(sel), step))); return }
            if (name === "Return") { monthMode = false; return }
        } else {           // лента: ←→ — день, ↓↑ — карточки, ↑ над первой — сетка месяца, Enter — план / день
            if (name === "Left" || name === "Right") { select(Cal.iso(Cal.addDays(Cal.fromIso(sel), name === "Left" ? -1 : 1))); return }
            if (name === "Down") { if (dayItems.length) tsel = Math.min(dayItems.length - 1, tsel + 1); return }
            if (name === "Up") { if (tsel > 0) tsel--; else { tsel = -1; monthMode = true } return }
            if (name === "Return") { const it = dayItems[tsel]; if (it && it.kind === "plan") edit(it.ev, ""); else openDay(sel); return }
        }
        if (name === "Page_Up") shiftMonth(-1)
        else if (name === "Page_Down") shiftMonth(1)
        else if (name === "Home" || name === "t") select(today)
        else if (name === "Return") openDay(sel)
        else if (name === "n") edit(null, sel)
    }

    Popup {
        id: pop
        name: "calendar"
        open: menu.open
        screen: Menus.screen
        contentW: 380                                       // «Остров»: одна колонка, как в превью
        pad: 18
        marginRight: 36                                    // под часами в пилюле справа (часы ≈ 226 px от края)
        marginTop: Theme.barH * (Theme.dev ? 2 : 1) + 6
        readonly property int maxH: 760
        fixedH: maxH + pad * 2                             // окно постоянного размера, высоту анимирует карточка внутри
        contentH: Math.min(body.implicitHeight, maxH) + pad * 2

        FocusScope {
            id: scope
            anchors.fill: parent
            focus: true
            Keys.onPressed: (e) => {
                if (e.key === Qt.Key_Escape) { menu.back(); e.accepted = true; return }
                if (menu.page !== "main") return
                const name = { [Qt.Key_Left]: "Left", [Qt.Key_Right]: "Right", [Qt.Key_Up]: "Up", [Qt.Key_Down]: "Down",
                               [Qt.Key_PageUp]: "Page_Up", [Qt.Key_PageDown]: "Page_Down", [Qt.Key_Home]: "Home",
                               [Qt.Key_Return]: "Return", [Qt.Key_Enter]: "Return" }[e.key]
                        || ({ "t": "t", "е": "t", "n": "n", "т": "n" })[e.text.toLowerCase()]
                if (name) { menu.pressKey(name); e.accepted = true }
            }

            Flickable {
                id: flick
                anchors.fill: parent
                contentHeight: body.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                ColumnLayout {
                    id: body
                    width: flick.width
                    spacing: 12

                    // ---- шапка: месяц и ‹ › на главной; ‹ и название на страницах ----
                    CardHead {
                        title: menu.page === "edit" ? menu.edTitle : menu.page === "day" ? menu.dayTitle : Cal.monthTitle(menu.view)
                        dry: data.dry
                        back: menu.page !== "main"
                        onBackClicked: menu.back()
                        status: menu.toastText ? menu.toastText
                            : menu.page === "edit" ? menu.edSub
                            : menu.page === "day" ? Cal.daySub(Cal.fromIso(menu.dayDate), Cal.fromIso(menu.today), menu.dayEvents.length)
                            : "Сегодня · " + Cal.longDate(Cal.fromIso(menu.today), false).toLowerCase()
                              + (data.weather.length ? " · " + data.weather : "")   // погода из ~/.cache/yumi/weather.txt (если свежая)
                        statusColor: menu.toastText ? (menu.toastError ? Colors.bad : Colors.acc) : Colors.fgDim
                        IconBtn { visible: menu.page === "main"; icon: "󰅁"; flat: true; onClicked: menu.shiftMonth(-1) }
                        IconBtn { visible: menu.page === "main"; icon: "󰅂"; flat: true; onClicked: menu.shiftMonth(1) }
                    }

                    // ================= главная: месяц, планы дня, дальше на неделе =================
                    Reveal {
                        shown: menu.page === "main"
                        spacing: 12

                        // ---- месяц (↑ над списком — клавиши в сетке: ←→↑↓ по дням) ----
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: monthCol.implicitHeight + (menu.monthMode ? 12 : 0)
                            radius: Theme.radiusTile
                            color: menu.monthMode ? Colors.alpha(Colors.acc, 0.06) : "transparent"
                            border.width: menu.monthMode ? 1 : 0; border.color: Colors.alpha(Colors.acc, 0.6)
                            Behavior on color { ColorAnimation { duration: Theme.fast } }
                            Behavior on implicitHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }   // 30.10: без перелёта — меню дёргалось
                            ColumnLayout {
                                id: monthCol
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: menu.monthMode ? 6 : 0 }
                                spacing: 4
                                Row {   // пн … вс
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Repeater {
                                        model: Cal.WD_GRID
                                        Text {
                                            required property string modelData
                                            width: (monthCol.width - 24) / 7; height: 22
                                            text: modelData; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                            font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim
                                        }
                                    }
                                }
                                Item {   // лента месяцев: три сетки, листание — сдвиг x внутри clip
                                    id: strip
                                    Layout.fillWidth: true
                                    clip: true
                                    readonly property date targetMonth: slideAnim.running ? Cal.addMonths(menu.view, menu.slideDir) : menu.view
                                    implicitHeight: Cal.gridRows(targetMonth) * 40 - 4
                                    Behavior on implicitHeight { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                                    Item {
                                        id: track
                                        x: -strip.width; width: strip.width * 3; height: strip.height
                                        Repeater {
                                            model: 3
                                            MonthGrid {
                                                required property int index
                                                x: index * strip.width; width: strip.width
                                                month: Cal.addMonths(menu.view, index - 1)
                                                today: menu.today; sel: menu.sel; byDay: menu.byDay
                                                onDayClicked: d => menu.onCell(d)
                                            }
                                        }
                                    }
                                    NumberAnimation {
                                        id: slideAnim
                                        target: track; property: "x"
                                        duration: 340; easing.type: Easing.OutCubic
                                        onFinished: { menu.view = Cal.addMonths(menu.view, menu.slideDir); track.x = -strip.width }
                                    }
                                }
                            }
                        }

                        // ---- выбранный день ----
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            ISection {
                                Layout.bottomMargin: 4
                                text: menu.sel === menu.today ? "Сегодня"
                                    : (menu.sel ? Cal.longDate(Cal.fromIso(menu.sel), Cal.fromIso(menu.sel).getFullYear() !== Cal.fromIso(menu.today).getFullYear()) : "")
                            }
                            Repeater {
                                model: menu.dayItems
                                EventRow {
                                    required property var modelData
                                    required property int index
                                    ev: modelData.ev; today: menu.today; order: index; open: menu.open
                                    selected: menu.tsel === index
                                    onClicked: { menu.tsel = index; menu.edit(modelData.ev, "") }
                                }
                            }
                            Text {
                                visible: menu.dayItems.length === 0
                                Layout.fillWidth: true; wrapMode: Text.Wrap
                                leftPadding: 10; topPadding: 4; bottomPadding: 4
                                text: "Пусто. N — новый план, Enter — открыть день."
                                font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fgDim
                            }

                            // ---- дальше на неделе (как «ближайшие 7 дней») ----
                            ISection { visible: menu.upcoming.length > 0; Layout.topMargin: 10; Layout.bottomMargin: 4; text: "Дальше на неделе" }
                            Repeater {
                                model: menu.upcoming.slice(0, menu.maxUpcoming)
                                EventRow {
                                    required property var modelData
                                    required property int index
                                    ev: modelData; today: menu.today; withDay: true; order: index + 3; open: menu.open
                                    onClicked: menu.edit(modelData, "")
                                }
                            }
                            Text {
                                visible: menu.upcoming.length > menu.maxUpcoming
                                leftPadding: 10
                                text: "…и ещё " + Cal.plural(menu.upcoming.length - menu.maxUpcoming, "план", "плана", "планов")
                                font.family: Theme.fontUi; font.pixelSize: 11; color: Colors.fgDim
                            }
                        }

                        RowLayout {   // быстрые действия: новый план (N), сегодня (T)
                            Layout.fillWidth: true
                            spacing: 8
                            IButton { Layout.fillWidth: true; primary: true; icon: "󰐕"; text: "Новый план"; onClicked: menu.edit(null, menu.sel) }
                            IButton { visible: !menu.atToday; text: "Сегодня"; onClicked: menu.select(menu.today) }
                        }

                        CardHints {
                            items: menu.monthMode
                                ? [["←→↑↓", "день"], ["PgUp/Dn", "месяц"], ["↵ Esc", "к списку"]]
                                : [["←→", "день"], ["↑↓", "запись"], ["N", "новый"], ["T", "сегодня"]]
                        }
                    }

                    // ================= страница дня =================
                    Reveal {
                        shown: menu.page === "day"
                        spacing: 10
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Repeater {
                                model: menu.page === "day" ? menu.dayEvents : []
                                EventRow {
                                    required property var modelData
                                    required property int index
                                    ev: modelData; today: menu.today; full: true; order: index; open: menu.page === "day"
                                    onClicked: menu.edit(modelData, "")
                                    onDoneToggled: data.setDone(modelData.id, !modelData.done)
                                }
                            }
                            Text { visible: menu.dayEvents.length === 0; Layout.fillWidth: true; leftPadding: 10
                                   text: "На этот день планов нет."; font.family: Theme.fontUi; font.pixelSize: 13; color: Colors.fgDim }
                        }
                        IButton { Layout.fillWidth: true; primary: true; icon: "󰐕"; text: "Добавить"; onClicked: menu.edit(null, menu.dayDate) }
                        CardHints { items: [["↵", "открыть план"], ["Esc", "назад"]] }
                    }

                    // ================= запись: новый план / правка =================
                    Reveal {
                        shown: menu.page === "edit"
                        spacing: 10

                        RowLayout {   // ‹ Вторник, 6 октября 2026 ›
                            Layout.fillWidth: true
                            spacing: 6
                            IconBtn { icon: "󰅁"; onClicked: menu.edDate = Cal.iso(Cal.addDays(Cal.fromIso(menu.edDate), -1)) }   // День назад
                            Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                                   text: menu.edDate ? Cal.longDate(Cal.fromIso(menu.edDate)) : ""
                                   font.family: Theme.fontUi; font.pixelSize: 14; font.weight: Font.Medium; color: Colors.fg }
                            IconBtn { icon: "󰅂"; onClicked: menu.edDate = Cal.iso(Cal.addDays(Cal.fromIso(menu.edDate), 1)) }    // День вперёд
                        }

                        Rectangle {   // текст
                            Layout.fillWidth: true
                            implicitHeight: Math.min(140, Math.max(56, textEdit.contentHeight + 24))
                            Behavior on implicitHeight { NumberAnimation { duration: Theme.fast } }
                            radius: Theme.radius
                            color: Colors.isl2
                            border.width: textEdit.activeFocus ? 1.5 : 0; border.color: Colors.acc
                            Flickable {
                                id: textFlick
                                anchors { fill: parent; margins: 12; leftMargin: 14; rightMargin: 14 }
                                contentHeight: textEdit.contentHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                function follow(r) {
                                    if (r.y < contentY) contentY = r.y
                                    else if (r.y + r.height > contentY + height) contentY = r.y + r.height - height
                                }
                                TextEdit {
                                    id: textEdit
                                    width: textFlick.width
                                    wrapMode: TextEdit.Wrap
                                    font.family: Theme.fontUi; font.pixelSize: 14
                                    color: Colors.fg
                                    selectionColor: Colors.alpha(Colors.acc, 0.45); selectedTextColor: Colors.fg
                                    cursorVisible: activeFocus
                                    onCursorRectangleChanged: textFlick.follow(cursorRectangle)
                                    Keys.onPressed: (e) => {
                                        if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && (e.modifiers & Qt.ControlModifier)) { menu.save(); e.accepted = true }
                                        else if (e.key === Qt.Key_Tab) e.accepted = true
                                    }
                                }
                            }
                            Text {   // подсказка-заполнитель
                                anchors { left: parent.left; top: parent.top; leftMargin: 14; topMargin: 12 }
                                visible: textEdit.length === 0
                                text: "Что запланировано…"
                                font.family: Theme.fontUi; font.pixelSize: 14; color: Colors.fgDim
                            }
                        }

                        // ---- время ----
                        ISection { text: "Время" }
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 8
                            SpinField { id: hours; max: 23; step: 1; enabled: !menu.edAllday }      // Часы
                            Text { text: ":"; font.family: Theme.fontUi; font.pixelSize: 19; font.weight: Font.DemiBold; color: Colors.fgDim }
                            SpinField { id: minutes; max: 59; step: 5; enabled: !menu.edAllday }    // Минуты
                        }
                        RowLayout {   // «Весь день» и быстрые часы
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: [{ key: "allday", text: "Весь день" }, { key: "9", text: "09:00" }, { key: "13", text: "13:00" }, { key: "19", text: "19:00" }]
                                IChip {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    text: modelData.text
                                    on: modelData.key === "allday" && menu.edAllday
                                    onClicked: {
                                        if (modelData.key === "allday") menu.edAllday = !menu.edAllday
                                        else { hours.set(parseInt(modelData.key)); minutes.set(0); menu.edAllday = false }
                                    }
                                }
                            }
                        }

                        // ---- напоминание ----
                        ISection { text: "Напомнить" }
                        RemindSeg { currentKey: menu.edRemind; onPickedKey: k => menu.edRemind = k }

                        IRow {   // «Выполнено» — только у существующей записи
                            visible: menu.edId.length > 0
                            icon: "󰄬"; title: "Выполнено"; sel: menu.edDone
                            onClicked: menu.edDone = !menu.edDone
                            IToggle { on: menu.edDone; onToggled: menu.edDone = !menu.edDone }
                        }

                        // ---- сохранить / удалить ----
                        RowLayout {
                            visible: !menu.confirmDelete
                            Layout.fillWidth: true
                            spacing: 8
                            IButton { visible: menu.edId.length > 0; Layout.fillWidth: true; Layout.preferredWidth: 1; text: "Удалить"; danger: true; onClicked: menu.confirmDelete = true }
                            IButton { Layout.fillWidth: true; Layout.preferredWidth: 1; text: "Сохранить"; primary: true; onClicked: menu.save() }
                        }
                        Reveal {
                            shown: menu.confirmDelete
                            MConfirm {
                                text: "Удалить «" + (menu.edId ? Cal.firstLine(data.events.find(e => e.id === menu.edId) || {}).slice(0, 40) : "") + "»?"
                                onYes: data.remove(menu.edId)
                                onNo: menu.confirmDelete = false
                            }
                        }
                        CardHints { items: [["Ctrl+↵", "сохранить"], ["Esc", "назад без сохранения"]] }
                    }
                }
            }
        }
    }
}
