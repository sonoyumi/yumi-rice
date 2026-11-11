-- Мониторы Hyprland. По умолчанию — любой выход в родном режиме, расстановка и масштаб автоматически.
-- Свои мониторы: имена и режимы — `hyprctl monitors all`; можно собрать мышкой в nwg-displays (он перезапишет файл).
-- Пример (ноутбук + внешний справа):
--   hl.monitor({ output = "eDP-1", mode = "2560x1600@60", position = "0x0", scale = 1.6, reserved = { top = 38 } })
--   hl.monitor({ output = "DP-1", mode = "1920x1080@144", position = "1600x0", scale = 1, reserved = { top = 38 } })
-- Не убирайте reserved: место под бар держит монитор, а не сам бар (38 = высота бара) — окна не прыгают при его перезапуске.

hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "auto",
    reserved = { top = 38 },
})
