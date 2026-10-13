-- Экономия: всё как в gaming, но читаемость сохраняется
local wf = { name = "Powersaver", icon = "", description = "Экономия батареи: без эффектов и анимаций" }
if not hl then return wf end
hl.config({
	decoration = { shadow = { enabled = false }, blur = { enabled = false, xray = true }, rounding = 0,
		active_opacity = 1, inactive_opacity = 1, fullscreen_opacity = 1 },
	general = { gaps_in = 0, gaps_out = 0, border_size = 1 },
})
hl.window_rule({ opaque = true, match = { class = ".*" } })
hl.layer_rule({
	name = "yumi_workflow_powersaver",
	no_anim = true,
	blur = false,
	match = { namespace = "^(notifications|swaync-(notification-window|control-center)|waybar)$" },
})
dofile(yumi.dir .. "/anim-off.lua")
return wf
