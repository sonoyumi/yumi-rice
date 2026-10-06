-- Hyprland loads this file when it is started without a config, and it prefers
-- it over hyprland.conf. HyDE loads it too, last, as the override layer below.
-- The block keeps the two apart: hyde.lua sets `hyde` on its first line, so it
-- runs only when this file is the entry point and HyDE has not been loaded.
-- Removing it leaves a session with a cursor and nothing else.
if not hyde then
	local share = os.getenv("XDG_DATA_HOME") or (os.getenv("HOME") .. "/.local/share")
	local entry = share .. "/hypr/hyde.lua"
	local handle = io.open(entry, "r")
	if not handle then
		error("HyDE is not installed at " .. entry .. ". Run install.sh -r, or point Hyprland at your own config.")
	end
	handle:close()
	dofile(entry)
end


-- === Мои настройки ===

-- Один курсор для всех: HyDE ставит Bibata 20 (hyprctl setcursor), а программы без
-- этих переменных брали размер 24 → после разблокировки мелькали два курсора разного размера
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "20")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "20")

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

	decoration = {

		active_opacity = 0.95,

		inactive_opacity = 0.85,

	},

	general = {
			layout = "dwindle",
			},
		--master = {
		--mfact = 0.60,          -- главное окно = 70% экрана
		--orientation = "left",  -- master-зона слева, стек — справа
		--new_status = "slave",  -- новые окна встают в стек справа, а не заменяют главное
	--},

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
-- поэтому медиа — на ALT + те же клавиши. SUPER+F10..F12 заняты скриншотами HyDE
local media = {
	{ "F9",          "playerctl play-pause",                   "play / pause" },
	{ "F10",         "playerctl stop",                         "stop" },
	{ "F11",         "playerctl previous",                     "previous track" },
	{ "F12",         "playerctl next",                         "next track" },
	{ "Print",       hyde.sh.volumecontrol("-o", "m"),         "mute" },
	{ "Scroll_Lock", hyde.sh.volumecontrol("-o", "d"),         "volume down" },
	{ "Pause",       hyde.sh.volumecontrol("-o", "i"),         "volume up" },
}
for _, m in ipairs(media) do
	hl.bind("ALT + " .. m[1], hl.dsp.exec_cmd(m[2]), { description = "[Media] " .. m[3], repeating = (m[1] == "Scroll_Lock" or m[1] == "Pause") })
end

-- При входе в систему: сервер OpenRGB, цвет подсветки по обоям и Solaar для мыши
hl.on("hyprland.start", function()
	-- Сервер OpenRGB: устройства опрашиваются один раз, дальше цвет меняется мгновенно (--client)
	hl.exec_cmd("openrgb --server --server-port 6742")
	hl.exec_cmd(os.getenv("HOME") .. "/.config/hyde/wallbash/scripts/keyboard.sh")
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
-- Меню rofi на внешнем мониторе уменьшает обёртка ~/.local/bin/rofi (DPI по имени монитора).

--hl.bind("SUPER + F",hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind("XF86KbdBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -d kbd_backlight set 10%+"), { locked = true, repeating = true })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("brightnessctl -d kbd_backlight set 10%-"), { locked = true, repeating = true })



hl.window_rule({ match = { class = "kitty" },   opacity = "0.85 override 0.70 override" })

-- Экран блокировки сразу при входе (автовход SDDM).
-- Этот файл выполняется ДВАЖДЫ (точка входа Hyprland + require("hyprland") в конце hyde.lua),
-- поэтому без флага обработчик регистрировался два раза → два hyprlock при входе. Флаг — один раз.
if not _G.yumi_lock_on_start then
	_G.yumi_lock_on_start = true
	hl.on("hyprland.start", function()
		hl.exec_cmd("hyprlock")
	end)
end

-- Меню выключения
hl.bind("SUPER + Escape", hl.dsp.exec_cmd("@HOME@/.local/bin/yumi-menu-session --center"), {description = "[Session] power menu"})

