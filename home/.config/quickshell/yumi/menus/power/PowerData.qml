import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Данные батареи: UPower (живые сигналы D-Bus) + /sys/class/power_supply/macsmc-battery (то, чего в UPower нет:
// напряжение, температура, ёмкость в А·ч для здоровья, циклы, дата выпуска, предел зарядки).
// Как в yumi-menu-power: проценты — из ядра (как у пилюли), остальное — UPower, запас — sysfs.
// /sys перечитывается при открытии меню и раз в 5 с, пока оно открыто (active).
// YP_POWER_FAKE=pct:state[:watts] — подмена батареи для снимков (state = charging|discharging|full|pending).
QtObject {
    id: root
    property bool active: false

    readonly property var dev: UPower.displayDevice
    readonly property string fake: Quickshell.env("YP_POWER_FAKE") || ""
    readonly property var fakeParts: fake ? fake.split(":") : []

    function num(s, k) { const v = parseFloat(s); return isNaN(v) ? null : v * (k || 1) }

    // ---- sysfs ----
    property SysFile fCapacity: SysFile { name: "capacity" }
    property SysFile fStatus:   SysFile { name: "status" }
    property SysFile fPower:    SysFile { name: "power_now" }
    property SysFile fVoltage:  SysFile { name: "voltage_now" }
    property SysFile fEnergy:   SysFile { name: "energy_now" }
    property SysFile fEnergyF:  SysFile { name: "energy_full" }
    property SysFile fEnergyD:  SysFile { name: "energy_full_design" }
    property SysFile fChargeF:  SysFile { name: "charge_full" }
    property SysFile fChargeD:  SysFile { name: "charge_full_design" }
    property SysFile fCycles:   SysFile { name: "cycle_count" }
    property SysFile fModel:    SysFile { name: "model_name" }
    property SysFile fYear:     SysFile { name: "manufacture_year" }
    property SysFile fMonth:    SysFile { name: "manufacture_month" }
    property SysFile fDay:      SysFile { name: "manufacture_day" }
    property SysFile fTemp:     SysFile { name: "temp" }
    property SysFile fLimit:    SysFile { name: "charge_control_end_threshold" }
    property SysFile fAc:       SysFile { dir: "/sys/class/power_supply/macsmc-ac/"; name: "online" }
    readonly property list<SysFile> live: [fCapacity, fStatus, fPower, fVoltage, fEnergy, fEnergyF, fTemp, fLimit, fAc, fCycles]

    function reload() { for (const f of live) f.reload() }
    property Timer poll: Timer { interval: 5000; repeat: true; running: root.active; triggeredOnStart: true; onTriggered: root.reload() }

    // ---- состояние ----
    readonly property string sysState: ({ "charging": "charging", "discharging": "discharging", "full": "full",
                                          "not charging": "pending" })[fStatus.value.toLowerCase()] || "unknown"
    readonly property string upState: !dev ? "unknown" : ({
        [UPowerDeviceState.Charging]: "charging", [UPowerDeviceState.Discharging]: "discharging",
        [UPowerDeviceState.Empty]: "discharging", [UPowerDeviceState.FullyCharged]: "full",
        [UPowerDeviceState.PendingCharge]: "pending", [UPowerDeviceState.PendingDischarge]: "discharging" })[dev.state] || "unknown"
    readonly property string state: fakeParts.length > 1 ? fakeParts[1] : (upState !== "unknown" ? upState : sysState)
    readonly property bool onAc: fake ? (state === "charging" || state === "full" || state === "pending")
                                      : (fAc.value !== "" ? fAc.value === "1" : (state === "charging" || state === "full" || state === "pending"))

    readonly property real pct: fakeParts.length > 0 ? num(fakeParts[0]) : (num(fCapacity.value) ?? (dev ? dev.percentage * 100 : 0))
    readonly property real rate: fake ? (fakeParts.length > 2 ? num(fakeParts[2]) : 8.0)
                                      : Math.abs((dev && dev.changeRate) ? dev.changeRate : (num(fPower.value, 1e-6) || 0))
    readonly property int tte: fake ? (state === "discharging" ? Math.round(pct / 100 * 49 / Math.max(rate, 0.1) * 3600) : 0)
                                    : (dev ? dev.timeToEmpty : 0)
    readonly property int ttf: fake ? (state === "charging" ? Math.round((100 - pct) / 100 * 49 / Math.max(rate, 0.1) * 3600) : 0)
                                    : (dev ? dev.timeToFull : 0)
    readonly property var temp: num(fTemp.value, 0.1)
    readonly property var health: {
        const f = num(fChargeF.value), d = num(fChargeD.value)
        if (f && d) return f / d * 100
        return (dev && dev.healthSupported) ? dev.healthPercentage : null
    }
    readonly property var energy:       (dev && dev.energy) ? dev.energy : num(fEnergy.value, 1e-6)
    readonly property var energyFull:   (dev && dev.energyCapacity) ? dev.energyCapacity : num(fEnergyF.value, 1e-6)
    readonly property var energyDesign: num(fEnergyD.value, 1e-6)
    readonly property var voltage:      num(fVoltage.value, 1e-6)
    readonly property var cycles:       num(fCycles.value)
    readonly property string model:     (dev && dev.model) ? dev.model : fModel.value
    readonly property string made: (fYear.value && fMonth.value && fDay.value)
        ? ("0" + parseInt(fDay.value)).slice(-2) + "." + ("0" + parseInt(fMonth.value)).slice(-2) + "." + fYear.value : ""
    readonly property int limit: num(fLimit.value) ?? 100

    // ---- слова (дословно из yumi-menu-power) ----
    function hm(sec) { if (!sec || sec <= 0) return ""; const m = Math.floor(sec / 60); return Math.floor(m / 60) + ":" + ("0" + (m % 60)).slice(-2) }
    readonly property string stateWord: ({ charging: "заряжается", full: "заряжено", pending: "не заряжается",
                                           discharging: "от батареи" })[state] || "нет данных"
    readonly property string timeWord: state === "charging" ? (hm(ttf) ? "до полного " + hm(ttf) : "")
                                     : state === "discharging" ? (hm(tte) ? "осталось " + hm(tte) : "")
                                     : (state === "full" || state === "pending") ? "от сети" : ""
    readonly property string sign: state === "charging" ? "+" : (state === "discharging" ? "−" : "")
    readonly property string powerText: rate >= 0.05 ? sign + rate.toFixed(1) + " Вт" : "0 Вт"
    readonly property string icon: {
        const bat = ["󰁺","󰁻","󰁼","󰁽","󰁾","󰁿","󰂀","󰂁","󰂂","󰁹"], chg = ["󰢜","󰂆","󰂇","󰂈","󰢝","󰂉","󰢞","󰂊","󰂋","󰂅"]
        const i = Math.min(Math.max(Math.round(pct) - 1, 0) / 10 | 0, 9)
        return (state === "charging" || state === "full" || state === "pending") ? chg[i] : bat[i]
    }
}
