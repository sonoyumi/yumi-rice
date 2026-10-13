#!/bin/bash
# Хук yumi-colors: kitty.conf подключает базовые настройки yumi-base.conf (бывший hyde.conf HyDE)
# первой строкой; старые include hyde.conf / share/hyde/kitty.conf убираются. Затем kitty перечитывает тему

confDir="${confDir:-$HOME/.config}"
kittyConf="${confDir}/kitty/kitty.conf"

INC_LINE="include yumi-base.conf"

sed -i -e "/include .*share\/hyde\/kitty.conf.*/d" -e "/^include hyde\.conf$/d" "$kittyConf"
# Ensure the line is at the top and remove duplicates
if ! grep -Fxq "$INC_LINE" "$kittyConf"; then
    sed -i "1i $INC_LINE" "$kittyConf"
fi

# Refresh kitty terminal
killall -SIGUSR1 kitty
