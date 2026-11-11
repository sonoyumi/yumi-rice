#!/usr/bin/env zsh

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
# ZDOTDIR=$HOME трактуем как «не задан» (так его передаёт интеграция VS Code),
# иначе файл загрузил бы сам себя → бесконечная рекурсия.
if [[ -z $ZDOTDIR || $ZDOTDIR == $HOME ]]; then
    export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
fi

if ! source $ZDOTDIR/.zshenv; then
    echo "FATAL Error: Could not source $ZDOTDIR/.zshenv"
    return 1
fi
