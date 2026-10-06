#!/usr/bin/env bash
# Наши правки к файлам HyDE в ~/.local/share/hypr/lua.
# HyDE перезаписывает эти файлы при обновлении — после обновления запусти: ./rice hyde-patches
# Каждая правка идемпотентна: повторный запуск ничего не ломает.
set -u
L="$HOME/.local/share/hypr/lua"
kb="$L/key_binds.lua"
bin="$HOME/.local/bin"

[ -f "$kb" ] || { echo "Не найден $kb — структура HyDE изменилась, правки не применены."; exit 1; }
cp -p "$kb" "$kb.rice-bak"

# SUPER+V (буфер) и SUPER+/ теперь задаёт сам hyprland.lua (hl.unbind + GTK-меню yumi-panel),
# поэтому key_binds.lua HyDE для них больше не правим.

# 1. SUPER+ALT+↑/↓ (лейауты Waybar) → следующий/предыдущий режим
sed -i "s|hl.dsp.exec_cmd(\"hyde-shell waybar --next\")|hl.dsp.exec_cmd(\"$bin/menu-workflows --next\")|; s|hl.dsp.exec_cmd(\"hyde-shell waybar --prev\")|hl.dsp.exec_cmd(\"$bin/menu-workflows --prev\")|" "$kb"

# 2. Свайп 3 пальцами по вертикали не переключает столы (вниз — обзор столов, см. hyprland.lua)
perl -0pi -e 's/hl\.gesture\(\s*\{\s*fingers\s*=\s*3,\s*direction\s*=\s*"vertical",\s*action\s*=\s*"workspace"\s*\}\s*\)\s*//g' "$L"/layouts/*.lua

echo "--- бинды:"
grep -n "menu-workflows" "$kb"
echo "--- вертикальных жестов осталось (должно быть 0):"
grep -c '"vertical"' "$L"/layouts/*.lua | awk -F: '{s+=$2} END {print s}'
hyprctl reload >/dev/null && echo "Hyprland перечитан. Копия key_binds: $kb.rice-bak"
