.pragma library
// Буква по ФИЗИЧЕСКОЙ клавише, как в латинской раскладке (16.10): с RU/UA раскладкой e.key — кириллица, и проверки
// вида k === Qt.Key_D не срабатывали («D — не беспокоить» в центре уведомлений). nativeScanCode на Wayland = код xkb
// (evdev + 8) — его и переводим. Возвращает код как Qt.Key_A…Qt.Key_Z (= ASCII заглавной буквы), иначе e.key как есть.
// Использование: import qs.components → const k = Latin.key(e)
var MAP = { 38: "A", 56: "B", 54: "C", 40: "D", 26: "E", 41: "F", 42: "G", 43: "H", 31: "I", 44: "J", 45: "K", 46: "L", 58: "M",
            57: "N", 32: "O", 33: "P", 24: "Q", 27: "R", 39: "S", 28: "T", 30: "U", 55: "V", 25: "W", 53: "X", 29: "Y", 52: "Z" }
function key(e) {
    var l = MAP[e.nativeScanCode]
    return l ? l.charCodeAt(0) : e.key
}
