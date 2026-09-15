local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats      = game:GetService("Stats")

local LP = Players.LocalPlayer
local SESSION = os.clock()

local LOADER = _G.VEIL_LOADER or {}
local RAW    = LOADER.raw or "https://raw.githubusercontent.com/dreidadev-cmyk/VeilHub/main/"
local http_get = LOADER.http
local fresh    = LOADER.fresh or function(u) return u end

if not http_get then
    http_get = function(url)
        if request then
            local ok, r = pcall(request, {Url=url, Method="GET"})
            if ok and r and r.Body then return r.Body end
        end
        if game.HttpGet then
            local ok, b = pcall(function() return game:HttpGet(url) end)
            if ok then return b end
        end
        error("[Veil] no HTTP method")
    end
end

-- ============================================================
-- CONFIG
-- ============================================================
local CFG = {
    title = "Veil Hub", version = "0.0.1",
    discord = "https://discord.gg/hcV9Efe4y",
    accent = Color3.fromRGB(250, 204, 21),
    accent2 = Color3.fromRGB(255, 230, 80),
    accent_dark = Color3.fromRGB(180, 140, 10),
    bg = Color3.fromRGB(8, 8, 12),
    bg2 = Color3.fromRGB(14, 14, 20),
    card_top = Color3.fromRGB(28, 28, 38),
    card_bot = Color3.fromRGB(18, 18, 26),
    sidebar = Color3.fromRGB(12, 12, 18),
    icon_bg = Color3.fromRGB(38, 38, 50),
    text = Color3.fromRGB(245, 245, 250),
    subtext = Color3.fromRGB(140, 140, 160),
    dim = Color3.fromRGB(90, 90, 110),
    good = Color3.fromRGB(90, 220, 130),
    danger = Color3.fromRGB(240, 90, 100),
    black = Color3.fromRGB(0, 0, 0),
    white = Color3.fromRGB(255, 255, 255),
}

local ICON = {
    home  = "rbxassetid://6023426926",
    farm  = "rbxassetid://6031090990",
    boss  = "rbxassetid://6031094678",
    chest = "rbxassetid://6031075931",
    fruit = "rbxassetid://6031075931",
    quest = "rbxassetid://6031075929",
    bolt  = "rbxassetid://6034287409",
    aura  = "rbxassetid://6031094678",
    shield= "rbxassetid://6031075943",
    energy= "rbxassetid://6034287409",
    run   = "rbxassetid://6023564503",
    esp   = "rbxassetid://6031075954",
    shop  = "rbxassetid://6031075929",
    util  = "rbxassetid://6034287521",
    tp    = "rbxassetid://6031094667",
}

-- ============================================================
-- LOAD UI
-- ============================================================
local ui_src = http_get(fresh(RAW .. "ui.lua"))
local ui_chunk = loadstring(ui_src, "@Veil/ui.lua")
if not ui_chunk then
    warn("[Veil] ui.lua compile failed")
    return
end
local UI = ui_chunk()
if type(UI) ~= "table" or type(UI.new) ~= "function" then
    warn("[Veil] ui.lua did not return UI.new")
    return
end
local hub = UI.new(CFG, ICON)

-- ============================================================
-- STATS LOOP — runs before anything else fetches
-- ============================================================
local fps, frames, last_tick = 0, 0, os.clock()
RunService.RenderStepped:Connect(function()
    frames += 1
    local now = os.clock()
    if now - last_tick >= 1 then
        fps, frames, last_tick = frames, 0, now
    end
end)

local ping = 0
task.spawn(function()
    while hub.gui and hub.gui.Parent do
        local ok, val = pcall(function()
            return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        if ok and tonumber(val) then ping = math.floor(val) end
        task.wait(1)
    end
end)

local function fmt_time(s)
    s = math.floor(s)
    local h = math.floor(s / 3600)
    local m = math.floor((s % 3600) / 60)
    local x = s % 60
    if h > 0 then return string.format("%dh %dm %ds", h, m, x) end
    if m > 0 then return string.format("%dm %ds", m, x) end
    return string.format("%ds", x)
end

local function write_stats()
    hub.stat("player", string.format("%s (@%s)", LP.DisplayName, LP.Name))
    hub.stat("place", tostring(game.PlaceId))
    hub.stat("time", fmt_time(os.clock() - SESSION))
    hub.stat("perf", string.format("%d FPS · %d ms", fps, ping))
end
write_stats()

task.spawn(function()
    while hub.gui and hub.gui.Parent do
        pcall(write_stats)
        task.wait(0.5)
    end
end)

-- ============================================================
-- GAME MODULE LOADER — async, never blocks the hub
-- ============================================================
task.spawn(function()
    -- fetch manifest
    local ok_m, m_src = pcall(http_get, fresh(RAW .. "games/manifest.lua"))
    if not ok_m or not m_src or #m_src == 0 then
        hub.status("Manifest fetch failed", CFG.danger)
        return
    end
    local m_chunk = loadstring(m_src, "@Veil/manifest")
    if not m_chunk then
        hub.status("Manifest compile failed", CFG.danger)
        return
    end
    local ok_r, manifest = pcall(m_chunk)
    if not ok_r or type(manifest) ~= "table" then
        hub.status("Manifest invalid", CFG.danger)
        return
    end

    local pid = game.PlaceId
    local entry = manifest[pid]
    if not entry then
        hub.status("Universal mode · " .. tostring(pid), CFG.subtext)
        return
    end

    hub.status(entry.name .. " · loading", CFG.good)

    -- fetch game module
    local ok_g, g_src = pcall(http_get, fresh(RAW .. "games/scripts/" .. entry.file))
    if not ok_g or not g_src or #g_src == 0 then
        hub.status(entry.name .. " · fetch failed", CFG.danger)
        return
    end
    local g_chunk = loadstring(g_src, "@Veil/" .. entry.file)
    if not g_chunk then
        hub.status(entry.name .. " · compile failed", CFG.danger)
        return
    end
    local ok_mod, mod = pcall(g_chunk)
    if not ok_mod or type(mod) ~= "table" then
        hub.status(entry.name .. " · runtime failed", CFG.danger)
        return
    end

    -- build
    local display_name = entry.name or mod.name or "Game"
    if type(mod.build) == "function" then
        local ok_build = pcall(mod.build, hub, CFG, ICON)
        if not ok_build then
            hub.status(display_name .. " · build failed", CFG.danger)
            return
        end
        hub.status(display_name .. " · ready", CFG.good)
    elseif type(mod.scripts) == "table" then
        -- legacy fallback: flat list
        local p = hub.page("Scripts", ICON.util)
        for label, fn in pairs(mod.scripts) do
            if type(fn) == "function" then
                hub.button(p, label, "Tap to run", ICON.bolt, fn)
            end
        end
        hub.status(display_name .. " · ready", CFG.good)
    else
        hub.status(display_name .. " · unknown module shape", CFG.danger)
    end

    hub.select("Home")
end)

print(string.format("[Veil v%s] loaded · place=%d · user=%s", CFG.version, game.PlaceId, LP.Name))