-- Меню rofi держат фокус клавиатуры, пока открыты (Esc работает при любом положении курсора)
hl.window_rule {
  name = "rofi_keep_focus",
  match = {
    class = "Rofi"
  },
  stay_focused = true
}
hl.bind("SUPER + N", hl.dsp.exec_cmd("@HOME@/.local/bin/cc-open --bind"), {description = "[Session] control center"})

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

-- Обзор рабочих столов
hl.bind("SUPER + grave", hl.dsp.exec_cmd("@HOME@/.local/bin/yumi-menu-system --center"), {description = "[Session] system menu"})

-- Рисовать рабочий стол под экраном блокировки: после разблокировки всё уже готово, без серого экрана
hl.config({ misc = { session_lock_xray = true } })

-- Прозрачность всех окон: 85% в фокусе, 75% без фокуса, полный экран — непрозрачно
hl.config({ decoration = { active_opacity = 0.85, inactive_opacity = 0.75, fullscreen_opacity = 1 } })

-- Меню rofi: 84% в фокусе, 78% без фокуса (прозрачнее, за ним размытие)
hl.window_rule {
  name = "rofi_opacity",
  match = { class = "Rofi" },
  opacity = "0.84 override 0.78 override",
  opaque = false
}

-- Размытие под центром управления и уведомлениями (как у окон)
hl.layer_rule({
  name = "swaync_blur",
  match = { namespace = "^swaync-.*" },
  blur = true,
  ignore_alpha = 0.5,
})

-- Плеер yumi-player (GTK4 + layer-shell): SUPER+M — по центру, повторно — закрыть
hl.bind("SUPER + M", hl.dsp.exec_cmd("@HOME@/.local/bin/yumi-player toggle --center"), {description = "[Media] player"})

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

-- === Мой вид окон: не зависит от темы HyDE (тема меняет только цвета) ===
local function my_look()
	hl.config({
		general = { border_size = 2, gaps_in = 3, gaps_out = 8 },
		misc = { session_lock_xray = true },
		decoration = {
			rounding = 10,
			rounding_power = 2,
			active_opacity = 0.85,
			inactive_opacity = 0.75,
			fullscreen_opacity = 1,
			shadow = { enabled = false },
			blur = { enabled = true, size = 6, passes = 3 },
		},
	})
end
my_look()
hl.on("config.reloaded", my_look)

-- Тяжёлые программы: только после разблокировки (не мешают загрузке рабочего стола)
hl.on("hyprland.start", function()
	hl.exec_cmd([[sh -c 'sleep 6; while pgrep -x hyprlock >/dev/null; do sleep 1; done; sleep 30; Telegram -startintray &']])
end)

-- Обои при старте: без анимации перехода, пока открыт экран блокировки
hl.on("hyprland.start", function()
	hl.exec_cmd([[sh -c 'for i in $(seq 40); do awww query >/dev/null 2>&1 && break; sleep 0.5; done; sleep 2; awww img --transition-type none "$(readlink -f "$HOME/.cache/hyde/wall.set")"']])
end)

-- Обои на мониторе, подключённом после старта (иначе там чёрный фон)
hl.on("monitor.added", function()
	hl.exec_cmd([[sh -c 'sleep 2; awww img --transition-type none "$(readlink -f "$HOME/.cache/hyde/wall.set")"']])
end)


-- === Цвета только из обоев ===
-- Wallbash в режиме «всегда тёмный» (enableWallDcol=2), темы HyDE убраны в ~/.local/share/hyde-themes-off.
-- Выбор темы и режима wallbash не нужен — остаются только обои (SUPER+SHIFT+W, SUPER+ALT+←/→)
hl.unbind("SUPER + SHIFT + T")
hl.unbind("SUPER + SHIFT + R")

