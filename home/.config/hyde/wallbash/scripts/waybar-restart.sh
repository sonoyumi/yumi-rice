#!/usr/bin/env bash
# Полный перезапуск Waybar после смены обоев вместо перечитывания стиля.
# Вызывается из theme/waybar.dcol — копии шаблона HyDE, где вместо `hyde-shell waybar --update`
# (он перечитывает Waybar через SIGUSR2, это давало второе мигание) стоит этот скрипт.
# При каждом перечитывании Waybar создаёт новые буферы отрисовки (memfd) и не освобождает старые:
# за день смен обоев служба дорастала до 2–3 ГБ. Новый процесс стартует с ~40 МБ.
# Смена обоев может вызвать скрипт несколько раз подряд — перезапуск выполняет только последний вызов.
token="${XDG_RUNTIME_DIR:-/tmp}/waybar-restart.token"
echo "$$" >"$token"
sleep 1.5 # склеить все запросы одной смены обоев (theme.css HyDE + yumi-accent) в ОДИН перезапуск
[ "$(cat "$token" 2>/dev/null)" = "$$" ] || exit 0
systemctl --user restart hyde-Hyprland-bar.service
