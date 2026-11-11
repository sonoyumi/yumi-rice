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
bind(MOD .. " + B", exec(BIN .. "yumi-launch open web-browser chromium"), { description = "[Launcher|Apps] browser" })
bind(MOD .. " + Y", exec(BIN .. "yumi-youtube"), { description = "[Launcher|Apps] YumiTube (YouTube)" })   -- 11.11
bind(MOD .. " + SHIFT + C", exec("kwrite"), { description = "[Launcher|Apps] text editor" })   -- 16.10: было SUPER+C (теперь центр управления)
bind("CTRL + SHIFT + ESCAPE", exec(BIN .. "yumi-sysmon"), { description = "[Launcher|Apps] system monitor" })

-- ── Окна ──
bind(MOD .. " + Q", hl.dsp.window.close(), { description = "[Window Management] close focused window" })
bind("ALT + F4", hl.dsp.window.close(), { description = "[Window Management] close focused window" })
bind(MOD .. " + ALT + F4", hl.dsp.window.kill(), { description = "[Window Management] kill focused window" })
bind(MOD .. " + Delete", exec("qs -c yumi ipc call menu center session"), { description = "[Window Management] logout menu" })
bind(MOD .. " + W", hl.dsp.window.float({ action = "toggle" }), { description = "[Window Management] toggle float true" })
bind(MOD .. " + G", hl.dsp.group.toggle(), { description = "[Window Management] toggle group" })
-- ALT+P (псевдоплитка) снят 07.10: конфликт с zsh (Alt+P — поиск по истории)
bind(MOD .. " + F", cycle_fullscreen, { description = "[Window Management] cycle fullscreen" })
bind(MOD .. " + SHIFT + F", exec(BIN .. "yumi-window-pin"), { description = "[Window Management] toggle pin" })
bind("CTRL + ALT + DELETE", exec("qs -c yumi ipc call menu center session"), { description = "[Window Management] logout menu" })
-- SUPER+N — блокировка (было SUPER+L; перенесено 07.10, SUPER+L свободен)
bind(MOD .. " + N", exec(BIN .. "yumi-lock"), { description = "[Window Management] lock session" })

-- SUPER+CTRL+H (группа назад) отдан меню AirPods 19.10 по просьбе пользователя. Вернуть:
-- bind(MOD .. " + CTRL + H", hl.dsp.group.prev(), { description = "[Window Management|Group Navigation] change active group backwards" })
bind(MOD .. " + CTRL + L", hl.dsp.group.next(), { description = "[Window Management|Group Navigation] change active group forwards" })

-- 19.10: в monocle SUPER+←/→ листают окна стола (cycleprev/cyclenext) — соседа по направлению там нет,
-- и фокус уходил на другой монитор (как будто переключался стол). Бэкап: binds.lua.bak-monocle-20261019
local monocle_cycle = { left = "cycleprev", right = "cyclenext" }
for _, d in ipairs({ { "Left", "left" }, { "Right", "right" }, { "Up", "up" }, { "Down", "down" } }) do
	local cyc = monocle_cycle[d[2]]
	if cyc then
		bind(MOD .. " + " .. d[1], function()
			local ws = hl.get_active_workspace()
			if ws and ws.tiled_layout == "monocle" then
				hl.dispatch(hl.dsp.layout(cyc))
			else
				hl.dispatch(hl.dsp.focus({ direction = d[2] }))
			end
		end, { description = "[Window Management|Change focus] focus " .. d[2] .. " (monocle: " .. cyc .. ")" })
	else
		bind(MOD .. " + " .. d[1], hl.dsp.focus({ direction = d[2] }), { description = "[Window Management|Change focus] focus " .. d[2] })
	end
end

