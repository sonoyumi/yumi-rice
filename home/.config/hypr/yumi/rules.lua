-- yumi/rules.lua — правила окон и слоёв (были window_rules.lua и layer_rules.lua HyDE)

local any = yumi.lib.any

-- Плавающие: диалоги, порталы, настройки, менеджеры паролей…
hl.window_rule({
	name = "yumi_floating_class",
	tag = "+yumi_floating",
	match = {
		class = any({
			"Bitwarden",
			"org.keepassxc.KeePassXC",
			"hyprland-share-picker",
			"blueman-manager",
			"pavucontrol-qt",
			"com\\.gabm\\.satty",
			"vlc",
			"kvantummanager",
			"qt6ct",
			"qt[56]ct",
			"nwg-(look|displays)",
			"org\\.kde\\.ark",
			"org\\.pulseaudio\\.pavucontrol",
			"nm-(applet|connection-editor)",
			"hyprpolkitagent",
			"console-dropdown",
			"org\\.kde\\.dolphin",
			".*dialog.*",
			"[Xx]dg-desktop-portal-gtk",
			"org\\.freedesktop\\.impl\\.portal\\.desktop\\.(hyprland|gtk)",
		}),
	},
	float = true,
})

hl.window_rule({
	name = "yumi_floating_title",
	tag = "+yumi_floating",
	match = {
		title = any({
			"Progress Dialog — Dolphin",
			"Copying — Dolphin",
			"Choose Files",
			"Save As",
			"Confirm to replace files",
			"File Operation Progress",
			"Open",
			"Authentication Required",
			"Add Folder to Workspace",
			"File Upload.*",
			"Choose wallpaper.*",
			"Library.*",
			".*dialog.*",
			"Open File",
			"Volume Control",
			"Save As.*",
			"File Already Exists — Dolphin",
			"Properties for.*",
		}),
	},
	float = true,
})

-- «Картинка в картинке» — маленькое окно поверх всех, в правом нижнем углу
hl.window_rule({
	name = "yumi_pin",
	tag = "+yumi_pin",
	match = { title = any({ "[Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture(.*)" }) },
	float = true,
	move = "(monitor_w*0.73) (monitor_h*0.72)",
	size = "(monitor_w*0.25) (monitor_h*0.25)",
	pin = true,
})

-- Окна выбора файлов, пароли и т.п. — по центру, поверх всех
hl.window_rule({
	name = "yumi_modals",
	tag = "+yumi_modals",
	match = {
		class = any({ "pinentry-.*" }),
		title = any({
			"Choose Files",
			"Open File",
			"Save As.*",
			"File Operation Progress",
			"Authentication Required",
			"File Upload.*",
		}),
		initial_title = any({ "Open File", "Save As.*" }),
		modal = true,
	},
	float = true,
	center = true,
	pin = true,
})

hl.window_rule({
	name = "xwayland_video_bridge_fixes",
	match = { class = "xwaylandvideobridge" },
	no_initial_focus = true,
	no_focus = true,
	no_anim = true,
	no_blur = true,
	no_follow_mouse = true,
	max_size = { 1, 1 },
	opacity = 0.0,
	float = true,
	workspace = "special:xwayland_video_bridge silent",
})

-- Файловые менеджеры — плиткой; прозрачность общая, как у всех окон (13.10: убрано opaque = true)
hl.window_rule({
	name = "filemanagers-fullscreen",
	match = { class = "^(.*dolphin.*)$|^(.*pcmanfm-qt.*)$|^(.*nemo.*)$|^(.*ark.*)$|.*Nautilus.*" },
	float = false,
})


-- ── Слои ──
hl.layer_rule({
	name = "yumi_layer_blur",
	match = { namespace = any({ "notifications", "swaync-(notification-window|control-center)", "waybar" }) },
	blur = true,
})

hl.layer_rule({
	name = "yumi_layer_ignore_alpha",
	match = { namespace = any({ "notifications", "swaync-(notification-window|control-center)", "waybar", "selection" }) },
	ignore_alpha = 0,
})

hl.layer_rule({
	name = "yumi_layer_no_anim",
	match = { namespace = "selection" },
	no_anim = true,
})

-- Waybar перезапускается при смене обоев — пусть исчезает и появляется затуханием, а не рывком
hl.layer_rule({
	name = "yumi_waybar_fade",
	match = { namespace = "^waybar$" },
	animation = "fade",
})
