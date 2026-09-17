--[[
    VeilHub — ui-key.lua v0.0.1
    Key gate. NOT wired into loader.lua yet — push to repo now for later.
    Get Key → https://veil-hub.vercel.app/getkey?uid=<UserId>
    Admin bypass: VEILHUB-ADMIN-123
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer
local CAM = workspace.CurrentCamera

local CFG = {
    title="Veil Hub", version="0.0.1",
    discord="https://discord.gg/hcV9Efe4y",
    website="https://veil-hub.vercel.app/getkey",
    accent=Color3.fromRGB(250,204,21),
    accent2=Color3.fromRGB(255,230,80),
    accent_dark=Color3.fromRGB(180,140,10),
    bg=Color3.fromRGB(10,10,12),
    panel=Color3.fromRGB(24,24,28),
    panel2=Color3.fromRGB(32,32,38),
    text=Color3.fromRGB(240,240,240),
    subtext=Color3.fromRGB(150,150,158),
    danger=Color3.fromRGB(235,90,100),
    good=Color3.fromRGB(110,220,140),
    black=Color3.fromRGB(0,0,0),
}

-- ============================================================
-- VALID KEYS
-- Admin key is ONLY for Axion99. Users get theirs from the website.
-- ============================================================
local ADMIN_KEY = "VEILHUB-ADMIN-123"
local FALLBACK_KEYS = {
    -- local test keys (used before website is live)
    "VEIL-TEST-001",
    "VEIL-TEST-002",
    "AXION99",
    -- admin bypass — NEVER give this out
    ADMIN_KEY,
}

-- Remote key list (optional). Set to a URL that returns one key per line.
local REMOTE_KEYS_URL = nil -- e.g. "https://veil-hub.vercel.app/api/keys.txt"

-- Remote verify endpoint. Set this once the website is deployed.
local VERIFY_URL = nil -- e.g. "https://veil-hub.vercel.app/api/verify"

-- ============================================================
-- HELPERS
-- ============================================================
local function new(c,p,ch)
    local i = Instance.new(c)
    for k,v in pairs(p or {}) do i[k]=v end
    for _,x in ipairs(ch or {}) do x.Parent = i end
    return i
end
local function corner(p,r) return new("UICorner",{CornerRadius=UDim.new(0,r or 8),Parent=p}) end
local function grad(p,c1,c2)
    local g = new("UIGradient",{Parent=p, Rotation=90})
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,c1),
        ColorSequenceKeypoint.new(1,c2),
    })
    return g
end
local function stroke(p,c,t,tr)
    return new("UIStroke",{Color=c, Thickness=t or 1, Transparency=tr or 0,
        ApplyStrokeMode=Enum.ApplyStrokeMode.Border, Parent=p})
end
local function padding(p,x)
    return new("UIPadding",{
        PaddingTop=UDim.new(0,x), PaddingBottom=UDim.new(0,x),
        PaddingLeft=UDim.new(0,x), PaddingRight=UDim.new(0,x), Parent=p})
end
local function get_parent()
    if gethui then local ok,h = pcall(gethui); if ok and h then return h end end
    local ok,cg = pcall(function() return CoreGui end)
    if ok and cg then
        local ok2 = pcall(function() return cg.Name end)
        if ok2 then return cg end
    end
    return LP:WaitForChild("PlayerGui")
end
local function drag(f,h)
    h = h or f
    local d,s,sp = false,nil,nil
    h.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then d,s,sp=true,i.Position,f.Position end
    end)
    h.InputChanged:Connect(function(i)
        if d and (i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch) then
            local m = i.Position - s
            f.Position = UDim2.new(sp.X.Scale, sp.X.Offset+m.X, sp.Y.Scale, sp.Y.Offset+m.Y)
        end
    end)
    h.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then d=false end
    end)
end
local function scale_for(w,h)
    local vp = CAM and CAM.ViewportSize or Vector2.new(1280,720)
    return math.clamp(math.min((vp.X*0.80)/w, (vp.Y*0.72)/h), 0.55, 1.0)
end

