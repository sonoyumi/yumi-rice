#!/usr/bin/env sh
# yumi: общее окружение пользователя для uwsm (было env.d/00-hyde.sh HyDE).
# uwsm читает env.d/* по алфавиту; 01-gpu.sh — до этого файла.

# Каталоги XDG по умолчанию (обычно уже заданы входом через zsh; было setup_xdg из ~/.local/lib/hyde/shell/activate)
: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_CACHE_HOME:=$HOME/.cache}"
: "${XDG_DATA_HOME:=$HOME/.local/share}"
: "${XDG_STATE_HOME:=$HOME/.local/state}"

# Свои команды (~/.local/bin) — первыми в PATH
PATH="$HOME/.local/bin:$PATH"

# История less — во временный каталог
LESSHISTFILE="${LESSHISTFILE:-/tmp/less-hist}"

# Настройки программ в ~/.config
PARALLEL_HOME="$XDG_CONFIG_HOME/parallel"
SCREENRC="$XDG_CONFIG_HOME/screen/screenrc"

export XDG_CONFIG_HOME XDG_CACHE_HOME XDG_DATA_HOME XDG_STATE_HOME PATH LESSHISTFILE PARALLEL_HOME SCREENRC

# Мусор программ — по местам XDG, а не в ~ (npm, история python, wget, git)
export NPM_CONFIG_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/npm"
export PYTHON_HISTORY="${XDG_STATE_HOME:-$HOME/.local/state}/python/history"
export WGETRC="${XDG_CONFIG_HOME:-$HOME/.config}/wgetrc"
export PARALLEL_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/parallel"
