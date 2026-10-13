#!/usr/bin/env bash
# ┌──────────────────────────────────────────────────────────────┐
# │ Откат темы SDDM «yumi» → снова HyDE «Corners»                  │
# │ Запуск:  sudo ~/.local/share/yumi-sddm/uninstall.sh            │
# │ Удаляет: zz-yumi-theme.conf, /usr/share/sddm/themes/yumi,      │
# │ /var/lib/yumi-sddm, а также раскладки/курсор — только если их  │
# │ ставил install.sh (по маркеру). the_hyde_project.conf и        │
# │ zz-autologin.conf не трогаются.                                 │
# └──────────────────────────────────────────────────────────────┘
set -euo pipefail

src="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
theme_dst=/usr/share/sddm/themes/yumi
data_dir=/var/lib/yumi-sddm
conf=/etc/sddm.conf.d/zz-yumi-theme.conf
kbd_conf=/etc/X11/xorg.conf.d/00-keyboard.conf
ptr_conf=/etc/X11/xorg.conf.d/40-yumi-pointer.conf
marker="# yumi-sddm: создано install.sh"

[[ $EUID -eq 0 ]] || { echo "Запустите через sudo: sudo $0" >&2; exit 1; }
user="${SUDO_USER:-root}"

# бэкап перед удалением
ts="$(date +%Y%m%d-%H%M%S)"
bk="$src/backup/uninstall-$ts"
mkdir -p "$bk"
cp -a /etc/sddm.conf.d "$bk/sddm.conf.d"
[[ -d "$theme_dst" ]] && cp -a "$theme_dst" "$bk/theme-yumi"
[[ -f "$kbd_conf" ]] && cp -a "$kbd_conf" "$bk/"
[[ -f "$ptr_conf" ]] && cp -a "$ptr_conf" "$bk/"
[[ "$user" != root ]] && chown -R "$user:$(id -gn "$user")" "$src/backup"
echo "• бэкап: $bk"

if [[ -f "$conf" ]]; then
    if grep -qF "$marker" "$conf"; then rm -f "$conf"; echo "• удалён $conf"
    else echo "! $conf создан не install.sh — оставляю"; fi
fi

if [[ -f "$kbd_conf" ]] && grep -qF "$marker" "$kbd_conf"; then
    rm -f "$kbd_conf"; echo "• удалён $kbd_conf"
fi
if [[ -f "$ptr_conf" ]] && grep -qF "$marker" "$ptr_conf"; then
    rm -f "$ptr_conf"; echo "• удалён $ptr_conf"
fi
if [[ -f /usr/share/icons/Bibata-Modern-Ice/.yumi-sddm ]]; then
    rm -rf /usr/share/icons/Bibata-Modern-Ice; echo "• удалён курсор /usr/share/icons/Bibata-Modern-Ice"
fi

[[ -d "$theme_dst" ]] && { rm -rf "$theme_dst"; echo "• удалена тема $theme_dst"; }
[[ -d "$data_dir" ]] && { rm -rf "$data_dir"; echo "• удалён $data_dir"; }

cur="$(grep -h '^Current=' /etc/sddm.conf.d/*.conf 2>/dev/null | tail -n1 || true)"
echo
echo "Готово. Действующая тема: ${cur:-по умолчанию} (ожидается Current=Corners)"