-- === Раскладка: SUPER+K переключает СРАЗУ все клавиатуры (и на экране блокировки) ===
-- HyDE менял только «текущую» клавиатуру, а у Logitech два устройства — язык иногда не переключался
hl.unbind("SUPER + K")
hl.bind("SUPER + K", hl.dsp.exec_cmd("@HOME@/.local/bin/kb-switch"), { description = "[Utilities] toggle keyboard layout", locked = true })

-- === Выбор обоев: SUPER+SHIFT+W — GTK-меню yumi-panel (сетка миниатюр) вместо rofi HyDE ===
hl.unbind("SUPER + SHIFT + W")
hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("@HOME@/.local/bin/yumi-menu-wallpaper --center"), { description = "[Theming and Wallpaper] select a global wallpaper" })

-- === Буфер обмена: SUPER+V / SUPER+SHIFT+V — GTK-меню yumi-panel (поиск, миниатюры, закреп) ===
hl.unbind("SUPER + V")
hl.unbind("SUPER + SHIFT + V")
hl.bind("SUPER + V", hl.dsp.exec_cmd("@HOME@/.local/bin/yumi-menu-clipboard --center"), { description = "[Launcher|Rofi menus] clipboard" })
hl.bind("SUPER + SHIFT + V", hl.dsp.exec_cmd("@HOME@/.local/bin/yumi-menu-clipboard --center"), { description = "[Launcher|Rofi menus] clipboard manager" })

-- Калькулятор rofi не нужен (пакета rofi-calc нет) — сочетание свободно
hl.unbind("SUPER + SHIFT + K")

-- === Рабочие столы: SUPER+TAB — GTK-меню вместо переключателя окон HyDE (altab у нас не работал) ===
hl.unbind("SUPER + TAB")
hl.bind("SUPER + TAB", hl.dsp.exec_cmd("@HOME@/.local/bin/yumi-menu-workspaces --center"), { description = "[Workspaces] overview" })
-- остатки переключателя окон HyDE (altab): SUPER+SHIFT+TAB и отпускание SUPER — сняты
hl.unbind("SUPER + SHIFT + TAB")
hl.unbind("SUPER + SUPER_L")
hl.unbind("SUPER + SUPER_R")

-- SUPER+/ — режимы работы (workflow) в нашем меню «Питание» вместо старой rofi-панели menu-workflows
hl.unbind("SUPER + slash")
hl.bind("SUPER + slash", hl.dsp.exec_cmd("@HOME@/.local/bin/yumi-menu-power --center"), { description = "[Utils] workflows" })

-- SUPER+SHIFT+U (выбор макета hyprlock) при каждом шаге по списку запускает НАСТОЯЩИЙ hyprlock → faillock; снят
hl.unbind("SUPER + SHIFT + U")

-- === CTRL+ALT+DELETE — наше меню «Питание системы» вместо меню выхода HyDE ===
hl.unbind("CTRL + ALT + DELETE")
hl.bind("CTRL + ALT + DELETE", hl.dsp.exec_cmd("@HOME@/.local/bin/yumi-menu-session --center"), { description = "[Window Management] logout menu" })

-- Рамки окон в тоне обоев (yumi-tone, хук 40-hypr-borders): поверх цветов HyDE, и после перезагрузки конфига
local function yumi_borders()
	local f = loadfile(os.getenv("HOME") .. "/.cache/yumi-tone/hypr-borders.lua")
	if f then pcall(f) end
end
yumi_borders()
hl.on("config.reloaded", yumi_borders)

-- Апплет NetworkManager не нужен: Wi-Fi и VPN — свои пилюли и меню (yumi-menu-wifi, yumi-menu-vpn).
-- HyDE запускает его из hyde.config.start при событии hyprland.start — к этому моменту строка ниже уже выполнена.
-- blueman-applet остаётся: он агент сопряжения (окно PIN); его значок в трее выключен настройкой blueman (StatusIcon).
if hyde and hyde.config and hyde.config.start then
	hyde.config.start.applet_network_manager = nil
end
