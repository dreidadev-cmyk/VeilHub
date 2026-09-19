--[[
    VeilHub — remote/dumper.lua v0.2.0
    Aggressive scanner:
      · scans game:GetDescendants() (EVERYTHING)
      · scans getreg() if the executor supports it (finds hidden instances)
      · hooks DescendantAdded so remotes created after load are captured
      · waits 3s for game to settle before first dump
      · writes to VeilHub/veil_remotes_<PlaceId>.txt
]]

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local StarterGui        = game:GetService("StarterGui")
local CoreGui           = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer
local CAM = workspace.CurrentCamera

-- ============================================================
-- CONFIG
-- ============================================================
local CFG = {
    title="VeilHub Remote Dumper", version="0.2.0",
    accent=Color3.fromRGB(250,204,21),
    accent2=Color3.fromRGB(255,230,80),
    accent_dark=Color3.fromRGB(180,140,10),
    bg=Color3.fromRGB(10,10,14),
    bg2=Color3.fromRGB(14,14,20),
    card_top=Color3.fromRGB(28,28,38),
    card_bot=Color3.fromRGB(18,18,26),
    panel=Color3.fromRGB(24,24,28),
    icon_bg=Color3.fromRGB(38,38,50),
    text=Color3.fromRGB(245,245,250),
    subtext=Color3.fromRGB(150,150,165),
    dim=Color3.fromRGB(95,95,115),
    good=Color3.fromRGB(90,220,130),
    danger=Color3.fromRGB(240,90,100),
    blue=Color3.fromRGB(90,140,255),
    purple=Color3.fromRGB(180,120,255),
    black=Color3.fromRGB(0,0,0),
    white=Color3.fromRGB(255,255,255),
}

local OUTPUT_NAME = "veil_remotes_" .. tostring(game.PlaceId) .. ".txt"
local OUTPUT_DIR  = "VeilHub"

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
    if gethui then local ok,h=pcall(gethui); if ok and h then return h end end
    local ok,cg=pcall(function() return CoreGui end)
    if ok and cg then
        local ok2=pcall(function() return cg.Name end)
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
            local m=i.Position-s
            f.Position=UDim2.new(sp.X.Scale,sp.X.Offset+m.X,sp.Y.Scale,sp.Y.Offset+m.Y)
        end
    end)
    h.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
        or i.UserInputType==Enum.UserInputType.Touch then d=false end
    end)
end
local function scale_for(w,h)
    local vp = CAM and CAM.ViewportSize or Vector2.new(1280,720)
    return math.clamp(math.min((vp.X*0.94)/w, (vp.Y*0.88)/h), 0.55, 1.0)
end
local function notify(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title=title, Text=text, Duration=dur or 4,
        })
    end)
end

local has_file_api = (writefile ~= nil)
local has_folder_api = (makefolder ~= nil) and (isfolder ~= nil)
local function ensure_dir()
    if not has_folder_api then return end
    pcall(function()
        if not isfolder(OUTPUT_DIR) then makefolder(OUTPUT_DIR) end
    end)
end

-- ============================================================
-- REMOTE TYPES
-- ============================================================
local REMOTE_CLASSES = {
    ["RemoteEvent"]           = true,
    ["RemoteFunction"]        = true,
    ["BindableEvent"]         = true,
    ["BindableFunction"]      = true,
    ["UnreliableRemoteEvent"] = true,
}

-- ============================================================
-- SEEN MAP (dedupe by full path)
-- ============================================================
local SEEN = {}

local function record(obj, source, results)
    if not obj then return end
    if not REMOTE_CLASSES[obj.ClassName] then return end
    local ok_path, path = pcall(function() return obj:GetFullName() end)
    if not ok_path then return end
    if SEEN[path] then return end
    SEEN[path] = true
    table.insert(results, {
        source = source,
        class  = obj.ClassName,
        path   = path,
        parent = (obj.Parent and obj.Parent:GetFullName()) or "nil",
        name   = obj.Name,
    })
end

-- ============================================================
-- SCAN: game:GetDescendants() — EVERYTHING
-- ============================================================
local function scan_game(results)
    pcall(function()
        for _, obj in ipairs(game:GetDescendants()) do
            record(obj, "game", results)
        end
    end)
end

