import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import "Cal.js" as Cal

// Строка плана — «Остров» (29.10): IRow (значок в квадрате 34, текст, подпись «[день ·] время · напоминание»).
// Выполненный — отмечен (sel) и с галочкой. На странице дня (full) справа переключатель «выполнено».
IRow {
    id: row
    property var ev: ({})
    property string today: ""
    property bool withDay: false
    property bool full: false
    property int order: 0
    property bool open: true
    property bool selected: false
    signal doneToggled()
    readonly property bool done: !!ev.done
    readonly property string time: ev.time || ""
    readonly property string remindText: ev.remind === null || ev.remind === undefined ? "" : (Cal.REMIND_TEXT[ev.remind] || "")

    icon: done ? "󰄬" : (time ? "󰥔" : "󰃭")
    sel: done
    kb: selected
    title: full ? (ev.text || "").trim().split("\n")[0] : Cal.firstLine(ev)
    sub: [withDay ? Cal.shortDay(Cal.fromIso(ev.date), Cal.fromIso(today || ev.date)) : "",
          time || "весь день",
          done ? "выполнено" : (remindText ? "напомнить " + remindText : "")].filter(x => x).join(" · ")

    // каскад: opacity + y 8 px, 40 мс на строку
    property bool ready: false
    Timer { interval: 20; running: true; onTriggered: row.ready = true }
    opacity: open && ready ? 1 : 0
    property real dy: open && ready ? 0 : 8
    transform: Translate { y: row.dy }
    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: row.open ? Theme.contentDelay + row.order * Theme.cascade : 0 } NumberAnimation { duration: 280; easing.type: Easing.OutCubic } } }
    Behavior on dy { SequentialAnimation { PauseAnimation { duration: row.open ? Theme.contentDelay + row.order * Theme.cascade : 0 } NumberAnimation { duration: 280; easing.type: Easing.OutCubic } } }

    IToggle { visible: row.full; on: row.done; onToggled: row.doneToggled() }
}
