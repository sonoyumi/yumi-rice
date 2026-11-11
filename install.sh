#!/usr/bin/env bash
# install.sh — установщик Yumi-Rice 3.1 (Hyprland + Quickshell) для Arch Linux и Arch Linux ARM.
#
#   ./install.sh               установка: вопросы по шагам, перед каждым шагом — подтверждение
#   ./install.sh --dry-run     только показать, что было бы сделано (ничего не меняет)
#   ./install.sh --uninstall   откат: вернуть файлы из бэкапов, выключить службы и вход через greetd
#
# Повторный запуск безопасен: пакеты ставятся с --needed, каждый запуск делает свой бэкап,
# а откат берёт для каждого файла самую раннюю (исходную) версию.
# Бэкапы и журнал: ~/.local/state/yumi-rice/backup-ДАТА
set -euo pipefail

REPO="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/yumi-rice"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$STATE/backup-$STAMP"
GREETER_ROOT=/var/lib/yumi-greeter
PKGDIR="$REPO/packages"
TOUCHID_URL="https://github.com/sonoyumi/yumi-touchid"
TOUCHBAR_URL="https://github.com/sonoyumi/yumi-touchbar"
TOUCHBARD_URL="https://github.com/0800tim/touchbard"

DRY=0
MODE=install
IS_MAC=0
USE_MAC=0
AUR_HELPER=""

# --- вывод и вопросы ---------------------------------------------------------------------------------------
if [ -t 1 ]; then B=$'\e[1m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'; else B=""; G=""; Y=""; R=""; N=""; fi
say()  { printf '%s\n' "$*"; }
step() { printf '\n%s==> %s%s\n' "$B" "$*" "$N"; }
ok()   { printf '%s  ✓ %s%s\n' "$G" "$*" "$N"; }
warn() { printf '%s  ! %s%s\n' "$Y" "$*" "$N" >&2; }
die()  { printf '%sОшибка: %s%s\n' "$R" "$*" "$N" >&2; exit 1; }

# ask "вопрос" [y|n] — по умолчанию «нет». Ответ читается с терминала; без терминала — значение по умолчанию.
ask() {
    local q=$1 def=${2:-n} hint a=""
    if [ "$def" = y ]; then hint="[Y/n]"; else hint="[y/N]"; fi
    if { : < /dev/tty; } 2>/dev/null; then
        read -rp "  $q $hint " a < /dev/tty || a=""
    else
        say "  $q $hint → по умолчанию ($def)"
    fi
    a="${a:-$def}"
    case "$a" in [yYдД]*) return 0 ;; *) return 1 ;; esac
}

# run команда… — выполнить (в --dry-run только напечатать)
run() {
    if [ "$DRY" = 1 ]; then printf '  [dry-run]'; printf ' %q' "$@"; printf '\n'; else "$@"; fi
}

# Список пакетов из файла: первое слово строки, без комментариев и пустых строк
pkg_list() { [ -f "$1" ] || return 0; sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$1" | awk 'NF { print $1 }'; }

# Содержимое файла, если он есть (для списков в бэкапах)
read_opt() { if [ -f "$1" ]; then cat "$1"; fi; }

# Список системных файлов из system-manifest.txt
sys_list() { grep -vE '^[[:space:]]*(#|$)' "$REPO/system-manifest.txt" || true; }

rice_env() { env RICE_LOCAL=off RICE_MAC="$([ "$USE_MAC" = 1 ] && echo on || echo off)" "$@"; }

usage() { sed -n '2,10s/^# \{0,1\}//p' "$0"; }

# --- 1. проверки ---------------------------------------------------------------------------------------------
check_system() {
    step "Проверка системы"
    [ "$(id -u)" -ne 0 ] || die "не запускайте установщик от root — он сам попросит sudo, где нужно"
    local id="" like=""
    if [ -r /etc/os-release ]; then
        id="$(. /etc/os-release; echo "${ID:-}")"; like="$(. /etc/os-release; echo "${ID_LIKE:-}")"
    fi
    case " $id $like " in
        *" arch "*|*" archarm "*) ok "дистрибутив: $id" ;;
        *) die "поддерживаются только Arch Linux и Arch Linux ARM (найдено: ${id:-неизвестно})" ;;
    esac
    command -v pacman >/dev/null || die "нет pacman"
    command -v sudo >/dev/null || die "нет sudo: sudo pacman -S sudo и добавьте себя в группу wheel"
    command -v git >/dev/null || warn "нет git — поставится вместе с пакетами"
    [ -x "$REPO/rice" ] || die "не найден $REPO/rice — запустите install.sh из папки репозитория"
    if [ "$DRY" = 0 ]; then
        say "  Нужны права sudo (пакеты, /etc, вход greetd)."
        sudo -v || die "sudo не сработал"
    fi
    ok "пользователь: $USER, домашняя папка: $HOME"

    if grep -qa 'apple,' /proc/device-tree/compatible 2>/dev/null; then
        IS_MAC=1
        ok "найден MacBook (Apple Silicon, Asahi)"
        if ask "Ставить Mac-модули (раздел @mac: заставка при загрузке, крышка, AirPods, слои тачбара)?" y; then
            USE_MAC=1
        fi
    fi

    if [ ! -e "$REPO/home/.config/quickshell/yumi/shell.qml" ]; then
        warn "в репозитории нет конфига Quickshell (home/.config/quickshell/yumi) — без него не будет бара, меню и экрана блокировки"
        ask "Продолжить всё равно?" n || exit 1
    fi
}

