-- yumi/autostart.lua — запуск сеанса (было start_up.lua + hyde.config.start HyDE)
-- Фоновые программы — обычные службы systemd --user с WantedBy=graphical-session.target:
-- uwsm поднимает их сам после `uwsm finalize`. Список и состояние: yumi-session status
--   из пакетов:  waybar (+ drop-in waybar.service.d/yumi.conf), hypridle, hyprsunset, hyprpolkitagent
--   свои:        yumi-clip-text, yumi-clip-image, yumi-clip-persist, yumi-udiskie, yumi-wallpaper
-- blueman-applet стартует из ~/.config/autostart (XDG), nm-applet выключен (свои меню Wi-Fi/VPN).

local session_env = table.concat({
	"WAYLAND_DISPLAY", "XDG_CURRENT_DESKTOP", "XDG_SESSION_TYPE", "XDG_SESSION_DESKTOP",
	"XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME", "XDG_STATE_HOME", "QT_QPA_PLATFORMTHEME",
}, " ")

hl.on("hyprland.start", function()
	hl.exec_cmd("dbus-update-activation-environment --systemd " .. session_env)
	hl.exec_cmd("systemctl --user import-environment " .. session_env)
	hl.exec_cmd("uwsm finalize")
	hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 20")
end)