-- ALT+колесо мыши — фокус по кругу между окнами текущего стола (14.10)
bind("ALT + mouse_down", hl.dsp.window.cycle_next({ next = true }), { description = "[Window Management|Change focus|Mouse] focus next window" })
bind("ALT + mouse_up", hl.dsp.window.cycle_next({ next = false }), { description = "[Window Management|Change focus|Mouse] focus previous window" })

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
bind(MOD .. " + A", exec("qs -c yumi ipc call launcher apps"), { description = "[Launcher|Menus] application finder" })
bind(MOD .. " + SHIFT + E", exec("qs -c yumi ipc call launcher files"), { description = "[Launcher|Menus] file finder" })
-- Пульт (как Spotlight, Cmd+Space на MacBook): программы, команды Yumi, файлы, счёт, эмодзи, веб — одним окном.
-- SUPER+Space был свободен (13.10); раскладка — SUPER+K, у Logitech Win↔Alt — Super всё равно у пробела
bind(MOD .. " + SPACE", exec("qs -c yumi ipc call menu center pult"), { description = "[Launcher|Menus] Yumi pult — search everything" })
-- SUPER+SHIFT+A (выбор стиля rofi) снят 13.10: меню программ теперь GTK4 (yumi-menu-launcher)
bind(MOD .. " + SHIFT + slash", exec("qs -c yumi ipc call menu center websearch"), { description = "[Launcher|Rofi menus] Web Search" })
bind(MOD .. " + comma", exec("qs -c yumi ipc call picker emoji"), { description = "[Launcher|Menus] emoji picker" })
-- 30.10: macOS-фишки — Mission Control, «Быстрый просмотр» (в Dolphin — выделенный файл), «Машина времени», стопка загрузок
bind(MOD .. " + code:40", exec("qs -c yumi ipc call mission toggle"), { description = "[Launcher|Menus] Mission Control — all windows" })
bind(MOD .. " + code:29", exec(BIN .. "yumi-quicklook"), { description = "[Launcher|Menus] Quick Look — preview selected file" })
bind(MOD .. " + T", exec("qs -c yumi ipc call timemachine toggle"), { description = "[Launcher|Menus] Time Machine — snapper snapshots" })
bind(MOD .. " + SHIFT + D", exec("qs -c yumi ipc call downloads toggle"), { description = "[Launcher|Menus] recent downloads stack" })
bind(MOD .. " + period", exec("qs -c yumi ipc call picker glyph"), { description = "[Launcher|Menus] glyph picker" })

-- ── Меню Quickshell с клавиатуры (16.10): SUPER+C — центр (из него стрелками — любое меню), SUPER+CTRL+буква — меню напрямую ──
bind(MOD .. " + C", exec("qs -c yumi ipc call control toggle"), { description = "[Menus] control center — hub to every menu" })
bind(MOD .. " + CONTROL + W", exec("qs -c yumi ipc call menu center wifi"), { description = "[Menus] Wi-Fi" })
bind(MOD .. " + CONTROL + B", exec("qs -c yumi ipc call menu center bluetooth"), { description = "[Menus] Bluetooth" })
bind(MOD .. " + CONTROL + A", exec(BIN .. "yumi-airpods-key"), { description = "[Menus] AirPods (не подключены — найти и подключить)" })   -- 30.10: было H; не подключены — поиск в острове (yumi-airpods-key)
bind(MOD .. " + CONTROL + V", exec("qs -c yumi ipc call menu center vpn"), { description = "[Menus] VPN" })
bind(MOD .. " + CONTROL + S", exec("qs -c yumi ipc call menu center sound"), { description = "[Menus] sound" })   -- 30.10: было A
bind(MOD .. " + CONTROL + E", exec("qs -c yumi ipc call menu center power"), { description = "[Menus] battery and power" })
bind(MOD .. " + CONTROL + T", exec("qs -c yumi ipc call menu center top"), { description = "[Menus] processes" })
bind(MOD .. " + CONTROL + Y", exec("qs -c yumi ipc call menu center tray"), { description = "[Menus] tray" })
bind(MOD .. " + CONTROL + C", exec("qs -c yumi ipc call menu center calendar"), { description = "[Menus] calendar" })
bind(MOD .. " + CONTROL + K", exec("qs -c yumi ipc call menu center keys"), { description = "[Menus] keyboard shortcuts" })
bind(MOD .. " + CONTROL + N", exec("qs -c yumi ipc call notif open"), { description = "[Menus] notification center" })
-- медиа без F-клавиш (ALT+F9…F12 остаются дублями)
bind(MOD .. " + ALT + SPACE", exec("playerctl play-pause"), { description = "[Media] play / pause", locked = true })
bind(MOD .. " + ALT + comma", exec("playerctl previous"), { description = "[Media] previous track", locked = true })
bind(MOD .. " + ALT + period", exec("playerctl next"), { description = "[Media] next track", locked = true })
-- Буфер обмена — GTK-меню yumi-panel (поиск, миниатюры, закреп)
-- Quickshell (3.1), откат: yumi-uninstall quickshell — буфер обмена по центру (бывший yumi-menu-clipboard --center)
bind(MOD .. " + V", exec("qs -c yumi ipc call clipboard toggle center"), { description = "[Launcher|Rofi menus] clipboard" })
bind(MOD .. " + SHIFT + V", exec("qs -c yumi ipc call clipboard toggle center"), { description = "[Launcher|Rofi menus] clipboard manager" })
-- Режимы работы (workflow) — в меню «Питание»
bind(MOD .. " + slash", exec("qs -c yumi ipc call menu center power"), { description = "[Utils] workflows" })
-- Рабочие столы — GTK-меню (переключатель окон HyDE altab у нас не работал)
bind(MOD .. " + TAB", exec("qs -c yumi ipc call menu center workspaces"), { description = "[Workspaces] overview" })
-- SUPER+SHIFT+K (калькулятор rofi) снят: пакета rofi-calc нет

