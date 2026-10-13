-- Быстрый: без скруглений, отступов и анимаций
local wf = { name = "Snappy", icon = "󰓅", description = "Без анимаций и эффектов" }
if not hl then return wf end
hl.config({ decoration = { rounding = 0 }, general = { gaps_in = 0, gaps_out = 0, border_size = 1 } })
dofile(yumi.dir .. "/anim-off.lua")
return wf
