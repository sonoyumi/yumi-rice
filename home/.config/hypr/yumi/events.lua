-- yumi/events.lua — события сеанса (было events.lua HyDE)

-- Плавающее окно не открывается больше экрана (например, Dolphin)
hl.on("window.open", yumi.lib.float_size_bounds)

-- Выход из Hyprland: корректно завершить сеанс uwsm
hl.on("hyprland.shutdown", function()
	hl.dispatch(hl.dsp.exec_cmd("uwsm stop"))
	hl.dispatch(hl.dsp.exec_cmd("hyprshutdown"))
end)