-- ── Звук, медиа, яркость ──
bind("XF86AudioMute", exec(BIN .. "yumi-volume -o m"), { description = "[Hardware Controls|Audio] un/mute output", locked = true })
bind("XF86AudioMicMute", exec(BIN .. "yumi-volume -i m"), { description = "[Hardware Controls|Audio] un/mute microphone", locked = true })
bind("XF86AudioLowerVolume", exec(BIN .. "yumi-volume -o d"), { description = "[Hardware Controls|Audio] decrease volume", locked = true, repeating = true })
bind("XF86AudioRaiseVolume", exec(BIN .. "yumi-volume -o i"), { description = "[Hardware Controls|Audio] increase volume", locked = true, repeating = true })

bind("XF86AudioPlay", exec(BIN .. "yumi-play-pause"), { description = "[Hardware Controls|Media] play media", locked = true })
bind("XF86AudioPause", exec(BIN .. "yumi-play-pause"), { description = "[Hardware Controls|Media] pause media", locked = true })
bind("XF86AudioNext", exec("playerctl next"), { description = "[Hardware Controls|Media] next media", locked = true })
bind("XF86AudioPrev", exec("playerctl previous"), { description = "[Hardware Controls|Media] previous media", locked = true })
bind(MOD .. " + CONTROL + M", exec(BIN .. "yumi-window-mute"), { description = "[Hardware Controls|Media] toggle un/mute for active-window" })

bind("XF86MonBrightnessUp", exec(BIN .. "yumi-brightness i"), { description = "[Hardware Controls|Brightness] increase brightness", locked = true, repeating = true })
bind("XF86MonBrightnessDown", exec(BIN .. "yumi-brightness d"), { description = "[Hardware Controls|Brightness] decrease brightness", locked = true, repeating = true })

-- ── Утилиты ──
-- Раскладка: сразу на всех клавиатурах (у Logitech два устройства), и на экране блокировки
bind(MOD .. " + K", exec(BIN .. "yumi-kb-switch"), { description = "[Utilities] toggle keyboard layout", locked = true })
-- ALT+Shift (в любом порядке) — то же самое; на отпускание, поэтому ALT+Shift+клавиша в программах раскладку не меняет (26.10)
-- При отпускании Hyprland видит оба модификатора, поэтому в каждом сочетании ALT + SHIFT, а последней — отпущенная клавиша:
--   Shift_L/R — первым зажат ALT;  Alt_L/R — первым Shift на MacBook;
--   Super_L/R — первым Shift на Logitech: altwin:swap_alt_win, а для биндов Hyprland берёт исходную клавишу (Win)
for _, key in ipairs({ "Shift_L", "Shift_R", "Alt_L", "Alt_R", "Super_L", "Super_R" }) do
	bind("ALT + SHIFT + " .. key, exec(BIN .. "yumi-kb-switch"), { description = "[Utilities] toggle keyboard layout (Alt+Shift)", locked = true, release = true })
end
-- SUPER+ALT+G (игровой режим HyDE) снят 13.10: был сломан; режим «Игры» — в меню «Питание» (SUPER+/)
-- SUPER+SHIFT+G (каталог игр HyDE) снят 13.10: Steam удалён
bind(MOD .. " + CONTROL + SHIFT + P", exec("hyprpicker -an"), { description = "[Utilities|Screen Capture] color picker", locked = true })   -- 16.10: было SUPER+SHIFT+P
-- снимки без F-клавиш (на Mac неудобны; F10–F12 ниже остаются дублями)
bind(MOD .. " + P", exec(BIN .. "yumi-screenshot s"), { description = "[Utilities] partial screenshot capture", locked = true })
bind(MOD .. " + ALT + P", exec(BIN .. "yumi-screenshot sf"), { description = "[Utilities] freeze and snip screen", locked = true })
bind(MOD .. " + SHIFT + P", exec(BIN .. "yumi-screenshot m"), { description = "[Utilities] print monitor", locked = true })
bind(MOD .. " + F10", exec(BIN .. "yumi-screenshot s"), { description = "[Utilities] partial screenshot capture", locked = true })
bind(MOD .. " + F11", exec(BIN .. "yumi-screenshot sf"), { description = "[Utilities] freeze and snip screen", locked = true })
bind(MOD .. " + F12", exec(BIN .. "yumi-screenshot m"), { description = "[Utilities] print monitor", locked = true })
bind("Print", exec(BIN .. "yumi-screenshot p"), { description = "[Utilities] print all monitors", locked = true })
-- 30.10: центр настроек пока без бинда (по просьбе): bind(MOD .. " + CONTROL + H", exec("qs -c yumi ipc call menu center settings"), { description = "[Menus] settings center" })

