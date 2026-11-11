//@ pragma UseQApplication
import Quickshell
import qs
import qs.bar
import qs.notifications
import qs.menus.sound
import qs.player
import qs.osd
import qs.island
import qs.menus.control
import qs.menus.power
import qs.menus.wifi
import qs.menus.bluetooth
import qs.menus.airpods
import qs.menus.system
import qs.menus.updates
import qs.menus.backup
import qs.menus.session
import qs.menus.top
import qs.menus.tray
import qs.menus.calendar
import qs.menus.vpn
import qs.menus.clipboard
import qs.menus.launcher
import qs.menus.websearch
import qs.menus.pult
import qs.menus.wallpaper
import qs.menus.picker
import qs.menus.music

import qs.menus.workspaces
import qs.menus.mouse
import qs.menus.keys
import qs.menus.devices
import qs.lock
import qs.polkit
import qs.menus.timemachine
import qs.menus.mission
import qs.menus.quicklook
import qs.menus.downloads
// Yumi Quickshell — бар, уведомления, OSD и меню на QML (yumi-rice 3.1).
// Запуск: systemd yumi-quickshell.service (qs -c yumi). Проверка рядом с Waybar: YUMI_QS_DEV=1 qs -c yumi
ShellRoot {
    // Без перезагрузки на лету: в Quickshell 0.3.2 горячая перезагрузка падает в QWindow::setScreen (окна меню).
    // Правки применяет перезапуск: systemctl --user restart yumi-quickshell (или yumi-bar-restart). Dev-*.qml не затронуты.
    settings.watchFiles: false
    // 18.10 (ускорение загрузки): сразу создаются только экран блокировки, уведомления и OSD — бар и меню
    // догружаются в фоне (LazyLoader activeAsync) уже после экрана блокировки. Копия: shell.qml.bak-lazy-20261018
    LazyLoader { activeAsync: Signals.lazyReady; Bar {} }
    Notifications {}       // центр уведомлений (notifications/, services/Notifs.qml); всплывашки — в острове
    LazyLoader { activeAsync: Signals.lazyReady; Island {} }        // «Остров» (29.10): центральный остров — плеер, уведомления, OSD (island/)
    // Menus {}           — агенты меню (menus/<имя>/)
    LazyLoader { activeAsync: Signals.lazyReady; PowerMenu {} }          // меню «Питание»: qs -c yumi ipc call menu toggle power
    Osd {}                // OSD (показывает остров): qs -c yumi ipc call -- osd show <vol|mic|bri|kbd|lang|caps|caffeine> <значение|->
    LazyLoader { activeAsync: Signals.lazyReady; ControlCenter {} }      // центр управления: qs -c yumi ipc call control toggle
    LazyLoader { activeAsync: Signals.lazyReady; SoundMenu {} }          // меню звука: qs -c yumi ipc call menu toggle sound
    LazyLoader { activeAsync: Signals.lazyReady; PlayerIsland {} }       // остров плеера: qs -c yumi ipc call player toggle
    LazyLoader { activeAsync: Signals.lazyReady; FullPlayer {} }         // полноэкранный плеер: qs -c yumi ipc call player full
    LazyLoader { activeAsync: Signals.lazyReady; WifiMenu {} }           // меню Wi-Fi: qs -c yumi ipc call menu toggle wifi (бэкенд ~/.local/lib/yumi/qs/wifi)
    LazyLoader { activeAsync: Signals.lazyReady; BluetoothMenu {} }      // меню Bluetooth: qs -c yumi ipc call menu toggle bluetooth (бэкенд ~/.local/lib/yumi/qs/bluetooth)
    LazyLoader { activeAsync: Signals.lazyReady; AirPodsMenu {} }        // меню AirPods под их пилюлей: qs -c yumi ipc call airpods toggle <x пилюли> (тот же бэкенд, AAP)
    // «AirPods подключены» — пузырь центрального острова (island/IslandState: ipc airpodsPopup show "<имя>", зовёт yumi-airpods); отдельный AirPodsPopup отключён 30.10
    LazyLoader { activeAsync: Signals.lazyReady; CalendarMenu {} }       // календарь: qs -c yumi ipc call menu toggle calendar (бэкенд ~/.local/lib/yumi/qs/calendar)
    LazyLoader { activeAsync: Signals.lazyReady; VpnMenu {} }            // меню VPN: qs -c yumi ipc call menu toggle vpn (бэкенд ~/.local/lib/yumi/qs/vpn)
    LazyLoader { activeAsync: Signals.lazyReady; ClipboardMenu {} }      // буфер обмена: qs -c yumi ipc call menu toggle clipboard | clipboard toggle center (SUPER+V; бэкенд ~/.local/lib/yumi/qs/clipboard)
    LazyLoader { activeAsync: Signals.lazyReady; LauncherMenu {} }       // «Программы и файлы» (по центру): qs -c yumi ipc call launcher apps (SUPER+A) | launcher files (SUPER+SHIFT+E); бэкенд ~/.local/lib/yumi/qs/launcher
    LazyLoader { activeAsync: Signals.lazyReady; WebSearchMenu {} }      // веб-поиск (по центру): qs -c yumi ipc call menu center websearch (SUPER+SHIFT+/); бэкенд ~/.local/lib/yumi/qs/websearch
    LazyLoader { activeAsync: Signals.lazyReady; PultMenu {} }           // «Пульт» (Spotlight, по центру): qs -c yumi ipc call menu center pult (SUPER+Space); бэкенд ~/.local/lib/yumi/qs/pult
    LazyLoader { activeAsync: Signals.lazyReady; TopMenu {} }            // меню «Процессы»: qs -c yumi ipc call top toggle <x пилюли> | menu toggle top (бэкенд ~/.local/lib/yumi/qs/top)
    LazyLoader { activeAsync: Signals.lazyReady; TrayMenu {} }           // меню трея: qs -c yumi ipc call tray toggle <x пилюли> | menu toggle tray (штатный SystemTray + items.json yumi-tray)
    LazyLoader { activeAsync: Signals.lazyReady; SystemMenu {} }         // меню «Система» (пилюля Arch): qs -c yumi ipc call menu toggle system (бэкенд ~/.local/lib/yumi/qs/system)
    LazyLoader { activeAsync: Signals.lazyReady; UpdatesMenu {} }        // меню обновлений (пилюля обновлений, стиль Wi-Fi): qs -c yumi ipc call menu toggle updates (тот же бэкенд qs/system)
    LazyLoader { activeAsync: Signals.lazyReady; BackupMenu {} }         // меню бэкапа (пилюля бэкапа): qs -c yumi ipc call menu toggle backup (yumi-backup, только чтение + run)
    LazyLoader { activeAsync: Signals.lazyReady; WallpaperWidget {} }    // обои — виджет-карусель (стили → обои, ←→ ↑↓): qs -c yumi ipc call menu center wallpaper (SUPER+SHIFT+W); старое меню-сетка — WallpaperMenu.qml
    LazyLoader { activeAsync: Signals.lazyReady; PickerMenu {} }         // эмодзи / символы: qs -c yumi ipc call picker emoji | picker glyph (SUPER+, / SUPER+.; бэкенд ~/.local/lib/yumi/qs/picker)
    LazyLoader { activeAsync: Signals.lazyReady; SessionMenu {} }        // меню «Питание системы» (пилюля ⏻): qs -c yumi ipc call menu toggle session (бэкенд ~/.local/lib/yumi/qs/session)
    LazyLoader { activeAsync: Signals.lazyReady; MusicMenu {} }          // «Музыка» (yumi-music): qs -c yumi ipc call menu center music (SUPER+SHIFT+M) | menu toggle music (бэкенд ~/.local/lib/yumi/qs/music)
    LazyLoader { activeAsync: Signals.lazyReady; WorkspacesMenu {} }     // рабочие столы: qs -c yumi ipc call menu center workspaces (SUPER+TAB, жест) | menu toggle workspaces (бэкенд ~/.local/lib/yumi/qs/workspaces)
    LazyLoader { activeAsync: Signals.lazyReady; MouseMenu {} }          // мышь PRO X 2: qs -c yumi ipc call menu toggle mouse | menu center mouse (бэкенд ~/.local/lib/yumi/qs/mouse)
    LazyLoader { activeAsync: Signals.lazyReady; KeysMenu {} }           // горячие клавиши: qs -c yumi ipc call menu center keys (бэкенд ~/.local/lib/yumi/qs/keys)
    LazyLoader { activeAsync: Signals.lazyReady; DevicesMenu {} }        // устройства (мышь + подсветка клавиатуры): qs -c yumi ipc call menu toggle devices | menu center devices
    LazyLoader { activeAsync: Signals.lazyReady; TimeMachine {} }       // 30.10 «Машина времени» (снимки snapper): qs -c yumi ipc call timemachine open <путь> | timemachine toggle (SUPER+T; бэкенд ~/.local/lib/yumi/qs/timemachine)
    LazyLoader { activeAsync: Signals.lazyReady; MissionControl {} }    // 30.10 Mission Control: qs -c yumi ipc call mission toggle (SUPER+D, 3 пальца вверх)
    LazyLoader { activeAsync: Signals.lazyReady; QuickLook {} }         // 30.10 «Быстрый просмотр»: qs -c yumi ipc call quicklook open <путь> | yumi-quicklook (SUPER+Y; бэкенд ~/.local/lib/yumi/qs/quicklook)
    LazyLoader { activeAsync: Signals.lazyReady; DownloadsStack {} }    // 30.10 стопка загрузок: qs -c yumi ipc call downloads toggle (SUPER+SHIFT+D; бэкенд ~/.local/lib/yumi/qs/downloads)
    LazyLoader { activeAsync: Signals.lazyReady; PolkitService {} }      // свой агент polkit «Черта» — только при флаге ~/.config/yumi/polkit-qs (yumi-polkit-switch on|off|status); превью: dev-polkit.qml
    LockPreview {}        // ПРЕВЬЮ экрана блокировки (без PAM): qs -c yumi ipc call lock preview
    LockReal {}           // НАСТОЯЩИЙ экран блокировки (WlSessionLock + PAM), вызывается через yumi-lock
}
