--[[
    VeilHub — games/scripts/blox_fruits.lua v0.0.1
    Sea-aware. Clean layout using toggle/slider/dropdown/textbox/button.
]]

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser       = game:GetService("VirtualUser")
local Lighting          = game:GetService("Lighting")
local TeleportService   = game:GetService("TeleportService")
local HttpService       = game:GetService("HttpService")

local LP = Players.LocalPlayer
local RS = ReplicatedStorage

local SEA = 1
if game.PlaceId == 4442272183 then SEA = 2
elseif game.PlaceId == 7449423635 then SEA = 3 end

-- remotes
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
    RegisterHit    = find_in(Net, "RE/RegisterHit", "RegisterHit"),
}

-- state
local S = {
    auto_farm=false, auto_boss=false, auto_chest=false, auto_fruit=false,
    auto_mastery=false, auto_sea_event=false, auto_raid=false, auto_elite=false,
    auto_stats=false, auto_grab=false, tween_fruit=false,
    fast_attack=false, kill_aura=false, god_mode=false, inf_energy=false,
    noclip=false, walk_water=false, anti_afk=false,
    esp_players=false, esp_fruits=false, esp_chests=false, esp_boss=false,
    speed=16, jump=50, bring_range=120, attack_delay=0.15,
    kill_aura_range=40, attack_mode="Nearest", fruit_filter="All",
    last_attack=0, farm_target=nil, esp_folder=nil,
    current_chest=nil, fruit_priority_list={},
}

-- helpers
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
    pcall(function() r.CFrame = tr.CFrame * CFrame.new(0, 0, 2) end)
    if RE.RegisterAttack then pcall(function() RE.RegisterAttack:FireServer(0) end) end
    if RE.RegisterHit then pcall(function() RE.RegisterHit:FireServer({[1] = tr}) end) end
    if RE.SwordHit then pcall(function() RE.SwordHit:FireServer({[1] = tr}) end) end
    local tool = c:FindFirstChildOfClass("Tool")
    if tool then pcall(function() tool:Activate() end) end
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

-- pick target based on attack mode
local function pick_target(radius)
    radius = radius or S.bring_range
    local r = root(); if not r then return nil end
    local best, best_val = nil, nil

    for _, m in ipairs(workspace:GetChildren()) do
        if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid")
        and m:FindFirstChild("HumanoidRootPart") and m ~= char() then
            local h = m:FindFirstChildOfClass("Humanoid")
            if h.Health > 0 and not Players:GetPlayerFromCharacter(m) then
                local d = (m.HumanoidRootPart.Position - r.Position).Magnitude
                if d < radius then
                    local val
                    if S.attack_mode == "Nearest" then val = d
                    elseif S.attack_mode == "Lowest HP" then val = h.Health
                    elseif S.attack_mode == "Elite" then
                        if m.Name:lower():find("elite") or m.Name:lower():find("pirate") then
                            val = d
                        end
                    elseif S.attack_mode == "Highest HP" then val = -h.Health
                    end
                    if val and (not best_val or val < best_val) then
                        best, best_val = m, val
                    end
                end
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

-- esp
local esp_conns = {}
local function esp_folder()
    if S.esp_folder and S.esp_folder.Parent then return S.esp_folder end
    local sg = Instance.new("Folder")
    sg.Name = "VeilESP"
    local parent = gethui and gethui() or LP:WaitForChild("PlayerGui")
    sg.Parent = parent
    S.esp_folder = sg
    return sg
end
local function clear_esp()
    for _, c in ipairs(esp_conns) do c:Disconnect() end
    esp_conns = {}
    if S.esp_folder then
        for _, ch in ipairs(S.esp_folder:GetChildren()) do ch:Destroy() end
    end
end
local function make_highlight(adornee, fill_color)
    local h = Instance.new("Highlight")
    h.FillColor = fill_color
    h.OutlineColor = fill_color
    h.FillTransparency = 0.5
    h.OutlineTransparency = 0
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Adornee = adornee
    h.Parent = esp_folder()
end
local function esp_players()
    clear_esp()
    local function hook(p)
        if p == LP then return end
        local function on_c(c)
            local hrp = c:WaitForChild("HumanoidRootPart", 5); if not hrp then return end
            make_highlight(c, Color3.fromRGB(255, 80, 80))
        end
        if p.Character then on_c(p.Character) end
        table.insert(esp_conns, p.CharacterAdded:Connect(on_c))
    end
    for _, p in ipairs(Players:GetPlayers()) do hook(p) end
    table.insert(esp_conns, Players.PlayerAdded:Connect(hook))
