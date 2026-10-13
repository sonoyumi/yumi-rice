#!/usr/bin/env zsh

# Yumi-Rice: окружение zsh (было в HyDE). Подключается из ~/.zshenv для любой zsh,
# не только интерактивной.

# Подключаем все модули conf.d/*.zsh, каталоги пропускаются. Поэтому набор
# файлов можно держать в conf.d/<имя>/ и подключать его одним conf.d/<имя>.zsh

for file in "${ZDOTDIR:-$HOME/.config/zsh}/conf.d/"*.zsh; do
  [ -r "$file" ] && source "$file"
done
