--[[
    VeilHub — ui-key.lua v0.0.1
    Key gate. NOT used by loader yet. Ready for later.
    Get Key → https://veil-hub.vercel.app
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer
local CAM = workspace.CurrentCamera

local CFG = {
    title="Veil Hub", version="0.0.1",
    discord="https://discord.gg/hcV9Efe4y",
    website="https://veil-hub.vercel.app",
    accent=Color3.fromRGB(250,204,21),
    bg=Color3.fromRGB(10,10,12), panel=Color3.fromRGB(24,24,28),
    panel2=Color3.fromRGB(32,32,38),
    text=Color3.fromRGB(240,240,240), subtext=Color3.fromRGB(150,150,158),
    danger=Color3.fromRGB(235,90,100), good=Color3.fromRGB(110,220,140),
    black=Color3.fromRGB(0,0,0),
}

local function new(c,p,ch)
    local i = Instance.new(c)
    for k,v in pairs(p or {}) do i[k]=v end
    for _,x in ipairs(ch or {}) do x.Parent = i end
    return i
end
local function corner(p,r) return new("UICorner",{CornerRadius=UDim.new(0,r or 8),Parent=p}) end
local function padding(p,x)
    return new("UIPadding",{PaddingTop=UDim.new(0,x),PaddingBottom=UDim.new(0,x),
        PaddingLeft=UDim.new(0,x),PaddingRight=UDim.new(0,x),Parent=p})
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
    h=h or f
    local d,s,sp=false,nil,nil
    h.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
        or i.UserInputType==Enum.UserInputType.Touch then d,s,sp=true,i.Position,f.Position end
    end)
    h.InputChanged:Connect(function(i)
        if d and (i.UserInputType==Enum.UserInputType.MouseMovement
        or i.UserInputType==Enum.UserInputType.Touch) then
            local m = i.Position - s
            f.Position = UDim2.new(sp.X.Scale, sp.X.Offset+m.X, sp.Y.Scale, sp.Y.Offset+m.Y)
        end
    end)
    h.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
        or i.UserInputType==Enum.UserInputType.Touch then d=false end
    end)
end
local function scale_for(w,h)
    local vp = CAM and CAM.ViewportSize or Vector2.new(1280,720)
    return math.clamp(math.min((vp.X*0.80)/w,(vp.Y*0.72)/h),0.55,1.0)
end

local CACHE_PATH = "veil_key.txt"
local function load_cached()
    if not (readfile and isfile) then return nil end
    local ok,e = pcall(isfile, CACHE_PATH); if not ok or not e then return nil end
    local ok2,c = pcall(readfile, CACHE_PATH)
    if not ok2 or type(c)~="string" then return nil end
    return c:gsub("%s+","")
end
local function save_cached(k) if writefile then pcall(writefile, CACHE_PATH, k) end end
local function clear_cached() if delfile then pcall(delfile, CACHE_PATH) end end

-- simple key list — replace with remote verify later
local VALID_KEYS = { "VEIL-TEST-001", "VEIL-TEST-002", "AXION99" }
local function is_valid(k)
    for _, v in ipairs(VALID_KEYS) do if v == k then return true end end
    return false
end

-- build UI
local parent = get_parent()
local old = parent:FindFirstChild("VeilHubKey"); if old then old:Destroy() end

local gui = new("ScreenGui",{
    Name="VeilHubKey", ResetOnSpawn=false, IgnoreGuiInset=true,
    ZIndexBehavior=Enum.ZIndexBehavior.Global, DisplayOrder=999999, Parent=parent,
})
pcall(function() gui.ClipToDeviceSafeArea = false end)

