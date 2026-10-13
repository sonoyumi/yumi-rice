-- yumi/anim-off.lua — выключить все анимации (для режимов gaming/powersaver/snappy)
for _, leaf in ipairs({
	"global", "windows", "windowsIn", "windowsOut", "windowsMove", "layers", "layersIn", "layersOut",
	"fade", "fadeIn", "fadeOut", "fadeSwitch", "fadeShadow", "fadeGlow", "fadeDim", "fadeLayers",
	"fadeLayersIn", "fadeLayersOut", "fadePopups", "fadePopupsIn", "fadePopupsOut", "fadeDpms",
	"border", "borderangle", "shadowangle", "glowangle", "workspaces", "workspacesIn", "workspacesOut",
	"specialWorkspace", "specialWorkspaceIn", "specialWorkspaceOut", "zoomFactor", "monitorAdded",
}) do
	hl.animation({ leaf = leaf, enabled = false })
end
