#!/usr/bin/env bash
# ┌──────────────────────────────────────────────────────────────┐
# │ Установка темы SDDM «yumi» вместо HyDE «Corners».              │
# │ Запуск:  sudo ~/.local/share/yumi-sddm/install.sh              │
# │ Флаги:   --keyboard  раскладки EN/RU/UA в greeter (Xorg)       │
# │          --cursor    курсор Bibata-Modern-Ice в greeter        │
# │                                                                │
# │ Что делает:                                                    │
# │  1) бэкап /etc/sddm.conf.d и прежней темы yumi → backup/<время>│
# │  2) тема → /usr/share/sddm/themes/yumi (root:root, только чтение)│
# │  3) /var/lib/yumi-sddm — владелец вы, 0755: сюда yumi-sddm-sync │
# │     кладёт обои/цвета/аватар без sudo; sddm только читает      │
# │  4) /etc/sddm.conf.d/zz-yumi-theme.conf (после the_hyde_project│
# │     и zz-autologin по алфавиту; автовход НЕ трогается)         │
# │  5) первый запуск yumi-sddm-sync от вашего имени               │
# │ Откат: sudo .../uninstall.sh  (вернётся Corners)               │
# └──────────────────────────────────────────────────────────────┘
set -euo pipefail

src="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
theme_dst=/usr/share/sddm/themes/yumi
data_dir=/var/lib/yumi-sddm
conf=/etc/sddm.conf.d/zz-yumi-theme.conf
kbd_conf=/etc/X11/xorg.conf.d/00-keyboard.conf
manifest="$theme_dst/.yumi-install"
marker="# yumi-sddm: создано install.sh"

want_kbd=0; want_cursor=0
for a in "$@"; do
    case "$a" in
        --keyboard) want_kbd=1 ;;
        --cursor)   want_cursor=1 ;;
        -h|--help)  sed -n '2,20p' "$0"; exit 0 ;;
        *) echo "неизвестный флаг: $a" >&2; exit 2 ;;
    esac
done

[[ $EUID -eq 0 ]] || { echo "Запустите через sudo: sudo $0 $*" >&2; exit 1; }
user="${SUDO_USER:-}"
[[ -n "$user" && "$user" != root ]] || { echo "Запускайте через sudo от своего пользователя (нужен SUDO_USER)" >&2; exit 1; }
group="$(id -gn "$user")"
home="$(getent passwd "$user" | cut -d: -f6)"
[[ -f "$src/yumi/Main.qml" ]] || { echo "Нет $src/yumi/Main.qml" >&2; exit 1; }
id sddm >/dev/null 2>&1 || { echo "Нет пользователя sddm — SDDM не установлен?" >&2; exit 1; }

# ── 1. бэкап ──
ts="$(date +%Y%m%d-%H%M%S)"
bk="$src/backup/install-$ts"
mkdir -p "$bk"
cp -a /etc/sddm.conf.d "$bk/sddm.conf.d"
[[ -f /etc/sddm.conf ]] && cp -a /etc/sddm.conf "$bk/"
[[ -d "$theme_dst" ]] && cp -a "$theme_dst" "$bk/theme-yumi"
[[ -f "$kbd_conf" ]] && cp -a "$kbd_conf" "$bk/"
chown -R "$user:$group" "$src/backup"
echo "• бэкап: $bk"

# ── 2. тема ──
rm -rf "$theme_dst"
install -d -m 0755 "$theme_dst" "$theme_dst/fonts"
for f in Main.qml metadata.desktop theme.conf background.jpg preview.png; do
    [[ -f "$src/yumi/$f" ]] && install -m 0644 "$src/yumi/$f" "$theme_dst/$f"
done
install -m 0644 "$src/yumi/fonts/"* "$theme_dst/fonts/"
echo "• тема: $theme_dst"

# ── 3. каталог данных для yumi-sddm-sync ──
install -d -m 0755 -o "$user" -g "$group" "$data_dir"
# theme.conf.user темы → файл в каталоге данных (только данные, не код)
ln -sfn "$data_dir/theme.conf.user" "$theme_dst/theme.conf.user"
echo "• данные: $data_dir (владелец $user, sddm читает)"

