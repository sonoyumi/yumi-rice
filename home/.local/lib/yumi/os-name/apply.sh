#!/bin/bash
# Название и значок системы Yumi-Rice в /usr/lib/os-release (19.10.2026, по просьбе пользователя).
# Меняет только PRETTY_NAME и LOGO; NAME, ID=archarm и ID_LIKE=arch остаются — по ним pacman/paru/скрипты узнают Arch.
# Значок yumi-rice (печать 弓) ставится в hicolor и pixmaps — его видят и программы без темы Yumi-Folders.
# Хук pacman возвращает правку после обновления пакета filesystem (он перезаписывает os-release).
# Запуск: sudo bash ~/.local/lib/yumi/os-name/apply.sh   Откат: sudo bash ~/.local/lib/yumi/os-name/apply.sh --undo
set -euo pipefail
OS=/usr/lib/os-release
BAK=/usr/lib/os-release.bak-yumi-20261019
LIB=/usr/local/lib/yumi-os-name
HOOK=/etc/pacman.d/hooks/95-yumi-os-release.hook
ICONS=(/usr/share/icons/hicolor/scalable/apps/yumi-rice.svg /usr/share/pixmaps/yumi-rice.svg)
SRC=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

say() { printf '\033[1;32m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31mОШИБКА: %s\033[0m\n' "$*" >&2; exit 1; }
[ "$(id -u)" = 0 ] || die "запускать через sudo"

if [ "${1:-}" = "--undo" ]; then
	say "Откат названия системы"
	rm -f "$HOOK" "${ICONS[@]}"; rm -rf "$LIB"
	[ -f "$BAK" ] && cp -f "$BAK" "$OS" && rm -f "$BAK"
	gtk-update-icon-cache -f -q -t /usr/share/icons/hicolor 2>/dev/null || true
	grep -E '^(PRETTY_NAME|LOGO)=' "$OS"
	say "Готово"
	exit 0
fi

# fix.sh — сама правка; её же зовёт хук pacman (идемпотентно)
install -d "$LIB"
cat > "$LIB/fix.sh" <<'FIX'
#!/bin/sh
OS=/usr/lib/os-release
grep -q '^PRETTY_NAME="Yumi-Rice' "$OS" && grep -q '^LOGO=yumi-rice$' "$OS" && exit 0
sed -i -e 's/^PRETTY_NAME=.*/PRETTY_NAME="Yumi-Rice (Arch Linux ARM)"/' -e 's/^LOGO=.*/LOGO=yumi-rice/' "$OS"
FIX
chmod 755 "$LIB/fix.sh"

[ -f "$BAK" ] || cp -p "$OS" "$BAK"
install -Dm644 "$SRC/yumi-rice.svg" "${ICONS[0]}"
install -Dm644 "$SRC/yumi-rice.svg" "${ICONS[1]}"
gtk-update-icon-cache -f -q -t /usr/share/icons/hicolor 2>/dev/null || true

install -d "$(dirname "$HOOK")"
cat > "$HOOK" <<HK
[Trigger]
Operation = Install
Operation = Upgrade
Type = Path
Target = usr/lib/os-release

[Action]
Description = Yumi-Rice: название и значок в os-release
When = PostTransaction
Exec = $LIB/fix.sh
HK

"$LIB/fix.sh"
say "os-release:"; grep -E '^(NAME|PRETTY_NAME|ID|ID_LIKE|LOGO)=' "$OS"
say "Готово. Откат: sudo bash $SRC/apply.sh --undo"
