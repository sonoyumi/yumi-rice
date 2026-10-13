-- Игры: без теней, размытия, скруглений и отступов; без анимаций
local wf = { name = "Gaming", icon = "", description = "Без теней и отступов — для скорости" }
if not hl then return wf end
hl.config({
	decoration = { shadow = { enabled = false }, blur = { enabled = false, xray = true }, rounding = 0,
		active_opacity = 1, inactive_opacity = 1, fullscreen_opacity = 1 },
	general = { gaps_in = 0, gaps_out = 0, border_size = 1 },
})
hl.window_rule({ opaque = true, match = { class = ".*" } })
hl.layer_rule({
	name = "yumi_workflow_gaming",
	blur = false,
	no_anim = true,
	match = { namespace = "^(notifications|swaync-(notification-window|control-center)|waybar|.*www-daemon)$" },
})
dofile(yumi.dir .. "/anim-off.lua")
return wf
