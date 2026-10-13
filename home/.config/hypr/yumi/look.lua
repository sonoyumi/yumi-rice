-- yumi/look.lua — вид окон и общие опции (были defaults.lua, тема HyDE и dynamic.lua)
-- Свой «закреплённый» вид (my_look) остаётся в hyprland.lua и применяется поверх.

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
