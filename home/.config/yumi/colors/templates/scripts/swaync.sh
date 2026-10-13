#!/usr/bin/env bash
#  Author : JaxTsai (переделано для Yumi-Rice: значения берутся из запущенного Hyprland)
# Syncs swaync with the live Hyprland options:
#   - notification popup gap from the screen edge  <- general:gaps_out (theme.css)
#   - control center margin from the screen edge   <- general:gaps_out (config.json)
#   - corner rounding                               <- decoration:rounding (theme.css)
# Values are pulled once per wallpaper change via `hyprctl getoption -j`. The theme.css values are
# stamped over the tagged placeholders below (do not hand-edit those values,
# they are overwritten every time this runs). The config.json margins are
# managed the same way: control-center-margin-* is overwritten every reload,
# everything else in config.json is left untouched.

confDir="${confDir:-${XDG_CONFIG_HOME:-$HOME/.config}}"
theme_css="${confDir}/swaync/theme.css"
config_json="${confDir}/swaync/config.json"

# hyprctl getoption -j: gaps_out — {"css": "8 8 8 8"} (верх право низ лево), rounding — {"int": 10}.
# Ответ приводится к прежнему виду hyq: "8" при равных сторонах, иначе "в,п,н,л"
hypr_opt() {
    command -v hyprctl &>/dev/null && command -v jq &>/dev/null || return 1
    hyprctl getoption "$1" -j 2>/dev/null | jq -r '
        if .css then (.css | split(" ") | if (unique | length) == 1 then .[0] else join(",") end)
        elif .int != null then .int | tostring else empty end' 2>/dev/null
}

# gaps_out -> padding (yumi:gaps_out) + control-center-margin-*
gaps_out="$(hypr_opt "general:gaps_out")"
[[ $gaps_out =~ ^([0-9]+,){0,3}[0-9]+$ ]] || gaps_out=8

if [ -f "$theme_css" ]; then
    gaps_css="$(awk -F',' '{for(i=1;i<=NF;i++) printf "%s%dpx", (i>1?" ":""), $i}' <<<"$gaps_out")"
    sed -i -E "s#padding: [0-9]+px( [0-9]+px){0,3};([[:space:]]*/\* yumi:gaps_out \*/)#padding: ${gaps_css};\2#" "$theme_css"
fi

if [ -f "$config_json" ] && command -v jq &>/dev/null; then
    # Same 1/2/3/4-value CSS shorthand Hyprland itself parses gaps_out with
    # 1 -> all sides
    # 2 -> vertical, horizontal
    # 3 -> top, horizontal, bottom
    # 4 -> top, right, bottom, left
    IFS=',' read -ra _gaps <<<"$gaps_out"
    case ${#_gaps[@]} in
    1) gap_top=${_gaps[0]} gap_right=${_gaps[0]} gap_bottom=${_gaps[0]} gap_left=${_gaps[0]} ;;
    2) gap_top=${_gaps[0]} gap_right=${_gaps[1]} gap_bottom=${_gaps[0]} gap_left=${_gaps[1]} ;;
    3) gap_top=${_gaps[0]} gap_right=${_gaps[1]} gap_bottom=${_gaps[2]} gap_left=${_gaps[1]} ;;
    *) gap_top=${_gaps[0]} gap_right=${_gaps[1]} gap_bottom=${_gaps[2]} gap_left=${_gaps[3]} ;;
    esac
    config_tmp="$(mktemp)"
    if jq --argjson t "$gap_top" --argjson r "$gap_right" --argjson b "$gap_bottom" --argjson l "$gap_left" \
        '."control-center-margin-top"=$t | ."control-center-margin-right"=$r | ."control-center-margin-bottom"=$b | ."control-center-margin-left"=$l' \
        "$config_json" >"$config_tmp"; then
        mv "$config_tmp" "$config_json"
    else
        rm -f "$config_tmp"
    fi
fi

# decoration:rounding -> border-radius (yumi:rounding)
if [ -f "$theme_css" ]; then
    rounding="$(hypr_opt "decoration:rounding")"
    [[ $rounding =~ ^[0-9]+$ ]] || rounding=12
    sed -i -E "s#border-radius: [0-9]+px;([[:space:]]*/\* yumi:rounding \*/)#border-radius: ${rounding}px;\1#" "$theme_css"
fi

swaync-client -R && swaync-client -rs