local W,H = 400, 320
local main = new("Frame",{
    Size=UDim2.fromOffset(W,H),
    Position=UDim2.new(0.5,0,0.5,0), AnchorPoint=Vector2.new(0.5,0.5),
    BackgroundColor3=CFG.bg, BorderSizePixel=0, ZIndex=1, Parent=gui,
})
corner(main,12)

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
new("TextLabel",{
    Size=UDim2.new(1,-60,1,0), Position=UDim2.new(0,14,0,0),
    BackgroundTransparency=1, Font=Enum.Font.GothamBold, TextSize=13,
    TextColor3=CFG.accent, TextXAlignment=Enum.TextXAlignment.Left,
    Text=CFG.title.."  ·  Key", ZIndex=3, Parent=tb,
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

local body = new("Frame",{
    Size=UDim2.new(1,-28,1,-32-20),
    Position=UDim2.new(0,14,0,42),
    BackgroundTransparency=1, ZIndex=2, Parent=main,
})

new("TextLabel",{
    Size=UDim2.new(1,0,0,20), BackgroundTransparency=1,
    Font=Enum.Font.GothamBold, TextSize=16, TextColor3=CFG.accent,
    TextXAlignment=Enum.TextXAlignment.Left,
    Text="Enter your key", ZIndex=3, Parent=body,
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
corner(box,6); padding(box,10)

local status = new("TextLabel",{
    Size=UDim2.new(1,0,0,16), Position=UDim2.new(0,0,0,86),
    BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=11,
    TextColor3=CFG.subtext, TextXAlignment=Enum.TextXAlignment.Left,
    Text="", ZIndex=3, Parent=body,
})

local submit = new("TextButton",{
    Size=UDim2.new(1,0,0,34), Position=UDim2.new(0,0,0,108),
    BackgroundColor3=CFG.accent, BorderSizePixel=0,
    Font=Enum.Font.GothamBold, TextSize=13,
    TextColor3=CFG.black, Text="Submit", AutoButtonColor=false,
    ZIndex=3, Parent=body,
})
corner(submit,6)

local getkey = new("TextButton",{
    Size=UDim2.new(1,0,0,34), Position=UDim2.new(0,0,0,150),
    BackgroundColor3=CFG.panel2, BorderSizePixel=0,
    Font=Enum.Font.GothamBold, TextSize=13,
    TextColor3=CFG.accent, Text="Get Key", AutoButtonColor=false,
    ZIndex=3, Parent=body,
})
corner(getkey,6)

new("TextLabel",{
    Size=UDim2.new(1,0,0,14), Position=UDim2.new(0,0,1,-14),
    BackgroundTransparency=1, Font=Enum.Font.Gotham, TextSize=10,
    TextColor3=CFG.subtext, TextXAlignment=Enum.TextXAlignment.Center,
    Text=CFG.website, ZIndex=3, Parent=body,
})

-- behaviour
getkey.MouseButton1Click:Connect(function()
    if setclipboard then setclipboard(CFG.website) end
    if request then
        pcall(function() request({Url=CFG.website, Method="GET"}) end)
    end
    getkey.Text = "Opened · URL Copied"
    task.delay(1.6, function() getkey.Text = "Get Key" end)
end)

local locked = false
local function unlock()
    if locked then return end
    locked = true
    gui:Destroy()
    local runner = _G.VEIL_RUN_MAIN
    if type(runner) == "function" then
        pcall(runner)
    else
        warn("[Veil/key] _G.VEIL_RUN_MAIN not set — run loader.lua")
    end
end

local function attempt(raw)
    if locked then return end
    local k = tostring(raw or ""):gsub("%s+", "")
    if #k == 0 then
        status.Text = "Type a key first."
        status.TextColor3 = CFG.danger
        return
    end
    if is_valid(k) then
        status.Text = "Key accepted."
        status.TextColor3 = CFG.good
        save_cached(k)
        task.delay(0.35, unlock)
    else
        status.Text = "Invalid key."
        status.TextColor3 = CFG.danger
        box.Text = ""
        submit.BackgroundColor3 = CFG.danger
        task.delay(0.35, function() submit.BackgroundColor3 = CFG.accent end)
    end
end

submit.MouseButton1Click:Connect(function() attempt(box.Text) end)
box.FocusLost:Connect(function(enter)
    if enter then attempt(box.Text) end
end)

task.spawn(function()
    local cached = load_cached()
    if cached and is_valid(cached) then
        status.Text = "Saved key accepted."
        status.TextColor3 = CFG.good
        task.wait(0.4); unlock()
    elseif cached then
        clear_cached()
    end
end)
