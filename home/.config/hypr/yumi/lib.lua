-- yumi/lib.lua — помощники базы (вместо hyde.utils / hyde.binds / hyde.handlers)

local M = {}

-- Список строк → одна регулярка "^(a|b|c)$" (меньше правил — быстрее сопоставление)
function M.any(list)
	return "^(" .. table.concat(list, "|") .. ")$"
end

-- ── Бинды: повторный бинд на то же сочетание заменяет прежний ──
-- Без этого Hyprland держит оба и выполняет оба действия. Сочетание сравнивается
-- как набор модификаторов + клавиша («SUPER + CTRL + Left» = «CONTROL + SUPER + LEFT»),
-- плюс флаги, которые меняют смысл бинда (locked, release, mouse…).
local ALIAS = { CONTROL = "CTRL", WIN = "SUPER", LOGO = "SUPER", MOD1 = "ALT", MOD4 = "SUPER" }
local FLAGS = { "locked", "release", "click", "drag", "long_press", "repeating", "non_consuming",
	"auto_consuming", "transparent", "ignore_mods", "separate", "bypass", "submap_universal", "devices" }

local function trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function normalize(combo)
	return trim((combo:gsub("%s*%+%s*", " + ")))
end

local function canonical(combo)
	local toks = {}
	for t in normalize(combo):gmatch("[^+]+") do
		toks[#toks + 1] = trim(t)
	end
	local key = (table.remove(toks) or ""):upper()
	local mods, seen = {}, {}
	for _, t in ipairs(toks) do
		local m = ALIAS[t:upper()] or t:upper()
		if not seen[m] then
			seen[m] = true
			mods[#mods + 1] = m
		end
	end
	table.sort(mods)
	mods[#mods + 1] = key
	return table.concat(mods, " + ")
end

local function flag_sig(...)
	for i = select("#", ...), 1, -1 do
		local o = select(i, ...)
		if type(o) == "table" then
			local parts = {}
			for _, f in ipairs(FLAGS) do
				if o[f] ~= nil then
					parts[#parts + 1] = f .. "=" .. tostring(o[f])
				end
			end
			if #parts > 0 then
				return table.concat(parts, "|")
			end
		end
	end
	return ""
end

-- Таблица hl ПЕРЕЖИВАЕТ `hyprctl reload` (глобальные переменные Lua — нет). Поэтому в hl.bind может
-- остаться обёртка прошлого конфига (например, HyDE). Берём родную C-функцию из-под любых обёрток…
local function native(fn)
	for _ = 1, 16 do
		if type(fn) ~= "function" or debug.getinfo(fn, "S").what == "C" then
			return fn
		end
		local inner
		for i = 1, 255 do
			local name, v = debug.getupvalue(fn, i)
			if not name then
				break
			end
			if type(v) == "function" and (name:find("bind") or name:find("orig")) then
				inner = v
				break
			end
		end
		if not inner then
			return fn
		end
		fn = inner
	end
	return fn
end

-- …а свою обёртку метим загрузкой: устаревшая (с прошлой загрузки) просто передаёт вызов дальше
local raw_bind = native(hl.bind)
local load_id = {}
hl._yumi_load = load_id
local active = {}
local function yumi_bind(combo, action, ...)
	if hl._yumi_load ~= load_id or type(combo) ~= "string" then
		return raw_bind(combo, action, ...)
	end
	local id = canonical(combo) .. "|" .. flag_sig(...)
	combo = normalize(combo)
	if active[id] then
		hl.unbind(active[id])
	end
	active[id] = combo
	return raw_bind(combo, action, ...)
end
hl.bind = yumi_bind

-- ── Плавающее окно не больше 95 % свободной области монитора ──
-- (было hyde.handle.float_size_bounds: иначе Dolphin и др. открываются больше экрана)
local EDGE = 0.01 -- поля по краям монитора, доля размера
local SCALE = 0.95

function M.float_size_bounds(win)
	if not win or not win.floating then
		return
	end
	local mon = hl.get_active_monitor()
	if not mon then
		return
	end
	local scale = mon.scale or 1
	local w, h = mon.width, mon.height
	local tr = mon.transform or 0
	if tr == 1 or tr == 3 or tr == 5 or tr == 7 then
		w, h = h, w
	end
	local res = mon.reserved or {}
	local usable_w = math.max(100, w - ((res.left or 0) + (res.right or 0) + 2 * EDGE * w))
	local usable_h = math.max(100, h - ((res.top or 0) + (res.bottom or 0) + 2 * EDGE * h))
	local max_w = math.floor(usable_w * SCALE / scale)
	local max_h = math.floor(usable_h * SCALE / scale)
	if win.size.x > max_w or win.size.y > max_h then
		hl.dispatch(hl.dsp.window.resize({
			window = win,
			x = math.max(1, math.min(win.size.x, max_w)),
			y = math.max(1, math.min(win.size.y, max_h)),
			exact = true,
		}))
	end
end

return M
