--[[
    VeilHub — games/scripts/build_a_cow_empire.lua v0.0.1
    Build a Cow Empire module. Uses Veil UI framework.
    Placeholder PlaceId — replace after confirming the actual ID.
]]

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local VirtualUser       = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting          = game:GetService("Lighting")
local HttpService       = game:GetService("HttpService")

local LP = Players.LocalPlayer
local RS = ReplicatedStorage

-- ============================================================
-- REMOTES (best-effort — inspect at runtime)
-- ============================================================
local Remotes = RS:FindFirstChild("Remotes")

local function find_in(folder, ...)
    if not folder then return nil end
    for _, n in ipairs({...}) do
        local r = folder:FindFirstChild(n)
        if r then return r end
    end
    return nil
end

local RE = {
    Buy      = find_in(Remotes, "Buy", "BuyItem", "Purchase"),
    Sell     = find_in(Remotes, "Sell", "SellMilk", "Collect"),
    Upgrade  = find_in(Remotes, "Upgrade", "UpgradeItem"),
    Collect  = find_in(Remotes, "Collect", "CollectMilk", "Milk"),
    Trade    = find_in(Remotes, "Trade", "AcceptTrade", "TradeAccept"),
}

-- ============================================================
-- STATE
-- ============================================================
local S = {
    auto_collect=false, auto_buy=false, auto_sell=false, auto_upgrade=false,
    auto_accept_trade=false,
    buy_filter="All", trade_min=500,
    walk_speed=16, jump_power=50,
    anti_afk=false, esp_cows=false,
    last_action=0, esp_folder=nil, cow_target=nil,
}

-- ============================================================
-- HELPERS
-- ============================================================
local function rand(a,b) return a + math.random() * (b-a) end
local function char() return LP.Character end
local function root() local c=char(); return c and c:FindFirstChild("HumanoidRootPart") end
local function hum() local c=char(); return c and c:FindFirstChildOfClass("Humanoid") end
local function alive() local h=hum(); return h and h.Health > 0 end

-- Find the player's tycoon plot
local function find_my_tycoon()
    local tycoons = workspace:FindFirstChild("Tycoons")
    if not tycoons then return nil end
    for _, t in ipairs(tycoons:GetChildren()) do
        local owner = t:FindFirstChild("Owner")
        if owner and owner.Value == LP.Name then return t end
    end
    return nil
end

-- Find uncollected milk in the player's plot
local function find_nearest_milk()
    local r = root(); if not r then return nil end
    local plot = find_my_tycoon()
    if not plot then return nil end

    local best, bd = nil, 500
    for _, obj in ipairs(plot:GetDescendants()) do
        if obj:IsA("BasePart") and (obj.Name:lower():find("milk") or obj.Name:lower():find("bucket")) then
            local d = (obj.Position - r.Position).Magnitude
            if d < bd then best, bd = obj, d end
        end
    end
    return best
end

-- Find any cow in the player's plot
local function find_nearest_cow()
    local r = root(); if not r then return nil end
    local plot = find_my_tycoon()
    if not plot then return nil end

    local best, bd = nil, 500
    for _, obj in ipairs(plot:GetDescendants()) do
        if obj:IsA("Model") and obj.Name:lower():find("cow") then
            local hrp = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
            if hrp then
                local d = (hrp.Position - r.Position).Magnitude
                if d < bd then best, bd = obj, d end
            end
        end
    end
    return best
end

-- Walk toward a position (no teleport)
local function walk_toward(pos, speed)
    local r = root(); if not r or not pos then return end
    local dir = (pos - r.Position)
    dir = Vector3.new(dir.X, 0, dir.Z)
    if dir.Magnitude < 2 then return end
    local unit = dir.Unit
    local steps = math.min(math.floor(dir.Magnitude / 5), 20)
    for i = 1, steps do
        if not alive() then return end
        local r2 = root(); if not r2 then return end
        r2.CFrame = r2.CFrame + unit * 5
        RunService.Heartbeat:Wait()
    end
end

-- ============================================================
-- ESP — cows highlight
-- ============================================================
local esp_conns = {}
local function esp_folder()
    if S.esp_folder and S.esp_folder.Parent then return S.esp_folder end
    local sg = Instance.new("Folder")
    sg.Name = "VeilESP"
    local parent
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then parent = h end
    end
    if not parent then parent = LP:WaitForChild("PlayerGui") end
    sg.Parent = parent
    S.esp_folder = sg
    return sg
end

local function clear_esp()
    if S.esp_folder and S.esp_folder.Parent then
        for _, ch in ipairs(S.esp_folder:GetChildren()) do ch:Destroy() end
    end
end