end
local function esp_world(kind)
    clear_esp()
    local fill = kind == "fruit" and Color3.fromRGB(255, 200, 40)
              or kind == "chest" and Color3.fromRGB(120, 220, 255)
              or Color3.fromRGB(255, 140, 40)
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local n = obj.Name:lower()
            local hit = (kind == "fruit" and (n:find("fruit") or n:find("devil")))
                     or (kind == "chest" and n:find("chest"))
                     or (kind == "boss" and (n:find("boss") or n:find("rip")))
            if hit then make_highlight(obj, fill) end
        end
    end
end

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

-- loops
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
    if not S.auto_farm or not alive() then return end
    local t = pick_target(S.bring_range); if not t then return end
    S.farm_target = t
    bring_mob(t)
    if tick() - S.last_attack > rand(S.attack_delay * 0.7, S.attack_delay * 1.3) then
        do_attack(t)
    end
end)

RunService.Heartbeat:Connect(function()
    if not S.fast_attack then return end
    local t = S.farm_target or pick_target(40)
    if t and tick() - S.last_attack > S.attack_delay * 0.4 then
        bring_mob(t); do_attack(t)
    end
end)

RunService.Heartbeat:Connect(function()
    if not S.kill_aura then return end
    local r = root(); if not r then return end
    for _, m in ipairs(workspace:GetChildren()) do
        if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid")
        and m:FindFirstChild("HumanoidRootPart") and m ~= char() then
            local h = m:FindFirstChildOfClass("Humanoid")
            if h.Health > 0 and (m.HumanoidRootPart.Position - r.Position).Magnitude < S.kill_aura_range then
                bring_mob(m)
                if tick() - S.last_attack > 0.06 then do_attack(m) end
            end
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if not S.auto_chest then S.current_chest = nil; return end
    local r = root(); if not r then return end
    if S.current_chest and S.current_chest.Parent then
        local d = (S.current_chest.Position - r.Position).Magnitude
        if d < 15 then
            pcall(function()
                firetouchinterest(r, S.current_chest, 0)
                firetouchinterest(r, S.current_chest, 1)
            end)
        else
            pcall(function() r.CFrame = CFrame.new(S.current_chest.Position + Vector3.new(0, 3, 0)) end)
        end
        return
    end
    S.current_chest = nil
    local nearest, nd = nil, 300
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name:lower():find("chest") then
            local d = (obj.Position - r.Position).Magnitude
            if d < nd then nearest, nd = obj, d end
        end
    end
    S.current_chest = nearest
end)

RunService.Heartbeat:Connect(function()
    if not (S.auto_fruit or S.tween_fruit) then return end
    local r = root(); if not r then return end
    local RARE = { ["leopard"]=true, ["kitsune"]=true, ["dragon"]=true, ["dough"]=true,
                   ["venom"]=true, ["shadow"]=true, ["control"]=true, ["portal"]=true }
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local n = obj.Name:lower()
            if n:find("fruit") or n:find("devil") then
                local key = n:gsub("%s*fruit%s*",""):gsub("%s*","")
                local ok_target = true
                if S.fruit_filter == "Rare Only" and not RARE[key] then ok_target = false end
                if S.fruit_filter == "Ignore Common" and (key == "rocket" or key == "spin" or key == "blade") then ok_target = false end
                if ok_target and (obj.Position - r.Position).Magnitude < 400 then
                    pcall(function() r.CFrame = CFrame.new(obj.Position + Vector3.new(0, 3, 0)) end)
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
                    if r then pcall(function() r.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 3, 4)) end) end
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
                    if r then pcall(function() r.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 3, 4)) end) end
                    if tick() - S.last_attack > rand(0.1, 0.2) then do_attack(m) end
                end
            end
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if not S.auto_mastery then return end
    local t = pick_target(60)
    if t then bring_mob(t); if tick() - S.last_attack > rand(0.15, 0.22) then do_attack(t) end end
end)

RunService.Heartbeat:Connect(function()
    if not S.auto_elite then return end
    local t = find_named("elite", 800) or find_named("pirate", 400)
    if not t then return end
    local hrp = t:FindFirstChild("HumanoidRootPart")
    if hrp then
        local r = root()
        if r then pcall(function() r.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 3, 4)) end) end
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
    local t = pick_target(400)
    if t then bring_mob(t); if tick() - S.last_attack > rand(0.1, 0.2) then do_attack(t) end end
end)

