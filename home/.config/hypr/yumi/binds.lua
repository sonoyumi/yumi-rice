-- yumi/binds.lua — сочетания клавиш (были key_binds.lua HyDE + замены из hyprland.lua)
-- Все команды — свои (~/.local/bin); вызовов скриптов HyDE здесь больше нет.

local MOD = "SUPER"
local BIN = os.getenv("HOME") .. "/.local/bin/"
local exec = hl.dsp.exec_cmd

local function bind(combo, action, opts)
	hl.bind(combo, action, opts)
end

-- ── Вспомогательные действия ──

-- Полный экран по кругу: обычный → развернуть → полный
local function cycle_fullscreen()
	local win = assert(hl.get_active_window(), "нет активного окна")
	local state = ((tonumber(win.fullscreen) or 0) + 1) % 3
	hl.dispatch(hl.dsp.window.fullscreen_state({ internal = state, client = state, window = win }))
end

-- Плавающее окно — сдвиг на pix, плиточное — перестановка в сторону dir
local function move_window(dir, pix)
	local lut = { l = { -1, 0 }, r = { 1, 0 }, u = { 0, -1 }, d = { 0, 1 } }
	local m = lut[dir]
	return function()
		local args = hl.get_active_window().floating
			and { x = m[1] * pix, y = m[2] * pix, relative = true }
			or { direction = dir }
		hl.dispatch(hl.dsp.window.move(args))
	end
end

-- ── Программы ──
bind(MOD .. " + RETURN", exec(BIN .. "yumi-launch term"), { description = "[Launcher|Apps] terminal emulator" })
bind(MOD .. " + E", exec(BIN .. "yumi-launch open file-manager dolphin"), { description = "[Launcher|Apps] file explorer" })
bind(MOD .. " + B", exec(BIN .. "yumi-launch open web-browser zen-browser"), { description = "[Launcher|Apps] browser" })
bind(MOD .. " + C", exec("kwrite"), { description = "[Launcher|Apps] text editor" })
bind("CTRL + SHIFT + ESCAPE", exec(BIN .. "yumi-sysmon"), { description = "[Launcher|Apps] system monitor" })

-- ── Окна ──
bind(MOD .. " + Q", hl.dsp.window.close(), { description = "[Window Management] close focused window" })
bind("ALT + F4", hl.dsp.window.close(), { description = "[Window Management] close focused window" })
bind(MOD .. " + ALT + F4", hl.dsp.window.kill(), { description = "[Window Management] kill focused window" })
bind(MOD .. " + Delete", hl.dsp.exit(), { description = "[Window Management] exit hyprland session" })
bind(MOD .. " + W", hl.dsp.window.float({ action = "toggle" }), { description = "[Window Management] toggle float true" })
bind(MOD .. " + G", hl.dsp.group.toggle(), { description = "[Window Management] toggle group" })
-- ALT+P (псевдоплитка) снят 07.10: конфликт с zsh (Alt+P — поиск по истории)
bind(MOD .. " + F", cycle_fullscreen, { description = "[Window Management] cycle fullscreen" })
bind(MOD .. " + SHIFT + F", exec(BIN .. "yumi-window-pin"), { description = "[Window Management] toggle pin" })
bind("CTRL + ALT + DELETE", exec(BIN .. "yumi-menu-session --center"), { description = "[Window Management] logout menu" })
-- SUPER+CTRL+B (скрыть Waybar) снят 13.10 по просьбе пользователя. Вернуть:
-- bind(MOD .. " + CTRL + B", exec("systemctl --user kill -s SIGUSR1 waybar.service"), { description = "[Window Management] hide waybar" })
-- SUPER+N — блокировка (было SUPER+L; перенесено 07.10, SUPER+L свободен)
bind(MOD .. " + N", exec(BIN .. "yumi-lock"), { description = "[Window Management] lock session" })

bind(MOD .. " + CTRL + H", hl.dsp.group.prev(), { description = "[Window Management|Group Navigation] change active group backwards" })
bind(MOD .. " + CTRL + L", hl.dsp.group.next(), { description = "[Window Management|Group Navigation] change active group forwards" })

for _, d in ipairs({ { "Left", "left" }, { "Right", "right" }, { "Up", "up" }, { "Down", "down" } }) do
	bind(MOD .. " + " .. d[1], hl.dsp.focus({ direction = d[2] }), { description = "[Window Management|Change focus] focus " .. d[2] })
