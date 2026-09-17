--[[
    VeilHub — games/scripts/build_a_cow_empire.lua v0.0.1
    Buy page with individual buttons, Auto Call NPC, trade min-bucket filter.
]]

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local VirtualUser       = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting          = game:GetService("Lighting")

local LP = Players.LocalPlayer
local RS = ReplicatedStorage

local S = {
    auto_collect=false, auto_call_npc=false, auto_sell=false, auto_upgrade=false,
    auto_accept_trade=false,
    npc_target="Milk Buyer",
    trade_min_buckets=100,
    walk_speed=16, jump_power=50,
    anti_afk=false, esp_cows=false,
    last_action=0, esp_folder=nil,
    buy_flags={},
}

local function char() return LP.Character end
local function root() local c=char(); return c and c:FindFirstChild("HumanoidRootPart") end
local function hum() local c=char(); return c and c:FindFirstChildOfClass("Humanoid") end
local function alive() local h=hum(); return h and h.Health > 0 end

-- ============================================================
-- TYCOON HELPERS
-- ============================================================
local function find_my_tycoon()
    local tycoons = workspace:FindFirstChild("Tycoons")
    if not tycoons then return nil end
    for _, t in ipairs(tycoons:GetChildren()) do
        local owner = t:FindFirstChild("Owner")
        if owner and owner.Value == LP.Name then return t end
    end
    return nil
end

local function find_nearest_milk()
    local r = root(); if not r then return nil end
    local plot = find_my_tycoon(); if not plot then return nil end
    local best, bd = nil, 500
    for _, obj in ipairs(plot:GetDescendants()) do
        if obj:IsA("BasePart") and (obj.Name:lower():find("milk") or obj.Name:lower():find("bucket")) then
            local d = (obj.Position - r.Position).Magnitude
            if d < bd then best, bd = obj, d end
        end
    end
    return best
end

local function find_nearest_cow()
    local r = root(); if not r then return nil end
    local plot = find_my_tycoon(); if not plot then return nil end
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

-- find any NPC in workspace matching name
local function find_npc(name_query)
    if not name_query or name_query == "" then return nil end
    local q = name_query:lower()
    local best, bd = nil, 1000
    local r = root(); if not r then return nil end
    local function scan(container)
        for _, obj in ipairs(container:GetChildren()) do
            if obj:IsA("Model") then
                if obj.Name:lower():find(q) then
                    local hrp = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Head") or obj.PrimaryPart
                    if hrp then
                        local d = (hrp.Position - r.Position).Magnitude
                        if d < bd then best, bd = obj, d end
                    end
                end
                local nested = obj:FindFirstChild("HumanoidRootPart")
                if not nested then scan(obj) end
            end
        end
    end
    scan(workspace)
    return best
end

-- ============================================================
-- ESP
-- ============================================================
local esp_conns = {}
local function esp_folder()
    if S.esp_folder and S.esp_folder.Parent then return S.esp_folder end
    local sg = Instance.new("Folder")
    sg.Name = "VeilESP"
    local parent
    if gethui then local ok, h = pcall(gethui); if ok and h then parent = h end end
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
    h.FillColor = color; h.OutlineColor = color
    h.FillTransparency = 0.55; h.OutlineTransparency = 0.15
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Adornee = adornee
    h.Parent = esp_folder()
end
local function esp_cows()
    clear_esp()
    local plot = find_my_tycoon(); if not plot then return end
    for _, obj in ipairs(plot:GetDescendants()) do
        if obj:IsA("Model") and obj.Name:lower():find("cow") then
            attach_highlight(obj, Color3.fromRGB(255, 200, 40))
        end
    end
end

-- ============================================================
-- ANTI-AFK
-- ============================================================
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
-- BUY HELPER — tries GUI first, then workspace part
-- ============================================================
local function try_buy(item_name)
    local pg = LP:FindFirstChild("PlayerGui")
    if pg then
        for _, gui in ipairs(pg:GetChildren()) do
            if gui:IsA("ScreenGui") and (gui.Name:lower():find("shop") or gui.Name:lower():find("store")) then
                for _, d in ipairs(gui:GetDescendants()) do
                    if d:IsA("TextLabel") and d.Text:lower():find(item_name:lower()) then
                        -- find the nearest button
                        local par = d.Parent
                        for _ = 1, 4 do
                            if not par then break end
                            for _, sib in ipairs(par:GetDescendants()) do
                                if sib:IsA("TextButton") and (sib.Text:lower():find("buy") or sib.Name:lower():find("buy")) then
                                    pcall(function() sib:Activate() end)
                                    return true
                                end
                                if sib:IsA("ImageButton") and sib.Name:lower():find("buy") then
                                    pcall(function() sib:Activate() end)
                                    return true
                                end
                            end
                            par = par.Parent
                        end
                    end
                end
            end
        end
    end
    -- fallback: workspace part with matching name
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name:lower():find(item_name:lower()) then
            local cd = obj:FindFirstChild("ClickDetector") or obj:FindFirstChildOfClass("ClickDetector")
            if cd then
                pcall(function() fireclickdetector(cd) end)
                return true
            end
        end
    end
    return false
