--[[
    VeilHub — games/scripts/blox_fruits.lua v0.0.1
    Blox Fruits module. Uses hub:page(), hub:toggle(), hub:button().
    To add another game: copy this structure, change PlaceId in manifest.
]]

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local VirtualUser       = game:GetService("VirtualUser")
local StarterGui        = game:GetService("StarterGui")
local Lighting          = game:GetService("Lighting")
local TeleportService   = game:GetService("TeleportService")
local HttpService       = game:GetService("HttpService")

local LP = Players.LocalPlayer
local RS = ReplicatedStorage

-- ============================================================
-- REMOTES
-- ============================================================
local Remotes = RS:FindFirstChild("Remotes")
local Net     = RS:FindFirstChild("Net")

local function find_in(folder, ...)
    if not folder then return nil end
    for _, n in ipairs({...}) do
        local r = folder:FindFirstChild(n)
        if r then return r end
    end
    return nil
end

local RE = {
    CommF = Remotes and Remotes:FindFirstChild("CommF_"),
    SwordHit = find_in(Net, "RE/SwordHit", "SwordHit"),
    RegisterAttack = find_in(Net, "RE/RegisterAttack", "RegisterAttack"),
}

-- ============================================================
-- STATE
-- ============================================================
local S = {
    auto_farm=false, auto_boss=false, auto_chest=false, auto_fruit=false,
    auto_quest=false, auto_mastery=false, auto_sea_event=false,
    auto_raid=false, auto_elite=false, auto_stats=false, auto_grab=false,
    tween_fruit=false, auto_third=false,
    fast_attack=false, kill_aura=false, god_mode=false, inf_energy=false,
    noclip=false, walk_water=false, anti_afk=false,
    esp_players=false, esp_fruits=false, esp_chests=false, esp_boss=false,
    speed=16, jump=50,
    last_attack=0, farm_target=nil, esp_folder=nil, bring_range=120,
}

-- ============================================================
-- HELPERS
-- ============================================================
local function rand(a,b) return a + math.random() * (b-a) end
local function char() return LP.Character end
local function root() local c=char(); return c and c:FindFirstChild("HumanoidRootPart") end
local function hum() local c=char(); return c and c:FindFirstChildOfClass("Humanoid") end
local function alive() local h=hum(); return h and h.Health > 0 end

local function do_attack(target)
    if not target or not alive() then return end
    local c = char(); local r = root()
    if not c or not r then return end
    local tr = target:FindFirstChild("HumanoidRootPart"); if not tr then return end
    pcall(function() r.CFrame = CFrame.lookAt(r.Position, tr.Position) end)
    local tool = c:FindFirstChildOfClass("Tool")
    if tool then pcall(function() tool:Activate() end) end
    if RE.SwordHit then pcall(function() RE.SwordHit:FireServer({[1]=tr}) end) end
    if RE.RegisterAttack then pcall(function() RE.RegisterAttack:FireServer(0) end) end
    S.last_attack = tick()
end