end

-- Размер: SUPER+SHIFT+CTRL+стрелки
local resize = { RIGHT = { 30, 0, "right" }, LEFT = { -30, 0, "left" }, UP = { 0, -30, "up" }, DOWN = { 0, 30, "down" } }
for key, r in pairs(resize) do
	bind(MOD .. " + SHIFT + CONTROL + " .. key, hl.dsp.window.resize({ x = r[1], y = r[2], relative = true }),
		{ description = "[Window Management|Resize Active Window] resize window " .. r[3], repeating = true })
end
-- Перемещение: SUPER+SHIFT+стрелки
for key, d in pairs({ LEFT = { "l", "left" }, RIGHT = { "r", "right" }, UP = { "u", "up" }, DOWN = { "d", "down" } }) do
	bind(MOD .. " + SHIFT + " .. key, move_window(d[1], 30),
		{ description = "[Window Management|Move active window] " .. d[2], repeating = true })
end

bind(MOD .. " + mouse:272", hl.dsp.window.drag(), { description = "[Window Management|Drag & Resize with mouse] drag window", mouse = true })
bind(MOD .. " + mouse:273", hl.dsp.window.resize(), { description = "[Window Management|Drag & Resize with mouse] resize window", mouse = true })
bind(MOD .. " + Z", hl.dsp.window.drag(), { description = "[Window Management|Drag & Resize with mouse] hold to move window", mouse = true })
bind(MOD .. " + X", hl.dsp.window.resize(), { description = "[Window Management|Drag & Resize with mouse] hold to resize window", mouse = true })

-- ── Меню ──
bind(MOD .. " + A", exec(BIN .. "yumi-menu-launcher --center"), { description = "[Launcher|Menus] application finder" })
bind(MOD .. " + SHIFT + E", exec(BIN .. "yumi-menu-launcher --files --center"), { description = "[Launcher|Menus] file finder" })
-- Пульт (как Spotlight, Cmd+Space на MacBook): программы, команды Yumi, файлы, счёт, эмодзи, веб — одним окном.
-- SUPER+Space был свободен (13.10); раскладка — SUPER+K, у Logitech Win↔Alt — Super всё равно у пробела
bind(MOD .. " + SPACE", exec(BIN .. "yumi-pult --center"), { description = "[Launcher|Menus] Yumi pult — search everything" })
-- SUPER+SHIFT+A (выбор стиля rofi) снят 13.10: меню программ теперь GTK4 (yumi-menu-launcher)
bind(MOD .. " + SHIFT + slash", exec(BIN .. "yumi-menu-websearch --center"), { description = "[Launcher|Rofi menus] Web Search" })
bind(MOD .. " + comma", exec(BIN .. "yumi-menu-picker --emoji --center"), { description = "[Launcher|Menus] emoji picker" })
bind(MOD .. " + period", exec(BIN .. "yumi-menu-picker --glyph --center"), { description = "[Launcher|Menus] glyph picker" })
-- Буфер обмена — GTK-меню yumi-panel (поиск, миниатюры, закреп)
bind(MOD .. " + V", exec(BIN .. "yumi-menu-clipboard --center"), { description = "[Launcher|Rofi menus] clipboard" })
bind(MOD .. " + SHIFT + V", exec(BIN .. "yumi-menu-clipboard --center"), { description = "[Launcher|Rofi menus] clipboard manager" })
-- Режимы работы (workflow) — в меню «Питание»
bind(MOD .. " + slash", exec(BIN .. "yumi-menu-power --center"), { description = "[Utils] workflows" })
-- Рабочие столы — GTK-меню (переключатель окон HyDE altab у нас не работал)
bind(MOD .. " + TAB", exec(BIN .. "yumi-menu-workspaces --center"), { description = "[Workspaces] overview" })
-- SUPER+SHIFT+K (калькулятор rofi) снят: пакета rofi-calc нет

-- ── Звук, медиа, яркость ──
bind("XF86AudioMute", exec(BIN .. "yumi-volume -o m"), { description = "[Hardware Controls|Audio] un/mute output", locked = true })
bind("XF86AudioMicMute", exec(BIN .. "yumi-volume -i m"), { description = "[Hardware Controls|Audio] un/mute microphone", locked = true })
bind("XF86AudioLowerVolume", exec(BIN .. "yumi-volume -o d"), { description = "[Hardware Controls|Audio] decrease volume", locked = true, repeating = true })
bind("XF86AudioRaiseVolume", exec(BIN .. "yumi-volume -o i"), { description = "[Hardware Controls|Audio] increase volume", locked = true, repeating = true })

