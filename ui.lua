--[[
    VeilHub — ui.lua v0.0.1
    Universal UI framework. Final. Never needs editing again.
    API: hub.stat, hub.status, hub.page, hub.select,
         hub.toggle, hub.button, hub.slider, hub.dropdown, hub.textbox
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer
local CAM = workspace.CurrentCamera

local function new(c, p, ch)
    local i = Instance.new(c)
    for k, v in pairs(p or {}) do i[k] = v end
    for _, x in ipairs(ch or {}) do x.Parent = i end
    return i
end

local function corner(p, r)
    return new("UICorner", { CornerRadius = UDim.new(0, r or 8), Parent = p })
end

local function grad(p, c1, c2)
    local g = new("UIGradient", { Parent = p, Rotation = 90 })
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, c1),
        ColorSequenceKeypoint.new(1, c2),
    })
    return g
end

local function stroke(p, c, t, tr)
    return new("UIStroke", {
        Color = c, Thickness = t or 1, Transparency = tr or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = p,
    })
end

local function padding(p, x)
    return new("UIPadding", {
        PaddingTop = UDim.new(0, x), PaddingBottom = UDim.new(0, x),
        PaddingLeft = UDim.new(0, x), PaddingRight = UDim.new(0, x), Parent = p,
    })
end

local function get_parent()
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    local ok, cg = pcall(function() return CoreGui end)
    if ok and cg then
        local ok2 = pcall(function() return cg.Name end)
        if ok2 then return cg end
    end
    return LP:WaitForChild("PlayerGui")
end

local function drag(f, h)
    h = h or f
    local d, s, sp = false, nil, nil
    h.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            d, s, sp = true, i.Position, f.Position
        end
    end)
    h.InputChanged:Connect(function(i)
        if d and (i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch) then
            local m = i.Position - s
            f.Position = UDim2.new(sp.X.Scale, sp.X.Offset + m.X, sp.Y.Scale, sp.Y.Offset + m.Y)
        end
    end)
    h.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then d = false end
    end)
end

local function scale_for(w, h)
    local vp = CAM and CAM.ViewportSize or Vector2.new(1280, 720)
    return math.clamp(math.min((vp.X * 0.94) / w, (vp.Y * 0.86) / h), 0.55, 1.0)
end

local UI = {}

