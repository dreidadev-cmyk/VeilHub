--[[
    VeilHub — remote/loader.lua v0.0.1
    Separate loadstring — DIFFERENT from the main loader.
    Fetches remote/dumper.lua and runs it.
]]

local RAW = "https://raw.githubusercontent.com/dreidadev-cmyk/VeilHub/main/"
local DUMPER_URL = RAW .. "remote/dumper.lua"

local function http_get(url)
    if syn and syn.request then
        local ok, r = pcall(syn.request, {Url=url, Method="GET"})
        if ok and r and r.Body then return r.Body end
    end
    if request then
        local ok, r = pcall(request, {Url=url, Method="GET"})
        if ok and r and r.Body then return r.Body end
    end
    if http_request then
        local ok, r = pcall(http_request, {Url=url, Method="GET"})
        if ok and r and r.Body then return r.Body end
    end
    if game.HttpGet then
        local ok, b = pcall(function() return game:HttpGet(url) end)
        if ok then return b end
    end
    error("[Veil/remote] no HTTP method available")
end

local function fresh(url)
    local sep = url:find("?") and "&" or "?"
    return url .. sep .. "v=" .. tostring(math.floor(os.clock() * 1000000)) .. tostring(math.random(100, 999))
end

local src = http_get(fresh(DUMPER_URL))
if not src or #src == 0 then
    warn("[Veil/remote] loader: empty dumper response")
    return
end

local chunk, err = loadstring(src, "@Veil/remote/dumper.lua")
if not chunk then
    warn("[Veil/remote] compile failed: " .. tostring(err))
    return
end

local ok, run_err = pcall(chunk)
if not ok then
    warn("[Veil/remote] runtime error: " .. tostring(run_err))
end
