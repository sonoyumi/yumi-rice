-- Редактирование: окна непрозрачные (точные цвета), размытие только под панелями
local wf = { name = "Editing", icon = "", description = "Без прозрачности — точные цвета" }
if not hl then return wf end
hl.config({ decoration = { blur = { enabled = true }, active_opacity = 1, inactive_opacity = 1, fullscreen_opacity = 1 } })
hl.window_rule({ opaque = true, match = { class = ".*" } })
hl.layer_rule({
	name = "yumi_workflow_editing",
	blur = true,
	match = { namespace = "^(notifications|swaync-(notification-window|control-center)|waybar)$" },
})
return wf