# --- 2. бэкап ------------------------------------------------------------------------------------------------
make_backup() {
    step "Бэкап того, что будет перезаписано"
    local p n_old=0 n_new=0 files
    files="$(rice_env "$REPO/rice" files)"
    if [ "$DRY" = 1 ]; then
        while read -r p; do
            [ -n "$p" ] || continue
            if [ -e "$HOME/$p" ] || [ -L "$HOME/$p" ]; then n_old=$((n_old + 1)); else n_new=$((n_new + 1)); fi
        done <<< "$files"
        say "  [dry-run] в $BACKUP было бы сохранено файлов: $n_old (новых будет: $n_new)"
        return 0
    fi
    mkdir -p "$BACKUP/home" "$BACKUP/system"
    : > "$BACKUP/home-existed.txt"; : > "$BACKUP/home-created.txt"
    : > "$BACKUP/system-existed.txt"; : > "$BACKUP/system-created.txt"
    while read -r p; do
        [ -n "$p" ] || continue
        if [ -e "$HOME/$p" ] || [ -L "$HOME/$p" ]; then
            mkdir -p "$BACKUP/home/$(dirname "$p")"
            cp -a "$HOME/$p" "$BACKUP/home/$p"
            echo "$p" >> "$BACKUP/home-existed.txt"; n_old=$((n_old + 1))
        else
            echo "$p" >> "$BACKUP/home-created.txt"; n_new=$((n_new + 1))
        fi
    done <<< "$files"
    while read -r p; do
        [ -n "$p" ] || continue
        if sudo test -e "$p"; then
            sudo mkdir -p "$BACKUP/system$(dirname "$p")"
            sudo cp -a "$p" "$BACKUP/system$p"
            echo "$p" >> "$BACKUP/system-existed.txt"
        else
            echo "$p" >> "$BACKUP/system-created.txt"
        fi
    done < <(sys_list)
    # состояние до установки — для отката
    pacman -Qq > "$BACKUP/pkgs-before.txt"
    systemctl --user list-unit-files --state=enabled --no-legend 2>/dev/null | awk '{print $1}' > "$BACKUP/units-before.txt" || true
    readlink -f /etc/systemd/system/display-manager.service 2>/dev/null | xargs -r basename > "$BACKUP/dm-before.txt" || true
    : > "$BACKUP/units-enabled.txt"
    ok "файлов из ~ сохранено: $n_old (новых будет: $n_new) → ${BACKUP/#$HOME/\~}"
    say "  Список: ${BACKUP/#$HOME/\~}/home-existed.txt; системные — system-existed.txt"
}

# --- 3. пакеты -----------------------------------------------------------------------------------------------
find_aur_helper() {
    if command -v paru >/dev/null; then AUR_HELPER=paru
    elif command -v yay >/dev/null; then AUR_HELPER=yay
    else AUR_HELPER=""; fi
}

