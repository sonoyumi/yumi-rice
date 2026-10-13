#!/usr/bin/env zsh

# Окружение оболочки: ~/.local/bin в PATH, каталоги XDG

case ":$PATH:" in
*":$HOME/.local/bin:"*) ;;
*) PATH="$HOME/.local/bin:$PATH" ;;
esac

typeset -gx XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
typeset -gx XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
typeset -gx XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
typeset -gx XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
typeset -gx XDG_DATA_DIRS="${XDG_DATA_DIRS:-$XDG_DATA_HOME:/usr/local/share:/usr/share}"
# ~/.local/bin в начало PATH, только если его там ещё нет
[[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && PATH="$HOME/.local/bin:$PATH"

function set_xdg_user_dir() {
  [[ -n "$2" ]] && typeset -gx "$1=$2"
}

if command -v xdg-user-dir >/dev/null 2>&1; then
  set_xdg_user_dir XDG_DESKTOP_DIR "$(xdg-user-dir DESKTOP 2>/dev/null)"
  set_xdg_user_dir XDG_DOWNLOAD_DIR "$(xdg-user-dir DOWNLOAD 2>/dev/null)"
  set_xdg_user_dir XDG_TEMPLATES_DIR "$(xdg-user-dir TEMPLATES 2>/dev/null)"
  set_xdg_user_dir XDG_PUBLICSHARE_DIR "$(xdg-user-dir PUBLICSHARE 2>/dev/null)"
  set_xdg_user_dir XDG_DOCUMENTS_DIR "$(xdg-user-dir DOCUMENTS 2>/dev/null)"
  set_xdg_user_dir XDG_MUSIC_DIR "$(xdg-user-dir MUSIC 2>/dev/null)"
  set_xdg_user_dir XDG_PICTURES_DIR "$(xdg-user-dir PICTURES 2>/dev/null)"
  set_xdg_user_dir XDG_VIDEOS_DIR "$(xdg-user-dir VIDEOS 2>/dev/null)"
fi
unfunction set_xdg_user_dir

# Окружение сеанса (XDG_CURRENT_DESKTOP, HYPRLAND_CONFIG и т.п.) задаёт uwsm:
# ~/.config/uwsm/env.d, env-hyprland.d

typeset -U PATH

# Мусор программ — по местам XDG, а не в ~ (npm, история python, wget, git)
export NPM_CONFIG_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/npm"
export PYTHON_HISTORY="${XDG_STATE_HOME:-$HOME/.local/state}/python/history"
export WGETRC="${XDG_CONFIG_HOME:-$HOME/.config}/wgetrc"
export PARALLEL_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/parallel"