-- ============================================================
-- FILE CACHE
-- ============================================================
local CACHE_PATH = "veil_key.txt"
local function load_cached_key()
    if not (readfile and isfile) then return nil end
    local ok, e = pcall(isfile, CACHE_PATH)
    if not ok or not e then return nil end
    local ok2, c = pcall(readfile, CACHE_PATH)
    if not ok2 or type(c) ~= "string" then return nil end
    return c:gsub("%s+", "")
end
local function save_cached_key(k)
    if not writefile then return end
    pcall(writefile, CACHE_PATH, k)
end
local function clear_cached_key()
    if not delfile then return end
    pcall(delfile, CACHE_PATH)
end

-- ============================================================
-- KEY VALIDATION
-- ============================================================
local function is_admin_key(k) return k == ADMIN_KEY end

local function is_local_key(k)
    for _, v in ipairs(FALLBACK_KEYS) do
        if v == k then return true end
    end
    return false
end

local function fetch_remote_keys()
    if not REMOTE_KEYS_URL then return nil end
    local ok_loader, L = pcall(function() return _G.VEIL_LOADER end)
    if not ok_loader or type(L) ~= "table" or type(L.http) ~= "function" then
        return nil
    end
    local ok, body = pcall(L.http, REMOTE_KEYS_URL)
    if not ok or type(body) ~= "string" then return nil end
    local keys = {}
    for line in body:gmatch("[^\r\n]+") do
        line = line:gsub("^%s+", ""):gsub("%s+$", "")
        if #line > 0 and not line:match("^#") then
            table.insert(keys, line)
        end
    end
    if #keys == 0 then return nil end
    return keys
end

local function remote_verify(key)
    if not VERIFY_URL then return nil end
    local ok_loader, L = pcall(function() return _G.VEIL_LOADER end)
    if not ok_loader or type(L) ~= "table" or type(L.http) ~= "function" then
        return nil
    end
    local url = VERIFY_URL .. "?key=" .. key .. "&hwid=" .. tostring(LP.UserId)
    local ok, body = pcall(L.http, url)
    if not ok or type(body) ~= "string" then return nil end
    -- expects {"valid":true} or {"valid":false,...}
    if body:find('"valid"%s*:%s*true') then return true end
    if body:find('"valid"%s*:%s*false') then return false end
    return nil
end

-- ============================================================
-- BUILD UI
-- ============================================================
local parent = get_parent()
local old = parent:FindFirstChild("VeilHubKey")
if old then old:Destroy() end

local gui = new("ScreenGui",{
    Name="VeilHubKey", ResetOnSpawn=false, IgnoreGuiInset=true,
    ZIndexBehavior=Enum.ZIndexBehavior.Global,
    DisplayOrder=999999, Parent=parent,
})
pcall(function() gui.ClipToDeviceSafeArea=false end)

local W,H = 400, 320
local main = new("Frame",{
    Size=UDim2.fromOffset(W,H),
    Position=UDim2.new(0.5,0,0.5,0), AnchorPoint=Vector2.new(0.5,0.5),
    BackgroundColor3=CFG.bg, BorderSizePixel=0, ZIndex=1, Parent=gui,
})
corner(main,12)
grad(main, CFG.panel, CFG.bg)

local us = new("UIScale",{Scale=1,Parent=main})
local function apply() us.Scale = scale_for(W,H) end
apply()
if CAM then CAM:GetPropertyChangedSignal("ViewportSize"):Connect(apply) end

