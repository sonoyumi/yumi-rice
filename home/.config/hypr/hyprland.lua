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

	-- Настройка монитора MacBook (имя, разрешение, позиция, масштаб)
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

--hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind("XF86KbdBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -d kbd_backlight set 10%+"), { locked = true, repeating = true })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("brightnessctl -d kbd_backlight set 10%-"), { locked = true, repeating = true })



hl.window_rule({ match = { class = "kitty" },   opacity = "0.85 override 0.70 override" })

-- Экран блокировки сразу при входе (автовход SDDM)
hl.on("hyprland.start", function()
hl.exec_cmd("hyprlock")
end)

-- Меню выключения
hl.bind("SUPER + Escape", hl.dsp.exec_cmd("@HOME@/.local/bin/powermenu --center"), {description = "[Session] power menu"})

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
	hl.exec_cmd("@HOME@/.local/bin/menu-workspaces")
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
-- hl.plugin.load("/var/cache/hyprpm/yumi044/hyprland-scroll-overview/scrolloverview.so")

-- Обзор рабочих столов
hl.bind("SUPER + grave", hl.dsp.exec_cmd("@HOME@/.local/bin/menu-workspaces"), {description = "[Workspaces] overview"})

-- Обзор рабочих столов
hl.bind("SUPER + grave", hl.dsp.exec_cmd("@HOME@/.local/bin/menu-workspaces"), {description = "[Workspaces] overview"})

-- Рисовать рабочий стол под экраном блокировки: после разблокировки всё уже готово, без серого экрана
hl.config({ misc = { session_lock_xray = true } })

-- Прозрачность всех окон: 85% в фокусе, 75% без фокуса, полный экран — непрозрачно
hl.config({ decoration = { active_opacity = 0.85, inactive_opacity = 0.75, fullscreen_opacity = 1 } })

-- Меню rofi: 90% в фокусе, 85% без фокуса
hl.window_rule {
  name = "rofi_opacity",
  match = { class = "Rofi" },
  opacity = "0.90 override 0.85 override",
  opaque = false
}

-- Размытие под центром управления и уведомлениями (как у окон)
hl.layer_rule({
  name = "swaync_blur",
  match = { namespace = "^swaync-.*" },
  blur = true,
  ignore_alpha = 0.5,
})

-- Плеер
hl.bind("SUPER + M", hl.dsp.exec_cmd("@HOME@/.local/bin/menu-player --center"), {description = "[Media] player"})

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
	hl.exec_cmd([[sh -c 'sleep 6; while pgrep -x hyprlock >/dev/null; do sleep 1; done; sleep 30; telegram-desktop -startintray &']])
end)

-- Обои при старте: без анимации перехода, пока открыт экран блокировки
hl.on("hyprland.start", function()
	hl.exec_cmd([[sh -c 'for i in $(seq 40); do awww query >/dev/null 2>&1 && break; sleep 0.5; done; sleep 2; awww img --transition-type none "$(readlink -f "$HOME/.cache/hyde/wall.set")"']])
end)