# ── курсор (по желанию) ──
cursor_theme=Adwaita
cursor_installed=0
if (( want_cursor )); then
    cur_src="$home/.local/share/icons/Bibata-Modern-Ice"
    if [[ -d /usr/share/icons/Bibata-Modern-Ice ]]; then
        cursor_theme=Bibata-Modern-Ice
    elif [[ -d "$cur_src/cursors" ]]; then
        cp -r "$cur_src" /usr/share/icons/Bibata-Modern-Ice
        chown -R root:root /usr/share/icons/Bibata-Modern-Ice
        chmod -R u+rwX,go+rX,go-w /usr/share/icons/Bibata-Modern-Ice
        echo "$marker" > /usr/share/icons/Bibata-Modern-Ice/.yumi-sddm
        cursor_theme=Bibata-Modern-Ice
        cursor_installed=1
        echo "• курсор: /usr/share/icons/Bibata-Modern-Ice"
    else
        echo "! Bibata-Modern-Ice не найден в $cur_src — курсор Adwaita"
    fi
fi

# ── раскладки (по желанию): только для Xorg, на котором работает SDDM ──
kbd_installed=0
if (( want_kbd )); then
    if [[ -f "$kbd_conf" ]] && ! grep -qF "$marker" "$kbd_conf"; then
        echo "! $kbd_conf уже есть и создан не нами — не трогаю (раскладки: см. его XkbLayout)"
    else
        install -d -m 0755 /etc/X11/xorg.conf.d
        cat > "$kbd_conf" <<EOF
$marker
# Раскладки для экрана входа SDDM (Xorg). Hyprland этот файл не читает.
# Переключение — пилюлей с клавиатурой внизу слева.
Section "InputClass"
    Identifier "yumi-sddm keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "us,ru,ua"
EndSection
EOF
        chmod 0644 "$kbd_conf"
        kbd_installed=1
        echo "• раскладки: $kbd_conf (us,ru,ua)"
    fi
fi

# ── 4. конфиг SDDM ──
cat > "$conf" <<EOF
$marker $ts
# Тема yumi. Откат: sudo $src/uninstall.sh
# Файл назван zz-yumi-… чтобы читаться последним (после the_hyde_project.conf
# и zz-autologin.conf). Раздел [Autologin] здесь намеренно отсутствует.

[Theme]
Current=yumi
CursorTheme=$cursor_theme
# Xcursor на X11 — в физических пикселях: 32 ≈ 20 логических при ×1.6
CursorSize=32

[General]
# HiDPI: Qt-масштабирование в greeter выключено, 1 px = 1 физический пиксель.
# Тема сама масштабирует всё от размера каждого экрана (eDP-1 2560×1600 и
# DP-1 1920×1080), поэтому текст чёткий и одинаково крупный на обоих.
# (QT_SCREEN_SCALE_FACTORS=1.6 дал бы огромный интерфейс на DP-1 и мыло
# при дробном масштабе — так не делаем.)
GreeterEnvironment=QT_ENABLE_HIGHDPI_SCALING=0,QT_SCALE_FACTOR=1

[X11]
# в sddm 0.21 это только QT_AUTO_SCREEN_SCALE_FACTOR (наследие Qt5) — выключаем для ясности
EnableHiDPI=false
EOF
chmod 0644 "$conf"
echo "• конфиг: $conf"

# манифест для uninstall.sh
cat > "$manifest" <<EOF
installed=$ts
user=$user
cursor_installed=$cursor_installed
kbd_installed=$kbd_installed
EOF

# ── 5. первая синхронизация от имени пользователя ──
# синхронизатор живёт в ~/.local/bin (его же зовёт хук yumi-accent 95-sddm); старое место — запасное
sync="$home/.local/bin/yumi-sddm-sync"
[[ -x "$sync" ]] || sync="$src/bin/yumi-sddm-sync"
if sudo -u "$user" -H "$sync" "$data_dir"; then :; else
    echo "! yumi-sddm-sync завершился с ошибкой — тема покажет запасной фон"
fi

echo
echo "Готово. Проверка без выхода из сеанса:"
echo "  sddm-greeter-qt6 --test-mode --theme $theme_dst"
echo "Экран входа появится при выходе из сеанса (автовход не изменён)."
echo "Откат: sudo $src/uninstall.sh"