-- titlebar
local tb = new("Frame",{
    Size=UDim2.new(1,0,0,32), BackgroundColor3=CFG.panel,
    BorderSizePixel=0, ZIndex=2, Parent=main,
})
corner(tb,12)
new("Frame",{
    Size=UDim2.new(1,0,0,12), Position=UDim2.new(0,0,1,-12),
    BackgroundColor3=CFG.panel, BorderSizePixel=0, ZIndex=2, Parent=tb,
})
local dot = new("Frame",{
    Size=UDim2.fromOffset(8,8), Position=UDim2.new(0,14,0.5,-4),
    BackgroundColor3=CFG.accent, BorderSizePixel=0, ZIndex=4, Parent=tb,
})
corner(dot,4)
grad(dot, CFG.accent2, CFG.accent_dark)
new("TextLabel",{
    Size=UDim2.new(1,-60,1,0), Position=UDim2.new(0,28,0,0),
    BackgroundTransparency=1, Font=Enum.Font.GothamBold, TextSize=13,
    TextColor3=CFG.accent, TextXAlignment=Enum.TextXAlignment.Left,
    Text=CFG.title.."  ·  Key", ZIndex=4, Parent=tb,
})
local xb = new("TextButton",{
    Size=UDim2.fromOffset(22,22), Position=UDim2.new(1,-28,0,5),
    BackgroundColor3=CFG.panel2, BorderSizePixel=0,
    Font=Enum.Font.GothamBold, TextSize=13, TextColor3=CFG.danger,
    Text="×", AutoButtonColor=false, ZIndex=3, Parent=tb,
})
corner(xb,6)
xb.MouseButton1Click:Connect(function() gui:Destroy() end)
drag(main,tb)

-- body
local body = new("Frame",{
    Size=UDim2.new(1,-28,1,-32-20), Position=UDim2.new(0,14,0,42),
    BackgroundTransparency=1, ZIndex=2, Parent=main,
})

new("TextLabel",{
    Size=UDim2.new(1,0,0,20), BackgroundTransparency=1,
    Font=Enum.Font.GothamBold, TextSize=16, TextColor3=CFG.accent,
    TextXAlignment=Enum.TextXAlignment.Left, Text="Enter your key",
    ZIndex=3, Parent=body,
})
new("TextLabel",{
    Size=UDim2.new(1,0,0,14), Position=UDim2.new(0,0,0,22),
    BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=11,
    TextColor3=CFG.subtext, TextXAlignment=Enum.TextXAlignment.Left,
    Text="Get yours from the website.", ZIndex=3, Parent=body,
})

local box = new("TextBox",{
    Size=UDim2.new(1,0,0,34), Position=UDim2.new(0,0,0,46),
    BackgroundColor3=CFG.panel, BorderSizePixel=0,
    Font=Enum.Font.Code, TextSize=13, TextColor3=CFG.text,
    PlaceholderText="VEIL-XXXX-XXXX", PlaceholderColor3=CFG.subtext,
    Text="", ClearTextOnFocus=false,
    TextXAlignment=Enum.TextXAlignment.Left,
    ZIndex=3, Parent=body,
})
corner(box,6)
padding(box,10)
stroke(box, CFG.accent, 1, 0.75)

local status = new("TextLabel",{
    Size=UDim2.new(1,0,0,16), Position=UDim2.new(0,0,0,86),
    BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=11,
    TextColor3=CFG.subtext, TextXAlignment=Enum.TextXAlignment.Left,
    Text="", ZIndex=3, Parent=body,
})

-- submit
local submit = new("TextButton",{
    Size=UDim2.new(1,0,0,34), Position=UDim2.new(0,0,0,108),
    BackgroundColor3=CFG.accent, BorderSizePixel=0,
    Font=Enum.Font.GothamBold, TextSize=13,
    TextColor3=CFG.black, Text="Submit", AutoButtonColor=false,
    ZIndex=3, Parent=body,
})
corner(submit,6)
grad(submit, CFG.accent2, CFG.accent)
stroke(submit, CFG.accent, 1, 0.3)

-- get key
local getkey = new("TextButton",{
    Size=UDim2.new(1,0,0,34), Position=UDim2.new(0,0,0,150),
    BackgroundColor3=CFG.panel2, BorderSizePixel=0,
    Font=Enum.Font.GothamBold, TextSize=13,
    TextColor3=CFG.accent, Text="Get Key  ·  "..CFG.website,
    AutoButtonColor=false, ZIndex=3, Parent=body,
})
corner(getkey,6)
stroke(getkey, CFG.accent, 1, 0.4)