local function bring_mob(t)
    if not t then return end
    local r = root(); if not r then return end
    local tr = t:FindFirstChild("HumanoidRootPart"); if not tr then return end
    pcall(function()
        tr.CFrame = r.CFrame * CFrame.new(0, 0, -4)
        tr.AssemblyLinearVelocity = Vector3.zero
        tr.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function nearest_npc(radius)
    radius = radius or S.bring_range
    local r = root(); if not r then return nil end
    local best, bd = nil, radius
    for _, m in ipairs(workspace:GetChildren()) do
        if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid")
        and m:FindFirstChild("HumanoidRootPart") and m ~= char() then
            local h = m:FindFirstChildOfClass("Humanoid")
            if h.Health > 0 and not Players:GetPlayerFromCharacter(m) then
                local d = (m.HumanoidRootPart.Position - r.Position).Magnitude
                if d < bd then best, bd = m, d end
            end
        end
    end
    return best
end

local function find_named(pattern, radius)
    radius = radius or 600
    local r = root(); if not r then return nil end
    local best, bd = nil, radius
    for _, m in ipairs(workspace:GetChildren()) do
        if m:IsA("Model") and m:FindFirstChild("HumanoidRootPart") then
            local h = m:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 0 and m.Name:lower():find(pattern) then
                local d = (m.HumanoidRootPart.Position - r.Position).Magnitude
                if d < bd then best, bd = m, d end
            end
        end
    end
    return best
end

-- ============================================================
-- ESP
-- ============================================================
local esp_conns = {}
local function esp_folder()
    if S.esp_folder and S.esp_folder.Parent then return S.esp_folder end
    local pg = LP:FindFirstChild("PlayerGui")
    local sg = pg:FindFirstChild("VeilESP") or Instance.new("ScreenGui")
    sg.Name = "VeilESP"; sg.ResetOnSpawn=false; sg.IgnoreGuiInset=true
    sg.Parent = pg; S.esp_folder = sg
    return sg
end
local function clear_esp()
    for _, c in ipairs(esp_conns) do c:Disconnect() end
    esp_conns = {}
    local pg = LP:FindFirstChild("PlayerGui")
    local sg = pg and pg:FindFirstChild("VeilESP")
    if sg then sg:ClearAllChildren() end
end
local function make_box(a, color)
    local sg = esp_folder()
    local b = Instance.new("BoxHandleAdornment")
    b.Size = a.Size + Vector3.new(0.4,0.4,0.4)
    b.Adornee = a; b.AlwaysOnTop = true
    b.ZIndex = 5; b.Transparency = 0.6
    b.Color3 = color; b.Parent = sg
end
local function esp_players()
    clear_esp()
    local function hook(p)
        if p == LP then return end
        local function on_c(c)
            local hrp = c:WaitForChild("HumanoidRootPart", 5); if not hrp then return end
            make_box(hrp, Color3.fromRGB(255,80,80))
        end
        if p.Character then on_c(p.Character) end
        table.insert(esp_conns, p.CharacterAdded:Connect(on_c))
    end
    for _, p in ipairs(Players:GetPlayers()) do hook(p) end
    table.insert(esp_conns, Players.PlayerAdded:Connect(hook))
end
local function esp_world(kind)
    clear_esp()
    local color = kind=="fruit" and Color3.fromRGB(255,200,40)
               or kind=="chest" and Color3.fromRGB(120,220,255)
               or Color3.fromRGB(255,140,40)
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("BasePart") then
            local n = o.Name:lower()
            local hit = (kind=="fruit" and (n:find("fruit") or n:find("devil")))
                     or (kind=="chest" and n:find("chest"))
                     or (kind=="boss" and (n:find("boss") or n:find("rip")))
            if hit then make_box(o, color) end
        end
    end
end

-- noclip / afk
local noc_conn
local function set_noclip(on)
    if noc_conn then noc_conn:Disconnect(); noc_conn = nil end
    if not on then return end
    noc_conn = RunService.Stepped:Connect(function()
        local c = char(); if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end
    end)
end
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
RunService.Heartbeat:Connect(function()
    if not S.auto_farm or not alive() then return end
    local t = nearest_npc(S.bring_range); if not t then return end
    S.farm_target = t; bring_mob(t)
    if tick() - S.last_attack > rand(0.10, 0.18) then do_attack(t) end
end)

RunService.Heartbeat:Connect(function()
    if not S.fast_attack then return end
    local t = S.farm_target or nearest_npc(40)
    if t and tick() - S.last_attack > 0.05 then bring_mob(t); do_attack(t) end
end)

RunService.Heartbeat:Connect(function()
    if not S.kill_aura then return end
    local r = root(); if not r then return end
    for _, m in ipairs(workspace:GetChildren()) do
        if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid")
        and m:FindFirstChild("HumanoidRootPart") and m ~= char() then
            local h = m:FindFirstChildOfClass("Humanoid")
            if h.Health > 0 and (m.HumanoidRootPart.Position - r.Position).Magnitude < 40 then
                bring_mob(m)
                if tick() - S.last_attack > 0.06 then do_attack(m) end
            end
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if S.god_mode then
        local h = hum()
        if h and h.Health < h.MaxHealth then h.Health = h.MaxHealth end
    end
    if S.inf_energy then
        local c = char()
        if c then
            for _, v in ipairs(c:GetDescendants()) do
                if v:IsA("NumberValue") and v.Name:lower():find("energy") then
                    v.Value = math.huge
                end
            end
        end
    end
    local h = hum()
    if h then
        if S.speed ~= 16 then h.WalkSpeed = S.speed end
        if S.jump ~= 50 then h.JumpPower = S.jump end
    end
end)

RunService.Heartbeat:Connect(function()
    if S.auto_chest then
        local r = root(); if not r then return end
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name:lower():find("chest")
            and (obj.Position - r.Position).Magnitude < 200 then
                pcall(function() r.CFrame = CFrame.new(r.Position + (obj.Position - r.Position).Unit * 5) end)
            end
        end
    end
    if S.auto_fruit or S.tween_fruit then
        local r = root(); if not r then return end
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local n = obj.Name:lower()
                if (n:find("fruit") or n:find("devil"))
                and (obj.Position - r.Position).Magnitude < 400 then
                    pcall(function() r.CFrame = CFrame.new(r.Position + (obj.Position - r.Position).Unit * 5) end)
                end
            end
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if not S.auto_boss then return end
    for _, m in ipairs(workspace:GetChildren()) do
        if m:IsA("Model") then
            local n = m.Name:lower()
            if n:find("boss") or n:find("rip") or n:find("katakuri")
            or n:find("doflamingo") or n:find("kaidou") then
                local hrp = m:FindFirstChild("HumanoidRootPart")
                local h = m:FindFirstChildOfClass("Humanoid")
                if hrp and h and h.Health > 0 then
                    local r = root()
                    if r then pcall(function() r.CFrame = CFrame.new(hrp.Position + Vector3.new(0,3,4)) end) end
                    bring_mob(m)
                    if tick() - S.last_attack > rand(0.1, 0.2) then do_attack(m) end
                end
            end
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if not S.auto_sea_event then return end
    for _, m in ipairs(workspace:GetChildren()) do
        if m:IsA("Model") then
            local n = m.Name:lower()
            if n:find("seabeast") or n:find("ghostship")
            or n:find("piratebrigade") or n:find("terror") then
                local hrp = m:FindFirstChild("HumanoidRootPart")
                local h = m:FindFirstChildOfClass("Humanoid")
                if hrp and h and h.Health > 0 then
                    local r = root()
                    if r then pcall(function() r.CFrame = CFrame.new(hrp.Position + Vector3.new(0,3,4)) end) end
                    bring_mob(m)
                    if tick() - S.last_attack > rand(0.1, 0.2) then do_attack(m) end
                end
            end
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if not S.auto_mastery then return end
    local t = nearest_npc(60)
    if t then bring_mob(t); if tick() - S.last_attack > rand(0.15, 0.22) then do_attack(t) end end
end)

RunService.Heartbeat:Connect(function()
    if not S.auto_elite then return end
    local t = find_named("elite", 800) or find_named("pirate", 400)
    if not t then return end
    local hrp = t:FindFirstChild("HumanoidRootPart")
    if hrp then
        local r = root()
        if r then pcall(function() r.CFrame = CFrame.new(hrp.Position + Vector3.new(0,3,4)) end) end
        if tick() - S.last_attack > rand(0.1, 0.2) then do_attack(t) end
    end
end)

RunService.Heartbeat:Connect(function()
    if not S.auto_grab then return end
    local r = root(); if not r then return end
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("BasePart") then
            local n = o.Name:lower()
            if (n:find("fruit") or n:find("devil"))
            and (o.Position - r.Position).Magnitude < 25 then
                pcall(function()
                    firetouchinterest(r, o, 0)
                    firetouchinterest(r, o, 1)
                end)
            end
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if not S.walk_water then return end
    local r = root()
    if r and r.Position.Y < 5 then
        pcall(function() r.CFrame = r.CFrame + Vector3.new(0, 0.5, 0) end)
    end
end)

RunService.Heartbeat:Connect(function()
    if not S.auto_raid then return end
    local t = nearest_npc(400)
    if t then bring_mob(t); if tick() - S.last_attack > rand(0.1, 0.2) then do_attack(t) end end
end)

RunService.Heartbeat:Connect(function()
    if not S.auto_stats then return end
    pcall(function()
        if RE.CommF then
            RE.CommF:InvokeServer("BuyHaki","Geppo")
            RE.CommF:InvokeServer("BuyHaki","Busoshoku")
            RE.CommF:InvokeServer("BuyHaki","Ken")
        end
    end)
end)

RunService.Heartbeat:Connect(function()
    if not S.auto_third then return end
    local r = root(); if not r then return end
    if r.Position.Y < 100 then
        pcall(function()
            if RE.CommF then RE.CommF:InvokeServer("TravelThirdSea") end
        end)
    end
end)

RunService.Heartbeat:Connect(function()
    local r = root(); if not r then return end
    if r.Position.Y < -500 or r.Position.Y > 50000 then
        pcall(function() local c = char(); if c then c:BreakJoints() end end)
    end
end)

-- ============================================================
-- BUILD
-- ============================================================
local module = { name = "Blox Fruits" }

function module.build(hub, CFG, ICON)
    -- ============ FARM ============
    local farm = hub.page("Farm", ICON.farm)

    hub.toggle(farm, "Auto Farm Level", "Grinds nearest mob continuously", ICON.farm,
        function(on) S.auto_farm = on end)
    hub.toggle(farm, "Auto Boss Farm", "Farms all nearby bosses", ICON.boss,
        function(on) S.auto_boss = on end)
    hub.toggle(farm, "Auto Chest Collect", "Collects chests on the map", ICON.chest,
        function(on) S.auto_chest = on end)
    hub.toggle(farm, "Auto Fruit Sniper", "Snipes fruit spawns", ICON.fruit,
        function(on) S.auto_fruit = on end)
    hub.toggle(farm, "Auto Mastery", "Grinds mastery on nearest mob", ICON.bolt,
        function(on) S.auto_mastery = on end)
    hub.toggle(farm, "Auto Sea Events", "Farms sea beasts and events", ICON.boss,
        function(on) S.auto_sea_event = on end)
    hub.toggle(farm, "Auto Elite Hunter", "Farms elite pirates", ICON.boss,
        function(on) S.auto_elite = on end)
    hub.toggle(farm, "Auto Raid Farm", "Auto-joins and clears raids", ICON.boss,
        function(on) S.auto_raid = on end)
    hub.toggle(farm, "Auto Grab Fruits", "Picks up dropped fruit", ICON.fruit,
        function(on) S.auto_grab = on end)
    hub.toggle(farm, "Tween Fruit", "Moves toward fruit smoothly", ICON.fruit,
        function(on) S.tween_fruit = on end)
    hub.toggle(farm, "Auto Third Sea", "Travel to Third Sea", ICON.tp,
        function(on) S.auto_third = on end)

    -- ============ COMBAT ============
    local combat = hub.page("Combat", ICON.aura)

    hub.toggle(combat, "Kill Aura", "Attacks everything within 40 studs", ICON.aura,
        function(on) S.kill_aura = on end)
    hub.toggle(combat, "God Mode", "Keeps your HP at max", ICON.shield,
        function(on) S.god_mode = on end)
    hub.toggle(combat, "Infinite Energy", "Pins energy value to max", ICON.energy,
        function(on) S.inf_energy = on end)
    hub.toggle(combat, "Fast Attack", "Attack speed boost", ICON.bolt,
        function(on) S.fast_attack = on end)
    hub.toggle(combat, "Auto Stats", "Buys all Haki automatically", ICON.shield,
        function(on) S.auto_stats = on end)

    -- ============ MOVEMENT ============
    local move = hub.page("Movement", ICON.run)

    hub.button(move, "Noclip", "Walk through walls", ICON.run, function()
        S.noclip = not S.noclip
        set_noclip(S.noclip)
    end)
    hub.button(move, "Walk on Water", "Float above the ocean", ICON.run, function()
        S.walk_water = not S.walk_water
    end)
    hub.button(move, "Speed 80", "Set WalkSpeed to 80", ICON.run,
        function() S.speed = 80 end)
    hub.button(move, "Speed 120", "Set WalkSpeed to 120", ICON.run,
        function() S.speed = 120 end)
    hub.button(move, "Speed 200", "Set WalkSpeed to 200", ICON.run,
        function() S.speed = 200 end)
    hub.button(move, "Jump 120", "Set JumpPower to 120", ICON.run,
        function() S.jump = 120 end)
    hub.button(move, "Reset Speed", "Reset to default", ICON.run,
        function() S.speed = 16; S.jump = 50 end)
    hub.button(move, "TP Spawn", "Teleport to spawn", ICON.tp, function()
        local r = root(); if r then r.CFrame = CFrame.new(0,12,0) end
    end)
    hub.button(move, "TP Middle Town", "Teleport to Middle Town", ICON.tp, function()
        local r = root(); if r then r.CFrame = CFrame.new(400,15,600) end
    end)
    hub.button(move, "TP Desert", "Teleport to Desert", ICON.tp, function()
        local r = root(); if r then r.CFrame = CFrame.new(1500,15,2200) end
    end)

    -- ============ ESP ============
    local esp = hub.page("ESP", ICON.esp)

    hub.toggle(esp, "ESP Players", "Red boxes on players", ICON.esp,
        function(on) if on then esp_players() else clear_esp() end end)
    hub.toggle(esp, "ESP Fruits", "Gold boxes on fruits", ICON.fruit,
        function(on) if on then esp_world("fruit") else clear_esp() end end)
    hub.toggle(esp, "ESP Chests", "Blue boxes on chests", ICON.chest,
        function(on) if on then esp_world("chest") else clear_esp() end end)
    hub.toggle(esp, "ESP Bosses", "Orange boxes on bosses", ICON.boss,
        function(on) if on then esp_world("boss") else clear_esp() end end)

    -- ============ UTILITY ============
    local util = hub.page("Utility", ICON.util)

    hub.toggle(util, "Anti AFK", "Prevents 20-min kick", ICON.util,
        function(on) set_afk(on) end)
    hub.toggle(util, "Remove Fog", "Clears fog rendering", ICON.util, function(on)
        if on then
            Lighting.FogEnd = 1e6; Lighting.FogStart = 1e5
        else
            Lighting.FogEnd = 1000; Lighting.FogStart = 0
        end
    end)
    hub.toggle(util, "Full Bright", "Brightens the world", ICON.util, function(on)
        if on then
            Lighting.Ambient = Color3.fromRGB(180,180,180); Lighting.Brightness = 3
        else
            Lighting.Ambient = Color3.fromRGB(70,70,70); Lighting.Brightness = 2
        end
    end)
    hub.button(util, "Hop Server", "Jumps to a random server", ICON.util, function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if not ok then return end
        local ok2, data = pcall(function() return HttpService:JSONDecode(body) end)
        if not ok2 or not data or not data.data then return end
        local servers = {}
        for _, s in ipairs(data.data) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then
                table.insert(servers, s.id)
            end
        end
        if #servers == 0 then return end
        pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1,#servers)], LP)
        end)
    end)
end

return module