bind("XF86AudioPlay", exec("playerctl play-pause"), { description = "[Hardware Controls|Media] play media", locked = true })
bind("XF86AudioPause", exec("playerctl play-pause"), { description = "[Hardware Controls|Media] pause media", locked = true })
bind("XF86AudioNext", exec("playerctl next"), { description = "[Hardware Controls|Media] next media", locked = true })
bind("XF86AudioPrev", exec("playerctl previous"), { description = "[Hardware Controls|Media] previous media", locked = true })
bind(MOD .. " + CONTROL + M", exec(BIN .. "yumi-window-mute"), { description = "[Hardware Controls|Media] toggle un/mute for active-window" })

bind("XF86MonBrightnessUp", exec(BIN .. "yumi-brightness i"), { description = "[Hardware Controls|Brightness] increase brightness", locked = true, repeating = true })
bind("XF86MonBrightnessDown", exec(BIN .. "yumi-brightness d"), { description = "[Hardware Controls|Brightness] decrease brightness", locked = true, repeating = true })

-- ── Утилиты ──
-- Раскладка: сразу на всех клавиатурах (у Logitech два устройства), и на экране блокировки
bind(MOD .. " + K", exec(BIN .. "yumi-kb-switch"), { description = "[Utilities] toggle keyboard layout", locked = true })
-- SUPER+ALT+G (игровой режим HyDE) снят 13.10: был сломан; режим «Игры» — в меню «Питание» (SUPER+/)
-- SUPER+SHIFT+G (каталог игр HyDE) снят 13.10: Steam удалён
bind(MOD .. " + SHIFT + P", exec("hyprpicker -an"), { description = "[Utilities|Screen Capture] color picker", locked = true })
bind(MOD .. " + F10", exec(BIN .. "yumi-screenshot s"), { description = "[Utilities] partial screenshot capture", locked = true })
bind(MOD .. " + F11", exec(BIN .. "yumi-screenshot sf"), { description = "[Utilities] freeze and snip screen", locked = true })
bind(MOD .. " + F12", exec(BIN .. "yumi-screenshot m"), { description = "[Utilities] print monitor", locked = true })
bind("Print", exec(BIN .. "yumi-screenshot p"), { description = "[Utilities] print all monitors", locked = true })
bind(MOD .. " + CONTROL + S", exec(BIN .. "yumi-screenshot sc"), { description = "[Utilities] OCR scanner", locked = true })

-- ── Обои и режимы ──
-- Обои по кругу в папке ~/Pictures/Wallpapers; цвета всего стола пересчитываются следом (yumi-colors)
bind(MOD .. " + ALT + Right", exec(BIN .. "yumi-wallpaper next"), { description = "[Theming and Wallpaper] next global wallpaper" })
bind(MOD .. " + ALT + Left", exec(BIN .. "yumi-wallpaper prev"), { description = "[Theming and Wallpaper] previous global wallpaper" })
bind(MOD .. " + ALT + Up", exec(BIN .. "yumi-workflow next"), { description = "[Theming and Wallpaper] next workflow" })
bind(MOD .. " + ALT + Down", exec(BIN .. "yumi-workflow prev"), { description = "[Theming and Wallpaper] previous workflow" })
-- Выбор обоев — GTK-меню yumi-panel (сетка миниатюр)
bind(MOD .. " + SHIFT + W", exec(BIN .. "yumi-menu-wallpaper --center"), { description = "[Theming and Wallpaper] select a global wallpaper" })
-- SUPER+SHIFT+Y (выбор анимаций HyDE) снят 13.10: в своей базе ни на что не влиял
-- Сняты: SUPER+SHIFT+T/R (темы HyDE и режим wallbash — цвета только из обоев),
-- SUPER+SHIFT+U (выбор макета hyprlock запускал настоящий hyprlock → faillock)

