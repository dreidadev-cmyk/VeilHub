local VEIL_VERSION = "0.0.1"
local RAW = "https://raw.githubusercontent.com/dreidadev-cmyk/VeilHub/main/"

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
    error("[Veil] no HTTP method for " .. url)
end

local function fresh(url)
    local sep = url:find("?") and "&" or "?"
    return url .. sep .. "v=" .. tostring(math.floor(os.clock() * 1000000)) .. tostring(math.random(100, 999))
end

_G.VEIL_LOADER = {
    version = VEIL_VERSION,
    raw     = RAW,
    http    = http_get,
    fresh   = fresh,
}

local src = http_get(fresh(RAW .. "main.lua"))
if not src or #src == 0 then
    warn("[Veil] loader: empty main.lua")
    return
end

local chunk, err = loadstring(src, "@Veil/main.lua")
if not chunk then
    warn("[Veil] loader: main.lua compile failed — " .. tostring(err))
    return
end

local ok, run_err = pcall(chunk)
if not ok then
    warn("[Veil] loader: runtime error — " .. tostring(run_err))
end
