-- ~/.config/hypr/hyprland.lua — точка входа Hyprland.
-- 1) своя база ~/.config/hypr/yumi (окружение, вид, правила, бинды, раскладки, автозапуск, режим);
--    карта файлов и подсказки «как добавить бинд/правило/автозапуск» — в yumi/init.lua
-- 2) ниже — личные настройки: клавиатуры, мониторы, жесты, свои меню и правила; они главнее базы.
-- Hyprland стартует с этого файла: HYPRLAND_CONFIG задаёт ~/.config/uwsm/env-hyprland.d/90-yumi.sh

dofile((os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/yumi/init.lua")


-- === Мои настройки ===

-- Курсор (Bibata-Modern-Ice 20) и переменные окружения — в yumi/env.lua

hl.config({
	-- Монитор по умолчанию (свои мониторы задайте ниже, в блоке «Два монитора»)
	monitor = {
		"eDP-1, preferred, auto, 1.666667"
	},

	input = {

		kb_layout = "us,ru,ua",

		--kb_options = "grp:alt_shift_toggle",

		touchpad = {

			tap_to_click = false,

			clickfinger_behavior = true,

			natural_scroll = true,

			disable_while_typing = true,

		},

	},

	-- прозрачность окон — в yumi/look.lua (14.10: здесь были 0.95/0.85 со времён 2.5, их перебивал my_look)

	general = {
			layout = "dwindle",
			},
		-- раскладка master (SUPER+O: dwindle → scrolling → master)
		master = {
			mfact = 0.65,           -- главное окно слева = 65 % ширины монитора
			orientation = "left",   -- master-зона слева, стек остальных окон — справа
			new_status = "slave",   -- новые окна встают в стек справа, главное не заменяют
			new_on_top = false,     -- новое окно — внизу стека справа
		},

})

-- === Внешняя клавиатура Logitech PRO ===
-- Win и Alt поменяны местами только на ней: Super у пробела, как Cmd на MacBook.
-- В системе она видна двумя устройствами, поэтому правило на оба имени
for _, kb in ipairs({ "logitech-pro-gaming-keyboard", "logitech-pro-gaming-keyboard-1" }) do
	hl.device({
		name = kb,
		kb_layout = "us,ru,ua",
		kb_options = "altwin:swap_alt_win",
	})
end

-- Музыка и громкость с внешней клавиатуры: её Fn не доходит до системы (с Fn и без шлёт одно и то же),
-- поэтому медиа — на ALT + те же клавиши. SUPER+F10..F12 заняты скриншотами
local media = {
	{ "F9",          "playerctl play-pause",                   "play / pause" },
	{ "F10",         "playerctl stop",                         "stop" },
	{ "F11",         "playerctl previous",                     "previous track" },
	{ "F12",         "playerctl next",                         "next track" },
	{ "Print",       "yumi-volume -o m",                        "mute" },
	{ "Scroll_Lock", "yumi-volume -o d",                        "volume down" },
	{ "Pause",       "yumi-volume -o i",                        "volume up" },
}
for _, m in ipairs(media) do
	hl.bind("ALT + " .. m[1], hl.dsp.exec_cmd(m[2]), { description = "[Media] " .. m[3], repeating = (m[1] == "Scroll_Lock" or m[1] == "Pause") })
end

-- При входе в систему: сервер OpenRGB, цвет подсветки по обоям и Solaar для мыши
hl.on("hyprland.start", function()
	-- Сервер OpenRGB: устройства опрашиваются один раз, дальше цвет меняется мгновенно (--client)
	hl.exec_cmd("openrgb --server --server-port 6742")
	hl.exec_cmd(os.getenv("HOME") .. "/.config/yumi/colors/templates/scripts/keyboard.sh")
	-- Solaar в фоне: держит DPI и частоту мыши (встроенный профиль выключен)
	hl.exec_cmd("solaar --window=hide")
end)


-- === Два монитора (пример) ===
-- Это МОЯ конфигурация: MacBook Pro M1 + MSI G27C3F справа. Всё индивидуально —
-- имена выходов, режимы, позиции и масштаб подберите под своё железо
-- (`hyprctl monitors all`) и только потом раскомментируйте.
-- Внешний монитор по USB-C на MacBook M1 под Asahi работает благодаря проекту
-- dp-altmode от haripako: https://github.com/haripako/dp-altmode — спасибо автору!
--
-- -- MacBook: родное разрешение, масштаб 1.666667
-- hl.monitor({ output = "eDP-1", mode = "2560x1600@60", position = "0x0", scale = 1.666667 })
-- -- MSI справа (1536 = 2560 / 1.666667): 180 Гц, без масштабирования
-- hl.monitor({ output = "DP-1", mode = "1920x1080@180", position = "1536x0", scale = 1 })
--
-- -- Рабочие столы: 1–5 на MacBook, 6–10 на внешнем (по 5 на каждом, всегда видны в Waybar).
-- -- default: при подключении внешнего монитора открывается 6, а не первый свободный номер
-- for i = 1, 10 do
-- 	hl.workspace_rule({
-- 		workspace = tostring(i),
-- 		monitor = (i <= 5) and "eDP-1" or "DP-1",
-- 		default = (i == 1 or i == 6),
-- 		persistent = true,
-- 	})
-- end
--
-- Обои на мониторе, подключённом после старта, перерисовываются ниже (hl.on("monitor.added")) — для любого железа.

--hl.bind("SUPER + F",hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind("XF86KbdBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -d kbd_backlight set 10%+"), { locked = true, repeating = true })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("brightnessctl -d kbd_backlight set 10%-"), { locked = true, repeating = true })
-- Лупа на тачбаре (клавиша Search) — файловый менеджер Dolphin
hl.bind("XF86Search", hl.dsp.exec_cmd("dolphin"))
-- Кнопка ☕ на тачбаре: tiny-dfr шлёт KEY_F13, а раскладка xkb называет его XF86Tools (не "F13")
hl.bind("XF86Tools", hl.dsp.exec_cmd("@HOME@/.local/bin/yumi-caffeine toggle"))
-- Часы на тачбаре: tiny-dfr шлёт KEY_F14 (в xkb это XF86Launch5) — открыть/закрыть календарь, как клик по часам в Waybar
hl.bind("XF86Launch5", hl.dsp.exec_cmd("@HOME@/.local/bin/yumi-menu-calendar"))



-- kitty: прозрачность общая, как у всех окон (13.10: убрано своё правило 0.85/0.70)

-- Экран блокировки сразу при входе (автовход SDDM).
-- Флаг — страховка: если файл выполнится дважды за загрузку, hyprlock всё равно запустится один раз.
if not _G.yumi_lock_on_start then
	_G.yumi_lock_on_start = true
	hl.on("hyprland.start", function()
		hl.exec_cmd("hyprlock")
	end)
end

-- Меню выключения
hl.bind("SUPER + Escape", hl.dsp.exec_cmd("@HOME@/.local/bin/yumi-menu-session --center"), {description = "[Session] power menu"})

-- === Крышка MacBook (07.10) ===
-- Сон при закрытии решает ☕ «Не засыпать» (yumi-caffeine держит блокировку handle-lid-switch у systemd).
-- Закрыли: блокировка; есть внешний монитор → встроенный экран отключается (всё остаётся на внешнем),
-- нет → экран гаснет. Открыли: встроенный экран снова включён (параметры как в monitors.lua).
-- locked = true — срабатывает и на экране блокировки.
local LID = "Apple SMC power/lid events"
local function has_external()
	for _, m in ipairs(hl.get_monitors()) do
		if m.name ~= "eDP-1" then return true end
	end
	return false
end
hl.bind("switch:on:" .. LID, function()
	hl.exec_cmd("loginctl lock-session")
	if has_external() then
		hl.monitor({ output = "eDP-1", disabled = true })
	else
		hl.dispatch(hl.dsp.dpms({ action = "disable" }))
	end
end, { locked = true, description = "[Hardware] lid closed" })
hl.bind("switch:off:" .. LID, function()
	hl.monitor({ output = "eDP-1", disabled = false, mode = "2560x1600@60.0", position = "0x0", scale = 1.6, vrr = 0, reserved = { top = 38 } })
	hl.dispatch(hl.dsp.dpms({ action = "enable" }))
end, { locked = true, description = "[Hardware] lid opened" })

-- SUPER+N (центр уведомлений) убран по просьбе пользователя 07.10; был: yumi-cc-open --bind

-- Загрузка плагинов Hyprland (hyprexpo) при входе
hl.on("hyprland.start", function()
	-- плагины подключаются через hl.plugin.load (ниже)
end)

-- === Жесты 3 пальцами вверх/вниз (свои для каждого лейаута) ===
local function overview()
	hl.exec_cmd("@HOME@/.local/bin/yumi-menu-workspaces --center")
end


-- Здесь настраиваются действия для каждого лейаута
local gestures3 = {
	dwindle   = { down = overview },
	scrolling = { down = overview },
}

local function run_gesture(dir)
	local ws = hl.get_active_workspace()
	local layout = (ws and ws.tiled_layout) or "dwindle"
	local set = gestures3[layout] or gestures3.dwindle
	if set[dir] then set[dir]() end
end

hl.gesture({ fingers = 3, direction = "down", action = function() run_gesture("down") end })

-- Плагин обзора рабочих столов (ScrollOverview)
-- hl.plugin.load("/var/cache/hyprpm/<user>/hyprland-scroll-overview/scrolloverview.so")

-- Обзор рабочих столов
hl.bind("SUPER + grave", hl.dsp.exec_cmd("@HOME@/.local/bin/yumi-menu-system --center"), {description = "[Session] system menu"})

-- Размытие под центром управления и уведомлениями (как у окон)
hl.layer_rule({
  name = "swaync_blur",
  match = { namespace = "^swaync-.*" },
  blur = true,
  ignore_alpha = 0.5,
})

-- Плеер yumi-player (GTK4 + layer-shell): SUPER+M — по центру, повторно — закрыть
hl.bind("SUPER + M", hl.dsp.exec_cmd("@HOME@/.local/bin/yumi-player toggle --center"), {description = "[Media] player"})
-- Меню «Музыка» (yumi-music: mpv + YouTube Music): очередь, поиск, плейлисты
hl.bind("SUPER + SHIFT + M", hl.dsp.exec_cmd("@HOME@/.local/bin/yumi-menu-music --center"), {description = "[Media] music library"})

-- Размытие под окном плеера (как у центра управления)
hl.layer_rule({
  name = "yumi_player_blur",
  match = { namespace = "^yumi-player$" },
  blur = true,
  ignore_alpha = 0.5,
})

-- Меню yumi-panel (звук, Wi-Fi, Bluetooth, питание…): блюр под полупрозрачным фоном
hl.layer_rule({
  name = "yumi_panel_blur",
  match = { namespace = "^yumi-panel$" },
  blur = true,
  ignore_alpha = 0.1,   -- низкий порог: при плавном проявлении меню блюр не включается рывком на середине
  -- анимация открытия/закрытия — как у плеера; окно меню размер не меняет (см. yumipanel.py),
  -- поэтому анимация изменения размера слоя (та же layersIn) больше не срабатывает
})

-- Вид окон (рамки, отступы, скругление, прозрачность, размытие, session_lock_xray) — один файл yumi/look.lua.
-- 14.10: прежний my_look() отсюда убран (дублировал look.lua со времён HyDE 2.5); режимы workflows/*.lua
-- теперь могут менять вид (gaming/powersaver — без размытия и скругления). Откат: ~/.local/share/yumi-archive/look-merge-20261014

-- 13.10: мягкое проявление слоёв (Waybar после смены обоев появляется плавно, без рывка в конце).
-- Только кривая, ≈0,2 с; стиль анимации меню (popin) не меняется. Откат: удалить 2 строки ниже
hl.curve("yumiFade", { type = "bezier", points = { {0.25, 0.1}, {0.25, 1.0} } })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 2, bezier = "yumiFade" })

-- Тяжёлые программы: только после разблокировки (не мешают загрузке рабочего стола)
hl.on("hyprland.start", function()
	hl.exec_cmd([[sh -c 'sleep 6; while pgrep -x hyprlock >/dev/null; do sleep 1; done; sleep 30; Telegram -startintray &']])
end)

-- Обои при старте: без анимации перехода, пока открыт экран блокировки
hl.on("hyprland.start", function()
	hl.exec_cmd([[sh -c 'for i in $(seq 40); do awww query >/dev/null 2>&1 && break; sleep 0.5; done; sleep 2; awww img --transition-type none "$(readlink -f "$HOME/.cache/yumi/theme/wall.set")"']])
end)

-- Обои на мониторе, подключённом после старта (иначе там чёрный фон)
hl.on("monitor.added", function()
	hl.exec_cmd([[sh -c 'sleep 2; awww img --transition-type none "$(readlink -f "$HOME/.cache/yumi/theme/wall.set")"']])
end)


-- === Цвета только из обоев ===
-- Палитру (формат wallbash, режим «всегда тёмный») считает yumi-colors, применяет yumi/look.lua.
-- Сочетания клавиш (в т.ч. свои меню: SUPER+K, SUPER+V, SUPER+TAB, SUPER+/, SUPER+SHIFT+W,
-- CTRL+ALT+DELETE) — в yumi/binds.lua.

-- Рамки окон в тоне обоев (yumi-tone, хук 40-hypr-borders): поверх палитры look.lua, и после перезагрузки конфига
local function yumi_borders()
	local f = loadfile(os.getenv("HOME") .. "/.cache/yumi-tone/hypr-borders.lua")
	if f then pcall(f) end
end
yumi_borders()
hl.on("config.reloaded", yumi_borders)

-- Апплет NetworkManager не нужен: Wi-Fi и VPN — свои пилюли и меню (yumi-menu-wifi, yumi-menu-vpn);
-- база его не запускает. blueman-applet стартует из ~/.config/autostart: он агент сопряжения (окно PIN),
-- его значок в трее выключен настройкой blueman (StatusIcon).
