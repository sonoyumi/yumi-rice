#!/usr/bin/env zsh

# Интерактивная оболочка: история, oh-my-zsh с плагинами, автодополнение,
# приглашение, функции, алиасы. Подключается из conf.d/00-yumi.zsh только при $- == *i*,
# чтобы ./.zshrc оставался чистым для своих настроек

setopt INTERACTIVE_COMMENTS

function _load_functions() {
    # Подключаем все functions/*.zsh, каталоги пропускаются
    for file in "${ZDOTDIR:-$HOME/.config/zsh}/functions/"*.zsh(N); do
        [ -r "$file" ] && source "$file"
    done
}

function _load_completions() {
    # (N): каталог может быть пустым — без ошибки nomatch
    for file in "${ZDOTDIR:-$HOME/.config/zsh}/completions/"*.zsh(N); do
        [ -r "$file" ] && source "$file"
    done
}

function _dedup_zsh_plugins {
    unset -f _dedup_zsh_plugins
    # Где установлен oh-my-zsh
    zsh_paths=(
        "/usr/share/oh-my-zsh"
        "/usr/local/share/oh-my-zsh"
        "$HOME/.oh-my-zsh"
    )
    for zsh_path in "${zsh_paths[@]}"; do [[ -d $zsh_path ]] && export ZSH=$zsh_path && break; done
    # Плагины по умолчанию + свои из user.zsh
    yumi_plugins=(git zsh-256color zsh-autosuggestions zsh-syntax-highlighting)
    plugins+=("${plugins[@]}" "${yumi_plugins[@]}")
    # Убираем повторы
    plugins=("${plugins[@]}")
    plugins=($(printf "%s\n" "${plugins[@]}" | sort -u))
    # Отложить oh-my-zsh до появления приглашения
    typeset -g DEFER_OMZ_LOAD=1
}

function _defer_omz_after_prompt_before_input() {

    [[ -r $ZSH/oh-my-zsh.sh ]] && source $ZSH/oh-my-zsh.sh
    #! Ничего медленного здесь не запускать

    # Свой каталог дополнений — в fpath
    fpath=($ZDOTDIR/completions "${fpath[@]}")

    _load_compinit
    _load_functions
    _load_completions

    # При отложенной загрузке zsh-autosuggestions иначе не работает на первом приглашении
    if typeset -f _zsh_autosuggest_start >/dev/null; then
        _zsh_autosuggest_start
    fi

    chmod +r $ZDOTDIR/.zshrc # .zshrc снова читаемый
    [[ -r $ZDOTDIR/.zshrc ]] && source $ZDOTDIR/.zshrc
}

function _load_deferred_plugin_system() {

    # Выходим, если YUMI_ZSH_DEFER не равен 1
    if [[ "${YUMI_ZSH_DEFER}" != "1" ]]; then
        unset -f _load_deferred_plugin_system
        return
    fi

    # Отложенный oh-my-zsh: грузится, когда запускается редактор строки (до ввода)
    if [[ -n $DEFER_OMZ_LOAD ]]; then
        unset DEFER_OMZ_LOAD
        [[ ${VSCODE_INJECTION} == 1 ]] || chmod -r $ZDOTDIR/.zshrc # VS Code должен читать .zshrc
        zle -N zle-line-init _defer_omz_after_prompt_before_input  # лучший момент — инициализация редактора строки
    fi
    #  Ниже — то, что выполняется после появления приглашения

    # autoload -Uz add-zsh-hook
    # add-zsh-hook zshaddhistory load_omz_deferred # после первой команды в истории
    # add-zsh-hook precmd load_omz_deferred # когда оболочка готова принимать команды
    # add-zsh-hook preexec load_omz_deferred # перед первой командой

    # При отложенной загрузке zsh-autosuggestions иначе не работает на первом приглашении
    if typeset -f _zsh_autosuggest_start >/dev/null; then
        _zsh_autosuggest_start
    fi

    # Часть привязок иначе не работает на первом приглашении
    bindkey '\e[H' beginning-of-line
    bindkey '\e[F' end-of-line

}

function do_render {
    # Умеет ли терминал картинки (image) / нужна ли ASCII-графика (art)
    local type="${1:-image}"
    TERMINAL_IMAGE_SUPPORT=(kitty konsole ghostty WezTerm)
    local terminal_no_art=(vscode code codium)
    TERMINAL_NO_ART="${TERMINAL_NO_ART:-${terminal_no_art[@]}}"
    CURRENT_TERMINAL="${TERM_PROGRAM:-$(ps -o comm= -p $(ps -o ppid= -p $$))}"

    case "${type}" in
    image)
        if [[ " ${TERMINAL_IMAGE_SUPPORT[@]} " =~ " ${CURRENT_TERMINAL} " ]]; then
            return 0
        else
            return 1
        fi
        ;;
    art)
        if [[ " ${TERMINAL_NO_ART[@]} " =~ " ${CURRENT_TERMINAL} " ]]; then
            return 1
        else
            return 0
        fi
        ;;
    *)
        return 1
        ;;
    esac
}