-- ============================================================
-- SCAN: getreg() — hidden instances (executor-dependent)
-- ============================================================
local function scan_registry(results)
    if type(getreg) ~= "function" then return 0 end
    local added = 0
    local ok = pcall(function()
        local reg = getreg()
        for _, obj in pairs(reg) do
            if typeof(obj) == "Instance" then
                local cls_ok, cls = pcall(function() return obj.ClassName end)
                if cls_ok and REMOTE_CLASSES[cls] then
                    local before = #results
                    record(obj, "getreg", results)
                    if #results > before then
                        added = added + 1
                    end
                end
            end
        end
    end)
    if not ok then
        warn("[Veil/remote] getreg scan failed — executor may not support it")
    end
    return added
end

-- ============================================================
-- LIVE HOOK — DescendantAdded on game
-- ============================================================
local hook_conn
local live_added = 0
local live_results
local on_new_descendant

local function start_live_hook(results)
    live_results = results
    on_new_descendant = function(obj)
        if REMOTE_CLASSES[obj.ClassName] then
            local before = #results
            record(obj, "live", results)
            if #results > before then
                live_added = live_added + 1
            end
        end
    end
    hook_conn = game.DescendantAdded:Connect(on_new_descendant)
end

-- ============================================================
-- FORMAT
-- ============================================================
local function format_results(results)
    local out = {}
    local function add(s) table.insert(out, s) end
    add("================================================================")
    add(" VeilHub — Remote Dump v0.2.0")
    add("================================================================")
    add(" PlaceId : " .. tostring(game.PlaceId))
    add(" JobId   : " .. tostring(game.JobId))
    add(" User    : " .. tostring(LP.Name) .. " (" .. tostring(LP.UserId) .. ")")
    add(" Time    : " .. os.date("%Y-%m-%d %H:%M:%S"))
    add(" Exec    : " .. tostring(identifyexecutor and identifyexecutor() or "unknown"))
    add(" Total   : " .. tostring(#results))
    add(" Live    : " .. tostring(live_added))
    add("================================================================")
    add("")
    local by_class = {}
    for _, r in ipairs(results) do
        by_class[r.class] = by_class[r.class] or {}
        table.insert(by_class[r.class], r)
    end
    local order = {"RemoteEvent","RemoteFunction","UnreliableRemoteEvent","BindableEvent","BindableFunction"}
    for _, cls in ipairs(order) do
        local list = by_class[cls]
        if list then
            add("---- " .. cls .. "  (" .. tostring(#list) .. ") ----")
            table.sort(list, function(a,b) return a.path < b.path end)
            for _, r in ipairs(list) do
                add("  [" .. r.source .. "]  " .. r.path)
            end
            add("")
            by_class[cls] = nil
        end
    end
    for cls, list in pairs(by_class) do
        add("---- " .. cls .. "  (" .. tostring(#list) .. ") ----")
        for _, r in ipairs(list) do add("  [" .. r.source .. "]  " .. r.path) end
        add("")
    end
    add("================================================================")
    add(" End of dump — " .. tostring(#results) .. " unique remotes")
    add("================================================================")
    return table.concat(out, "\n")
end

-- ============================================================
-- UI
-- ============================================================
local parent = get_parent()
local old = parent:FindFirstChild("VeilRemoteDumper")
if old then old:Destroy() end

local gui = new("ScreenGui",{
    Name="VeilRemoteDumper", ResetOnSpawn=false, IgnoreGuiInset=true,
    ZIndexBehavior=Enum.ZIndexBehavior.Global,
    DisplayOrder=999998, Parent=parent,
})
pcall(function() gui.ClipToDeviceSafeArea=false end)

local W,H = 640, 560
local main = new("Frame",{
    Name="Main", Size=UDim2.fromOffset(W,H),
    Position=UDim2.new(0.5,0,0.5,0), AnchorPoint=Vector2.new(0.5,0.5),
    BackgroundColor3=CFG.bg, BorderSizePixel=0, ZIndex=1, Parent=gui,
})
corner(main,16)
grad(main, CFG.bg2, CFG.bg)
stroke(main, Color3.fromRGB(45,45,60), 1, 0.4)

local us = new("UIScale",{Scale=1,Parent=main})
local function apply() us.Scale = scale_for(W,H) end
apply()
if CAM then CAM:GetPropertyChangedSignal("ViewportSize"):Connect(apply) end

-- titlebar
local tb = new("Frame",{
    Size=UDim2.new(1,0,0,42),
    BackgroundColor3=CFG.bg2, BorderSizePixel=0, ZIndex=2, Parent=main,
})
corner(tb,16)
grad(tb, CFG.bg2, CFG.bg)
new("Frame",{
    Size=UDim2.new(1,0,0,16), Position=UDim2.new(0,0,1,-16),
    BackgroundColor3=CFG.bg, BorderSizePixel=0, ZIndex=2, Parent=tb,
})
local dot = new("Frame",{
    Size=UDim2.fromOffset(8,8), Position=UDim2.new(0,16,0.5,-4),
    BackgroundColor3=CFG.accent, BorderSizePixel=0, ZIndex=4, Parent=tb,
})
corner(dot,4); grad(dot, CFG.accent2, CFG.accent_dark)
new("TextLabel",{
    Size=UDim2.new(1,-120,1,0), Position=UDim2.new(0,32,0,0),
    BackgroundTransparency=1, Font=Enum.Font.GothamBold, TextSize=14,
    TextColor3=CFG.text, TextXAlignment=Enum.TextXAlignment.Left,
    Text=CFG.title, ZIndex=4, Parent=tb,
})
new("TextLabel",{
    Size=UDim2.new(0,80,1,0), Position=UDim2.new(0,290,0,0),
    BackgroundTransparency=1, Font=Enum.Font.GothamMedium, TextSize=10,
    TextColor3=CFG.subtext, TextXAlignment=Enum.TextXAlignment.Left,
    Text="v"..CFG.version, ZIndex=4, Parent=tb,
})
local xb = new("TextButton",{
    Size=UDim2.fromOffset(26,26), Position=UDim2.new(1,-36,0.5,-13),
    BackgroundColor3=Color3.fromRGB(40,20,25), BorderSizePixel=0,
    Font=Enum.Font.GothamBold, TextSize=14, TextColor3=CFG.danger,
    Text="×", AutoButtonColor=false, ZIndex=4, Parent=tb,
})
corner(xb,8)
xb.MouseButton1Click:Connect(function() gui:Destroy() end)
drag(main,tb)

-- stats row
local stats_holder = new("Frame",{
    Size=UDim2.new(1,-28,0,70), Position=UDim2.new(0,14,0,56),
    BackgroundTransparency=1, ZIndex=3, Parent=main,
})
new("UIGridLayout",{
    CellSize=UDim2.new(0.25,-6,0,70),
    CellPadding=UDim2.new(0,8,0,0),
    SortOrder=Enum.SortOrder.LayoutOrder, Parent=stats_holder,
})

local stat_labels = {}
local function stat_card(label, color, order)
    local c = new("Frame",{
        LayoutOrder=order, BackgroundColor3=CFG.card_top,
        BorderSizePixel=0, ZIndex=3, Parent=stats_holder,
    })
    corner(c,12); grad(c, CFG.card_top, CFG.card_bot)
    stroke(c, color, 1, 0.65); padding(c,10)
    new("TextLabel",{
        Size=UDim2.new(1,0,0,12), BackgroundTransparency=1,
        Font=Enum.Font.GothamMedium, TextSize=10, TextColor3=color,
        TextXAlignment=Enum.TextXAlignment.Left, Text=label, ZIndex=4, Parent=c,
    })
    local v = new("TextLabel",{
        Size=UDim2.new(1,0,0,26), Position=UDim2.new(0,0,0,18),
        BackgroundTransparency=1, Font=Enum.Font.GothamBold, TextSize=22,
        TextColor3=CFG.text, TextXAlignment=Enum.TextXAlignment.Left,
        Text="—", ZIndex=4, Parent=c,
    })
    stat_labels[label] = v
end
stat_card("TOTAL", CFG.accent, 1)
stat_card("EVENTS", CFG.good, 2)
stat_card("FUNCTIONS", CFG.blue, 3)
stat_card("BINDABLES", CFG.purple, 4)

-- search
local search = new("TextBox",{
    Size=UDim2.new(1,-28,0,36), Position=UDim2.new(0,14,0,136),
    BackgroundColor3=CFG.panel, BorderSizePixel=0,
    Font=Enum.Font.Gotham, TextSize=12, TextColor3=CFG.text,
    PlaceholderText="Search remotes...", PlaceholderColor3=CFG.dim,
    Text="", ClearTextOnFocus=false, TextXAlignment=Enum.TextXAlignment.Left,
    ZIndex=4, Parent=main,
})
corner(search,8); stroke(search, CFG.accent, 1, 0.75); padding(search,10)

-- list
local list_frame = new("Frame",{
    Size=UDim2.new(1,-28,1,-300), Position=UDim2.new(0,14,0,182),
    BackgroundColor3=CFG.bg2, BorderSizePixel=0, ZIndex=3, Parent=main,
})
corner(list_frame,10); stroke(list_frame, Color3.fromRGB(45,45,60), 1, 0.5)

local scroll = new("ScrollingFrame",{
    Size=UDim2.new(1,-14,1,-14), Position=UDim2.new(0,7,0,7),
    BackgroundTransparency=1, BorderSizePixel=0,
    ScrollBarThickness=4, ScrollBarImageColor3=CFG.accent,
    CanvasSize=UDim2.new(0,0,0,0), ZIndex=4, Parent=list_frame,
})
new("UIListLayout",{
    SortOrder=Enum.SortOrder.LayoutOrder,
    Padding=UDim.new(0,4), Parent=scroll,
})

local row_count = 0

local function class_color(cls)
    if cls == "RemoteEvent" then return CFG.good end
    if cls == "RemoteFunction" then return CFG.blue end
    if cls == "UnreliableRemoteEvent" then return CFG.accent end
    if cls == "BindableEvent" then return CFG.purple end
    if cls == "BindableFunction" then return CFG.purple end
    return CFG.subtext
end

local function add_row(remote)
    row_count = row_count + 1
    local row = new("Frame",{
        Size=UDim2.new(1,-8,0,32), BackgroundColor3=CFG.card_top,
        BorderSizePixel=0, ZIndex=4, Parent=scroll, LayoutOrder=row_count,
    })
    corner(row,6)
    local dot = new("Frame",{
        Size=UDim2.fromOffset(3,16), Position=UDim2.new(0,6,0.5,-8),
        BackgroundColor3=class_color(remote.class), BorderSizePixel=0,
        ZIndex=5, Parent=row,
    })
    corner(dot,2)
    new("TextLabel",{
        Size=UDim2.new(0,140,1,0), Position=UDim2.new(0,16,0,0),
        BackgroundTransparency=1, Font=Enum.Font.GothamBold,
        TextSize=10, TextColor3=class_color(remote.class),
        TextXAlignment=Enum.TextXAlignment.Left,
        Text=remote.class, ZIndex=5, Parent=row,
    })
    new("TextLabel",{
        Size=UDim2.new(1,-220,1,0), Position=UDim2.new(0,158,0,0),
        BackgroundTransparency=1, Font=Enum.Font.Code,
        TextSize=10, TextColor3=CFG.text,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd,
        Text=remote.path, ZIndex=5, Parent=row,
    })
    new("TextLabel",{
        Size=UDim2.fromOffset(50,22), Position=UDim2.new(1,-110,0.5,-11),
        BackgroundTransparency=1, Font=Enum.Font.GothamMedium,
        TextSize=9, TextColor3=CFG.dim,
        TextXAlignment=Enum.TextXAlignment.Center,
        Text=remote.source, ZIndex=5, Parent=row,
    })
    local copy_btn = new("TextButton",{
        Size=UDim2.fromOffset(50,22), Position=UDim2.new(1,-56,0.5,-11),
        BackgroundColor3=CFG.icon_bg, BorderSizePixel=0,
        Font=Enum.Font.GothamBold, TextSize=10,
        TextColor3=CFG.accent, Text="Copy",
        AutoButtonColor=false, ZIndex=5, Parent=row,
    })
    corner(copy_btn,5)
    copy_btn.MouseButton1Click:Connect(function()
        if setclipboard then
            setclipboard(remote.path)
            copy_btn.Text = "✓"
            task.delay(1, function() copy_btn.Text = "Copy" end)
        end
    end)
    return row
end

local all_rows = {}
local current_query = ""

local function refresh_list()
    for _, r in ipairs(all_rows) do r:Destroy() end
    all_rows = {}
    row_count = 0
    for _, remote in ipairs(_G._veil_remotes or {}) do
        if current_query == "" or remote.path:lower():find(current_query, 1, true) then
            local row = add_row(remote)
            table.insert(all_rows, row)
        end
    end
    scroll.CanvasSize = UDim2.new(0,0,0,row_count * 36 + 8)
end

search:GetPropertyChangedSignal("Text"):Connect(function()
    current_query = search.Text:lower()
    refresh_list()
end)

-- buttons
local btn_holder = new("Frame",{
    Size=UDim2.new(1,-28,0,44), Position=UDim2.new(0,14,1,-56),
    BackgroundTransparency=1, ZIndex=3, Parent=main,
})
new("UIListLayout",{
    SortOrder=Enum.SortOrder.LayoutOrder,
    FillDirection=Enum.FillDirection.Horizontal,
    Padding=UDim.new(0,8), Parent=btn_holder,
})

local function make_btn(text, color, width_scale, callback)
    local b = new("TextButton",{
        Size=UDim2.new(width_scale,-8,1,0),
        BackgroundColor3=color, BorderSizePixel=0,
        Font=Enum.Font.GothamBold, TextSize=12,
        TextColor3=(color == CFG.accent) and CFG.black or CFG.white,
        Text=text, AutoButtonColor=false,
        ZIndex=4, Parent=btn_holder,
    })
    corner(b,10); grad(b, color, color)
    if color ~= CFG.accent then stroke(b, color, 1, 0.4) end
    b.MouseButton1Click:Connect(function()
        local ok, err = pcall(callback)
        if not ok then warn("[Veil/remote] "..tostring(err)) end
    end)
    return b
end

local rescan_btn, download_btn, copy_btn, close_btn

close_btn = make_btn("Close", CFG.panel, 0.16, function() gui:Destroy() end)
copy_btn  = make_btn("Copy All", CFG.icon_bg, 0.22, function()
    if not setclipboard then notify("Veil", "No clipboard", 3); return end
    local content = _G._veil_dump_content or ""
    if #content == 0 then notify("Veil", "Nothing to copy", 3); return end
    setclipboard(content)
    copy_btn.Text = "✓ Copied"
    task.delay(1.4, function() copy_btn.Text = "Copy All" end)
    notify("Veil Remote Dumper", "All remotes copied", 4)
end)
download_btn = make_btn("Download", CFG.accent, 0.30, function()
    if not has_file_api then
        notify("Veil", "No writefile — use Copy All", 5); return
    end
    ensure_dir()
    local content = _G._veil_dump_content or ""
    if #content == 0 then notify("Veil", "Nothing to save", 3); return end
    local path1 = OUTPUT_DIR .. "/" .. OUTPUT_NAME
    local ok = pcall(writefile, path1, content)
    if not ok then
        ok = pcall(writefile, OUTPUT_NAME, content)
        notify("Veil Remote Dumper", ok and ("Saved: " .. OUTPUT_NAME) or "Save failed", 6)
    else
        notify("Veil Remote Dumper", "Saved: " .. path1, 6)
    end
    download_btn.Text = "✓ Saved"
    task.delay(1.8, function() download_btn.Text = "Download" end)
end)
rescan_btn = make_btn("Re-scan", CFG.blue, 0.28, function()
    local before = #(_G._veil_remotes or {})
    scan_game(_G._veil_remotes)
    scan_registry(_G._veil_remotes)
    local after = #(_G._veil_remotes or {})
    _G._veil_dump_content = format_results(_G._veil_remotes)
    -- update stats
    local ev, fn, bd = 0, 0, 0
    for _, r in ipairs(_G._veil_remotes) do
        if r.class == "RemoteEvent" or r.class == "UnreliableRemoteEvent" then ev = ev + 1
        elseif r.class == "RemoteFunction" then fn = fn + 1
        elseif r.class == "BindableEvent" or r.class == "BindableFunction" then bd = bd + 1 end
    end
    stat_labels["TOTAL"].Text = tostring(#_G._veil_remotes)
    stat_labels["EVENTS"].Text = tostring(ev)
    stat_labels["FUNCTIONS"].Text = tostring(fn)
    stat_labels["BINDABLES"].Text = tostring(bd)
    refresh_list()
    notify("Veil Remote Dumper", "+"..tostring(after-before).." new · total "..tostring(after), 5)
end)

-- ============================================================
-- INITIAL SCAN (wait for game to settle, then scan + hook)
-- ============================================================
task.spawn(function()
    -- progress pulse
    local pulse = 0
    task.spawn(function()
        while pulse < 100 and stat_labels["TOTAL"] do
            pulse = math.min(pulse + 3, 95)
            stat_labels["TOTAL"].Text = tostring(pulse) .. "%"
            task.wait(0.05)
        end
    end)

    -- wait for the game to finish streaming
    task.wait(3)

    local results = {}
    scan_game(results)
    local reg_added = scan_registry(results)
    start_live_hook(results)

    _G._veil_remotes = results
    _G._veil_dump_content = format_results(results)

    local ev, fn, bd = 0, 0, 0
    for _, r in ipairs(results) do
        if r.class == "RemoteEvent" or r.class == "UnreliableRemoteEvent" then ev = ev + 1
        elseif r.class == "RemoteFunction" then fn = fn + 1
        elseif r.class == "BindableEvent" or r.class == "BindableFunction" then bd = bd + 1 end
    end

    stat_labels["TOTAL"].Text = tostring(#results)
    stat_labels["EVENTS"].Text = tostring(ev)
    stat_labels["FUNCTIONS"].Text = tostring(fn)
    stat_labels["BINDABLES"].Text = tostring(bd)

    refresh_list()
    notify("Veil Remote Dumper",
        string.format("%d remotes · %d from getreg", #results, reg_added), 6)
end)