-- ── Рабочие столы ──
-- Цифровой блок — столы 11–20: каждая клавиша под обоими именами (Num Lock вкл/выкл)
local kp = {
	{ "KP_1", "KP_End" }, { "KP_2", "KP_Down" }, { "KP_3", "KP_Next" }, { "KP_4", "KP_Left" }, { "KP_5", "KP_Begin" },
	{ "KP_6", "KP_Right" }, { "KP_7", "KP_Home" }, { "KP_8", "KP_Up" }, { "KP_9", "KP_Prior" }, { "KP_0", "KP_Insert" },
}
for i = 1, 10 do
	local key = (i == 10) and 0 or i
	bind(MOD .. " + " .. key, hl.dsp.focus({ workspace = i }), { description = "[Workspaces|Navigation] navigate to workspace " .. i })
	bind(MOD .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }),
		{ description = "[Workspaces|Move window to workspace] move focused window to workspace " .. i })
	bind(MOD .. " + ALT + " .. key, hl.dsp.window.move({ workspace = i, follow = false }),
		{ description = "[Workspaces|Move window (Don't follow)] move focused window to workspace " .. i })
	for _, k in ipairs(kp[i]) do
		bind(MOD .. " + " .. k, hl.dsp.focus({ workspace = tostring(i + 10) }),
			{ description = "[Workspaces|Navigation] navigate to workspace " .. (i + 10) })
		bind(MOD .. " + SHIFT + " .. k, hl.dsp.window.move({ workspace = tostring(i + 10) }),
			{ description = "[Workspaces|Move window to workspace] move focused window to workspace " .. (i + 10) })
	end
end

bind(MOD .. " + CONTROL + RIGHT", hl.dsp.focus({ workspace = "r+1" }), { description = "[Workspaces|Navigation|Relative workspace] change active workspace forwards" })
bind(MOD .. " + CONTROL + LEFT", hl.dsp.focus({ workspace = "r-1" }), { description = "[Workspaces|Navigation|Relative workspace] change active workspace backwards" })
bind(MOD .. " + CONTROL + DOWN", hl.dsp.focus({ workspace = "empty" }), { description = "[Workspaces|Navigation] navigate to the nearest empty workspace" })
bind(MOD .. " + CONTROL + ALT + RIGHT", hl.dsp.window.move({ workspace = "r+1" }), { description = "[Workspaces|Move window to workspace|Relative workspace] move focused window to next workspace" })
bind(MOD .. " + CONTROL + ALT + LEFT", hl.dsp.window.move({ workspace = "r-1" }), { description = "[Workspaces|Move window to workspace|Relative workspace] move focused window to previous workspace" })
bind(MOD .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "[Workspaces|Navigation|Mouse] next workspace" })
bind(MOD .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { description = "[Workspaces|Navigation|Mouse] previous workspace" })

-- Спецстол (scratchpad)
bind(MOD .. " + S", hl.dsp.workspace.toggle_special(), { description = "[Workspaces|Navigation|Special workspace] toggle scratchpad" })
bind(MOD .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special" }), { description = "[Workspaces|Navigation|Special workspace] move focused window to scratchpad" })
bind(MOD .. " + ALT + S", hl.dsp.window.move({ workspace = "special", follow = false }), { description = "[Workspaces|Navigation|Special workspace] move focused window silently to scratchpad" })


-- ── Раскладки окон ──
-- SUPER+O: по кругу dwindle → scrolling → master
bind(MOD .. " + O", function()
	local nxt = { dwindle = "scrolling", scrolling = "master", master = "dwindle" }
	local new = nxt[tostring(hl.get_config("general.layout"))] or "dwindle"
	hl.config({ general = { layout = new } })
	hl.exec_cmd("notify-send -t 1500 'Раскладка' '" .. new .. "'")
end, { description = "[Layout] cycle dwindle / scrolling / master" })

-- SUPER+J: в dwindle — ориентация сплита, в scrolling — направление ленты
bind(MOD .. " + J", function()
	local ws = hl.get_active_workspace()
	if not ws then
		return
	end
	if ws.tiled_layout == "dwindle" then
		hl.dispatch(hl.dsp.layout("togglesplit"))
	elseif ws.tiled_layout == "scrolling" then
		local dir = tostring(hl.get_config("scrolling.direction"))
		local new = (dir == "down" or dir == "up") and "right" or "down"
		hl.config({ scrolling = { direction = new } })
		hl.exec_cmd("notify-send -t 1500 'Scrolling' '" .. new .. "'")
	end
end, { description = "[Layout] toggle split / scroll direction" })
