-- yumi/env.lua — переменные окружения сеанса (были variables.lua + env.lua HyDE)

local home = os.getenv("HOME") or ""
local function xdg(name, fallback)
	local v = os.getenv(name)
	return (v and v ~= "") and v or (home .. fallback)
end

local vars = {
	XDG_CURRENT_DESKTOP = "Hyprland",
	XDG_SESSION_TYPE = "wayland",
	XDG_SESSION_DESKTOP = "Hyprland",
	XDG_CONFIG_HOME = xdg("XDG_CONFIG_HOME", "/.config"),
	XDG_CACHE_HOME = xdg("XDG_CACHE_HOME", "/.cache"),
	XDG_DATA_HOME = xdg("XDG_DATA_HOME", "/.local/share"),
	XDG_STATE_HOME = xdg("XDG_STATE_HOME", "/.local/state"),
	QT_AUTO_SCREEN_SCALE_FACTOR = "1",
	QT_QPA_PLATFORM = "wayland;xcb",
	QT_WAYLAND_DISABLE_WINDOWDECORATION = "1",
	QT_QPA_PLATFORMTHEME = "qt6ct",
	MOZ_ENABLE_WAYLAND = "1",
	GDK_SCALE = "1",
	ELECTRON_OZONE_PLATFORM_HINT = "auto",
	-- Один курсор для всех: программы без этих переменных брали размер 24,
	-- после разблокировки мелькали два курсора разного размера
	XCURSOR_THEME = "Adwaita",
	XCURSOR_SIZE = "20",
	HYPRCURSOR_THEME = "Adwaita",
	HYPRCURSOR_SIZE = "20",
}
-- при загрузке (флаг ниже) тему курсора не трогать: Hyprland стартует с пустой yumi-empty (95-yumi-hold.sh),
-- Bibata ставит yumi-cursor-wait при разблокировке
local boot_cursor = _G.yumi_boot_cursor
if boot_cursor == nil then
	local up = 999
	local f = io.open("/proc/uptime", "r")
	if f then up = tonumber((f:read("*l") or ""):match("^(%S+)")) or 999; f:close() end
	local lf = io.open((os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/yumi-locked", "r")
	if lf then lf:close() end
	boot_cursor = up < 60 and not lf
end
for name, value in pairs(vars) do
	if not (boot_cursor and name:match("CURSOR_THEME$")) then
		hl.env(name, value)
	end
end

-- Загрузка (16.10): первые 60 с после включения, пока нет экрана блокировки — флаг yumi_boot_cursor (мост заставки,
-- MSI в hyprland.lua, курсор). 18.10 (cursor6): курсор при загрузке — пустая тема yumi-empty у Hyprland с первого
-- кадра до разблокировки (Quickshell получает Bibata — autostart.lua). Бэкап: env.lua.bak-cursor6-20261018
if _G.yumi_boot_cursor == nil then
	_G.yumi_boot_cursor = boot_cursor
end
if _G.yumi_boot_cursor then
	-- мост при загрузке: первым делом — тот же кадр, что у заставки yumi-splash (swaybg рисует за миллисекунды;
	-- awww стартует через systemd на ~0,6 с позже). Убирает Quickshell, когда вход растворился (и yumi-lock).
	if not _G.yumi_boot_bridge then
		_G.yumi_boot_bridge = true
		-- 18.10: курсора нет ни на заставке, ни на экране блокировки — только на рабочем столе, при первом движении
		-- мыши/тачпада (yumi-cursor-wait --after-unlock). Без пустой темы: cursor.invisible — настройка отрисовки
		-- Hyprland, в окружение Quickshell не попадает. Бэкап: env.lua.bak-cursor2-20261018
		-- 18.10 ночь (2): мелькание в центре давал `hyprctl setcursor` при старте (теперь не вызывается при загрузке),
		-- патч HIDE_CURSOR_UNTIL_LOCK выключен — с ним курсор не возвращался
		-- 18.10 (cursor6): прячет пустая тема yumi-empty с первого кадра (95-yumi-hold.sh); cursor.invisible
		-- не действовал с первого кадра — убран. Бэкап: env.lua.bak-cursor6-20261018
		hl.on("hyprland.start", function()
			hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/yumi-boot-bridge")   -- заставка окном: продолжение анимации
			hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/yumi-cursor-wait --after-unlock")
		end)
	end
end
-- 18.10: курсор из XCursor-версии темы (cursors/, готовые картинки) вместо hyprcursor (hyprcursors/, SVG) — Hyprland
-- растрировал SVG при каждом старте ~0,2 с, полоска загрузки замирала на ~60 %. Вид тот же (проверено). Вернуть: true
hl.config({ cursor = { enable_hyprcursor = false } })
-- Курсор заново при каждой загрузке конфига. 18.10: кроме загрузки системы — setcursor показывал курсор в центре
-- экрана поверх заставки (~70 %); тему ставит yumi-cursor-wait, когда показывает курсор после разблокировки
if not _G.yumi_boot_cursor then
	hl.exec_cmd("hyprctl setcursor Adwaita 20")
end