local stats_last = 0
RunService.Heartbeat:Connect(function()
    if not S.auto_stats then return end
    if tick() - stats_last < 5 then return end
    stats_last = tick()
    pcall(function()
        if RE.CommF then
            RE.CommF:InvokeServer("BuyHaki", "Geppo")
            RE.CommF:InvokeServer("BuyHaki", "Busoshoku")
            RE.CommF:InvokeServer("BuyHaki", "Ken")
        end
    end)
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
local module = { name = "Blox Fruits · Sea " .. tostring(SEA) }

function module.build(hub, CFG, ICON)
    -- ============ FARM ============
    local farm = hub.page("Farm", ICON.farm)
    hub.toggle(farm, "Auto Farm Level", "Grinds mobs continuously", ICON.farm,
        function(on) S.auto_farm = on end)
    hub.dropdown(farm, "Attack Mode", "How to pick targets",
        {"Nearest", "Lowest HP", "Highest HP", "Elite"}, "Nearest", ICON.boss,
        function(v) S.attack_mode = v end)
    hub.slider(farm, "Farm Range", "Detection radius", 30, 500, 120, ICON.boss,
        function(v) S.bring_range = v end)
    hub.slider(farm, "Attack Speed", "Lower = faster", 5, 40, 15, ICON.bolt,
        function(v) S.attack_delay = v / 100 end)
    hub.toggle(farm, "Auto Boss Farm", "Chase and kill bosses", ICON.boss,
        function(on) S.auto_boss = on end)
    hub.toggle(farm, "Auto Chest Collect", "Nearest chest, stack until gone", ICON.chest,
        function(on) S.auto_chest = on; if not on then S.current_chest = nil end end)
    hub.toggle(farm, "Auto Fruit Sniper", "Teleport to fruit spawns", ICON.fruit,
        function(on) S.auto_fruit = on end)
    hub.dropdown(farm, "Fruit Filter", "Which fruits to grab",
        {"All", "Rare Only", "Ignore Common"}, "All", ICON.fruit,
        function(v) S.fruit_filter = v end)
    hub.toggle(farm, "Auto Mastery", "Grinds nearest mob for mastery", ICON.bolt,
        function(on) S.auto_mastery = on end)
    hub.toggle(farm, "Auto Sea Events", "Sea beasts and events", ICON.boss,
        function(on) S.auto_sea_event = on end)
    hub.toggle(farm, "Auto Elite Hunter", "Hunts elite pirates", ICON.boss,
        function(on) S.auto_elite = on end)
    hub.toggle(farm, "Auto Raid Farm", "Auto-joins and clears raids", ICON.boss,
        function(on) S.auto_raid = on end)
    hub.toggle(farm, "Auto Grab Fruits", "Pickup dropped fruit nearby", ICON.fruit,
        function(on) S.auto_grab = on end)

    -- ============ COMBAT ============
    local combat = hub.page("Combat", ICON.aura)
    hub.toggle(combat, "Kill Aura", "Attacks nearby mobs automatically", ICON.aura,
        function(on) S.kill_aura = on end)
    hub.slider(combat, "Aura Range", "Kill aura radius", 10, 120, 40, ICON.aura,
        function(v) S.kill_aura_range = v end)
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
    hub.slider(move, "Walk Speed", "16 = default, 300 = max", 16, 300, 16, ICON.run,
        function(v) S.speed = v end)
    hub.slider(move, "Jump Power", "50 = default, 250 = max", 50, 250, 50, ICON.run,
        function(v) S.jump = v end)
    hub.toggle(move, "Noclip", "Walk through walls", ICON.run,
        function(on) S.noclip = on; set_noclip(on) end)
    hub.toggle(move, "Walk on Water", "Float above ocean surface", ICON.run,
        function(on) S.walk_water = on end)
    hub.button(move, "Reset Speed/Jump", "Back to defaults", ICON.run,
        function() S.speed = 16; S.jump = 50 end)

    -- ============ TELEPORT ============
    local SEA_ISLANDS = {
        [1] = {
            "Starter Island", "Marine Fortress", "Middle Town", "Jungle",
            "Pirate Village", "Desert", "Frozen Village", "Skylands",
        },
        [2] = {
            "Kingdom of Rose", "Green Zone", "Graveyard", "Snow Mountain",
            "Hot and Cold", "Cursed Ship",
        },
        [3] = {
            "Port Town", "Hydra Island", "Great Tree", "Castle on the Sea",
            "Haunted Castle", "Floating Turtle",
        },
    }
    local SEA_COORDS = {
        [1] = {
            ["Starter Island"]   = Vector3.new(0, 12, 0),
            ["Marine Fortress"]  = Vector3.new(-200, 12, 200),
            ["Middle Town"]      = Vector3.new(400, 15, 600),
            ["Jungle"]           = Vector3.new(800, 15, 1200),
            ["Pirate Village"]   = Vector3.new(1200, 15, 1800),
            ["Desert"]           = Vector3.new(1500, 15, 2200),
            ["Frozen Village"]   = Vector3.new(1800, 15, 2600),
            ["Skylands"]         = Vector3.new(2000, 200, 3000),
        },
        [2] = {
            ["Kingdom of Rose"]  = Vector3.new(-5200, 20, -5200),
            ["Green Zone"]       = Vector3.new(-5000, 20, -5000),
            ["Graveyard"]        = Vector3.new(-4800, 20, -4800),
            ["Snow Mountain"]    = Vector3.new(-4600, 20, -4600),
            ["Hot and Cold"]     = Vector3.new(-4400, 20, -4400),
            ["Cursed Ship"]      = Vector3.new(-4200, 20, -4200),
        },
        [3] = {
            ["Port Town"]        = Vector3.new(5200, 30, -5200),
            ["Hydra Island"]     = Vector3.new(5400, 30, -5400),
            ["Great Tree"]       = Vector3.new(5600, 30, -5600),
            ["Castle on the Sea"]= Vector3.new(5800, 30, -5800),
            ["Haunted Castle"]   = Vector3.new(6000, 30, -6000),
            ["Floating Turtle"]  = Vector3.new(6200, 200, -6200),
        },
    }

    local tp = hub.page("Teleport · Sea " .. tostring(SEA), ICON.tp)
    local islands = SEA_ISLANDS[SEA] or SEA_ISLANDS[1]
    local coords = SEA_COORDS[SEA] or SEA_COORDS[1]

    local target_island = islands[1]
    hub.dropdown(tp, "Island", "Pick where to go", islands, islands[1], ICON.tp,
        function(v) target_island = v end)
    hub.button(tp, "Teleport to Island", "Go to selected island", ICON.tp, function()
        local pos = coords[target_island]
        if pos then
            local r = root()
            if r then r.CFrame = CFrame.new(pos + Vector3.new(0, 8, 0)) end
        end
    end)

    -- player teleport dropdown built at build time
    local player_names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then table.insert(player_names, p.Name) end
    end
    if #player_names > 0 then
        hub.dropdown(tp, "Player", "Pick a player to teleport to", player_names, player_names[1], ICON.esp,
            function(v)
                local target_plr = Players:FindFirstChild(v)
                if target_plr and target_plr.Character then
                    local hrp = target_plr.Character:FindFirstChild("HumanoidRootPart")
                    local r = root()
                    if hrp and r then r.CFrame = hrp.CFrame * CFrame.new(0, 0, -5) end
                end
            end)
    end

    hub.textbox(tp, "Custom Coordinates", "Format: x,y,z", "0, 100, 0", ICON.tp,
        function(txt)
            local parts = {}
            for num in txt:gmatch("[^,%s]+") do table.insert(parts, tonumber(num)) end
            if #parts == 3 and parts[1] and parts[2] and parts[3] then
                local r = root()
                if r then r.CFrame = CFrame.new(Vector3.new(parts[1], parts[2], parts[3])) end
            end
        end)

    -- ============ ESP ============
    local esp = hub.page("ESP", ICON.esp)
    hub.toggle(esp, "ESP Players", "Red highlight on players", ICON.esp,
        function(on) if on then esp_players() else clear_esp() end end)
    hub.toggle(esp, "ESP Fruits", "Gold highlight on fruits", ICON.fruit,
        function(on) if on then esp_world("fruit") else clear_esp() end end)
    hub.toggle(esp, "ESP Chests", "Blue highlight on chests", ICON.chest,
        function(on) if on then esp_world("chest") else clear_esp() end end)
    hub.toggle(esp, "ESP Bosses", "Orange highlight on bosses", ICON.boss,
        function(on) if on then esp_world("boss") else clear_esp() end end)

    -- ============ UTILITY ============
    local util = hub.page("Utility", ICON.util)
    hub.toggle(util, "Anti AFK", "Prevents 20-minute kick", ICON.util,
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
            Lighting.Ambient = Color3.fromRGB(180, 180, 180); Lighting.Brightness = 3
        else
            Lighting.Ambient = Color3.fromRGB(70, 70, 70); Lighting.Brightness = 2
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
            TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], LP)
        end)
    end)
end

return module
