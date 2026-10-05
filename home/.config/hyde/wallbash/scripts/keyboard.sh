#!/usr/bin/env bash
# Подсветка Logitech PRO Gaming Keyboard одним акцентом палитры wallbash (режим Static).
# Режим Direct (цвет на каждую клавишу) с этой клавиатурой через OpenRGB ненадёжен:
# часть клавиш пропускается, а порядок светодиодов не совпадает с раскладкой

cacheDir="${cacheDir:-${XDG_CACHE_HOME:-$HOME/.cache}/hyde}"
KB_DCOL="${cacheDir}/wallbash/keyboard"
DEVICE="PRO Gaming Keyboard"

command -v openrgb >/dev/null || exit 0
[[ -r "${KB_DCOL}" ]] || exit 0
# shellcheck disable=SC1090
source "${KB_DCOL}"

# Обычный запуск openrgb каждый раз заново опрашивает все устройства (несколько секунд нагрузки,
# мешает Solaar читать мышь). Поэтому при входе запускается сервер (см. hyprland.lua),
# а здесь только клиент отправляет ему цвет. Нет сервера — ждём его до 30 с (вход в систему),
# потом обычный запуск. Всё в фоне, чтобы не держать wallbash; flock — один вызов за раз
PORT=6742
server_up() { (exec 3<>"/dev/tcp/127.0.0.1/${PORT}") 2>/dev/null; }
(
    flock -w 30 9 || exit 0
    for _ in $(seq 30); do server_up && break; pgrep -x openrgb >/dev/null || break; sleep 1; done
    if server_up; then
        openrgb --client "127.0.0.1:${PORT}" --noautoconnect --device "${DEVICE}" --mode static --color "${KB_COLOR}" >/dev/null 2>&1
    else
        openrgb --device "${DEVICE}" --mode static --color "${KB_COLOR}" >/dev/null 2>&1
    fi
) 9>"${XDG_RUNTIME_DIR:-/tmp}/wallbash-keyboard.lock" &
disown