new("TextLabel",{
    Size=UDim2.new(1,0,0,14), Position=UDim2.new(0,0,1,-14),
    BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=10,
    TextColor3=CFG.subtext, TextXAlignment=Enum.TextXAlignment.Center,
    Text=CFG.discord, ZIndex=3, Parent=body,
})

-- ============================================================
-- GET KEY — redirect to website
-- ============================================================
getkey.MouseButton1Click:Connect(function()
    local url = CFG.website .. "?uid=" .. tostring(LP.UserId)
    if setclipboard then setclipboard(url) end

    local opened = false
    if syn and syn.request then
        opened = pcall(function() syn.request({Url=url, Method="GET"}) end)
    elseif request then
        opened = pcall(function() request({Url=url, Method="GET"}) end)
    elseif http_request then
        opened = pcall(function() http_request({Url=url, Method="GET"}) end)
    end

    if opened then
        getkey.Text = "Opened · URL Copied"
    else
        getkey.Text = "Copied: "..url
    end
    task.delay(1.8, function()
        getkey.Text = "Get Key  ·  "..CFG.website
    end)
end)

-- ============================================================
-- VALIDATION FLOW
-- ============================================================
local locked = false

local function unlock(reason)
    if locked then return end
    locked = true

    status.Text = reason or "Key accepted. Loading..."
    status.TextColor3 = CFG.good

    -- fade out
    local out = TweenService:Create(main,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { BackgroundTransparency = 1 })
    out:Play()
    for _, d in ipairs(main:GetDescendants()) do
        if d:IsA("GuiObject") and not d:IsA("UIStroke") then
            TweenService:Create(d,
                TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
        end
    end
    task.wait(0.25)
    gui:Destroy()

    -- hand off to loader
    local runner = _G.VEIL_RUN_MAIN
    if type(runner) == "function" then
        local ok, res = pcall(runner)
        if not ok then warn("[Veil/key] run_main failed — "..tostring(res)) end
    else
        warn("[Veil/key] _G.VEIL_RUN_MAIN not set — run loader.lua")
    end
end

local function attempt_key(raw)
    if locked then return end
    local key = tostring(raw or ""):gsub("%s+", "")
    if #key == 0 then
        status.Text = "Type a key first."
        status.TextColor3 = CFG.danger
        return
    end

    -- admin bypass
    if is_admin_key(key) then
        save_cached_key(key)
        unlock("Admin access granted.")
        return
    end

    -- local test keys
    if is_local_key(key) then
        save_cached_key(key)
        unlock("Key accepted.")
        return
    end

    -- remote verify (once VERIFY_URL is set)
    status.Text = "Verifying with server..."
    status.TextColor3 = CFG.subtext
    task.spawn(function()
        local result = remote_verify(key)
        if result == true then
            save_cached_key(key)
            unlock("Server verified.")
        elseif result == false then
            status.Text = "Invalid or expired key."
            status.TextColor3 = CFG.danger
            box.Text = ""
            submit.BackgroundColor3 = CFG.danger
            task.delay(0.35, function()
                submit.BackgroundColor3 = CFG.accent
            end)
        else
            -- no remote verify endpoint yet — reject
            status.Text = "Invalid key."
            status.TextColor3 = CFG.danger
            box.Text = ""
            submit.BackgroundColor3 = CFG.danger
            task.delay(0.35, function()
                submit.BackgroundColor3 = CFG.accent
            end)
        end
    end)
end

submit.MouseButton1Click:Connect(function() attempt_key(box.Text) end)
box.FocusLost:Connect(function(enter)
    if enter then attempt_key(box.Text) end
end)

-- auto-cache check on load
task.spawn(function()
    local cached = load_cached_key()
    if not cached then return end
    if is_admin_key(cached) or is_local_key(cached) then
        status.Text = "Saved key accepted."
        status.TextColor3 = CFG.good
        task.wait(0.4)
        unlock("Saved key accepted.")
    else
        -- try remote verify
        local result = remote_verify(cached)
        if result == true then
            task.wait(0.2)
            unlock("Saved key verified.")
        else
            clear_cached_key()
        end
    end
end)
