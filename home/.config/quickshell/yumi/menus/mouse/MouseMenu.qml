import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services
import qs.menus.wifi

// Меню «Мышь» на QML — содержимое и подписи как у ~/.local/bin/yumi-menu-mouse (GTK-меню остаётся рабочим):
// Logitech PRO X 2 через Solaar — заряд (из ядра, hidpp_battery_*), DPI (плитки + ползунок 100–6400), частота опроса,
// встроенный профиль, «Открыть Solaar». Логика — бэкенд ~/.local/lib/yumi/qs/mouse (MouseData).
//   qs -c yumi ipc call menu toggle mouse   (под баром) · menu center mouse (по центру экрана)
// YP_DRYRUN=1 — настройки мыши не меняются, команды solaar пишутся в журнал.
Popup {
    id: pop
    name: "mouse"
    open: Menus.current === "mouse"
    screen: Menus.screen
    marginRight: Theme.screenPad
    marginTop: Theme.barH * (Theme.dev ? 2 : 1) + 6
    contentW: 400                          // «Остров»: как карточка «Устройства», отступ 18
    pad: 18
    contentH: col.implicitHeight + pad * 2
    holdOpen: mouse.busy > 0

    property string toastText: ""
    property bool toastError: false
    Timer { id: toastTimer; onTriggered: pop.toastText = "" }
    onOpenChanged: if (!open) toastText = ""

    MouseData {
        id: mouse
        active: pop.open
        onToast: (t, e, h) => { pop.toastText = t; pop.toastError = e; toastTimer.interval = h * 1000; toastTimer.restart() }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 12
        MenuHeader {
            icon: "󰍽"; iconOn: true
            title: "Мышь"
            subtitle: pop.toastText || mouse.summary; error: pop.toastError && pop.toastText.length > 0
            showToggle: false; dry: mouse.dry
        }
        MousePanel {
            Layout.fillWidth: true
            md: mouse
            shown: pop.open
            onSolaarOpened: Menus.close("mouse")
        }
        MFooter { hints: [["Esc", "закрыть"]] }
    }
}