install_paru() {
    say "  paru собирается из AUR (пакет paru-bin): нужны base-devel и git."
    ask "Поставить paru?" y || return 1
    run sudo pacman -S --needed base-devel git
    local tmp
    tmp="$(mktemp -d)"
    run git clone https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
    if [ "$DRY" = 0 ]; then (cd "$tmp/paru-bin" && makepkg -si); else say "  [dry-run] cd $tmp/paru-bin && makepkg -si"; fi
    rm -rf "$tmp"
    find_aur_helper
    if [ "$DRY" = 1 ]; then AUR_HELPER=paru; fi
    [ -n "$AUR_HELPER" ]
}

# install_pkgs пакет… — из репозиториев через pacman, остальное через AUR
install_pkgs() {
    local repo=() aur=() p
    for p in "$@"; do
        if pacman -Si "$p" >/dev/null 2>&1; then repo+=("$p"); else aur+=("$p"); fi
    done
    if [ ${#repo[@]} -gt 0 ]; then
        run sudo pacman -S --needed "${repo[@]}" || warn "pacman завершился с ошибкой"
    fi
    if [ ${#aur[@]} -gt 0 ]; then
        say "  Из AUR: ${aur[*]}"
        find_aur_helper
        if [ -z "$AUR_HELPER" ]; then
            say "  Нет помощника AUR (paru или yay)."
            install_paru || { warn "пакеты AUR пропущены: ${aur[*]}"; return 0; }
        fi
        run "$AUR_HELPER" -S --needed "${aur[@]}" || warn "$AUR_HELPER: не все пакеты AUR поставились (${aur[*]})"
    fi
}

install_packages() {
    step "Пакеты"
    local main=()
    mapfile -t main < <(pkg_list "$PKGDIR/arch.txt"; pkg_list "$PKGDIR/aur.txt"; [ "$USE_MAC" = 1 ] && pkg_list "$PKGDIR/mac.txt")
    say "  Основных пакетов: ${#main[@]} (packages/arch.txt$([ "$USE_MAC" = 1 ] && echo ", mac.txt"))."
    if ask "Поставить основные пакеты (sudo pacman -S --needed …)?" y; then
        install_pkgs "${main[@]}"
    else
        warn "пакеты пропущены — без них рис работать не будет"
    fi

    # необязательные — по группам («## название» в optional.txt)
    local title="" line pkgs=()
    local -a groups=()
    while IFS= read -r line; do
        case "$line" in
            "## "*) groups+=("${line#\#\# }") ;;
        esac
    done < "$PKGDIR/optional.txt"
    if [ ${#groups[@]} -gt 0 ] && ask "Посмотреть необязательные пакеты (${#groups[@]} групп)?" n; then
        local chosen=()
        for title in "${groups[@]}"; do
            pkgs=()
            mapfile -t pkgs < <(awk -v t="## $title" '$0 == t { on = 1; next } /^## / { on = 0 } on' "$PKGDIR/optional.txt" \
                | sed -e 's/#.*//' | awk 'NF { print $1 }')
            [ ${#pkgs[@]} -gt 0 ] || continue
            say ""
            say "  ${B}$title${N}"
            awk -v t="## $title" '$0 == t { on = 1; next } /^## / { on = 0 } on && NF' "$PKGDIR/optional.txt" | sed 's/^/    /'
            if ask "Поставить эту группу?" n; then chosen+=("${pkgs[@]}"); fi
        done
        if [ ${#chosen[@]} -gt 0 ]; then install_pkgs "${chosen[@]}"; fi
    fi

    # Hyprland ≥ 0.56 (конфиг на Lua)
    local v
    v="$(pacman -Q hyprland 2>/dev/null | awk '{print $2}')" || v=""
    if [ -n "$v" ] && [ "$(vercmp "$v" 0.56)" -lt 0 ]; then
        warn "Hyprland $v слишком старый: нужен ≥ 0.56 (конфиг на Lua). Обновите систему: sudo pacman -Syu"
    fi
    if [ "$DRY" = 0 ] && [ -f "$BACKUP/pkgs-before.txt" ]; then
        pacman -Qq | sort > "$BACKUP/pkgs-after.txt"
        comm -13 <(sort "$BACKUP/pkgs-before.txt") "$BACKUP/pkgs-after.txt" > "$BACKUP/pkgs-installed.txt" || true
        ok "новых пакетов: $(wc -l < "$BACKUP/pkgs-installed.txt")"
    fi
}

# --- 4. файлы ------------------------------------------------------------------------------------------------
install_files() {
    step "Файлы риса в домашней папке"
    say "  ./rice push ставит публичную версию (RICE_LOCAL=off)$([ "$USE_MAC" = 0 ] && echo ", без раздела @mac")."
    say "  Прежние версии: бэкап выше и ~/.local/state/rice-bak/."
    if ask "Скопировать файлы (./rice push)?" y; then
        run rice_env "$REPO/rice" push
        run mkdir -p "$HOME/Pictures/Wallpapers"
        ok "файлы на месте"
    else
        warn "файлы не скопированы — дальше многое не заработает"
    fi
}

# --- 5. экран входа greetd -----------------------------------------------------------------------------------
# Пользователь автовхода в [initial_session] /etc/greetd/config.toml = текущий
fix_greetd_user() {
    local f=/etc/greetd/config.toml tmp
    sudo test -f "$f" || return 0
    tmp="$(mktemp)"
    sudo cat "$f" | awk -v u="$USER" '
        /^\[/ { sec = $0 }
        sec == "[initial_session]" && /^[[:space:]]*user[[:space:]]*=/ { print "user = \"" u "\""; next }
        { print }' > "$tmp"
    if ! sudo cmp -s "$tmp" "$f"; then
        run sudo install -m 644 "$tmp" "$f"
        ok "в $f подставлен пользователь автовхода: $USER"
    fi
    rm -f "$tmp"
}

# Без автовхода: убрать раздел [initial_session] (при загрузке сразу экран входа)
drop_autologin() {
    local f=/etc/greetd/config.toml tmp
    sudo test -f "$f" || return 0
    tmp="$(mktemp)"
    sudo cat "$f" | awk '/^\[/ { skip = ($0 == "[initial_session]") } !skip' > "$tmp"
    run sudo install -m 644 "$tmp" "$f"
    rm -f "$tmp"
    ok "автовход выключен"
}

setup_greeter() {
    step "Экран входа (greetd + sway + Quickshell)"
    say "  При загрузке — автовход и сразу экран блокировки; после выхода из Hyprland — экран входа Yumi."
    if ! command -v greetd >/dev/null || ! command -v sway >/dev/null; then
        warn "нет greetd или sway (packages/arch.txt) — шаг пропущен"
        return 0
    fi
    ask "Настроить вход через greetd?" y || { say "  Пропущено."; return 0; }

    say "  Сейчас ./rice push-system покажет разницу для файлов greetd — отвечайте y, чтобы применить."
    run "$REPO/rice" push-system greetd
    if [ "$DRY" = 0 ]; then fix_greetd_user; else say "  [dry-run] подставить user = \"$USER\" в [initial_session] /etc/greetd/config.toml"; fi
    if ! ask "Автовход при загрузке (сеанс открывается сразу под экраном блокировки)?" y; then
        if [ "$DRY" = 0 ]; then drop_autologin; else say "  [dry-run] убрать [initial_session] из /etc/greetd/config.toml"; fi
    fi

    # папка копии экрана входа: сам каталог и home — пользователь (пишет yumi-greeter-sync),
    # .cache/yumi — greeter (экран входа пишет туда погоду), .cache/yumi/theme — пользователь (обои)
    getent passwd greeter >/dev/null || warn "нет пользователя greeter (его создаёт пакет greetd)"
    local grp
    grp="$(id -gn)"
    run sudo install -d -o "$USER" -g "$grp" -m 755 "$GREETER_ROOT" "$GREETER_ROOT/home" "$GREETER_ROOT/home/.cache"
    if getent passwd greeter >/dev/null; then
        run sudo install -d -o greeter -g greeter -m 755 "$GREETER_ROOT/home/.cache/yumi"
    fi
    run sudo install -d -o "$USER" -g "$grp" -m 755 "$GREETER_ROOT/home/.cache/yumi/theme"
    ok "папка $GREETER_ROOT готова (копию экрана входа сделает yumi-greeter-sync при входе в сеанс)"

    # другие менеджеры входа
    local dm
    dm="$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null | xargs -r basename)" || dm=""
    if [ -n "$dm" ] && [ "$dm" != greetd.service ]; then
        say "  Сейчас включён другой менеджер входа: $dm."
        if ask "Выключить $dm (вход будет через greetd)?" y; then
            run sudo systemctl disable "$dm"
        else
            warn "$dm оставлен — greetd не включается (два менеджера входа одновременно нельзя)"
            return 0
        fi
    fi
    run sudo systemctl enable greetd.service
    if [ "$DRY" = 0 ]; then touch "$BACKUP/greetd-enabled"; fi
    ok "greetd включён (enable), но НЕ запущен"
    say "  Вход через greetd начнётся после перезагрузки. Не запускайте его сейчас (systemctl start greetd):"
    say "  он займёт первую консоль и может закрыть текущий сеанс."
}

# --- 6. остальные системные файлы ----------------------------------------------------------------------------
install_system_rest() {
    step "Остальные системные настройки (/etc) — по желанию"
    say "  GRUB (тихая загрузка), zram, sysctl, earlyoom, Bluetooth, faillock, таймаут служб."
    say "  Они настроены под машину автора: GRUB — тема и параметры ядра, Bluetooth — DeviceID Apple (для AirPods)."
    say "  ./rice push-system покажет разницу по каждому файлу и спросит отдельно; если не уверены — отвечайте N."
    if ask "Посмотреть и применить по одному?" n; then
        run "$REPO/rice" push-system
    fi
}

# --- 7. службы пользователя ----------------------------------------------------------------------------------
unit_exists() { [ "$(systemctl --user list-unit-files --no-legend "$1" 2>/dev/null | wc -l)" -gt 0 ]; }

enable_units() {
    step "Службы пользователя (systemd --user)"
    local units=(
        hypridle.service hyprsunset.service
        yumi-quickshell.service
        yumi-awww.service yumi-wallpaper.service yumi-wallpaper-scan.path
        yumi-bar-events.service yumi-battery-notify.service yumi-mouse-notify.service
        yumi-clip-text.service yumi-clip-image.service yumi-clip-persist.service
        yumi-hz-guard.service yumi-mic.service yumi-airpods.service yumi-kb-light-watch.service
        yumi-greeter-sync.path yumi-greeter-sync.service
        yumi-caffeine-guard.timer yumi-calendar-remind.timer
    )
    if [ "$USE_MAC" = 1 ]; then
        units+=(yumi-lid-guard.service)
        if [ -x /usr/local/bin/touchbar-agent ]; then units+=(touchbar-agent.service); fi
    fi
    if [ -f "$HOME/.local/share/yumi-music/venv/bin/python" ]; then units+=(yumi-music-update.timer); fi
    if [ -f "$HOME/.local/share/yumi-music/proxy/wireproxy.conf" ] && command -v wireproxy >/dev/null; then
        units+=(yumi-music-proxy.service)
    fi
    run systemctl --user daemon-reload
    local u todo=()
    for u in "${units[@]}"; do
        if [ "$DRY" = 1 ] || unit_exists "$u"; then todo+=("$u"); else warn "нет юнита $u — пропущен"; fi
    done
    say "  Будут включены (запустятся при следующем входе в Hyprland): ${#todo[@]}"
    printf '    %s\n' "${todo[@]}"
    ask "Включить?" y || return 0
    for u in "${todo[@]}"; do
        if [ "$DRY" = 0 ] && ! systemctl --user is-enabled --quiet "$u" 2>/dev/null; then
            echo "$u" >> "$BACKUP/units-enabled.txt"
        fi
        run systemctl --user --quiet enable "$u" || warn "не включилась: $u"
    done
    ok "службы включены"
    say "  Не включены нарочно: yumi-rice-drift.timer (для разработки риса), yumi-music-sync.timer (нужны свои"
    say "  плейлисты ~/.config/yumi/music/playlists.json), yumi-udiskie, yumi-tray, yumi-notify-log, yumi-battery-limit."
}

# --- 8. музыка -----------------------------------------------------------------------------------------------
setup_music() {
    step "Плеер yumi-music (YouTube Music и SoundCloud)"
    local venv="$HOME/.local/share/yumi-music/venv"
    if [ -x "$venv/bin/python" ]; then ok "окружение уже есть: ${venv/#$HOME/\~}"; return 0; fi
    say "  Плееру нужно своё окружение Python со свежими yt-dlp и ytmusicapi (pip, из интернета, ~60 МБ)."
    ask "Создать его сейчас?" y || { say "  Позже: python -m venv $venv && $venv/bin/pip install -U 'yt-dlp[default]' ytmusicapi"; return 0; }
    run python -m venv "$venv"
    run "$venv/bin/pip" install -q -U "yt-dlp[default]" ytmusicapi || warn "pip не смог поставить yt-dlp/ytmusicapi"
    if [ "$DRY" = 1 ] || unit_exists yumi-music-update.timer; then
        run systemctl --user --quiet enable yumi-music-update.timer || true
        if [ "$DRY" = 0 ]; then echo yumi-music-update.timer >> "$BACKUP/units-enabled.txt"; fi
    fi
    say "  Прокси для SoundCloud (необязательно): группа «Музыка» в optional.txt, затем"
    say "  python3 ~/.local/share/yumi-music/proxy/warp-register.py и systemctl --user enable --now yumi-music-proxy"
}

# --- 9. обои и цвета -----------------------------------------------------------------------------------------
setup_wallpaper() {
    step "Обои и цвета"
    local dir="$HOME/Pictures/Wallpapers" n=0
    [ -d "$dir" ] && n="$(find "$dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) | wc -l)"
    if [ "$n" -eq 0 ]; then
        say "  В ${dir/#$HOME/\~} пока нет картинок. Положите туда свои обои (подпапки = коллекции) —"
        say "  цвета всего рабочего стола берутся из них. После входа: SUPER+SHIFT+W или yumi-wallpaper random."
        return 0
    fi
    say "  Найдено картинок: $n."
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        if ask "Подготовить миниатюры и цвета для всех обоев в фоне (yumi-wallpaper scan + warm)?" y; then
            mkdir -p "$STATE"
            if [ "$DRY" = 1 ]; then
                say "  [dry-run] (yumi-wallpaper scan && yumi-wallpaper warm) в фоне → $STATE/wallpaper-warm.log"
            else
                nohup sh -c '"$HOME/.local/bin/yumi-wallpaper" scan && "$HOME/.local/bin/yumi-wallpaper" warm' \
                    > "$STATE/wallpaper-warm.log" 2>&1 &
                ok "идёт в фоне, журнал: ${STATE/#$HOME/\~}/wallpaper-warm.log"
            fi
        fi
    else
        say "  Миниатюры и цвета соберутся сами при первом входе (служба yumi-wallpaper)."
        say "  Чтобы смена обоев была мгновенной, потом в Hyprland: yumi-wallpaper warm"
    fi
}

# --- 10. окно пароля polkit ----------------------------------------------------------------------------------
setup_polkit() {
    step "Окно пароля (polkit)"
    say "  Свой агент на Quickshell вместо hyprpolkitagent: окна пароля в стиле риса. Откат: yumi-polkit-switch off"
    ask "Включить окно пароля Quickshell?" y || return 0
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ -x "$HOME/.local/bin/yumi-polkit-switch" ]; then
        run "$HOME/.local/bin/yumi-polkit-switch" on || warn "yumi-polkit-switch on завершился с ошибкой"
    else
        # вне сеанса: то же, что «on», без перезапуска Quickshell (он прочитает флаг при входе)
        run mkdir -p "$HOME/.config/yumi"
        run touch "$HOME/.config/yumi/polkit-qs"
        run systemctl --user --quiet disable hyprpolkitagent.service || true
    fi
    if [ "$DRY" = 0 ]; then touch "$BACKUP/polkit-on"; fi
    ok "окно пароля Quickshell включено"
}

# --- 11. оболочка --------------------------------------------------------------------------------------------
setup_shell() {
    step "Оболочка zsh"
    if [ ! -d "$HOME/.oh-my-zsh" ] && [ ! -d /usr/share/oh-my-zsh ]; then
        say "  Конфиг zsh подхватывает oh-my-zsh с плагинами автодополнения и подсветки, если они есть (без них тоже работает)."
        if ask "Скачать oh-my-zsh и плагины в ~/.oh-my-zsh (git, без sudo)?" n; then
            local c="$HOME/.oh-my-zsh/custom/plugins"
            run git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
            run git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions "$c/zsh-autosuggestions"
            run git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting "$c/zsh-syntax-highlighting"
            run git clone --depth 1 https://github.com/chrissicool/zsh-256color "$c/zsh-256color"
            if [ "$DRY" = 0 ]; then touch "$BACKUP/omz-installed"; fi
        fi
    fi
    local cur
    cur="$(getent passwd "$USER" | cut -d: -f7)"
    if [ "${cur##*/}" != zsh ] && command -v zsh >/dev/null; then
        if ask "Сделать zsh оболочкой по умолчанию (chsh)? Сейчас: $cur" y; then run chsh -s "$(command -v zsh)"; fi
    fi
    return 0
}

# --- 12. Mac -------------------------------------------------------------------------------------------------
mac_info() {
    [ "$IS_MAC" = 1 ] || return 0
    step "MacBook: дополнительные модули (ставятся отдельно)"
    cat << EOF
  Touch ID — вход, sudo и экран блокировки по пальцу. Нужно своё ядро и модули, поэтому установщик
  их не ставит. Читайте README и делайте по шагам (там же откат):
      git clone $TOUCHID_URL ~/Projects/yumi-touchid
      cd ~/Projects/yumi-touchid && less README.md

  Тачбар — touchbard ($TOUCHBARD_URL) со слоями, плагинами и цветами обоев:
      git clone $TOUCHBAR_URL ~/Projects/yumi-touchbar
      cd ~/Projects/yumi-touchbar && less README.md      # установка: ./install.sh в той папке
  После установки тачбара включите агент: systemctl --user enable touchbar-agent.service
EOF
}

# --- итог ----------------------------------------------------------------------------------------------------
finish() {
    step "Готово"
    cat << EOF
  Дальше:
    1. Мониторы: ~/.config/yumi/monitors.conf (масштаб интерфейса и название), экран входа —
       ~/.config/yumi/greeter/sway.conf (строки output: имена выходов — из hyprctl monitors).
    2. Свой аватар для экрана блокировки: ~/.config/hypr/hyprlock/avatar.jpg
    3. Перезагрузка — затем проверка: yumi-doctor
  Бэкап этого запуска: ${BACKUP/#$HOME/\~}
  Откат: ./install.sh --uninstall
EOF
}

# --- удаление ------------------------------------------------------------------------------------------------
uninstall() {
    step "Откат Yumi-Rice"
    local backups=() b p
    mapfile -t backups < <(ls -1d "$STATE"/backup-* 2>/dev/null | sort)
    [ ${#backups[@]} -gt 0 ] || die "нет бэкапов в $STATE — откатывать нечего"
    say "  Бэкапов: ${#backups[@]} (первый: ${backups[0]##*/}). Для каждого файла берётся самая ранняя версия."
    if [ "$DRY" = 0 ]; then sudo -v || die "sudo не сработал"; fi

    # что делать с каждым файлом: первая запись (самый ранний бэкап) побеждает
    declare -A act=() src=() sact=() ssrc=()
    for b in "${backups[@]}"; do
        while read -r p; do [ -n "$p" ] && [ -z "${act[$p]:-}" ] && { act[$p]=restore; src[$p]="$b/home/$p"; }; done < <(read_opt "$b/home-existed.txt")
        while read -r p; do [ -n "$p" ] && [ -z "${act[$p]:-}" ] && act[$p]=delete; done < <(read_opt "$b/home-created.txt")
        while read -r p; do [ -n "$p" ] && [ -z "${sact[$p]:-}" ] && { sact[$p]=restore; ssrc[$p]="$b/system$p"; }; done < <(read_opt "$b/system-existed.txt")
        while read -r p; do [ -n "$p" ] && [ -z "${sact[$p]:-}" ] && sact[$p]=delete; done < <(read_opt "$b/system-created.txt")
    done
    local nr=0 nd=0
    for p in "${!act[@]}"; do if [ "${act[$p]}" = restore ]; then nr=$((nr + 1)); else nd=$((nd + 1)); fi; done
    say "  Файлы в ~: вернуть прежние — $nr, удалить добавленные — $nd."
    say "  /etc: $(printf '%s\n' "${!sact[@]}" | grep -c . || true) файлов (вернуть или удалить), вход — прежний менеджер входа."

    # службы
    local units=()
    mapfile -t units < <(cat "${backups[@]/%//units-enabled.txt}" 2>/dev/null | sort -u)
    if [ ${#units[@]} -gt 0 ] && ask "Выключить службы, включённые установщиком (${#units[@]})?" y; then
        run systemctl --user --quiet disable "${units[@]}" || true
        ok "службы выключены"
    fi
    if ls "$STATE"/backup-*/polkit-on >/dev/null 2>&1 && ask "Вернуть штатное окно пароля (hyprpolkitagent)?" y; then
        run rm -f "$HOME/.config/yumi/polkit-qs"
        run systemctl --user --quiet enable hyprpolkitagent.service || true
    fi

    # файлы в ~
    if ask "Вернуть файлы в домашней папке ($nr) и удалить добавленные ($nd)?" y; then
        for p in "${!act[@]}"; do
            if [ "${act[$p]}" = restore ]; then
                run mkdir -p "$(dirname "$HOME/$p")"
                run rm -rf "$HOME/$p"
                run cp -a "${src[$p]}" "$HOME/$p"
            else
                run rm -f "$HOME/$p"
            fi
        done
        run systemctl --user daemon-reload
        ok "файлы в ~ возвращены"
    fi

    # вход и /etc
    if ask "Вернуть системные файлы (/etc) и прежний менеджер входа?" y; then
        for p in "${!sact[@]}"; do
            if [ "${sact[$p]}" = restore ]; then run sudo cp -a "${ssrc[$p]}" "$p"; else run sudo rm -f "$p"; fi
        done
        if ls "$STATE"/backup-*/greetd-enabled >/dev/null 2>&1; then
            local dm=""
            dm="$(cat "${backups[0]}/dm-before.txt" 2>/dev/null || true)"
            run sudo systemctl disable greetd.service || true
            if [ -n "$dm" ] && [ "$dm" != greetd.service ]; then
                run sudo systemctl enable "$dm" || warn "не удалось включить $dm"
                ok "менеджер входа: снова $dm (после перезагрузки)"
            else
                warn "прежнего менеджера входа не было — после перезагрузки будет текстовая консоль"
            fi
        fi
        if [ -d "$GREETER_ROOT" ] && ask "Удалить копию экрана входа $GREETER_ROOT?" y; then
            run sudo rm -rf "$GREETER_ROOT"
        fi
    fi

    # пакеты — только по явному согласию
    local pk=()
    mapfile -t pk < <(cat "${backups[@]/%//pkgs-installed.txt}" 2>/dev/null | sort -u)
    if [ ${#pk[@]} -gt 0 ]; then
        say "  Установщик поставил пакетов: ${#pk[@]}. Удалять их из открытого сеанса Hyprland опасно."
        if ask "Удалить их (sudo pacman -Rns)?" n; then
            run sudo pacman -Rns "${pk[@]}" || warn "pacman не удалил часть пакетов (нужны другим) — проверьте вручную"
        else
            say "  Позже: sudo pacman -Rns \$(cat ${STATE/#$HOME/\~}/backup-*/pkgs-installed.txt | sort -u)"
        fi
    fi
    if ls "$STATE"/backup-*/omz-installed >/dev/null 2>&1 && ask "Удалить ~/.oh-my-zsh?" n; then
        run rm -rf "$HOME/.oh-my-zsh"
    fi
    step "Откат завершён"
    say "  Перезагрузите компьютер. Бэкапы остаются в ${STATE/#$HOME/\~} — удалите их вручную, когда всё проверено."
}

# --- запуск --------------------------------------------------------------------------------------------------
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY=1 ;;
        --uninstall) MODE=uninstall ;;
        -h|--help) usage; exit 0 ;;
        *) usage; die "неизвестный параметр: $arg" ;;
    esac
done
if [ "$DRY" = 1 ]; then say "${Y}Режим проверки (--dry-run): ничего не меняется.${N}"; fi

if [ "$MODE" = uninstall ]; then
    [ "$(id -u)" -ne 0 ] || die "не запускайте от root"
    uninstall
    exit 0
fi

say "${B}Yumi-Rice 3.1 — установка${N} (репозиторий: $REPO)"
check_system
make_backup
install_packages
install_files
setup_greeter
install_system_rest
setup_music
enable_units
setup_wallpaper
setup_polkit
setup_shell
mac_info
finish
