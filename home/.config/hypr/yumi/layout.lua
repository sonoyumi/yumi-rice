-- yumi/layout.lua — раскладки окон и жесты (было layouts/master.lua HyDE)
-- Раскладка по умолчанию — dwindle (hyprland.lua), SUPER+O переключает dwindle → scrolling → master.

hl.config({
	master = {
		new_status = "slave",
		new_on_top = 1,
		allow_small_split = true,
	},
})

-- master: ALT+K / ALT+J — поменять окно местами со следующим / предыдущим
-- (остальные ALT-сочетания master сняты 07.10: конфликт с zsh, меню программ и браузером)
hl.bind("ALT + K", hl.dsp.layout("swapnext"), { description = "[Master] swap focused window with next window" })
hl.bind("ALT + J", hl.dsp.layout("swapprev"), { description = "[Master] swap focused window with previous window" })

-- Жесты: 3 пальца ←/→ — рабочие столы, 4 пальца — фокус в сторону свайпа
-- (3 пальца ↓ — свои действия по раскладке, в hyprland.lua)
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
for _, dir in ipairs({ "up", "down", "left", "right" }) do
	hl.gesture({
		fingers = 4,
		direction = dir,
		action = function()
			hl.dispatch(hl.dsp.focus({ direction = dir }))
		end,
	})
end
