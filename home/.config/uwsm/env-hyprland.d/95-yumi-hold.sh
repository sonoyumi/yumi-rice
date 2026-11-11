#!/usr/bin/env sh
# yumi: удержание первого кадра Hyprland до первого клиента (патч hyprland 0.56.2-4.1, docs/boot/hyprland-patch).
# Только сразу после загрузки (uptime < 60 с): при обычном выходе/входе — как обычно. Обычный Hyprland их не читает.
_up=$(cut -d. -f1 /proc/uptime 2>/dev/null)
if [ -n "$_up" ] && [ "$_up" -lt 60 ]; then
    export HYPRLAND_HOLD_FIRST_CLIENT=3
    export HYPRLAND_HOLD_OUTPUTS=eDP-1
    export HYPRLAND_HIDE_CURSOR_UNTIL_LOCK=0   # 18.10 (ночь, 2): с патчем курсор после разблокировки не возвращался 2–3 мин при любом порядке; прячет cursor.invisible (env.lua), показ — yumi-cursor-wait
    export HYPRLAND_SPLASH_HANDOFF=1      # патч 0002: экран у заставки просит сам Hyprland перед открытием DRM

    # 18.10 (cursor6): пустая тема курсора у самого Hyprland с первого кадра (мелькал на ~60 % при старте).
    # Службам (Quickshell и др.) autostart.lua сразу отдаёт Bibata; Hyprland получает Bibata при разблокировке
    # (yumi-cursor-wait --after-unlock). Бэкап: 95-yumi-hold.sh.bak-cursor6-20261018
    export XCURSOR_THEME=yumi-empty HYPRCURSOR_THEME=yumi-empty
fi
unset _up
