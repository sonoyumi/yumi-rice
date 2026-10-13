# Свои настройки (подключается после conf.d/yumi/terminal.zsh).
# То, что нужно до загрузки плагинов, — в $ZDOTDIR/user.zsh

#  Plugins 
# oh-my-zsh plugins are loaded  in $ZDOTDIR/.user.zsh file, see the file for more information

#  Aliases 
# Override aliases here in '$ZDOTDIR/.zshrc' (already set in .zshenv)

# # Helpful aliases
# alias c='clear'                                                        # clear terminal
# alias l='eza -lh --icons=auto'                                         # long list
# alias ls='eza -1 --icons=auto'                                         # short list
# alias ll='eza -lha --icons=auto --sort=name --group-directories-first' # long list all
# alias ld='eza -lhD --icons=auto'                                       # long list dirs
# alias lt='eza --icons=auto --tree'                                     # list folder as tree
# alias un='$aurhelper -Rns'                                             # uninstall package
# alias up='$aurhelper -Syu'                                             # update system/package/aur
# alias pl='$aurhelper -Qs'                                              # list installed package
# alias pa='$aurhelper -Ss'                                              # list available package
# alias pc='$aurhelper -Sc'                                              # remove unused cache
# alias po='$aurhelper -Qtdq | $aurhelper -Rns -'                        # remove unused packages, also try > $aurhelper -Qqd | $aurhelper -Rsu --print -
# alias vc='code'                                                        # gui code editor
# alias fastfetch='fastfetch --logo-type kitty'

# # Directory navigation shortcuts
# alias ..='cd ..'
# alias ...='cd ../..'
# alias .3='cd ../../..'
# alias .4='cd ../../../..'
# alias .5='cd ../../../../..'

# # Always mkdir a path (this doesn't inhibit functionality to make a single dir)
# alias mkdir='mkdir -p'

#  This is your file 
# Add your configurations here
# export EDITOR=nvim
# export EDITOR=code

# unset -f command_not_found_handler # Uncomment to prevent searching for commands not found in package manager
alias sc='mpv --no-video --ytdl-raw-options=ignore-errors='

# ================================================================
# Перенесено из ~/.zshrc (тот файл zsh не читает: ZDOTDIR=~/.config/zsh)

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

[[ -f $ZDOTDIR/user_aliases.zsh ]] && source $ZDOTDIR/user_aliases.zsh

# Простой вид для SSH (Termius): без значков и без starship
if [[ -n $SSH_CLIENT || -n $SSH_TTY ]]; then
    alias ls='command ls --color=auto'
    alias l='command ls -la --color=auto'
    alias ll='command ls -la --color=auto'
    # starship уже включён conf.d/yumi/prompt.zsh до этого файла — снимаем его хуки
    precmd_functions=(${precmd_functions:#*starship*})
    preexec_functions=(${preexec_functions:#*starship*})
    unset RPROMPT
    PROMPT='%F{cyan}%n@%m%f:%F{yellow}%~%f %# '
fi
