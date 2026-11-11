// Даты и подписи календаря — как в ~/.local/bin/yumi-menu-calendar (MONTHS, MONTHS_GEN, WEEKDAYS, plural, long_date…).
// Даты — JS Date в полдень по местному времени (чтобы переход на летнее время не сдвигал день).
.pragma library

var MONTHS = ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь",
              "Октябрь", "Ноябрь", "Декабрь"]
var MONTHS_GEN = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября",
                  "октября", "ноября", "декабря"]
var WEEKDAYS = ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"]
var WD_SHORT = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
var WD_GRID = ["пн", "вт", "ср", "чт", "пт", "сб", "вс"]   // «Остров»: подписи дней над сеткой
var REMIND = [{ key: "none", icon: "󰂛", text: "нет" }, { key: "0", icon: "󰂚", text: "в момент" },
              { key: "10", icon: "󰔛", text: "10 мин" }, { key: "60", icon: "󰥔", text: "1 час" },
              { key: "1440", icon: "󰃭", text: "1 день" }]
var REMIND_TEXT = { 0: "в момент", 10: "за 10 мин", 60: "за 1 ч", 1440: "за 1 день" }

function pad2(n) { return (n < 10 ? "0" : "") + n }
function iso(d) { return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate()) }
function fromIso(s) { const p = s.split("-"); return new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2]), 12) }
function addDays(d, n) { return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n, 12) }
function addMonths(d, n) { return new Date(d.getFullYear(), d.getMonth() + n, 1, 12) }
function firstOfMonth(d) { return new Date(d.getFullYear(), d.getMonth(), 1, 12) }
function daysInMonth(d) { return new Date(d.getFullYear(), d.getMonth() + 1, 0, 12).getDate() }
function weekday(d) { return (d.getDay() + 6) % 7 }                        // Пн = 0
function sameDay(a, b) { return iso(a) === iso(b) }
function daysBetween(a, b) { return Math.round((fromIso(iso(b)) - fromIso(iso(a))) / 86400000) }   // b − a в днях

function plural(n, one, few, many) {
    const n10 = n % 10, n100 = n % 100
    const w = (n10 === 1 && n100 !== 11) ? one : (n10 >= 2 && n10 <= 4 && !(n100 >= 12 && n100 <= 14)) ? few : many
    return n + " " + w
}
function longDate(d, year) {
    const s = WEEKDAYS[weekday(d)] + ", " + d.getDate() + " " + MONTHS_GEN[d.getMonth()]
    return s + (year === false ? "" : " " + d.getFullYear())
}
function shortDay(d, today) {
    const rel = { 0: "Сегодня", 1: "Завтра" }[daysBetween(today, d)]
    return rel || (WD_SHORT[weekday(d)] + " " + d.getDate())
}
function firstLine(ev) { return ((ev.text || "").trim().split("\n")[0] || "") }
function monthTitle(d) { return MONTHS[d.getMonth()] + " " + d.getFullYear() }
// подзаголовок страницы дня: «Среда (сегодня) · 2 плана»
function daySub(d, today, n) {
    const rel = { 0: "сегодня", 1: "завтра", "-1": "вчера" }[daysBetween(today, d)]
    let head = WEEKDAYS[weekday(d)] + (rel ? " (" + rel + ")" : "") + (d.getFullYear() !== today.getFullYear() ? " · " + d.getFullYear() : "")
    return head + " · " + (n ? plural(n, "план", "плана", "планов") : "планов нет")
}
// сколько строк сетки показывать: 6-я — только если в ней есть дни этого месяца (как в GTK)
function gridRows(month) {
    const start = weekday(month)
    return (start + daysInMonth(month) > 35) ? 6 : 5
}
