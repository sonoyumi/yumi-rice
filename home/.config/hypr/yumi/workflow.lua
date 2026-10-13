-- yumi/workflow.lua — подключить выбранный режим работы (было lua_state/workflows HyDE)
-- Выбор хранится в ~/.local/state/yumi/workflow, меняет его `yumi-workflow set ИМЯ`.
local state = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/yumi/workflow"
local name = "01-default"
local f = io.open(state, "r")
if f then
	name = (f:read("l") or ""):match("^%s*(.-)%s*$")
	f:close()
end
local file = yumi.dir .. "/workflows/" .. name .. ".lua"
local probe = name ~= "" and io.open(file, "r")
if probe then
	probe:close()
	dofile(file)
else
	hl.exec_cmd("hyprctl seterror 'rgba(c79bf0ff)' '[yumi] нет режима «" .. name .. "», работает обычный'")
end
