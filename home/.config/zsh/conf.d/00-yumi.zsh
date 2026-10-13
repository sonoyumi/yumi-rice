#!/usr/bin/env zsh

# Точка входа оболочки Yumi-Rice: окружение для любой zsh, остальное — только
# для интерактивной. Свои настройки — в ./user.zsh и ./.zshrc
# shellcheck disable=SC1091
if ! . "$ZDOTDIR/conf.d/yumi/env.zsh"; then
    echo "Error: Could not source $ZDOTDIR/conf.d/yumi/env.zsh"
    return 1
fi

if [[ $- == *i* ]] && [ -f "$ZDOTDIR/conf.d/yumi/terminal.zsh" ]; then
    . "$ZDOTDIR/conf.d/yumi/terminal.zsh" || echo "Error: Could not source $ZDOTDIR/conf.d/yumi/terminal.zsh"
fi

if [[ $- == *i* ]] && [ -f "$ZDOTDIR/conf.d/yumi/tools.zsh" ]; then
    . "$ZDOTDIR/conf.d/yumi/tools.zsh" || echo "Error: Could not source $ZDOTDIR/conf.d/yumi/tools.zsh"
fi