local function attach_highlight(adornee, color)
    local h = Instance.new("Highlight")
    h.FillColor = color
    h.OutlineColor = color
    h.FillTransparency = 0.55
    h.OutlineTransparency = 0.15
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Adornee = adornee
    h.Parent = esp_folder()
end

local function esp_cows()
    clear_esp()
    local plot = find_my_tycoon()
    if not plot then return end
    for _, obj in ipairs(plot:GetDescendants()) do
        if obj:IsA("Model") and obj.Name:lower():find("cow") then
            attach_highlight(obj, Color3.fromRGB(255, 200, 40))
        end
    end
end

-- anti afk
local afk_conn
local function set_afk(on)
    if afk_conn then afk_conn:Disconnect(); afk_conn = nil end
    if not on then return end
    afk_conn = LP.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end

-- ============================================================
-- LOOPS
-- ============================================================
-- Speed / Jump
RunService.Heartbeat:Connect(function()
    local h = hum(); if not h then return end
    if S.walk_speed ~= 16 then h.WalkSpeed = S.walk_speed end
    if S.jump_power ~= 50 then h.JumpPower = S.jump_power end
end)

-- AUTO COLLECT MILK — walks to nearest milk, does NOT teleport
RunService.Heartbeat:Connect(function()
    if not S.auto_collect then return end
    if not alive() then return end
    if tick() - S.last_action < 0.4 then return end

    local target = find_nearest_milk()
    if target then
        local r = root(); if not r then return end
        local d = (target.Position - r.Position).Magnitude
        if d < 8 then
            -- interact with the bucket / milk part
            pcall(function()
                firetouchinterest(r, target, 0)
                firetouchinterest(r, target, 1)
            end)
            S.last_action = tick()
        else
            -- walk toward the milk
            local pos = target.Position
            local dir = (pos - r.Position)
            dir = Vector3.new(dir.X, 0, dir.Z)
            if dir.Magnitude > 2 then
                local unit = dir.Unit
                pcall(function() r.CFrame = r.CFrame + unit * 5 end)
            end
        end
    else
        -- no milk visible — find a cow to milk
        local cow = find_nearest_cow()
        if cow then
            local hrp = cow:FindFirstChild("HumanoidRootPart") or cow.PrimaryPart
            if hrp then
                local r = root()
                if r then
                    local d = (hrp.Position - r.Position).Magnitude
                    if d > 8 then
                        local dir = (hrp.Position - r.Position)
                        dir = Vector3.new(dir.X, 0, dir.Z)
                        if dir.Magnitude > 2 then
                            pcall(function() r.CFrame = r.CFrame + dir.Unit * 5 end)
                        end
                    else
                        -- interact with the cow
                        pcall(function()
                            firetouchinterest(r, hrp, 0)
                            firetouchinterest(r, hrp, 1)
                        end)
                        S.last_action = tick()
                    end
                end
            end
        end
    end
end)

-- AUTO BUY — clicks buttons in the player's tycoon (best-effort)
RunService.Heartbeat:Connect(function()
    if not S.auto_buy then return end
    if tick() - S.last_action < 0.5 then return end

    local plot = find_my_tycoon()
    if not plot then return end
    local buttons = plot:FindFirstChild("Buttons")
    if not buttons then return end

    for _, btn in ipairs(buttons:GetChildren()) do
        local name = btn.Name:lower()
        local pass = true
        if S.buy_filter == "Cows Only" and not name:find("cow") then pass = false end
        if S.buy_filter == "Upgrades Only" and not name:find("upgrade") then pass = false end
        if S.buy_filter == "Processors Only" and not name:find("process") then pass = false end

        if pass and btn:IsA("BasePart") then
            pcall(function()
                if btn:FindFirstChild("ClickDetector") then
                    fireclickdetector(btn.ClickDetector)
                end
            end)
            S.last_action = tick()
            return
        end
    end
end)

-- AUTO SELL — clicks sell buttons
RunService.Heartbeat:Connect(function()
    if not S.auto_sell then return end
    if tick() - S.last_action < 0.5 then return end

    local plot = find_my_tycoon()
    if not plot then return end
    local buttons = plot:FindFirstChild("Buttons")
    if not buttons then return end

    for _, btn in ipairs(buttons:GetChildren()) do
        local name = btn.Name:lower()
        if name:find("sell") or name:find("collect") then
            if btn:IsA("BasePart") then
                pcall(function()
                    if btn:FindFirstChild("ClickDetector") then
                        fireclickdetector(btn.ClickDetector)
                    end
                end)
                S.last_action = tick()
                return
            end
        end
    end
end)