end

-- ============================================================
-- LOOPS
-- ============================================================
RunService.Heartbeat:Connect(function()
    local h = hum(); if not h then return end
    if S.walk_speed ~= 16 then h.WalkSpeed = S.walk_speed end
    if S.jump_power ~= 50 then h.JumpPower = S.jump_power end
end)

-- AUTO COLLECT MILK
RunService.Heartbeat:Connect(function()
    if not S.auto_collect or not alive() then return end
    if tick() - S.last_action < 0.4 then return end
    local r = root(); if not r then return end
    local target = find_nearest_milk()
    if target then
        local d = (target.Position - r.Position).Magnitude
        if d < 8 then
            pcall(function()
                firetouchinterest(r, target, 0)
                firetouchinterest(r, target, 1)
            end)
            S.last_action = tick()
        else
            local dir = target.Position - r.Position
            dir = Vector3.new(dir.X, 0, dir.Z)
            if dir.Magnitude > 2 then
                pcall(function() r.CFrame = r.CFrame + dir.Unit * 5 end)
            end
        end
    else
        local cow = find_nearest_cow()
        if cow then
            local hrp = cow:FindFirstChild("HumanoidRootPart") or cow.PrimaryPart
            if hrp then
                local d = (hrp.Position - r.Position).Magnitude
                if d > 8 then
                    local dir = hrp.Position - r.Position
                    dir = Vector3.new(dir.X, 0, dir.Z)
                    if dir.Magnitude > 2 then
                        pcall(function() r.CFrame = r.CFrame + dir.Unit * 5 end)
                    end
                else
                    pcall(function()
                        firetouchinterest(r, hrp, 0)
                        firetouchinterest(r, hrp, 1)
                    end)
                    S.last_action = tick()
                end
            end
        end
    end
end)

