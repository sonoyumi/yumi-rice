-- yumi/events.lua — события сеанса (было events.lua HyDE)

-- Плавающее окно не открывается больше экрана (например, Dolphin)
hl.on("window.open", yumi.lib.float_size_bounds)

-- Выход из Hyprland: корректно погасить службы сеанса (18.10: без uwsm — цель yumi-hyprland-session; было uwsm stop)
hl.on("hyprland.shutdown", function()
	hl.dispatch(hl.dsp.exec_cmd("systemctl --user stop --no-block yumi-hyprland-session.target"))
	hl.dispatch(hl.dsp.exec_cmd("hyprshutdown"))
end)
