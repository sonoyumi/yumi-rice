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
	XCURSOR_THEME = "Bibata-Modern-Ice",
	XCURSOR_SIZE = "20",
	HYPRCURSOR_THEME = "Bibata-Modern-Ice",
	HYPRCURSOR_SIZE = "20",
}
for name, value in pairs(vars) do
	hl.env(name, value)
end

-- Курсор заново при каждой загрузке конфига
hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 20")