-- ── Обои и режимы ──
-- Обои по кругу в папке ~/Pictures/Wallpapers; цвета всего стола пересчитываются следом (yumi-colors)
bind(MOD .. " + ALT + Right", exec(BIN .. "yumi-wallpaper next"), { description = "[Theming and Wallpaper] next global wallpaper" })
bind(MOD .. " + ALT + Left", exec(BIN .. "yumi-wallpaper prev"), { description = "[Theming and Wallpaper] previous global wallpaper" })
bind(MOD .. " + ALT + Up", exec(BIN .. "yumi-workflow next"), { description = "[Theming and Wallpaper] next workflow" })
bind(MOD .. " + ALT + Down", exec(BIN .. "yumi-workflow prev"), { description = "[Theming and Wallpaper] previous workflow" })
-- Выбор обоев — GTK-меню yumi-panel (сетка миниатюр)
bind(MOD .. " + SHIFT + W", exec("qs -c yumi ipc call menu center wallpaper"), { description = "[Theming and Wallpaper] select a global wallpaper" })
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

-- Тачбар (19.10): SUPER+CTRL+1…9 — слой по номеру (1–5 слои свайпа, 6 Папка, 7 F1–F12; порядок из config.toml)
for i = 1, 9 do
	bind(MOD .. " + CONTROL + " .. i, exec(BIN .. "yumi-touchbar-layer " .. i), { description = "[Touch Bar] show layer " .. i })
end

bind(MOD .. " + CONTROL + RIGHT", hl.dsp.focus({ workspace = "r+1" }),{ description = "[Workspaces|Navigation|Relative workspace] change active workspace forwards" })
bind(MOD .. " + CONTROL + LEFT", hl.dsp.focus({ workspace = "r-1" }), { description = "[Workspaces|Navigation|Relative workspace] change active workspace backwards" })
bind(MOD .. " + CONTROL + DOWN", hl.dsp.focus({ workspace = "empty" }), { description = "[Workspaces|Navigation] navigate to the nearest empty workspace" })
bind(MOD .. " + CONTROL + ALT + RIGHT", hl.dsp.window.move({ workspace = "r+1" }), { description = "[Workspaces|Move window to workspace|Relative workspace] move focused window to next workspace" })
bind(MOD .. " + CONTROL + ALT + LEFT", hl.dsp.window.move({ workspace = "r-1" }), { description = "[Workspaces|Move window to workspace|Relative workspace] move focused window to previous workspace" })
bind(MOD .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "[Workspaces|Navigation|Mouse] next workspace" })
bind(MOD .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { description = "[Workspaces|Navigation|Mouse] previous workspace" })

-- Спецстол (scratchpad)
bind(MOD .. " + CONTROL + H", hl.dsp.workspace.toggle_special(), { description = "[Workspaces|Navigation|Special workspace] toggle scratchpad" })   -- 30.10: было SUPER+S (отдан помощнику)
bind(MOD .. " + CONTROL + SHIFT + H", hl.dsp.window.move({ workspace = "special" }), { description = "[Workspaces|Navigation|Special workspace] move focused window to scratchpad" })   -- 30.10: было SUPER+SHIFT+S
bind(MOD .. " + ALT + S", hl.dsp.window.move({ workspace = "special", follow = false }), { description = "[Workspaces|Navigation|Special workspace] move focused window silently to scratchpad" })


-- ── Раскладки окон ──
-- SUPER+O: по кругу dwindle → scrolling → master → monocle (14.10: + monocle — каждое окно на весь экран)
bind(MOD .. " + O", function()
	local nxt = { dwindle = "scrolling", scrolling = "master", master = "monocle", monocle = "dwindle" }
	local new = nxt[tostring(hl.get_config("general.layout"))] or "dwindle"
	hl.config({ general = { layout = new } })
	hl.exec_cmd("notify-send -t 1500 'Раскладка' '" .. new .. "'")
end, { description = "[Layout] cycle dwindle / scrolling / master / monocle" })

-- SUPER+J: в dwindle — ориентация сплита, в scrolling — направление ленты, в monocle — следующее окно
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
	elseif ws.tiled_layout == "monocle" then
		hl.dispatch(hl.dsp.layout("cyclenext"))
	end
end, { description = "[Layout] toggle split / scroll direction / next window in monocle" })
