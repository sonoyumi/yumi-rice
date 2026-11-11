pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Цвета из обоев. Файл colors.json пишет yumi-colors по шаблону templates/always/quickshell.dcol,
// FileView следит за ним — смена обоев перекрашивает шелл без перезапуска (Behavior на цветах — в Theme).
// Живой акцент и тёмные тона в цвете обоев (yb-acc / yb-bg / yb-deep / yb-hover в Waybar) пишет yumi-accent:
// ~/.cache/yumi-accent/accent.txt (9 тонов xa1..xa9) и bg.txt (deep bg btn hov); пока их нет — тона wallbash.
Singleton {
    id: root
    property var d: ({})
    property var xa: []        // accent.txt: xa1..xa9
    property var tones: []     // bg.txt: deep bg btn hov
    readonly property string path: Quickshell.env("HOME") + "/.config/yumi/quickshell/colors.json"
    readonly property string accDir: Quickshell.env("HOME") + "/.cache/yumi-accent/"

    function c(key, fallback) { return (d && d[key]) ? d[key] : fallback }
    function hx(arr, i, fallback) { return (arr && arr.length > i && /^[0-9A-Fa-f]{6}$/.test(arr[i])) ? "#" + arr[i] : fallback }
    function alpha(col, a) { const x = Qt.color(col); return Qt.rgba(x.r, x.g, x.b, a) }
    function mix(a, b, t) {    // как mix(a, b, t) в GTK CSS
        const x = Qt.color(a), y = Qt.color(b)
        return Qt.rgba(x.r + (y.r - x.r) * t, x.g + (y.g - x.g) * t, x.b + (y.b - x.b) * t, 1)
    }

    // Читаемость на любых обоях: фон панелей не светлее maxL (белый текст на светлых обоях не читался — 15.10),
    // акцент — в коридоре светлоты [lo, hi] (не бледный и не тёмный на стекле). Оттенок обоев сохраняется.
    function capL(col, maxL) { const x = Qt.color(col); return x.hslLightness <= maxL ? x : Qt.hsla(x.hslHue < 0 ? 0 : x.hslHue, x.hslSaturation, maxL, 1) }
    function band(col, lo, hi) { const x = Qt.color(col); const l = Math.min(hi, Math.max(lo, x.hslLightness)); return l === x.hslLightness ? x : Qt.hsla(x.hslHue < 0 ? 0 : x.hslHue, x.hslSaturation, l, 1) }
    // Имена как в yumi-accent.css / theme.css Waybar — чтобы агенты узнавали их
    readonly property color pry1: capL(c("pry1", "#14110f"), 0.12)
    readonly property color pry2: capL(c("pry2", "#303445"), 0.20)
    readonly property color pry3: capL(c("pry3", "#3a456b"), 0.30)
    readonly property color pry4: c("pry4", "#6571a3")
    // текст для фонов pry1/pry2: фон теперь всегда тёмный (capL), а wallbash на светлых обоях даёт тёмный текст — держим светлым
    readonly property color txt1: band(c("txt1", "#ffffff"), 0.86, 0.97)
    readonly property color txt2: band(c("txt2", "#ccd7ff"), 0.82, 0.95)
    readonly property color acc:  band(hx(xa, 6, c("1xa7", "#9aa8e6")), 0.62, 0.80)      // = yb-acc (живой акцент yumi-accent)
    readonly property color acc5: band(hx(xa, 4, c("1xa5", "#6571a3")), 0.38, 0.55)      // = yb-acc5
    readonly property color bg:   capL(hx(tones, 2, c("1xa2", "#303445")), 0.24)   // = yb-bg (стекло пилюль)
    readonly property color deep: capL(hx(tones, 0, c("pry1", "#11131c")), 0.10)   // = yb-deep (подсказки, фон меню)
    readonly property color hover: capL(hx(tones, 3, c("1xa3", "#474d66")), 0.32)  // = yb-hover
    readonly property color actBg: c("1xa5", "#6571a3")                 // = wb-act-bg (рамка подсказок, конец капсулы стола)
    readonly property color fg:   band(c("1xa9", "#ccd7ff"), 0.86, 0.96)                  // = main-fg (theme.css: wallbash_1xa9)
    readonly property color fgDim: alpha(fg, 0.66)
    // «Остров» (29.10): острова — почти чёрные в оттенке обоев; isl2 — плитки/строки внутри; onAcc — текст на акценте
    readonly property color isl:   capL(mix(deep, bg, 0.22), 0.11)
    readonly property color isl2:  capL(mix(deep, bg, 0.62), 0.17)
    readonly property color edge:  alpha(fg, 0.07)
    readonly property color onAcc: { const x = Qt.color(acc); return Qt.hsla(x.hslHue < 0 ? 0 : x.hslHue, Math.min(0.6, x.hslSaturation), 0.12, 1) }
    // «Остров»: шкала «хорошо → плохо» — k = 1 зелёный (ok), через жёлтый и оранжевый, k = 0 красный (bad); оттенок HSL 120°→0°
    // (заряд батареи: k = заряд; лимиты: k = 1 − заполнение). Насыщенность/светлота — между bad и ok, чтобы читалось на острове.
    function goodTone(k) {
        k = Math.max(0, Math.min(1, Number(k) || 0)); const a = Qt.color(bad), b = Qt.color(ok)
        return Qt.hsla(k * 120 / 360, a.hslSaturation + (b.hslSaturation - a.hslSaturation) * k, a.hslLightness + (b.hslLightness - a.hslLightness) * k, 1)
    }
    readonly property color ok:   "#a6da95"                             // = yb-ok   (user-style.css, не из обоев)
    readonly property color warn: "#f5a97f"                             // = yb-warn
    readonly property color bad:  "#ed8796"                             // = yb-crit
    readonly property string wall: c("wall", "")

    FileView {
        id: file
        path: root.path
        watchChanges: true
        onFileChanged: reload()
        // 30.10: cp пишет файл не атомарно — FileView мог прочитать его недописанным; тогда перечитать через 30 мс
        onLoaded: { try { root.d = JSON.parse(text()); retry.tries = 0 } catch (e) { if (retry.tries++ < 10) retry.restart(); else console.warn("Colors: плохой JSON", e) } }
    }
    Timer { id: retry; property int tries: 0; interval: 30; onTriggered: file.reload() }
    FileView {
        path: root.accDir + "accent.txt"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.xa = text().trim().split(/\s+/)
    }
    FileView {
        path: root.accDir + "bg.txt"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.tones = text().trim().split(/\s+/)
    }
}