-- AUTO UPGRADE — clicks upgrade buttons
RunService.Heartbeat:Connect(function()
    if not S.auto_upgrade then return end
    if tick() - S.last_action < 0.5 then return end

    local plot = find_my_tycoon()
    if not plot then return end
    local buttons = plot:FindFirstChild("Buttons")
    if not buttons then return end

    for _, btn in ipairs(buttons:GetChildren()) do
        if btn.Name:lower():find("upgrade") and btn:IsA("BasePart") then
            pcall(function()
                if btn:FindFirstChild("ClickDetector") then
                    fireclickdetector(btn.ClickDetector)
                end
            end)
            S.last_action = tick()
            return
        end
    end
end)

-- AUTO ACCEPT TRADE — listens for trade GUI events (placeholder)
-- NOTE: exact trade remote shape unknown. This is a best-effort listener.
RunService.Heartbeat:Connect(function()
    if not S.auto_accept_trade then return end
    -- Look for a trade prompt in the player's GUI
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return end
    for _, gui in ipairs(pg:GetChildren()) do
        local txt = gui.Name:lower()
        if txt:find("trade") or txt:find("offer") then
            for _, btn in ipairs(gui:GetDescendants()) do
                if btn:IsA("TextButton") and (btn.Text:lower():find("accept") or btn.Text:lower():find("confirm")) then
                    -- check if the offered amount meets the minimum
                    local amount = 0
                    for _, lbl in ipairs(gui:GetDescendants()) do
                        if lbl:IsA("TextLabel") then
                            local num = tonumber(lbl.Text:match("%d+"))
                            if num and num > amount then amount = num end
                        end
                    end
                    if amount >= S.trade_min then
                        pcall(function() btn:Activate() end)
                    end
                end
            end
        end
    end
end)

-- SAFETY
RunService.Heartbeat:Connect(function()
    local r = root(); if not r then return end
    if r.Position.Y < -100 then
        pcall(function() local c = char(); if c then c:BreakJoints() end end)
    end
end)

-- ============================================================
-- BUILD
-- ============================================================
local module = { name = "Build a Cow Empire" }

function module.build(hub, CFG, ICON)
    -- ============ FARM ============
    local farm = hub.page("Farm", ICON.farm)

    hub.toggle(farm, "Auto Collect Milk", "Walks to milk buckets — no teleport", ICON.fruit,
        function(on) S.auto_collect = on end)
    hub.toggle(farm, "Auto Buy", "Clicks buy buttons in your plot", ICON.shop,
        function(on) S.auto_buy = on end)
    hub.dropdown(farm, "Buy Filter", "Which items to auto-buy",
        {"All", "Cows Only", "Upgrades Only", "Processors Only"}, "All", ICON.bolt,
        function(v) S.buy_filter = v end)
    hub.toggle(farm, "Auto Sell", "Clicks sell buttons automatically", ICON.shop,
        function(on) S.auto_sell = on end)
    hub.toggle(farm, "Auto Upgrade", "Clicks upgrade buttons", ICON.shield,
        function(on) S.auto_upgrade = on end)

    -- ============ MOVEMENT ============
    local move = hub.page("Movement", ICON.run)
    hub.slider(move, "Walk Speed", "16 = default, 200 = max", 16, 200, 16, ICON.run,
        function(v) S.walk_speed = v end)
    hub.slider(move, "Jump Power", "50 = default, 200 = max", 50, 200, 50, ICON.run,
        function(v) S.jump_power = v end)
    hub.button(move, "Reset Speed / Jump", "Back to defaults", ICON.run,
        function() S.walk_speed = 16; S.jump_power = 50 end)

    -- ============ TRADE ============
    local trade = hub.page("Trade", ICON.util)

    hub.toggle(trade, "Auto Accept Trade", "Accepts trades above minimum", ICON.util,
        function(on) S.auto_accept_trade = on end)
    hub.textbox(trade, "Minimum Amount", "Accept only if offer is at least this", "500", ICON.shop,
        function(txt)
            local n = tonumber(txt)
            if n then S.trade_min = n end
        end)

    -- ============ ESP ============
    local esp = hub.page("ESP", ICON.esp)
    hub.toggle(esp, "ESP Cows", "Gold highlight on your cows", ICON.esp,
        function(on) if on then esp_cows() else clear_esp() end end)

    -- ============ UTILITY ============
    local util = hub.page("Utility", ICON.util)
    hub.toggle(util, "Anti AFK", "Prevents 20-minute kick", ICON.util,
        function(on) set_afk(on) end)
    hub.toggle(util, "Full Bright", "Brightens the world", ICON.util, function(on)
        if on then
            Lighting.Ambient = Color3.fromRGB(180, 180, 180); Lighting.Brightness = 3
        else
            Lighting.Ambient = Color3.fromRGB(70, 70, 70); Lighting.Brightness = 2
        end
    end)
    hub.button(util, "Unload Hub", "Closes Veil Hub", ICON.util, function()
        if hub.gui then hub.gui:Destroy() end
    end)
end

return module
