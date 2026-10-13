-- yumi-music: обложка трека для MPRIS (yumi-player, пилюля Waybar, swaync).
-- mpv-mpris отдаёт как artUrl файл из опции cover-art-files; перед загрузкой трека подставляем сюда
-- квадратную обложку альбома из YouTube Music (ссылки — в ~/.cache/yumi-music/thumbs.tsv, пишет yumi-music),
-- иначе — миниатюру видео, обрезанную по центру до квадрата. Обложки кэшируются, следующая качается заранее.
local cache = (os.getenv("XDG_CACHE_HOME") or (os.getenv("HOME") .. "/.cache")) .. "/yumi-music"
local covers = cache .. "/covers"
local thumbs, map_mtime = {}, nil

local function file_size(p)
    local f = io.open(p, "rb")
    if not f then return 0 end
    local s = f:seek("end")
    f:close()
    return s or 0
end

local function load_map()
    local f = io.open(cache .. "/thumbs.tsv", "r")
    if not f then return end
    local size = f:seek("end")
    if size == map_mtime then f:close() return end      -- файл не менялся — не перечитывать
    map_mtime = size
    f:seek("set")
    thumbs = {}
    for line in f:lines() do
        local id, url = line:match("^([%w_-]+)\t(.+)$")
        if id then thumbs[id] = url end
    end
    f:close()
end

local function video_id(path)
    if not path then return nil end
    local id = path:match("[?&]v=([%w_-]+)") or path:match("youtu%.be/([%w_-]+)")
    if id then return id end
    if path:match("^https?://[%w.]*soundcloud%.com/") then       -- ключ как key_for() в yumi-music
        return (path:gsub("[^%w]", "_")):sub(1, 120)
    end
    return nil
end

-- прокси WARP для SoundCloud (служба yumi-music-proxy): сеть режет SoundCloud, YouTube идёт напрямую
local PROXY = "http://127.0.0.1:40080"
local function proxy_up()
    local r = mp.command_native({name = "subprocess", playback_only = false, capture_stdout = true,
                                 capture_stderr = true,
                                 args = {"bash", "-c", "exec 3<>/dev/tcp/127.0.0.1/40080"}})
    return r and r.status == 0
end

local function fetch_args(id, out)
    if thumbs[id] then
        local px = (thumbs[id]:match("sndcdn%.com") and proxy_up()) and ("-x " .. PROXY .. " ") or ""
        return {"sh", "-c", 'curl -sfL -m 6 ' .. px .. '-o "$2.tmp" "$1" && mv -f "$2.tmp" "$2"; rm -f "$2.tmp"',
                "sh", thumbs[id], out}
    end
    if id:sub(1, 4) == "http" then return nil end                -- SoundCloud без обложки — ничего
    return {"sh", "-c", 'curl -sfL -m 6 -o "$2.tmp" "https://i.ytimg.com/vi/$1/hqdefault.jpg" && ' ..
            'magick "$2.tmp" -gravity center -crop 270x270+0+0 +repage "$2"; rm -f "$2.tmp"', "sh", id, out}
end

local function cover(id, async)
    local out = covers .. "/" .. id .. ".jpg"
    if file_size(out) > 0 then return out end
    local args = fetch_args(id, out)
    if not args then return nil end
    local cmd = {name = "subprocess", args = args, playback_only = false,
                 capture_stdout = true, capture_stderr = true}
    if async then
        mp.command_native_async(cmd, function() end)
        return nil
    end
    mp.command_native(cmd)
    return file_size(out) > 0 and out or nil
end

-- mpv-mpris читает cover-art-files один раз в начале трека и кэширует по пути, поэтому обложку ставим
-- ДО start-file (on_before_start_file) — глобальной опцией, она и применится к загружаемому треку
mp.add_hook("on_before_start_file", 10, function()
    load_map()
    local pos = mp.get_property_number("playlist-pos", -1)
    local id = video_id(mp.get_property("playlist/" .. pos .. "/filename"))
    local p = id and cover(id, false) or nil
    mp.set_property("cover-art-files", p or "")
    local nid = video_id(mp.get_property("playlist/" .. (pos + 1) .. "/filename"))
    if nid then cover(nid, true) end
end)

-- Чистые артист/название (meta.tsv пишет yumi-music): название — всем MPRIS-клиентам через force-media-title
-- (артиста mpv подменить не даёт — его берут из meta.tsv сами yumi-player, пилюля и центр управления).
-- on_load с приоритетом 50 — после ytdl_hook (10), который ставит название ролика.
local meta, meta_size = {}, nil
local function load_meta()
    local f = io.open(cache .. "/meta.tsv", "r")
    if not f then return end
    local size = f:seek("end")
    if size == meta_size then f:close() return end
    meta_size = size
    f:seek("set")
    meta = {}
    for line in f:lines() do
        local id, artist, title = line:match("^([^\t]+)\t([^\t]*)\t([^\t]*)")
        if id then meta[id] = {artist = artist, title = title} end
    end
    f:close()
end

mp.add_hook("on_load", 50, function()
    load_meta()
    local path = mp.get_property("path") or ""
    if path:match("^https?://[%w.]*soundcloud%.com/") and proxy_up() then
        mp.set_property("file-local-options/http-proxy", PROXY)    -- сам звуковой поток — тоже через прокси
    end
    local id = video_id(path)
    local m = id and meta[id]
    if m and m.title ~= "" then
        mp.set_property("file-local-options/force-media-title", m.title)
    end
end)

-- Тексты песен заранее: текущий и следующий трек — в кэш yumi-player (yumi-music prefetch-lyrics, в фоне)
mp.register_event("file-loaded", function()
    local pos = mp.get_property_number("playlist-pos", -1)
    local urls = {}
    for _, i in ipairs({pos, pos + 1}) do
        local u = mp.get_property("playlist/" .. i .. "/filename")
        if u and u:match("^https?://") then table.insert(urls, u) end
    end
    if #urls == 0 then return end
    local args = {os.getenv("HOME") .. "/.local/bin/yumi-music", "prefetch-lyrics"}
    for _, u in ipairs(urls) do table.insert(args, u) end
    mp.command_native_async({name = "subprocess", args = args, playback_only = false,
                             capture_stdout = true, capture_stderr = true}, function() end)
end)

-- Трек не запустился (YouTube или SoundCloud): mpv сам идёт к следующему, а yumi-music drop в фоне
-- проверяет причину. Постоянная (DRM, регион, удалён) → трек в skip.tsv, из кэша плейлиста и из текущей
-- очереди; временная (сеть) → ничего. Подмены трека из другого сервиса нет.
local yumi_music = os.getenv("HOME") .. "/.local/bin/yumi-music"
local last_path = nil
mp.register_event("start-file", function() last_path = mp.get_property("path") end)
mp.register_event("end-file", function(e)
    if e.reason ~= "error" or not last_path or not last_path:match("^https?://") then return end
    local path, entry = last_path, e.playlist_entry_id
    mp.command_native_async({name = "subprocess", args = {yumi_music, "drop", path}, playback_only = false,
                             capture_stdout = true, capture_stderr = true}, function(_, r)
        if r and r.stdout and r.stdout:match("removed") then
            for i = 0, mp.get_property_number("playlist-count", 0) - 1 do
                if mp.get_property_number("playlist/" .. i .. "/id") == entry then
                    mp.commandv("playlist-remove", tostring(i))
                    break
                end
            end
            mp.msg.info("трек недоступен навсегда — убран: " .. path)
        end
    end)
end)
