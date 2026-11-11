import QtQuick
import Quickshell.Services.UPower
import Quickshell.Io
import qs
import qs.components

// Батарея через UPower (battery в Waybar): значок по уровню, зарядка 󰂄, от сети без зарядки 󰚥, полная 󰁹;
// warning ≤30 % — оранжевый, critical ≤15 % — красная пульсация, зарядка/сеть — зелёный со свечением.
// min-length 6 → ширина не прыгает. Подсказка — время до разряда/полной зарядки.
Mod {
    id: m
    readonly property var dev: UPower.displayDevice
    // 29.10: процент — от контроллера батареи (sysfs capacity), как в меню «Питание»; UPower пересчитывал из энергии
    // и расходился на 2–3 %. Перечитываем при каждом изменении UPower и раз в минуту; нет файла — UPower как раньше.
    FileView { id: capFile; path: "/sys/class/power_supply/macsmc-battery/capacity"; printErrors: false
               onLoaded: m.capSys = parseInt(text().trim()); onLoadFailed: m.capSys = -1 }
    property int capSys: -1
    Connections { target: m.dev; ignoreUnknownSignals: true
                  function onPercentageChanged() { capFile.reload() }
                  function onStateChanged() { capFile.reload(); acFile.reload() } }
    Timer { interval: 60000; repeat: true; running: true; onTriggered: capFile.reload() }
    readonly property int pct: capSys >= 0 ? capSys : (dev ? Math.round(dev.percentage * 100) : 0)
    readonly property bool charging: dev ? dev.state === UPowerDeviceState.Charging : false
    readonly property bool plugged: dev ? dev.state === UPowerDeviceState.PendingCharge : false
    readonly property bool full: dev ? dev.state === UPowerDeviceState.FullyCharged : false
    FileView { id: acFile; path: "/sys/class/power_supply/macsmc-ac/online"; printErrors: false
               onLoaded: m.onAcLine = text().trim() === "1" }
    property bool onAcLine: false
    Timer { interval: 2000; repeat: true; running: true; onTriggered: acFile.reload() }
    readonly property bool onAc: charging || plugged || onAcLine
    readonly property bool critical: pct <= 15 && !onAc && !full
    readonly property bool warning: pct <= 30 && !onAc && !full
    readonly property var icons: ["󰂎","󰁺","󰁻","󰁼","󰁽","󰁾","󰁿","󰂀","󰂁","󰂂","󰁹"]
    readonly property var iconsChg: ["󰢟","󰢜","󰂆","󰂇","󰂈","󰢝","󰂉","󰢞","󰂊","󰂋","󰂅"]   // те же уровни с молнией
    property real pulse: 0                      // 0 → 1 → 0: critical-анимация yb-crit (1.1 с туда-обратно)

    // 30.10: значок — цвет по заряду, как полоса в меню «Питание» (зелёный 100 % → красный 0 %, шаг 5 %);
    // текст обычный, критичный заряд — красная пульсация, как была
    readonly property color lvl: Colors.goodTone(Math.round(pct / 5) * 5 / 100)
    tone: critical ? Colors.mix(Colors.bad, "#ffd9de", pulse) : Colors.fg
    glow: critical
    glowColor: Colors.bad
    glowR: 8
    glowA: 0.95 * pulse
    minW: 36
    function hm(s) { s = Math.round(s); const h = Math.floor(s / 3600), mn = Math.floor(s % 3600 / 60); return h > 0 ? h + " ч " + mn + " мин" : mn + " мин" }
    tip: !dev ? "" : full ? "Заряжена полностью"
       : charging ? (dev.timeToFull > 0 ? "До полной зарядки " + hm(dev.timeToFull) : "Заряжается")
       : (plugged || onAcLine) ? "От сети, не заряжается"
       : (dev.timeToEmpty > 0 ? "Осталось " + hm(dev.timeToEmpty) : pct + "%")

    SequentialAnimation on pulse {
        running: m.critical; loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 1100; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 1100; easing.type: Easing.InOutSine }
    }
    // «Остров»: значок уровня (было 電); зарядка 󰂄, от сети без зарядки 󰚥, полная 󰁹 (цвет и свечение — как были)
    // зарядка — уровень с молнией, от сети без зарядки (лимит) — вилка 󰚥, от батареи — просто уровень
    Glyph { readonly property int i: Math.max(0, Math.min(10, Math.round(m.pct / 10)))
            text: m.charging ? m.iconsChg[i] : (m.plugged || (m.full && m.onAcLine) ? "󰚥" : m.icons[i])
            font.pixelSize: Theme.barIcon; color: m.critical ? m.ink : m.lvl
            Behavior on color { ColorAnimation { duration: 300 } } }
    Text { text: m.pct + "%"; font.family: Theme.fontUi; font.pixelSize: Theme.barFont; font.features: ({ "tnum": 1 }); color: m.ink
           Behavior on color { ColorAnimation { duration: 100 } } }
}
