-- ┌──────────────────────────────────────────────────────────────────────────────┐
-- │ yumi — своя база Hyprland (Lua-конфиг, Hyprland 0.56+), без HyDE              │
-- └──────────────────────────────────────────────────────────────────────────────┘
-- Подключается первой строкой ~/.config/hypr/hyprland.lua. Файлы грузятся по порядку,
-- каждый следующий может переопределить предыдущий:
--
--   lib.lua        помощники: yumi.lib.any(), замена повторных биндов, размер плавающих окон
--   env.lua        переменные окружения сеанса, курсор
--   look.lua       вид окон: рамки, отступы, скругление, размытие, прозрачность; цвета из обоев
--   rules.lua      правила окон и слоёв (что плавает, что поверх, где размытие)
--   binds.lua      сочетания клавиш
--   layout.lua     раскладки (master/dwindle/scrolling) и жесты тачпада
--   events.lua     реакции на события (открытие окна, выход из сеанса)
--   autostart.lua  что делается при входе (сами программы — службы systemd, см. файл)
--   ../monitors.lua  мониторы от nwg-displays, если файл есть
--   workflow.lua   режим работы (workflows/*.lua), выбор: yumi-workflow set ИМЯ
--   → затем ~/.config/hypr/hyprland.lua — личные настройки поверх всего этого
--
-- Как поменять или добавить (лучше в hyprland.lua — тогда база остаётся общей):
--   опцию        hl.config({ general = { gaps_out = 12 } })
--                текущее значение: hyprctl getoption general.gaps_out ; вики: wiki.hypr.land/Configuring
--   бинд         hl.bind("SUPER + T", hl.dsp.exec_cmd("kitty"), { description = "[Apps] terminal" })
--                тот же бинд ещё раз — заменяет прежний (lib.lua); снять: hl.unbind("SUPER + T")
--   правило окна hl.window_rule({ name = "my_rule", match = { class = "^(pavucontrol)$" }, float = true })
--                класс окна: hyprctl clients | grep class
--   автозапуск   долгоживущая программа — служба systemd --user с WantedBy=graphical-session.target;
--                разовая команда при входе — hl.on("hyprland.start", function() hl.exec_cmd("...") end)
--   режим        скопировать workflows/editing.lua под новым именем и поправить —
--                появится в `yumi-workflow list` и меню «Питание»
-- Проверить конфиг без перезагрузки:  Hyprland --verify-config -c ~/.config/hypr/hyprland.lua
-- Перечитать:  hyprctl reload ;  ошибки:  hyprctl configerrors

yumi = {}
yumi.dir = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/yumi"
yumi.lib = dofile(yumi.dir .. "/lib.lua")

for _, part in ipairs({ "env", "look", "rules", "binds", "layout", "events", "autostart" }) do
	dofile(yumi.dir .. "/" .. part .. ".lua")
end

-- Мониторы от nwg-displays (если есть файл)
local monitors = yumi.dir .. "/../monitors.lua"
local probe = io.open(monitors, "r")
if probe then
	probe:close()
	dofile(monitors)
end

dofile(yumi.dir .. "/workflow.lua")
