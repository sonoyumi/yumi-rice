# Yumi-Rice: инструменты терминала (только интерактивная оболочка).
# z / zi — zoxide (переход по памяти; обычный cd не тронут), Ctrl+R — atuin (стрелка вверх — как раньше),
# ls/ll/la/lt — eza со значками и git, если eza установлен.

# zoxide: «z rice» — в ~/Projects/yumi-rice из любой папки; «zi» — выбрать из списка
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

# atuin: история с поиском на Ctrl+R; без синхронизации (см. ~/.config/atuin/config.toml)
command -v atuin >/dev/null && eval "$(atuin init zsh --disable-up-arrow)"

# eza вместо ls
if command -v eza >/dev/null; then
    alias ls='eza --icons=auto --group-directories-first'
    alias ll='eza -l --icons=auto --git --group-directories-first --time-style=relative'
    alias la='eza -la --icons=auto --git --group-directories-first --time-style=relative'
    alias lt='eza --tree --level=2 --icons=auto --group-directories-first'
fi