function _load_compinit() {
    # Автодополнение; полная проверка не чаще раза в YUMI_ZSH_COMPINIT_CHECK часов
    autoload -Uz compinit

    # Нужен для квалификатора в шаблоне ниже
    setopt EXTENDED_GLOB

    if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+${YUMI_ZSH_COMPINIT_CHECK:-1}) ]]; then
        compinit
    else
        compinit -C
    fi

    _comp_options+=(globdots) # дополнять и скрытые файлы
}

function _load_prompt() {
    # Своё приглашение из ./prompt.zsh, а если он вернул ошибку — conf.d/yumi/prompt.zsh
    if ! source ${ZDOTDIR}/prompt.zsh >/dev/null 2>&1; then
        [[ -f $ZDOTDIR/conf.d/yumi/prompt.zsh ]] && source $ZDOTDIR/conf.d/yumi/prompt.zsh
    fi
}

# Настройки (переопределять в $ZDOTDIR/user.zsh)

YUMI_ZSH_DEFER="1"      # unset в $ZDOTDIR/user.zsh — без отложенной загрузки
YUMI_ZSH_PROMPT="1"     # unset в $ZDOTDIR/user.zsh — без своего приглашения
YUMI_ZSH_NO_PLUGINS="0" # "1" в $ZDOTDIR/user.zsh — без плагинов oh-my-zsh

ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# История
HISTFILE=${HISTFILE:-$ZDOTDIR/.zsh_history}
if [[ -f $HOME/.zsh_history ]] && [[ ! -f $HISTFILE ]]; then
    echo "Please manually move $HOME/.zsh_history to $HISTFILE"
    echo "Or move it somewhere else to avoid conflicts"
fi
HISTSIZE=10000
SAVEHIST=10000


export HISTFILE ZSH_AUTOSUGGEST_STRATEGY HISTSIZE SAVEHIST

# Пакетный менеджер для алиасов in/un/up/pl/pa и command_not_found_handler (functions/error-handlers.zsh):
# обёртка pm.sh, перенесена в ~/.local/lib/yumi/pm (раньше — через hyde-shell pm)
PM_COMMAND=(bash "$HOME/.local/lib/yumi/pm/pm.sh")

# Свои настройки до загрузки плагинов
if [[ -f $HOME/.user.zsh ]]; then
    source $HOME/.user.zsh
elif [[ -f $ZDOTDIR/user.zsh ]]; then
    source $ZDOTDIR/user.zsh
fi

_load_compinit

if [[ ${YUMI_ZSH_NO_PLUGINS} != "1" ]]; then
    _dedup_zsh_plugins
    if [[ "$YUMI_ZSH_OMZ_DEFER" == "1" ]] && [[ -r $ZSH/oh-my-zsh.sh ]]; then
        # Отложенный oh-my-zsh (капризный, только для совместимости)
        _load_deferred_plugin_system
        _load_prompt # отключает transient prompt
    elif source $ZDOTDIR/plugin.zsh >/dev/null 2>&1; then
        # Своя система плагинов из $ZDOTDIR/plugin.zsh
        source $ZDOTDIR/plugin.zsh
        _load_prompt
        _load_functions
        _load_completions
    elif [[ -r $ZSH/oh-my-zsh.sh ]]; then
        # По умолчанию (plugin.zsh возвращает ошибку) — oh-my-zsh
        source $ZSH/oh-my-zsh.sh
        _load_prompt
        _load_functions
        _load_completions
    else
        echo "No plugin system found. Please install a plugin system or create a $ZDOTDIR/plugin.zsh file."
        echo "You can use $ZDOTDIR/plugin.zsh file to load your own plugins."
    fi
else
    # Только свои плагины из $ZDOTDIR/plugin.zsh, если есть
    [[ -r $ZDOTDIR/plugin.zsh ]] && source $ZDOTDIR/plugin.zsh
    _load_prompt
    _load_functions
    _load_completions
fi

__package_manager () {
    ${PM_COMMAND[@]} "$@"
}

alias c='clear' \
    in='__package_manager install' \
    un='__package_manager remove' \
    up='__package_manager upgrade' \
    pl='__package_manager search installed' \
    pa='__package_manager search all' \
    vc='code' \
    ..='cd ..' \
    ...='cd ../..' \
    .3='cd ../../..' \
    .4='cd ../../../..' \
    .5='cd ../../../../..' \
    mkdir='mkdir -p'