function UI.new(CFG, ICON)
    ICON = ICON or {}
    local hub = {}

    local parent = get_parent()
    local old = parent:FindFirstChild("VeilHub")
    if old then old:Destroy() end

    local gui = new("ScreenGui", {
        Name = "VeilHub", ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
        DisplayOrder = 999999, Parent = parent,
    })
    pcall(function() gui.ClipToDeviceSafeArea = false end)
    hub.gui = gui

    local W, H = 640, 500

    local main = new("Frame", {
        Name = "Main", Size = UDim2.fromOffset(W, H),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = CFG.bg, BorderSizePixel = 0, ZIndex = 1, Parent = gui,
    })
    corner(main, 16)
    grad(main, CFG.bg2, CFG.bg)
    stroke(main, Color3.fromRGB(40, 40, 55), 1, 0.3)
    hub.main = main

    local us = new("UIScale", { Scale = 1, Parent = main })
    local function apply() us.Scale = scale_for(W, H) end
    apply()
    if CAM then CAM:GetPropertyChangedSignal("ViewportSize"):Connect(apply) end

    -- titlebar
    local tb = new("Frame", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = CFG.sidebar, BorderSizePixel = 0,
        ZIndex = 2, Parent = main,
    })
    corner(tb, 16)
    grad(tb, CFG.bg2, CFG.sidebar)
    new("Frame", {
        Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -16),
        BackgroundColor3 = CFG.sidebar, BorderSizePixel = 0,
        ZIndex = 2, Parent = tb,
    })
    local dot = new("Frame", {
        Size = UDim2.fromOffset(8, 8), Position = UDim2.new(0, 16, 0.5, -4),
        BackgroundColor3 = CFG.accent, BorderSizePixel = 0,
        ZIndex = 4, Parent = tb,
    })
    corner(dot, 4)
    grad(dot, CFG.accent2, CFG.accent_dark)
    new("TextLabel", {
        Size = UDim2.new(1, -120, 1, 0), Position = UDim2.new(0, 32, 0, 0),
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14,
        TextColor3 = CFG.text, TextXAlignment = Enum.TextXAlignment.Left,
        Text = CFG.title, ZIndex = 4, Parent = tb,
    })
    new("TextLabel", {
        Size = UDim2.new(0, 80, 1, 0), Position = UDim2.new(0, 110, 0, 0),
        BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 10,
        TextColor3 = CFG.subtext, TextXAlignment = Enum.TextXAlignment.Left,
        Text = "v" .. CFG.version, ZIndex = 4, Parent = tb,
    })
    local xb = new("TextButton", {
        Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -36, 0.5, -13),
        BackgroundColor3 = Color3.fromRGB(40, 20, 25), BorderSizePixel = 0,
        Font = Enum.Font.GothamBold, TextSize = 14,
        TextColor3 = CFG.danger, Text = "×", AutoButtonColor = false,
        ZIndex = 4, Parent = tb,
    })
    corner(xb, 8)
    xb.MouseButton1Click:Connect(function() gui.Enabled = false end)
    drag(main, tb)

    -- sidebar
    local SW = 148
    local side = new("Frame", {
        Size = UDim2.new(0, SW, 1, -42), Position = UDim2.new(0, 0, 0, 42),
        BackgroundColor3 = CFG.sidebar, BorderSizePixel = 0,
        ZIndex = 2, Parent = main,
    })
    corner(side, 16)
    new("Frame", {
        Size = UDim2.new(0, 16, 1, 0), Position = UDim2.new(1, -16, 0, 0),
        BackgroundColor3 = CFG.sidebar, BorderSizePixel = 0,
        ZIndex = 2, Parent = side,
    })
    local sl = new("Frame", {
        Size = UDim2.new(1, -14, 1, -16), Position = UDim2.new(0, 7, 0, 8),
        BackgroundTransparency = 1, ZIndex = 3, Parent = side,
    })
    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 5), Parent = sl,
    })

    local content = new("Frame", {
        Size = UDim2.new(1, -(SW + 18), 1, -42 - 16),
        Position = UDim2.new(0, SW + 10, 0, 42 + 8),
        BackgroundTransparency = 1, ZIndex = 3, Parent = main,
    })

    local pages = {}

    local function select_page(name)
        for pn, p in pairs(pages) do
            local on = (pn == name)
            p.frame.Visible = on
            p.bar.Visible = on
            p.btn.TextColor3 = on and CFG.text or CFG.subtext
            p.btn.Font = on and Enum.Font.GothamBold or Enum.Font.GothamMedium
            p.icon.ImageColor3 = on and CFG.accent or CFG.subtext
            p.ih.BackgroundColor3 = on and Color3.fromRGB(60, 50, 15) or CFG.icon_bg
        end
    end

    local function make_page(name, icon_id)
        local row = new("Frame", {
            Size = UDim2.new(1, 0, 0, 38),
            BackgroundColor3 = CFG.card_top, BorderSizePixel = 0,
            ZIndex = 4, Parent = sl,
        })
        corner(row, 10)
        grad(row, CFG.card_top, CFG.card_bot)
        local bar = new("Frame", {
            Size = UDim2.new(0, 3, 0.55, 0), Position = UDim2.new(0, 0, 0.225, 0),
            BackgroundColor3 = CFG.accent, BorderSizePixel = 0,
            ZIndex = 7, Visible = false, Parent = row,
        })
        corner(bar, 2)
        grad(bar, CFG.accent2, CFG.accent_dark)
        local ih = new("Frame", {
            Size = UDim2.fromOffset(24, 24), Position = UDim2.new(0, 12, 0.5, -12),
            BackgroundColor3 = CFG.icon_bg, BorderSizePixel = 0,
            ZIndex = 6, Parent = row,
        })
        corner(ih, 7)
        local icon = new("ImageLabel", {
            Size = UDim2.fromOffset(14, 14), Position = UDim2.new(0.5, -7, 0.5, -7),
            BackgroundTransparency = 1, Image = icon_id or ICON.home,
            ImageColor3 = CFG.subtext, ZIndex = 7, Parent = ih,
        })
        local btn = new("TextButton", {
            Size = UDim2.new(1, -50, 1, 0), Position = UDim2.new(0, 44, 0, 0),
            BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12,
            TextColor3 = CFG.subtext, TextXAlignment = Enum.TextXAlignment.Left,
            Text = name, AutoButtonColor = false, ZIndex = 6, Parent = row,
        })
        local frame = new("Frame", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            ZIndex = 4, Visible = false, Parent = content,
        })
        pages[name] = { row = row, bar = bar, btn = btn, icon = icon, frame = frame, ih = ih }
        btn.MouseButton1Click:Connect(function() select_page(name) end)
        return frame
    end

    -- home
    local home = make_page("Home", ICON.home)
    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = CFG.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Dashboard", ZIndex = 5, Parent = home,
    })

    local stat_labels = {}
    local function make_card(label, key, x, y)
        local c = new("Frame", {
            Size = UDim2.fromOffset(212, 58), Position = UDim2.fromOffset(x, y),
            BackgroundColor3 = CFG.card_top, BorderSizePixel = 0,
            ZIndex = 5, Parent = home,
        })
        corner(c, 12)
        grad(c, CFG.card_top, CFG.card_bot)
        stroke(c, Color3.fromRGB(45, 45, 60), 1, 0.5)
        padding(c, 10)
        new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 13), BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium, TextSize = 10, TextColor3 = CFG.dim,
            TextXAlignment = Enum.TextXAlignment.Left, Text = label, ZIndex = 6, Parent = c,
        })
        local v = new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0, 20),
            BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13,
            TextColor3 = CFG.text, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, Text = "—",
            ZIndex = 6, Parent = c,
        })
        stat_labels[key] = v
    end
    make_card("PLAYER", "player", 0, 30)
    make_card("PLACE ID", "place", 220, 30)
    make_card("SESSION TIME", "time", 0, 96)
    make_card("PERFORMANCE", "perf", 220, 96)

    -- discord
    local dd = new("Frame", {
        Size = UDim2.new(1, 0, 0, 38), Position = UDim2.new(0, 0, 0, 164),
        BackgroundColor3 = CFG.card_top, BorderSizePixel = 0,
        ClipsDescendants = true, ZIndex = 6, Parent = home,
    })
    corner(dd, 12)
    grad(dd, CFG.card_top, CFG.card_bot)
    stroke(dd, Color3.fromRGB(45, 45, 60), 1, 0.5)
    local dh = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = CFG.accent,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "   Discord   ▸", AutoButtonColor = false, ZIndex = 7, Parent = dd,
    })
    local db = new("Frame", {
        Size = UDim2.new(1, -16, 0, 86), Position = UDim2.new(0, 8, 0, 40),
        BackgroundTransparency = 1, ZIndex = 7, Parent = dd,
    })
    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1,
        Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = CFG.subtext,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Join for updates and support.", ZIndex = 8, Parent = db,
    })
    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 0, 16),
        BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 11,
        TextColor3 = CFG.accent, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = CFG.discord, ZIndex = 8, Parent = db,
    })
    local copy_btn = new("TextButton", {
        Size = UDim2.fromOffset(106, 28), Position = UDim2.new(0, 0, 0, 46),
        BackgroundColor3 = CFG.accent, BorderSizePixel = 0,
        Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = CFG.black, Text = "Copy", AutoButtonColor = false,
        ZIndex = 8, Parent = db,
    })
    corner(copy_btn, 8)
    grad(copy_btn, CFG.accent2, CFG.accent)
    copy_btn.MouseButton1Click:Connect(function()
        if setclipboard then
            setclipboard(CFG.discord)
            copy_btn.Text = "Copied!"
            task.delay(1.2, function() copy_btn.Text = "Copy" end)
        end
    end)
    local open_btn = new("TextButton", {
        Size = UDim2.fromOffset(86, 28), Position = UDim2.new(0, 114, 0, 46),
        BackgroundColor3 = CFG.icon_bg, BorderSizePixel = 0,
        Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = CFG.accent, Text = "Open", AutoButtonColor = false,
        ZIndex = 8, Parent = db,
    })
    corner(open_btn, 8)
    stroke(open_btn, CFG.accent, 1, 0.5)
    open_btn.MouseButton1Click:Connect(function()
        if setclipboard then setclipboard(CFG.discord) end
        if request then pcall(function() request({ Url = CFG.discord, Method = "GET" }) end) end
    end)
    do
        local open = false
        local OH, CH = 38 + 86 + 10, 38
        dh.MouseButton1Click:Connect(function()
            open = not open
            dh.Text = open and "   Discord   ▾" or "   Discord   ▸"
            TweenService:Create(dd,
                TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { Size = UDim2.new(1, 0, 0, open and OH or CH) }
            ):Play()
        end)
    end

    local scan = new("Frame", {
        Size = UDim2.new(1, 0, 0, 50), Position = UDim2.new(0, 0, 0, 210),
        BackgroundColor3 = CFG.card_top, BorderSizePixel = 0,
        ZIndex = 5, Parent = home,
    })
    corner(scan, 12)
    grad(scan, CFG.card_top, CFG.card_bot)
    stroke(scan, Color3.fromRGB(45, 45, 60), 1, 0.5)
    padding(scan, 10)
    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 13), BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium, TextSize = 10, TextColor3 = CFG.dim,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "GAME DETECTION", ZIndex = 6, Parent = scan,
    })
    local status_label = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0, 18),
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13,
        TextColor3 = CFG.text, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = "Scanning...", ZIndex = 6, Parent = scan,
    })

    -- API
    hub.stat = function(key, value)
        local lbl = stat_labels[key]
        if lbl then lbl.Text = tostring(value) end
    end

    hub.status = function(text, color)
        status_label.Text = tostring(text)
        if color then status_label.TextColor3 = color end
    end

    hub.page = function(name, icon_id) return make_page(name, icon_id) end
    hub.select = function(name) select_page(name) end

    local function ensure_scroll(page_frame)
        for _, ch in ipairs(page_frame:GetChildren()) do
            if ch:IsA("ScrollingFrame") then return ch end
        end
        new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = CFG.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = "Scripts", ZIndex = 5, Parent = page_frame,
        })
        local scroll = new("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, -28), Position = UDim2.new(0, 0, 0, 28),
            BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
            ScrollBarImageColor3 = CFG.accent, CanvasSize = UDim2.new(0, 0, 0, 0),
            ZIndex = 5, Parent = page_frame,
        })
        new("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8), Parent = scroll,
        })
        return scroll
    end

    local function bump_canvas(scroll)
        local total = 0
        for _, ch in ipairs(scroll:GetChildren()) do
            if ch:IsA("Frame") then total = total + ch.Size.Y.Offset + 8 end
        end
        scroll.CanvasSize = UDim2.new(0, 0, 0, total + 12)
    end

    -- ============================================================
    -- TOGGLE (premium switch)
    -- ============================================================
    hub.toggle = function(page_frame, label, desc, icon_id, callback)
        local scroll = ensure_scroll(page_frame)
        local row = new("Frame", {
            Size = UDim2.new(1, -6, 0, 58),
            BackgroundColor3 = CFG.card_top, BorderSizePixel = 0,
            ZIndex = 5, Parent = scroll,
        })
        corner(row, 12)
        grad(row, CFG.card_top, CFG.card_bot)
        stroke(row, Color3.fromRGB(45, 45, 60), 1, 0.5)

        local bar = new("Frame", {
            Size = UDim2.new(0, 3, 0.55, 0), Position = UDim2.new(0, 0, 0.225, 0),
            BackgroundColor3 = CFG.accent, BorderSizePixel = 0,
            ZIndex = 7, Visible = false, Parent = row,
        })
        corner(bar, 2)
        grad(bar, CFG.accent2, CFG.accent_dark)

        local ih = new("Frame", {
            Size = UDim2.fromOffset(34, 34), Position = UDim2.new(0, 12, 0.5, -17),
            BackgroundColor3 = CFG.icon_bg, BorderSizePixel = 0,
            ZIndex = 6, Parent = row,
        })
        corner(ih, 10)
        local icon = new("ImageLabel", {
            Size = UDim2.fromOffset(18, 18), Position = UDim2.new(0.5, -9, 0.5, -9),
            BackgroundTransparency = 1, Image = icon_id or ICON.bolt,
            ImageColor3 = CFG.subtext, ZIndex = 7, Parent = ih,
        })

        new("TextLabel", {
            Size = UDim2.new(1, -170, 0, 16),
            Position = UDim2.fromOffset(58, desc and 10 or 21),
            BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
            TextSize = 12, TextColor3 = CFG.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = label, ZIndex = 6, Parent = row,
        })
        if desc then
            new("TextLabel", {
                Size = UDim2.new(1, -170, 0, 14), Position = UDim2.fromOffset(58, 30),
                BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 10,
                TextColor3 = CFG.subtext, TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Text = desc, ZIndex = 6, Parent = row,
            })
        end

        -- PREMIUM SWITCH
        local tw, th = 54, 26
        local ks = 22
        local pad = 2

        local track = new("Frame", {
            Size = UDim2.fromOffset(tw, th),
            Position = UDim2.new(1, -tw - 14, 0.5, -th / 2),
            BackgroundColor3 = Color3.fromRGB(24, 24, 32),
            BorderSizePixel = 0,
            ZIndex = 6, Parent = row,
        })
        corner(track, th / 2)

        local track_grad = grad(track, CFG.accent2, CFG.accent)
        track_grad.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 1),
        })

        local track_glow = stroke(track, CFG.accent, 1.5, 1)

        local knob = new("Frame", {
            Size = UDim2.fromOffset(ks, ks),
            Position = UDim2.new(0, pad, 0.5, -ks / 2),
            BackgroundColor3 = Color3.fromRGB(70, 70, 85),
            BorderSizePixel = 0,
            ZIndex = 7, Parent = track,
        })
        corner(knob, ks / 2)
        stroke(knob, Color3.fromRGB(0, 0, 0), 1, 0.7)

        local click = new("TextButton", {
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
            Text = "", AutoButtonColor = false, ZIndex = 8, Parent = row,
        })

        local is_on = false

        local function apply_state(on)
            TweenService:Create(track,
                TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { BackgroundColor3 = on and CFG.accent or Color3.fromRGB(24, 24, 32) }
            ):Play()

            TweenService:Create(track_grad,
                TweenInfo.new(0.24),
                {
                    Transparency = on
                        and NumberSequence.new({
                            NumberSequenceKeypoint.new(0, 0.05),
                            NumberSequenceKeypoint.new(1, 0.15),
                        })
                        or NumberSequence.new({
                            NumberSequenceKeypoint.new(0, 1),
                            NumberSequenceKeypoint.new(1, 1),
                        }),
                }
            ):Play()

            TweenService:Create(track_glow,
                TweenInfo.new(0.24),
                { Transparency = on and 0.15 or 1 }
            ):Play()

            TweenService:Create(knob,
                TweenInfo.new(0.24),
                { BackgroundColor3 = on and CFG.white or Color3.fromRGB(70, 70, 85) }
            ):Play()

            TweenService:Create(icon,
                TweenInfo.new(0.24),
                { ImageColor3 = on and CFG.accent or CFG.subtext }
            ):Play()

            TweenService:Create(ih,
                TweenInfo.new(0.24),
                { BackgroundColor3 = on and Color3.fromRGB(60, 50, 15) or CFG.icon_bg }
            ):Play()

            bar.Visible = on
        end

        click.MouseButton1Click:Connect(function()
            is_on = not is_on

            local target_pos = is_on
                and UDim2.new(1, -ks - pad, 0.5, -ks / 2)
                or  UDim2.new(0, pad, 0.5, -ks / 2)

            TweenService:Create(knob,
                TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                { Position = target_pos }
            ):Play()

            apply_state(is_on)

            if callback then
                local ok, err = pcall(callback, is_on)
                if not ok then warn("[Veil/ui] toggle error: " .. tostring(err)) end
            end
        end)

        bump_canvas(scroll)
        return row
    end

    -- ============================================================
    -- BUTTON
    -- ============================================================
    hub.button = function(page_frame, label, desc, icon_id, callback)
        local scroll = ensure_scroll(page_frame)
        local row = new("Frame", {
            Size = UDim2.new(1, -6, 0, 58),
            BackgroundColor3 = CFG.card_top, BorderSizePixel = 0,
            ZIndex = 5, Parent = scroll,
        })
        corner(row, 12)
        grad(row, CFG.card_top, CFG.card_bot)
        stroke(row, Color3.fromRGB(45, 45, 60), 1, 0.5)
        local ih = new("Frame", {
            Size = UDim2.fromOffset(34, 34), Position = UDim2.new(0, 12, 0.5, -17),
            BackgroundColor3 = CFG.icon_bg, BorderSizePixel = 0,
            ZIndex = 6, Parent = row,
        })
        corner(ih, 10)
        new("ImageLabel", {
            Size = UDim2.fromOffset(18, 18), Position = UDim2.new(0.5, -9, 0.5, -9),
            BackgroundTransparency = 1, Image = icon_id or ICON.tp,
            ImageColor3 = CFG.subtext, ZIndex = 7, Parent = ih,
        })
        new("TextLabel", {
            Size = UDim2.new(1, -150, 0, 16),
            Position = UDim2.fromOffset(58, desc and 10 or 21),
            BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
            TextSize = 12, TextColor3 = CFG.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = label, ZIndex = 6, Parent = row,
        })
        if desc then
            new("TextLabel", {
                Size = UDim2.new(1, -150, 0, 14), Position = UDim2.fromOffset(58, 30),
                BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 10,
                TextColor3 = CFG.subtext, TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Text = desc, ZIndex = 6, Parent = row,
            })
        end
        local btn = new("TextButton", {
            Size = UDim2.fromOffset(72, 30),
            Position = UDim2.new(1, -84, 0.5, -15),
            BackgroundColor3 = CFG.accent, BorderSizePixel = 0,
            Font = Enum.Font.GothamBold, TextSize = 11,
            TextColor3 = CFG.black, Text = "Run", AutoButtonColor = false,
            ZIndex = 6, Parent = row,
        })
        corner(btn, 10)
        grad(btn, CFG.accent2, CFG.accent)
        stroke(btn, CFG.accent, 1, 0.4)
        btn.MouseButton1Click:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.08),
                { Size = UDim2.fromOffset(66, 26) }):Play()
            task.delay(0.09, function()
                TweenService:Create(btn, TweenInfo.new(0.12),
                    { Size = UDim2.fromOffset(72, 30) }):Play()
            end)
            if callback then
                local ok, err = pcall(callback)
                if not ok then warn("[Veil/ui] button error: " .. tostring(err)) end
            end
        end)
        bump_canvas(scroll)
        return row
    end

    -- ============================================================
    -- SLIDER
    -- ============================================================
    hub.slider = function(page_frame, label, desc, min_val, max_val, default_val, icon_id, callback)
        local scroll = ensure_scroll(page_frame)
        local row = new("Frame", {
            Size = UDim2.new(1, -6, 0, 70),
            BackgroundColor3 = CFG.card_top, BorderSizePixel = 0,
            ZIndex = 5, Parent = scroll,
        })
        corner(row, 12)
        grad(row, CFG.card_top, CFG.card_bot)
        stroke(row, Color3.fromRGB(45, 45, 60), 1, 0.5)
        local ih = new("Frame", {
            Size = UDim2.fromOffset(34, 34), Position = UDim2.new(0, 12, 0, 12),
            BackgroundColor3 = CFG.icon_bg, BorderSizePixel = 0,
            ZIndex = 6, Parent = row,
        })
        corner(ih, 10)
        new("ImageLabel", {
            Size = UDim2.fromOffset(18, 18), Position = UDim2.new(0.5, -9, 0.5, -9),
            BackgroundTransparency = 1, Image = icon_id or ICON.run,
            ImageColor3 = CFG.subtext, ZIndex = 7, Parent = ih,
        })
        new("TextLabel", {
            Size = UDim2.new(1, -180, 0, 16), Position = UDim2.fromOffset(58, 10),
            BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
            TextSize = 12, TextColor3 = CFG.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = label, ZIndex = 6, Parent = row,
        })
        if desc then
            new("TextLabel", {
                Size = UDim2.new(1, -180, 0, 14), Position = UDim2.fromOffset(58, 28),
                BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 10,
                TextColor3 = CFG.subtext, TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Text = desc, ZIndex = 6, Parent = row,
            })
        end
        local value_label = new("TextLabel", {
            Size = UDim2.fromOffset(50, 20),
            Position = UDim2.new(1, -60, 0, 10),
            BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
            TextSize = 13, TextColor3 = CFG.accent,
            TextXAlignment = Enum.TextXAlignment.Right,
            Text = tostring(default_val), ZIndex = 6, Parent = row,
        })
        local track_w = 200
        local track = new("Frame", {
            Size = UDim2.fromOffset(track_w, 8),
            Position = UDim2.new(1, -track_w - 14, 0, 46),
            BackgroundColor3 = Color3.fromRGB(50, 50, 62),
            BorderSizePixel = 0,
            ZIndex = 6, Parent = row,
        })
        corner(track, 4)
        local fill = new("Frame", {
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = CFG.accent, BorderSizePixel = 0,
            ZIndex = 7, Parent = track,
        })
        corner(fill, 4)
        grad(fill, CFG.accent2, CFG.accent)
        local ks = 16
        local knob = new("Frame", {
            Size = UDim2.fromOffset(ks, ks),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            BackgroundColor3 = CFG.white, BorderSizePixel = 0,
            ZIndex = 8, Parent = track,
        })
        corner(knob, ks / 2)
        stroke(knob, CFG.accent, 1, 0.4)
        local init_pct = math.clamp((default_val - min_val) / (max_val - min_val), 0, 1)
        fill.Size = UDim2.new(init_pct, 0, 1, 0)
        knob.Position = UDim2.new(init_pct, 0, 0.5, 0)
        local function set_value(pct)
            pct = math.clamp(pct, 0, 1)
            local val = math.floor(min_val + (max_val - min_val) * pct + 0.5)
            fill.Size = UDim2.new(pct, 0, 1, 0)
            knob.Position = UDim2.new(pct, 0, 0.5, 0)
            value_label.Text = tostring(val)
            if callback then
                local ok, err = pcall(callback, val)
                if not ok then warn("[Veil/ui] slider error: " .. tostring(err)) end
            end
        end
        local click = new("TextButton", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1, Text = "",
            AutoButtonColor = false, ZIndex = 9, Parent = row,
        })
        local dragging = false
        click.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                local rel = (i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
                set_value(rel)
            end
        end)
        click.InputChanged:Connect(function(i)
            if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
            or i.UserInputType == Enum.UserInputType.Touch) then
                local rel = (i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
                set_value(rel)
            end
        end)
        click.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        if callback then pcall(callback, default_val) end
        bump_canvas(scroll)
        return { set = set_value, row = row }
    end

    -- ============================================================
    -- DROPDOWN
    -- ============================================================
    hub.dropdown = function(page_frame, label, desc, options, default_val, icon_id, callback)
        local scroll = ensure_scroll(page_frame)
        local row = new("Frame", {
            Size = UDim2.new(1, -6, 0, 62),
            BackgroundColor3 = CFG.card_top, BorderSizePixel = 0,
            ZIndex = 5, Parent = scroll, ClipsDescendants = false,
        })
        corner(row, 12)
        grad(row, CFG.card_top, CFG.card_bot)
        stroke(row, Color3.fromRGB(45, 45, 60), 1, 0.5)

        local ih = new("Frame", {
            Size = UDim2.fromOffset(34, 34), Position = UDim2.new(0, 12, 0.5, -17),
            BackgroundColor3 = CFG.icon_bg, BorderSizePixel = 0,
            ZIndex = 6, Parent = row,
        })
        corner(ih, 10)
        new("ImageLabel", {
            Size = UDim2.fromOffset(18, 18), Position = UDim2.new(0.5, -9, 0.5, -9),
            BackgroundTransparency = 1, Image = icon_id or ICON.esp,
            ImageColor3 = CFG.subtext, ZIndex = 7, Parent = ih,
        })

        new("TextLabel", {
            Size = UDim2.new(1, -180, 0, 16), Position = UDim2.fromOffset(58, 10),
            BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
            TextSize = 12, TextColor3 = CFG.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = label, ZIndex = 6, Parent = row,
        })
        if desc then
            new("TextLabel", {
                Size = UDim2.new(1, -180, 0, 14), Position = UDim2.fromOffset(58, 28),
                BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 10,
                TextColor3 = CFG.subtext, TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Text = desc, ZIndex = 6, Parent = row,
            })
        end

        local value_btn = new("TextButton", {
            Size = UDim2.fromOffset(130, 28),
            Position = UDim2.new(1, -142, 0.5, -14),
            BackgroundColor3 = CFG.icon_bg, BorderSizePixel = 0,
            Font = Enum.Font.GothamMedium, TextSize = 11,
            TextColor3 = CFG.accent, Text = (default_val or options[1] or "—") .. "  ▾",
            AutoButtonColor = false,
            ZIndex = 6, Parent = row,
        })
        corner(value_btn, 6)
        stroke(value_btn, CFG.accent, 1, 0.7)

        local selected = default_val or options[1]

        local list_h = math.min(#options * 26 + 8, 200)
        local list = new("Frame", {
            Size = UDim2.fromOffset(180, 0),
            Position = UDim2.new(1, -192, 1, 6),
            BackgroundColor3 = CFG.bg2, BorderSizePixel = 0,
            ClipsDescendants = true, Visible = false,
            ZIndex = 100, Parent = row,
        })
        corner(list, 8)
        stroke(list, CFG.accent, 1, 0.4)

        local list_scroll = new("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = CFG.accent,
            CanvasSize = UDim2.new(0, 0, 0, #options * 26 + 8),
            ZIndex = 101, Parent = list,
        })
        new("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 2), Parent = list_scroll,
        })

        local option_btns = {}
        for i, opt in ipairs(options) do
            local opt_btn = new("TextButton", {
                Size = UDim2.new(1, -8, 0, 24),
                Position = UDim2.new(0, 4, 0, 4 + (i - 1) * 26),
                BackgroundColor3 = (opt == selected) and CFG.accent or CFG.card_top,
                BorderSizePixel = 0, Font = Enum.Font.GothamMedium,
                TextSize = 11, TextColor3 = (opt == selected) and CFG.black or CFG.text,
                Text = opt, TextXAlignment = Enum.TextXAlignment.Left,
                AutoButtonColor = false, ZIndex = 102, Parent = list_scroll,
            })
            corner(opt_btn, 5)
            opt_btn.MouseButton1Click:Connect(function()
                selected = opt
                value_btn.Text = opt .. "  ▾"
                for _, ob in ipairs(option_btns) do
                    ob.BackgroundColor3 = CFG.card_top
                    ob.TextColor3 = CFG.text
                end
                opt_btn.BackgroundColor3 = CFG.accent
                opt_btn.TextColor3 = CFG.black
                list.Visible = false
                list.Size = UDim2.fromOffset(180, 0)
                if callback then
                    local ok, err = pcall(callback, opt)
                    if not ok then warn("[Veil/ui] dropdown error: " .. tostring(err)) end
                end
            end)
            table.insert(option_btns, opt_btn)
        end

        local open = false
        value_btn.MouseButton1Click:Connect(function()
            open = not open
            list.Visible = open
            list.Size = open and UDim2.fromOffset(180, list_h) or UDim2.fromOffset(180, 0)
        end)

        if callback then pcall(callback, selected) end
        bump_canvas(scroll)
        return { get = function() return selected end, row = row }
    end

    -- ============================================================
    -- TEXTBOX
    -- ============================================================
    hub.textbox = function(page_frame, label, desc, placeholder, icon_id, callback)
        local scroll = ensure_scroll(page_frame)
        local row = new("Frame", {
            Size = UDim2.new(1, -6, 0, 62),
            BackgroundColor3 = CFG.card_top, BorderSizePixel = 0,
            ZIndex = 5, Parent = scroll,
        })
        corner(row, 12)
        grad(row, CFG.card_top, CFG.card_bot)
        stroke(row, Color3.fromRGB(45, 45, 60), 1, 0.5)

        local ih = new("Frame", {
            Size = UDim2.fromOffset(34, 34), Position = UDim2.new(0, 12, 0.5, -17),
            BackgroundColor3 = CFG.icon_bg, BorderSizePixel = 0,
            ZIndex = 6, Parent = row,
        })
        corner(ih, 10)
        new("ImageLabel", {
            Size = UDim2.fromOffset(18, 18), Position = UDim2.new(0.5, -9, 0.5, -9),
            BackgroundTransparency = 1, Image = icon_id or ICON.tp,
            ImageColor3 = CFG.subtext, ZIndex = 7, Parent = ih,
        })

        new("TextLabel", {
            Size = UDim2.new(1, -180, 0, 16), Position = UDim2.fromOffset(58, 10),
            BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
            TextSize = 12, TextColor3 = CFG.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = label, ZIndex = 6, Parent = row,
        })
        if desc then
            new("TextLabel", {
                Size = UDim2.new(1, -180, 0, 14), Position = UDim2.fromOffset(58, 28),
                BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 10,
                TextColor3 = CFG.subtext, TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Text = desc, ZIndex = 6, Parent = row,
            })
        end

        local box = new("TextBox", {
            Size = UDim2.fromOffset(150, 30),
            Position = UDim2.new(1, -162, 0.5, -15),
            BackgroundColor3 = CFG.icon_bg, BorderSizePixel = 0,
            Font = Enum.Font.Code, TextSize = 11,
            TextColor3 = CFG.text,
            PlaceholderText = placeholder or "type here...",
            PlaceholderColor3 = CFG.dim,
            Text = "", ClearTextOnFocus = false,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 6, Parent = row,
        })
        corner(box, 6)
        stroke(box, CFG.accent, 1, 0.7)
        padding(box, 8)

        box.FocusLost:Connect(function(enter)
            if enter and callback then
                local ok, err = pcall(callback, box.Text)
                if not ok then warn("[Veil/ui] textbox error: " .. tostring(err)) end
            end
        end)

        bump_canvas(scroll)
        return box
    end

    -- V toggle
    local V = 50
    local vbtn = new("TextButton", {
        Size = UDim2.fromOffset(V, V),
        Position = UDim2.new(1, -V - 20, 1, -V - 20),
        BackgroundColor3 = CFG.accent, BorderSizePixel = 0,
        Font = Enum.Font.GothamBlack, TextSize = 24,
        TextColor3 = CFG.black, Text = "V", AutoButtonColor = false,
        ZIndex = 500, Parent = gui,
    })
    corner(vbtn, V / 2)
    grad(vbtn, CFG.accent2, CFG.accent_dark)
    stroke(vbtn, CFG.accent2, 1.5, 0.3)
    do
        local dg, mv, s, sp = false, false, nil, nil
        vbtn.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
                dg, mv, s, sp = true, false, i.Position, vbtn.Position
            end
        end)
        vbtn.InputChanged:Connect(function(i)
            if dg and (i.UserInputType == Enum.UserInputType.MouseMovement
            or i.UserInputType == Enum.UserInputType.Touch) then
                local m = i.Position - s
                if math.abs(m.X) + math.abs(m.Y) > 6 then mv = true end
                vbtn.Position = UDim2.new(
                    sp.X.Scale, sp.X.Offset + m.X,
                    sp.Y.Scale, sp.Y.Offset + m.Y)
            end
        end)
        vbtn.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
                dg = false
                if not mv then main.Visible = not main.Visible end
            end
        end)
    end

    select_page("Home")
    return hub
end

return UI
