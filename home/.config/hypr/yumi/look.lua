-- yumi/look.lua — вид окон и общие опции (были defaults.lua, тема HyDE и dynamic.lua).
-- 14.10: единственный файл вида — my_look() из hyprland.lua сюда объединён (rounding_power, session_lock_xray).
-- Грузится до workflow.lua, поэтому режимы (gaming, powersaver, snappy…) могут менять эти значения.

local FONT, FONT_SIZE = "Cantarell", 10

hl.config({
	general = {
		border_size = 2,
		gaps_in = 3,
		gaps_out = 8,
		layout = "dwindle",
		resize_on_border = true,
		snap = {
			enabled = true,
			border_overlap = true,
			monitor_gap = 1,
			respect_gaps = true,
			window_gap = 1,
		},
	},
	decoration = {
		rounding = 10,
		rounding_power = 2,         -- из my_look (14.10)
		dim_special = 0.3,
		active_opacity = 0.75,      -- как в «Моих настройках» hyprland.lua (13.10)
		inactive_opacity = 0.65,
		fullscreen_opacity = 1,
		screen_shader = "",
		shadow = { enabled = false },
		blur = {
			enabled = true,
			size = 3,              -- слабое размытие по просьбе пользователя (13.10; было 6, потом 4)
			passes = 2,
			special = true,
			-- xray: размытие считается один раз по обоям и кэшируется. Без него Hyprland не успевал к такту
			-- MSI 165 Гц (82–119 к/с); с ним ~157 к/с, 96–98 % кадров вовремя (замер 13.10.2026)
			xray = true,
			ignore_opacity = true,
			new_optimizations = true,
		},
	},
	input = {
		accel_profile = "flat",
		numlock_by_default = true,
	},
	dwindle = {
		preserve_split = true,
	},
	misc = {
		session_lock_xray = true,   -- рисовать рабочий стол под экраном блокировки: после разблокировки всё готово
		vrr = 0,
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		force_default_wallpaper = 0,
		anr_missed_pings = 5,
		allow_session_lock_restore = true,
		font_family = FONT,
	},
	xwayland = {
		force_zero_scaling = true,
	},
	group = {
		groupbar = {
			font_size = FONT_SIZE,
			font_family = FONT,
		},
	},
})

-- ── Цвета из обоев ──
-- Палитру считает yumi-colors (тот же формат, что у wallbash HyDE) в ~/.local/state/yumi/colors.lua.
-- Рамки окон поверх красит yumi-tone (hyprland.lua). При смене обоев конфиг НЕ перезагружается целиком
-- (это роняет кадры анимации обоев): yumi-colors зовёт `hyprctl eval 'yumi.apply_palette()'`.
local palette_file = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state"))
	.. "/yumi/colors.lua"

-- with_borders: при загрузке конфига ставим и рамки (их потом перекрашивает yumi-tone), при смене обоев — нет
function yumi.apply_palette(with_borders)
	local chunk = loadfile(palette_file)
	local ok, c = false, nil
	if chunk then
		ok, c = pcall(chunk)
	end
	if not (ok and type(c) == "table" and c._pry1_rgba) then
		hl.exec_cmd("hyprctl seterror 'rgba(c79bf0ff)' '[yumi] нет палитры обоев: " .. palette_file .. "'")
		return false
	end
	local function grad(...)
		return { colors = { ... }, angle = 45 }
	end
	local cfg = {
		group = {
			groupbar = {
				enabled = true,
				gradients = 1,
				render_titles = 1,
				font_weight_inactive = "normal",
				font_weight_active = "semibold",
				blur = true,
				text_color = "rgba(" .. c._txt3 .. "ee)",
				text_color_inactive = "rgba(" .. c._txt1 .. "ee)",
				col = {
					active = grad(c._pry3_rgba),
					inactive = grad(c._pry1_rgba),
					locked_active = grad(c._pry2_rgba),
					locked_inactive = grad(c._pry4_rgba),
				},
			},
		},
		misc = {
			background_color = c._pry1_rgba,
		},
	}
	if with_borders then
		cfg.general = {
			col = {
				active_border = grad(c._pry4_rgba, c._4xa1_rgba),
				inactive_border = grad(c._pry1_rgba, c._pry2_rgba),
			},
		}
		cfg.group.col = {
			border_active = grad(c._pry4_rgba, c._pry2_rgba),
			border_inactive = grad(c._pry1_rgba, c._pry3_rgba),
			border_locked_active = grad(c._txt3_rgba, c._txt4_rgba),
			border_locked_inactive = grad(c._txt1_rgba, c._txt2_rgba),
		}
	end
	hl.config(cfg)
	return true
end

yumi.apply_palette(true)

-- ── Настройки из меню (yumi-menu-settings, SUPER+I; 14.10) ──
-- ~/.local/state/yumi/settings.lua пишет меню «Настройки». Вид применяется здесь, в базе, поэтому режимы
-- workflows/*.lua (грузятся позже) могут его перекрыть. Ввод, курсор и мониторы — yumi.apply_settings_late()
-- в конце hyprland.lua, после личных hl.config/hl.monitor. Нет файла — ничего не меняется. Откат: yumi-uninstall settings
local settings_file = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/yumi/settings.lua"
yumi.settings = {}
do
	local chunk = loadfile(settings_file)
	if chunk then
		local ok, t = pcall(chunk)
		if ok and type(t) == "table" then
			yumi.settings = t
		end
	end
end
do
	local s = yumi.settings.look
	if s then
		hl.config({
			general = { gaps_in = s.gaps_in, gaps_out = s.gaps_out },
			decoration = {
				rounding = s.rounding,
				active_opacity = s.active_opacity,
				inactive_opacity = s.inactive_opacity,
				shadow = { enabled = s.shadow },
				blur = { enabled = (s.blur or 1) > 0, size = math.max(s.blur or 1, 1) },
			},
		})
		if s.animations == false then
			dofile(yumi.dir .. "/anim-off.lua")
		end
	end
end

function yumi.apply_settings_late()
	local t = yumi.settings
	if t.input then
		hl.config({ input = {
			sensitivity = t.input.sensitivity,
			touchpad = {
				tap_to_click = t.input.tap_to_click,
				natural_scroll = t.input.natural_scroll,
				disable_while_typing = t.input.disable_while_typing,
			},
		} })
	end
	if t.cursor_size and t.cursor_size ~= 20 then
		hl.env("XCURSOR_SIZE", tostring(t.cursor_size))
		hl.env("HYPRCURSOR_SIZE", tostring(t.cursor_size))
		hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice " .. tostring(t.cursor_size))
	end
	for name, m in pairs(t.monitors or {}) do
		hl.monitor({ output = name, mode = m.mode, position = m.position, scale = m.scale, vrr = 0,
			reserved = { top = m.reserved_top or 38 } })
	end
end
