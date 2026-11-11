-- yumi/autostart.lua — запуск сеанса (было start_up.lua + hyde.config.start HyDE)
-- Фоновые программы — обычные службы systemd --user с WantedBy=graphical-session.target:
-- их поднимает yumi-hyprland-session.target (18.10, без uwsm; было uwsm finalize). Список и состояние: yumi-session status
--   из пакетов:  hypridle, hyprsunset, hyprpolkitagent (бар, меню и уведомления — yumi-quickshell.service)
--   свои:        yumi-clip-text, yumi-clip-image, yumi-clip-persist, yumi-udiskie, yumi-wallpaper
-- blueman-applet стартует из ~/.config/autostart (XDG), nm-applet выключен (свои меню Wi-Fi/VPN).

local session_env = table.concat({
	"WAYLAND_DISPLAY", "XDG_CURRENT_DESKTOP", "XDG_SESSION_TYPE", "XDG_SESSION_DESKTOP",
	"XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME", "XDG_STATE_HOME", "QT_QPA_PLATFORMTHEME",
}, " ")

hl.on("hyprland.start", function()
	-- Сеанс без uwsm (18.10, yumi-hyprland-session): первым — передать всё окружение Hyprland (WAYLAND_DISPLAY,
	-- HYPRLAND_INSTANCE_SIGNATURE, файлы ~/.config/uwsm/…) в systemd и dbus и сразу поднять yumi-hyprland-session.target
	-- (→ graphical-session.target: Quickshell с экраном блокировки и остальные службы). Было: uwsm finalize
	-- (копия autostart.lua.bak-nouwsm-20261018, откат — yumi-nouwsm-undo).
	-- 18.10 (cursor6): при загрузке у Hyprland пустая тема курсора (yumi-empty) — службам сразу Bibata, до запуска
	-- цели (иначе Quickshell запомнит пустую: курсора не будет над баром). Бэкап: autostart.lua.bak-cursor6-20261018
	local cur = "XCURSOR_THEME=Adwaita HYPRCURSOR_THEME=Adwaita XCURSOR_SIZE=20 HYPRCURSOR_SIZE=20"
	hl.exec_cmd("sh -c 'dbus-update-activation-environment --systemd --all; dbus-update-activation-environment --systemd "
		.. cur .. "; systemctl --user set-environment " .. cur .. "; systemctl --user start --no-block yumi-hyprland-session.target'")
	hl.exec_cmd("dbus-update-activation-environment --systemd " .. session_env)
	hl.exec_cmd("systemctl --user import-environment " .. session_env)
	if not _G.yumi_boot_cursor then   -- 18.10: при загрузке не трогать курсор (см. env.lua)
		hl.exec_cmd("hyprctl setcursor Adwaita 20")
	end
end)
