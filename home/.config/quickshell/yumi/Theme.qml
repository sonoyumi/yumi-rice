pragma Singleton
import QtQuick
import Quickshell

// Единая тема: размеры, шрифты, кривые. Менять стиль всего шелла — здесь, а не по файлам.
Singleton {
    // шрифты (как в Waybar/yumi-panel)
    readonly property string fontUi:   "Onest"                     // «Остров» (29.10): было JetBrainsMono Nerd Font
    readonly property string fontMono: "JetBrainsMono Nerd Font"   // цифры в терминальном виде, код
    readonly property string fontIcon: "JetBrainsMono Nerd Font Propo"
    readonly property string fontYumi: "YumiIcons"
    readonly property int    fontSize: 13          // px, меню и карточки
    readonly property int    iconSize: 17          // ≈130% от текста (iconwrap: size='130%')
    readonly property int    barFont:  12          // «Остров»: 12 px Onest (было 10, как Waybar)
    readonly property int    barIcon:  15          // бар: значки

    // «Остров» (29.10): Onest, сплошные острова в цвете обоев, пружины. Знак системы — печать 弓 (YumiMark), других иероглифов нет
    readonly property string fontSerif: "Onest"         // «Остров»: засечек больше нет — старое имя оставлено, чтобы не править 70 файлов разом
    readonly property string fontJp:    "Noto Serif CJK JP"   // ТОЛЬКО печать 弓 (YumiMark); иероглифов в подписях больше нет
    readonly property color  seal:      "#C0392B"      // = lock/hanko.png и печать Touch ID на тачбаре (touchid_style "seal")
    readonly property color  sealInk:   "#F6EFE8"
    readonly property int    pillRadius: 15            // «Остров»: острова-капсулы (pillH / 2)
    readonly property int    jpPx:      12             // устарело («Тушь»): японских подписей нет

    // бар и пилюли
    readonly property int barH:   38               // = reserved top в Hyprland
    readonly property int pillH:  30               // «Остров»: остров 30 px, сверху 6 (бар 38 = reserved top)
    readonly property int pillPadX: 10             // padding #pill 1em
    readonly property int pillGap: 8               // margin #pill 0.38em × 2
    readonly property int moduleGap: 7             // label.module: padding 0.3em + margin 0.04em, × 2
    readonly property int screenPad: 10

    // окна меню
    readonly property int radius:  16             // «Остров»: строки, поля, плитки внутри карточек
    readonly property int radiusBig: 26           // «Остров»: карточки меню
    readonly property int radiusTile: 18          // плитки центра управления, блоки
    readonly property int menuW:   380
    readonly property int menuPad: 14
    readonly property real glass:  1.0             // «Остров»: сплошные острова (Colors.isl), без стекла
    readonly property int  menuFar: 160            // меню из бара закрывается, когда курсор дальше этого (лог. px) от карточки — FAR в yumipanel.py
    readonly property int  menuLeaveMs: 500        // …и держится там столько мс (возврат ближе — отмена)

    // движение
    readonly property int fast:   150
    readonly property int normal: 260
    readonly property int slow:   450
    readonly property int easeSoft:   Easing.OutCubic
    readonly property int easeSpring: Easing.OutBack
    readonly property real overshoot: 1.2
    // «Остров»: остров и меню — пружина (размер/радиус), содержимое проявляется с задержкой
    readonly property int springMs:  550          // остров: ширина/высота/радиус
    readonly property int menuOpen:  300          // меню вырастает из пилюли (29.10: было 480 — открывалось вязко; старое «Тушь» = 260)
    readonly property int contentDelay: 0         // содержимое сразу (29.10: было 110 — меню казались медленными)
    readonly property int cascade:   20           // каскад строк (29.10: было 40)

    // YUMI_QS_DEV=1 — бар под Waybar (не вместо него), =2 — ещё на полосу ниже (свой экземпляр агента «бар»)
    readonly property int  devLevel: parseInt(Quickshell.env("YUMI_QS_DEV")) || 0
    readonly property bool dev: devLevel > 0

    // мониторы (19.10): встроенный экран ноутбука — выход, чьё имя начинается с eDP (eDP-1, eDP-2…); всё остальное — внешний
    function isInternal(name: string): bool { return String(name || "").startsWith("eDP") }
    // заглушка экрана блокировки/входа: этот экран внешний, а встроенный подключён (крышка закрыта — полный экран)
    function lockPlaceholder(name: string): bool {
        return name !== "" && !isInternal(name) && Quickshell.screens.some(s => isInternal(s.name))
    }
}
