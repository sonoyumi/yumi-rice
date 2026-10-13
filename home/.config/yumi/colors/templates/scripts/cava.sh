#!/usr/bin/env bash
# Хук yumi-colors: цвета cava из обоев — блок после KEY_LINE в ~/.config/cava/config заменяется
# содержимым ~/.cache/yumi/theme/wallbash/cava (шаблон always/cava.dcol), затем cava перечитывает цвета

confDir="${confDir:-${XDG_CONFIG_HOME:-$HOME/.config}}"
cacheDir="${cacheDir:-${XDG_CACHE_HOME:-$HOME/.cache}/yumi/theme}"
cvaDir="${confDir}/cava"
CAVA_CONF="${cvaDir}/config"
CAVA_DCOL="${cacheDir}/wallbash/cava"
KEY_LINE='### Auto generated wallbash colors ###'

if pacman -Qq cava >/dev/null 2>&1; then
    if [[ ! -d "${cvaDir}" ]]; then
        echo "cava: нет каталога настроек ${cvaDir} — сначала запустите cava" >&2
    else

        sed -i "/${KEY_LINE}/,\$d" "${CAVA_CONF}"
        if grep -q "${KEY_LINE}" "${CAVA_CONF}"; then
            sed -i "/${KEY_LINE}/r ${CAVA_DCOL}" "${CAVA_CONF}"
        else
            echo "${KEY_LINE}" >>"${CAVA_CONF}"
            sed -i "/${KEY_LINE}/r ${CAVA_DCOL}" "${CAVA_CONF}"
        fi

        pkill -USR2 cava
    fi
fi