-- AUTO CALL NPC — brings NPC to player
RunService.Heartbeat:Connect(function()
    if not S.auto_call_npc then return end
    if tick() - S.last_action < 1 then return end
    local r = root(); if not r then return end
    local npc = find_npc(S.npc_target)
    if not npc then return end
    local hrp = npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart
    if not hrp then return end
    local d = (hrp.Position - r.Position).Magnitude
    if d > 10 then
        pcall(function()
            hrp.CFrame = r.CFrame * CFrame.new(0, 0, -5)
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
        S.last_action = tick()
    end
end)

-- AUTO SELL
RunService.Heartbeat:Connect(function()
    if not S.auto_sell then return end
    if tick() - S.last_action < 0.5 then return end
    local plot = find_my_tycoon(); if not plot then return end
    local buttons = plot:FindFirstChild("Buttons"); if not buttons then return end
    for _, btn in ipairs(buttons:GetChildren()) do
        local name = btn.Name:lower()
        if (name:find("sell") or name:find("collect")) and btn:IsA("BasePart") then
            pcall(function()
                if btn:FindFirstChild("ClickDetector") then fireclickdetector(btn.ClickDetector) end
            end)
            S.last_action = tick()
            return
        end
    end
end)

-- AUTO UPGRADE
RunService.Heartbeat:Connect(function()
    if not S.auto_upgrade then return end
    if tick() - S.last_action < 0.5 then return end
    local plot = find_my_tycoon(); if not plot then return end
    local buttons = plot:FindFirstChild("Buttons"); if not buttons then return end
    for _, btn in ipairs(buttons:GetChildren()) do
        if btn.Name:lower():find("upgrade") and btn:IsA("BasePart") then
            pcall(function()
                if btn:FindFirstChild("ClickDetector") then fireclickdetector(btn.ClickDetector) end
            end)
            S.last_action = tick()
            return
        end
    end
end)

-- AUTO ACCEPT TRADE — reads bucket count from trade GUI, accepts if >= threshold
RunService.Heartbeat:Connect(function()
    if not S.auto_accept_trade then return end
    local pg = LP:FindFirstChild("PlayerGui"); if not pg then return end
    for _, gui in ipairs(pg:GetChildren()) do
        local gn = gui.Name:lower()
        if gn:find("trade") or gn:find("offer") or gn:find("request") then
            local bucket_count = 0
            local accept_btn = nil
            for _, d in ipairs(gui:GetDescendants()) do
                if d:IsA("TextLabel") then
                    local n = tonumber(d.Text:match("%d+"))
                    if n and n > bucket_count then
                        local parent_name = d.Parent and d.Parent.Name:lower() or ""
                        local label = d.Name:lower()
                        if parent_name:find("bucket") or parent_name:find("milk")
                        or label:find("bucket") or label:find("amount") then
                            bucket_count = n
                        elseif n > bucket_count then
                            bucket_count = n
                        end
                    end
                end
                if d:IsA("TextButton") then
                    local t = d.Text:lower()
                    if t:find("accept") or t:find("confirm") or t == "yes" then
                        accept_btn = d
                    end
                end
            end
            if accept_btn and bucket_count >= S.trade_min_buckets then
                pcall(function() accept_btn:Activate() end)
            end
        end
    end
end)

-- ============================================================
-- BUILD
-- ============================================================
local module = { name = "Build a Cow Empire" }

function module.build(hub, CFG, ICON)
    -- ============================================
    -- FARM
    -- ============================================
    local farm = hub.page("Farm", ICON.farm)
    hub.toggle(farm, "Auto Collect Milk", "Walks to nearest milk — no teleport", ICON.fruit,
        function(on) S.auto_collect = on end)
    hub.toggle(farm, "Auto Call NPC", "Brings NPC to your position", ICON.boss,
        function(on) S.auto_call_npc = on end)
    hub.dropdown(farm, "NPC Name", "Which NPC to call",
        {"Milk Buyer", "Cow Buyer", "Collector", "Seller", "Statue Seller", "Totem"}, "Milk Buyer", ICON.esp,
        function(v) S.npc_target = v end)
    hub.toggle(farm, "Auto Sell", "Clicks sell buttons automatically", ICON.shop,
        function(on) S.auto_sell = on end)
    hub.toggle(farm, "Auto Upgrade", "Clicks upgrade buttons", ICON.shield,
        function(on) S.auto_upgrade = on end)

    -- ============================================
    -- BUY PAGE — Collectors
    -- ============================================
    local buy = hub.page("Buy", ICON.shop)

    -- header: Collectors
    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = CFG.accent,
        TextXAlignment = Enum.TextXAlignment.Left, Text = "COLLECTORS", ZIndex = 5,
        Parent = buy,
    }) -- placeholder; real header created below

    -- We'll use hub.button for each item
    local collector_items = {
        "Basic Collector", "Improved Collector", "Enhanced Collector", "Sturdy Collector",
        "Legendary Collector", "Mythic Collector", "MoonMilk Collector", "WheatLaurel Collector",
        "MilkRobo Collector", "RabbitRobo Collector", "SummerRobo Collector",
    }
    local pen_items = {
        "Basic Cattle pen", "Improved Cattle pen", "Enhanced Cattle pen", "Sturdy Cattle pen",
        "Deluxe Cattle pen", "Elite Cattle pen", "Legendary Cattle pen", "Workshop Cattle pen",
        "Factory Cattle pen", "Sanctuary Cattle pen", "UFO Cattle pen",
    }
    local statue_items = {
        "Basic Statue", "Improved Statue", "Enhanced Statue", "Sturdy Statue",
        "Deluxe Statue", "Elite Statue", "Legendary Statue", "Mythic Statue",
    }
    local workshop_items = {
        "Basic Workshop", "Improved Workshop", "Enhanced Workshop", "Sturdy Workshop",
        "Deluxe Workshop", "Elite Workshop", "Legendary Workshop", "Mythic Workshop",
    }

    for _, name in ipairs(collector_items) do
        hub.button(buy, name, "Click to buy " .. name, ICON.shop, function() try_buy(name) end)
    end
    for _, name in ipairs(pen_items) do
        hub.button(buy, name, "Click to buy " .. name, ICON.farm, function() try_buy(name) end)
    end
    for _, name in ipairs(statue_items) do
        hub.button(buy, name, "Click to buy " .. name, ICON.aura, function() try_buy(name) end)
    end
    for _, name in ipairs(workshop_items) do
        hub.button(buy, name, "Click to buy " .. name, ICON.util, function() try_buy(name) end)
    end

    -- ============================================
    -- MOVEMENT
    -- ============================================
    local move = hub.page("Movement", ICON.run)
    hub.slider(move, "Walk Speed", "16 = default, 200 = max", 16, 200, 16, ICON.run,
        function(v) S.walk_speed = v end)
    hub.slider(move, "Jump Power", "50 = default, 200 = max", 50, 200, 50, ICON.run,
        function(v) S.jump_power = v end)
    hub.button(move, "Reset Speed / Jump", "Back to defaults", ICON.run,
        function() S.walk_speed = 16; S.jump_power = 50 end)

    -- ============================================
    -- ESP
    -- ============================================
    local esp = hub.page("ESP", ICON.esp)
    hub.toggle(esp, "ESP Cows", "Gold highlight on your cows", ICON.esp,
        function(on) if on then esp_cows() else clear_esp() end end)

    -- ============================================
    -- TRADE
    -- ============================================
    local trade = hub.page("Trade", ICON.util)
    hub.toggle(trade, "Auto Accept Trade", "Accepts offers above the minimum buckets", ICON.util,
        function(on) S.auto_accept_trade = on end)
    hub.textbox(trade, "Minimum Buckets", "Type number, e.g. 100", "100", ICON.shop,
        function(txt)
            local n = tonumber(txt)
            if n and n > 0 then S.trade_min_buckets = n end
        end)

    -- ============================================
    -- UTILITY
    -- ============================================
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

    -- ============================================
    -- PERFORMANCE (auto from ui.lua)
    -- ============================================
    hub.performance_page(CFG, ICON)
end

return module
