import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services
import qs.menus.wifi

// Компактное меню бэкапа (borg, yumi-backup) — «Остров» (29.10), в стиле меню обновлений (PillCard, ширина 360).
// Только чтение: время последнего — ~/.local/state/yumi-backup/last, состояние — …/status, конфиг (REPO, хранение,
// OVERDUE_DAYS) — ~/.config/yumi-backup/config, доступность флешки — `yumi-backup mounted` (код возврата, раз при открытии).
// Кнопка «Сделать бэкап» = `yumi-backup run` (как пилюля бэкапа в баре); YP_DRYRUN=1 — только журнал и строка состояния.
// Открыть/закрыть: qs -c yumi ipc call menu toggle backup. Клавиши: ↵ — сделать, Esc / клик мимо — закрыть.
// Проверка: qs … ipc call backupmenu state | run
Scope {
    id: menu
    readonly property bool open: Menus.current === "backup"
    readonly property bool dry: Quickshell.env("YP_DRYRUN") === "1"
    readonly property string home: Quickshell.env("HOME")
    readonly property string bin: home + "/.local/bin/yumi-backup"
    property string toast: ""
    Timer { id: toastTimer; interval: 4000; onTriggered: menu.toast = "" }

    function plural(n, one, few, many) {
        const a = n % 10, b = n % 100
        return a === 1 && b !== 11 ? one : (a >= 2 && a <= 4 && (b < 12 || b > 14)) ? few : many
    }

    // ---- состояние (только чтение) ----
    FileView { id: lastFile; path: menu.home + "/.local/state/yumi-backup/last"; printErrors: false }
    FileView { id: statusFile; path: menu.home + "/.local/state/yumi-backup/status"; printErrors: false }
    FileView { id: cfgFile; path: menu.home + "/.config/yumi-backup/config"; printErrors: false }
    function cfg(key) {
        const m = new RegExp("^\\s*" + key + "=(.*)$", "m").exec(String(cfgFile.text() || ""))
        return m ? m[1].trim().replace(/^["']|["']$/g, "").replace(/\s+#.*$/, "") : ""
    }
    readonly property real lastTs: { const t = parseInt(String(lastFile.text() || "").trim()); return isNaN(t) ? -1 : t }
    readonly property int age: lastTs < 0 ? -1 : Math.floor((Date.now() / 1000 - lastTs) / 86400)
    readonly property int overdueDays: parseInt(cfg("OVERDUE_DAYS")) || 4
    readonly property bool overdue: age < 0 || age >= overdueDays
    readonly property string ageText: age < 0 ? "ещё не делался" : age === 0 ? "сегодня" : age + " " + plural(age, "день", "дня", "дней") + " назад"
    readonly property string repo: cfg("REPO").replace("$HOME", home)
    readonly property string keep: [cfg("KEEP_DAILY") ? cfg("KEEP_DAILY") + " дн." : "", cfg("KEEP_WEEKLY") ? cfg("KEEP_WEEKLY") + " нед." : "",
                                    cfg("KEEP_MONTHLY") ? cfg("KEEP_MONTHLY") + " мес." : ""].filter(x => x).join(" · ")
    property int reachable: -1                      // -1 — проверяю, 0 — нет, 1 — да
    Process {
        id: mounted
        command: [menu.bin, "mounted"]
        onExited: (code) => menu.reachable = code === 0 ? 1 : 0
    }
    onOpenChanged: if (open) { lastFile.reload(); statusFile.reload(); cfgFile.reload(); reachable = -1; mounted.running = true; scope.forceActiveFocus() }

    function run() {
        const cmd = [bin, "run"]
        if (dry) { console.log("[dry-run] " + cmd.join(" ")); toast = "Имитация: yumi-backup run"; toastTimer.restart(); return }
        Quickshell.execDetached(cmd)
        toast = "Бэкап запущен"; toastTimer.restart()
    }

    IpcHandler {
        target: "backupmenu"
        function run(): void { menu.run() }
        function state(): string {
            return JSON.stringify({ open: menu.open, age: menu.age, overdue: menu.overdue, status: String(statusFile.text() || "").trim(),
                                    repo: menu.repo, reachable: menu.reachable, toast: menu.toast })
        }
    }

    PillCard {
        id: pop
        name: "backup"
        open: menu.open
        screen: Menus.screen
        marginRight: 180
        pad: 18
        contentW: 360
        contentH: body.implicitHeight + pad * 2

        FocusScope {
            id: scope
            anchors.fill: parent
            focus: true
            Keys.onPressed: (e) => {
                if (e.key === Qt.Key_Escape) Menus.close("backup")
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) menu.run()
                else return
                e.accepted = true
            }

            ColumnLayout {
                id: body
                width: parent.width
                spacing: 12

                CardHead {
                    title: "Бэкап"; dry: menu.dry
                    status: menu.toast || ("Последний — " + menu.ageText + (menu.overdue ? " · пора сделать" : ""))
                    statusColor: menu.toast ? Colors.acc : menu.overdue ? Colors.warn : Colors.fgDim
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2; columnSpacing: 8; rowSpacing: 8
                    IStat { Layout.preferredWidth: 1; label: "Последний"
                            value: menu.lastTs < 0 ? "—" : Qt.formatDateTime(new Date(menu.lastTs * 1000), "dd.MM HH:mm") }
                    IStat { Layout.preferredWidth: 1; label: "Напоминать через"; value: menu.overdueDays + " " + menu.plural(menu.overdueDays, "день", "дня", "дней") }
                }

                IRow {
                    hoverable: false
                    icon: menu.reachable === 1 ? "󰕓" : "󱊞"
                    sel: menu.reachable === 1
                    title: menu.reachable < 0 ? "Проверяю флешку…" : menu.reachable ? "Флешка подключена" : "Флешка не подключена"
                    sub: menu.repo || "репозиторий не задан (yumi-backup setup)"
                }
                IRow {
                    visible: menu.keep.length > 0
                    hoverable: false
                    icon: "󰋚"; title: "Хранит архивы"; sub: menu.keep
                }

                IButton {
                    Layout.fillWidth: true
                    primary: true
                    icon: "󰁯"; text: "Сделать бэкап"
                    onClicked: menu.run()
                }
                CardHints { items: [["↵", "сделать"], ["Esc", "закрыть"]] }
            }
        }
    }
}
