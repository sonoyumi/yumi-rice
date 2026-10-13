#!/usr/bin/env zsh

# Приглашение: Starship, если установлен, иначе Powerlevel10k (p10k)

# Выходим, если YUMI_ZSH_PROMPT не равен 1
if [[ "${YUMI_ZSH_PROMPT}" != "1" ]]; then
    return
fi

if command -v starship &>/dev/null; then
    # ===== Starship =====
    eval "$(starship init zsh)"
    export STARSHIP_CACHE=$XDG_CACHE_HOME/starship
    export STARSHIP_CONFIG=$XDG_CONFIG_HOME/starship/starship.toml
# ===== конец Starship =====
elif [ -r $HOME/.p10k.zsh ] || [ -r $ZDOTDIR/.p10k.zsh ]; then
    # ===== Powerlevel10k =====
    POWERLEVEL10K_TRANSIENT_PROMPT=same-dir
    P10k_THEME=${P10k_THEME:-/usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme}
    [[ -r $P10k_THEME ]] && source $P10k_THEME
    # Настройка: `p10k configure` или правка $HOME/.p10k.zsh
    if [[ -f $HOME/.p10k.zsh ]]; then
        source $HOME/.p10k.zsh
    elif [[ -f $ZDOTDIR/.p10k.zsh ]]; then
        source $ZDOTDIR/.p10k.zsh
    fi
# ===== конец Powerlevel10k =====
fi
