#!/usr/bin/env sh
# yumi: окружение сеанса Hyprland для uwsm (было env-hyprland.d/00-hyde.sh HyDE).
# Те же значения задаёт и yumi/env.lua (hl.env) — здесь они нужны раньше: службам, которые uwsm
# поднимает до конфига Hyprland, и самому Hyprland при старте.

# Qt — https://wiki.hyprland.org/Configuring/Environment-variables/#qt-variables
QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland;xcb}"                               # Wayland, если нет — X11
QT_AUTO_SCREEN_SCALE_FACTOR="${QT_AUTO_SCREEN_SCALE_FACTOR:-1}"                 # масштаб по плотности пикселей монитора
QT_WAYLAND_DISABLE_WINDOWDECORATION="${QT_WAYLAND_DISABLE_WINDOWDECORATION:-1}" # без своих рамок окон Qt
QT_QPA_PLATFORMTHEME="${QT_QPA_PLATFORMTHEME:-qt6ct}"                           # тема Qt из qt6ct

# Firefox/Zen, GTK под Xwayland, Electron
MOZ_ENABLE_WAYLAND="${MOZ_ENABLE_WAYLAND:-1}"
GDK_SCALE="${GDK_SCALE:-1}"
ELECTRON_OZONE_PLATFORM_HINT="${ELECTRON_OZONE_PLATFORM_HINT:-auto}"

# Hyprland стартует со своей базы: ~/.config/hypr/hyprland.lua (→ ~/.config/hypr/yumi)
HYPRLAND_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua"
HYPRLAND_NO_SD_NOTIFY=1 # готовность сеанса systemd сообщает uwsm finalize (yumi/autostart.lua), не Hyprland
HYPRLAND_NO_SD_VARS=1   # переменные в systemd/dbus передаёт uwsm и yumi/autostart.lua, не Hyprland

export QT_QPA_PLATFORM QT_AUTO_SCREEN_SCALE_FACTOR QT_WAYLAND_DISABLE_WINDOWDECORATION QT_QPA_PLATFORMTHEME \
    MOZ_ENABLE_WAYLAND GDK_SCALE ELECTRON_OZONE_PLATFORM_HINT \
    HYPRLAND_CONFIG HYPRLAND_NO_SD_NOTIFY HYPRLAND_NO_SD_VARS
