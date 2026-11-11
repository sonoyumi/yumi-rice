import Quickshell.Io

// Одно значение из /sys/class/power_supply/macsmc-battery/<name> (строка без пробелов; нет файла — "").
FileView {
    property string dir: "/sys/class/power_supply/macsmc-battery/"
    property string name: ""
    property string value: ""
    path: dir + name
    printErrors: false
    onLoaded: value = text().trim()
    onLoadFailed: value = ""
}
