pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Яркость экрана (apple-panel-bl), подсветки клавиатуры (kbd_backlight) и состояние Caps Lock — через brightnessctl.
// Событий от sysfs нет, поэтому refresh() зовут по случаю: открытие центра, событие OSD, сигнал bar refresh.
// Запись прореживается (40 мс, как в yumi-menu-control); экран не ниже 1 % (чтобы не гас). YP_DRYRUN=1 — только печать.
Singleton {
    id: root
    readonly property bool dry: Quickshell.env("YP_DRYRUN") === "1"
    readonly property string screenDev: "apple-panel-bl"
    readonly property string kbdDev: "kbd_backlight"
    property int screen: -1          // %, −1 = ещё не прочитано
    property int kbd: -1
    property bool caps: false
    property string screenName: "Экран"
    signal updated()

    function refresh() { if (!rd.running) rd.running = true; else again = true }
    property bool again: false

    Process {
        id: rd
        command: ["brightnessctl", "-m", "-l"]      // имя,класс,текущее,процент%,максимум — все устройства разом
        stdout: SplitParser {
            onRead: (line) => {
                const f = line.split(",")
                if (f.length < 5) return
                const pct = parseInt(f[3])
                if (f[0] === root.screenDev) root.screen = pct
                else if (f[0] === root.kbdDev) root.kbd = pct
                else if (f[0].endsWith("::capslock")) root.caps = parseInt(f[2]) > 0
            }
        }
        onExited: { root.updated(); if (root.again) { root.again = false; running = true } }
    }

    // --- запись с прореживанием ---
    property int pendScreen: -1
    property int pendKbd: -1
    function setScreen(pct) { pendScreen = Math.max(1, Math.min(100, Math.round(pct))); screen = pendScreen; flush.start() }
    function setKbd(pct)    { pendKbd = Math.max(0, Math.min(100, Math.round(pct))); kbd = pendKbd; flush.start() }
    function apply(dev, pct) {
        if (dry) { console.log("[dry] brightnessctl -q -d", dev, "set", pct + "%"); return }
        Quickshell.execDetached(["brightnessctl", "-q", "-d", dev, "set", pct + "%"])
    }
    Timer {
        id: flush; interval: 40
        onTriggered: {
            if (root.pendScreen >= 0) { root.apply(root.screenDev, root.pendScreen); root.pendScreen = -1 }
            if (root.pendKbd >= 0)    { root.apply(root.kbdDev, root.pendKbd); root.pendKbd = -1 }
        }
    }
    Component.onCompleted: refresh()
}
