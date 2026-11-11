# Yumi Quickshell — правила для всех, кто сюда пишет

Это оболочка yumi-rice 3.1 на Quickshell 0.3.2 (Qt 6.12, QML). Она заменяет Waybar, swaync и часть GTK-меню yumi-panel.
Ноутбук: MacBook M1, Arch ARM, Hyprland 0.56 (конфиг на Lua в ~/.config/hypr/yumi), 8 ГБ, экран eDP-1 scale 1.6.

## Структура
    shell.qml              корень: ShellRoot { Bar {} Notifications {} Osd {} ... }
    Theme.qml              размеры, шрифты, кривые, длительности — ЕДИНСТВЕННОЕ место для стиля
    Colors.qml             цвета из обоев (colors.json от yumi-colors), имена как в Waybar: acc, bg, deep, hover, fg, pry1..4, txt1..4
    Signals.qml            IPC: qs -c yumi ipc call bar refresh <имя>  (вместо pkill -RTMIN+N waybar)
    components/            Pill, Glyph, ScriptText, BarScript (обёртка над скриптами Waybar-формата), Popup (окно под баром), Pango.js
    bar/Bar.qml            бар; bar/modules/*.qml — модули
    notifications/         всплывашки, центр, журнал (агент «уведомления»)
    osd/                   громкость/яркость/раскладка (агент «OSD»)
    menus/<имя>/           меню на QML; логика остаётся в Python-бэкендах (см. ниже)
    services/              синглтоны-сервисы (Network, Bt, Audio, Power…) — общие для бара и меню

Импорты: `import qs` (корень), `import qs.components`, `import qs.bar.modules`, `import qs.services`. Новая папка = свой `qmldir`.

## Стиль (не выдумывать своё — брать из Theme/Colors)
- Пилюли и карточки: стекло Colors.bg 0.78→0.62 с кромкой Colors.acc 0.18 (hover 0.30). Меню: Colors.mix(Colors.deep, Colors.bg, 0.5) с Theme.glass (тон бара; pry2 не брать — может быть другого оттенка), radius Theme.radiusBig.
- Шрифты: Theme.fontUi (JetBrainsMono Nerd Font) 13 px, значки Theme.fontIcon 17 px через `Glyph`, YumiIcons — `Glyph { yumi: true }`.
- Движение: Behavior на width/height/opacity/scale/color. Открытие — scale 0.85→1 + opacity с Theme.easeSpring, закрытие — Theme.fast.
  Списки — каскад (delay 40 мс на строку). Нажатие — scale 0.96. Цвета — ColorAnimation Theme.normal (смена обоев перекрашивает плавно).
- Ничего не мигает и не прыгает: у текста, который меняет длину, фиксируй Layout.minimumWidth.
- Все подписи по-русски, как в существующих меню (брать дословно из ~/.local/bin/yumi-menu-*).

## Логика: Python остаётся
Не переписывать парсинг nmcli/pactl/bluetoothctl/UPower. Схема: Python-бэкенд печатает JSON-строки (поток или по запросу),
QML читает через `Process` + `SplitParser`; команды — `Quickshell.execDetached([...])` или stdin процесса.
Бэкенды класть в ~/.local/lib/yumi/qs/<имя> (python3 -I, без root). Сухой прогон: переменная YP_DRYRUN=1 — команды, меняющие
сеть/звук/питание, только печатаются. Скрипты пилюль ~/.local/lib/yumi/bar/* уже используются через BarScript — не дублировать.
Штатные модули Quickshell, которые можно брать вместо скриптов: Quickshell.Hyprland, Services.Pipewire, Services.UPower,
Services.SystemTray, Services.Mpris, Services.Notifications, Bluetooth, Networking (NetworkManager), Io.

## Как проверять (ОБЯЗАТЕЛЬНО перед «готово»)
Тесты — ТОЛЬКО на eDP-1 (макбук): на DP-1 (MSI) пользователь смотрит видео, туда никаких окон, курсора и смены системной громкости.
Окружение в Bash: `export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-1 HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/$(id -u)/hypr | head -1)`
- Свой экземпляр: точка входа `dev-<имя>.qml` В КОРНЕ этой папки (иначе `import qs` не найдётся), запуск
  `setsid qs -p ~/.config/quickshell/yumi/dev-<имя>.qml > /tmp/qs-<имя>.log 2>&1 &`, остановка `qs kill -p ~/.config/quickshell/yumi/dev-<имя>.qml`.
  НИКОГДА `pkill -x qs` / `pkill -f qs` — убьёт чужие экземпляры и свою оболочку. Основной бар (dev-режим, под Waybar) уже запущен — не трогать.
- Основной экземпляр (служба yumi-qs-dev сейчас, yumi-quickshell после переключения) НЕ перечитывает файлы на лету (watchFiles: false — горячая перезагрузка роняет Quickshell 0.3.2 в QWindow::setScreen). Применить правки к нему: `systemctl --user restart yumi-qs-dev` (или yumi-quickshell). Свои dev-*.qml перезагружаются как раньше.
- Журнал: в нём не должно быть WARN/ReferenceError/TypeError. `YUMI_QS_DEV=1` — бар смещён на 38 px вниз, под Waybar.
- Снимок: `grim -g "X,Y WxH" /tmp/<имя>.png` (координаты в физических пикселях, scale 1.6: бар dev = y 60..122) и посмотреть файл.
- Не запускать настоящий hyprlock, не выключать Waybar/swaync, не перезагружать Hyprland (гасит экраны), не трогать сеть/звук без YP_DRYRUN.
- Память: `ps -o rss= -p $(pgrep -x qs)` — экземпляр не должен расти со временем (следить за Process без выхода).

## Git
Папка — git-репозиторий. Коммитить свои файлы по готовности куска: `git add <свои пути> && git commit -m "qs: <что>"`.
Только свои пути; Theme.qml/Colors.qml/Bar.qml не править без нужды — если нужно, минимальная правка и сказать в отчёте.
Без строк Co-Authored-By и подписей. Сообщения коммитов по-русски.

## Откат
`yumi-uninstall quickshell` (скрипт в ~/.local/share/yumi-archive/uninstall/yumi-quickshell-uninstall) должен уметь убрать всё,
что ты добавил вне этой папки: пиши туда строки удаления своих файлов/юнитов в раздел «# агенты».
