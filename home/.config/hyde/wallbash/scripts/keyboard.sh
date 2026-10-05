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

# openrgb ищет устройства несколько секунд — не держим wallbash, запускаем в фоне.
# flock: при быстрой смене тем выполняется один вызов за раз
(
    flock -w 30 9 || exit 0
    openrgb --device "${DEVICE}" --mode static --color "${KB_COLOR}" >/dev/null 2>&1
) 9>"${XDG_RUNTIME_DIR:-/tmp}/wallbash-keyboard.lock" &
disown
