--[[
    BEST TWEEN — v1
    Mobile / Delta / universal / self-learning
    Loadstring: loadstring(game:HttpGet("https://raw.githubusercontent.com/supercaptain1233/best-tween/main/besttween.lua"))()
]]

--============ PROTECTION ============
local cloneref = cloneref or function(o) return o end
local typeof = typeof or type

if typeof(setthreadidentity) == "function" then pcall(setthreadidentity, 7) end
if typeof(setidentity) == "function" then pcall(setidentity, 7) end
if typeof(setfpscap) == "function" then pcall(setfpscap, 60) end

local RAW_URL = "https://raw.githubusercontent.com/supercaptain1233/best-tween/main/besttween.lua"
local PATCH_URL = "https://raw.githubusercontent.com/supercaptain1233/best-tween/main/patches/%s.lua"
local FOLDER = "BestTween"
local STORE = FOLDER .. "/saves.json"
local TAG = "BestTween_" .. tostring(math.random(100000, 999999))

if getgenv and getgenv().BestTween and getgenv().BestTween.destroy then
    pcall(getgenv().BestTween.destroy)
end

local bootCount = (getgenv and getgenv().BestTweenBoot or 0) + 1
if getgenv then getgenv().BestTweenBoot = bootCount end

local function boot()

local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local UIS = cloneref(game:GetService("UserInputService"))
local VU = cloneref(game:GetService("VirtualUser"))
local TweenService = cloneref(game:GetService("TweenService"))
local Http = cloneref(game:GetService("HttpService"))
local TPS = cloneref(game:GetService("TeleportService"))
local SG = cloneref(game:GetService("StarterGui"))

local LP = Players.LocalPlayer
if not LP then return end

local SPEED = 1050

--============ FILE ============
local function safeRead(p)
    if typeof(readfile) ~= "function" then return nil end
    local ok, d = pcall(readfile, p)
    if ok and typeof(d) == "string" then return d end
    return nil
end

local function safeWrite(p, d)
    if typeof(writefile) ~= "function" then return false end
    if typeof(makefolder) == "function" then pcall(makefolder, FOLDER) end
    return (pcall(writefile, p, d))
end

--============ STORE / LEARNING ============
local store = {}
do
    local raw = safeRead(STORE)
    if raw then
        local ok, tbl = pcall(function() return Http:JSONDecode(raw) end)
        if ok and typeof(tbl) == "table" then store = tbl end
    end
end

local placeKey = tostring(game.PlaceId)
store[placeKey] = store[placeKey] or { saves = {}, picked = 0, learn = {}, trips = 0 }
local data = store[placeKey]
data.learn = data.learn or {}

local function persist()
    pcall(function() safeWrite(STORE, Http:JSONEncode(store)) end)
end

local function packCF(cf)
    return {
        x = cf.X, y = cf.Y, z = cf.Z,
        lx = cf.LookVector.X, ly = cf.LookVector.Y, lz = cf.LookVector.Z,
    }
end

local function unpackCF(t)
    local p = Vector3.new(t.x, t.y, t.z)
    local l = Vector3.new(t.lx, t.ly, t.lz)
    return CFrame.lookAt(p, p + l)
end

local function learnUp(style)
    data.learn[style] = (data.learn[style] or 0) + 1
    data.trips = (data.trips or 0) + 1
    persist()
end

--============ ANTI-AFK / ANTI-KICK ============
local conns = {}
local function track(c) conns[#conns + 1] = c return c end

pcall(function()
    track(LP.Idled:Connect(function()
        pcall(function()
            VU:CaptureController()
            VU:ClickButton2(Vector2.new())
        end)
    end))
end)

pcall(function()
    if typeof(queue_on_teleport) == "function" then
        queue_on_teleport(string.format(
            'pcall(function() loadstring(game:HttpGet("%s"))() end)', RAW_URL))
    elseif typeof(syn) == "table" and typeof(syn.queue_on_teleport) == "function" then
        pcall(syn.queue_on_teleport, string.format(
            'pcall(function() loadstring(game:HttpGet("%s"))() end)', RAW_URL))
    end
end)

pcall(function()
    track(LP.OnTeleport:Connect(function(s)
        if s == Enum.TeleportState.Failed then
            pcall(function() TPS:Teleport(game.PlaceId, LP) end)
        end
    end))
end)

pcall(function() SG:SetCore("ResetButtonCallback", true) end)

--============ COLLISION / NOCLIP ============
local noclipOn = false
local noclipConns = {}
local forced = setmetatable({}, { __mode = "k" })
local baseSpeed = nil

local function forcePart(part)
    if noclipOn then return end
    if not part:IsA("BasePart") then return end
    if forced[part] then
        if not part.CanCollide then
            forced[part] = nil
            pcall(function() part.CanCollide = true end)
            forced[part] = true
        end
        return
    end
    forced[part] = true
    pcall(function() part.CanCollide = true end)
end

local function installCollision(char)
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do forcePart(d) end
    track(char.DescendantAdded:Connect(function(d)
        task.defer(function() forcePart(d) end)
    end))
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") then
            track(d:GetPropertyChangedSignal("CanCollide"):Connect(function()
                if not noclipOn and not d.CanCollide then
                    pcall(function() d.CanCollide = true end)
                end
            end))
        end
    end
end

-- beat the game's own writes: every part gets its own guard
local function noclipHooks(on)
    if on then
        local char = LP.Character
        if not char then return end
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") then
                noclipConns[#noclipConns + 1] =
                    d:GetPropertyChangedSignal("CanCollide"):Connect(function()
                        if noclipOn and d.CanCollide then
                            pcall(function() d.CanCollide = false end)
                        end
                    end)
            end
        end
    else
        for _, c in ipairs(noclipConns) do pcall(function() c:Disconnect() end) end
        noclipConns = {}
    end
end

local function setNoclip(on)
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if on then
        noclipOn = true
        if hum then
            baseSpeed = hum.WalkSpeed
            pcall(function()
                hum.PlatformStand = true
                hum.WalkSpeed = 0
                hum:ChangeState(Enum.HumanoidStateType.Physics)
            end)
        end
        noclipHooks(true)
        if char then
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("BasePart") then pcall(function() d.CanCollide = false end) end
            end
        end
    else
        noclipOn = false
        noclipHooks(false)
        if char then
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("BasePart") then pcall(function() d.CanCollide = true end) end
            end
        end
        if hum then
            pcall(function()
                hum.PlatformStand = false
                if baseSpeed then hum.WalkSpeed = baseSpeed end
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end)
        end
    end
end

installCollision(LP.Character)
track(LP.CharacterAdded:Connect(function(c)
    installCollision(c)
    c:WaitForChild("HumanoidRootPart", 10)
end))

track(RunService.Heartbeat:Connect(function()
    local char = LP.Character
    if not char then return end
    if noclipOn then
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") and d.CanCollide then
                pcall(function() d.CanCollide = false end)
            end
        end
        return
    end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp and not hrp.CanCollide then
        pcall(function() hrp.CanCollide = true end)
    end
end))

--============ STATE ============
local busy = false
local token = 0
local bannerBusy = false

local function hrpOf()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function alive()
    local c = LP.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0 and hrpOf() ~= nil
end

--============ GUI ============
local gui = Instance.new("ScreenGui")
gui.Name = TAG
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 9999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
if typeof(protectgui) == "function" then pcall(protectgui, gui) end
if typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
    pcall(syn.protect_gui, gui)
end

local parented = false
if typeof(gethui) == "function" then
    local ok, h = pcall(gethui)
    if ok and h then gui.Parent = h parented = true end
end
if not parented then
    local ok = pcall(function() gui.Parent = cloneref(game:GetService("CoreGui")) end)
    if not ok then gui.Parent = LP:WaitForChild("PlayerGui") end
end

local main = Instance.new("Frame")
main.Name = TAG .. "_main"
main.Size = UDim2.fromOffset(250, 352)
main.Position = UDim2.new(0, 22, 0.5, -176)
main.BackgroundColor3 = Color3.fromRGB(15, 16, 20)
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui

local uiscale = Instance.new("UIScale")
uiscale.Parent = main

local function refreshScale()
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
    uiscale.Scale = math.clamp(math.min(vp.X, vp.Y) / 420, 0.70, 1.05)
end
refreshScale()
track((function()
    local c = workspace.CurrentCamera
    if not c then return Instance.new("BindableEvent").Event end
    return c:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScale)
end)())

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(56, 58, 70)
stroke.Thickness = 1.5
stroke.Parent = main

local bar = Instance.new("Frame")
bar.Size = UDim2.new(1, 0, 0, 26)
bar.BackgroundTransparency = 1
bar.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -128, 1, 0)
title.Position = UDim2.fromOffset(9, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "BEST TWEEN"
title.TextSize = 13
title.TextColor3 = Color3.fromRGB(140, 205, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = bar

local function topButton(xOffset, w)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(w, 21)
    b.Position = UDim2.new(1, xOffset, 0, 3)
    b.BackgroundColor3 = Color3.fromRGB(34, 36, 44)
    b.TextColor3 = Color3.fromRGB(220, 220, 230)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.AutoButtonColor = true
    b.Parent = bar
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 5)
    c.Parent = b
    return b
end

local moveBtn = topButton(-94, 30)
moveBtn.TextSize = 9
moveBtn.Text = " ↑ \n← →\n ↓ "
moveBtn.TextYAlignment = Enum.TextYAlignment.Center
local shrinkBtn = topButton(-62, 30)
shrinkBtn.Text = "▽"
shrinkBtn.TextSize = 10
local closeBtn = topButton(-28, 24)
closeBtn.Text = "✕"

local dragging, dragStart, startPos
moveBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
track(UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end))

local function bigButton(text, y, h, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(110, h)
    b.Position = UDim2.new(0.5, -55, 0, y)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.fromRGB(238, 238, 244)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Parent = main
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 7)
    c.Parent = b
    return b
end

local playBtn = bigButton("PLAY", 31, 26, Color3.fromRGB(38, 120, 76))
local saveBtn = bigButton("SAVE", 61, 26, Color3.fromRGB(40, 52, 78))
local clearAllBtn = bigButton("CLEAR ALL", 91, 22, Color3.fromRGB(60, 40, 44))
clearAllBtn.TextSize = 11

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.new(0, 10, 0, 120)
list.Size = UDim2.new(1, -20, 1, -130)
list.BackgroundColor3 = Color3.fromRGB(22, 23, 29)
list.BorderSizePixel = 0
list.ScrollBarThickness = 4
list.ScrollingDirection = Enum.ScrollingDirection.Y
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.ElasticBehavior = Enum.ElasticBehavior.Always
list.Parent = main

local lc = Instance.new("UICorner")
lc.CornerRadius = UDim.new(0, 8)
lc.Parent = list

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 6)
pad.PaddingLeft = UDim.new(0, 6)
pad.PaddingRight = UDim.new(0, 6)
pad.PaddingBottom = UDim.new(0, 6)
pad.Parent = list

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

--============ MINI ============
local mini = Instance.new("TextButton")
mini.Size = UDim2.fromOffset(58, 58)
mini.BackgroundColor3 = Color3.fromRGB(18, 38, 56)
mini.Text = "best\ntween"
mini.TextWrapped = true
mini.TextColor3 = Color3.fromRGB(150, 215, 255)
mini.Font = Enum.Font.GothamBold
mini.TextSize = 10
mini.Visible = false
mini.AutoButtonColor = true
mini.Parent = gui
local mc = Instance.new("UICorner")
mc.CornerRadius = UDim.new(1, 0)
mc.Parent = mini
local ms = Instance.new("UIStroke")
ms.Color = Color3.fromRGB(90, 160, 220)
ms.Thickness = 2
ms.Parent = mini

shrinkBtn.Activated:Connect(function()
    mini.Position = main.Position
    main.Visible = false
    mini.Visible = true
end)

mini.Activated:Connect(function()
    mini.Visible = false
    main.Visible = true
end)

--============ LIST ============
local rows = {}

local function rebuild()
    for _, r in ipairs(rows) do
        if r.parent then pcall(function() r.parent:Destroy() end) end
    end
    rows = {}

    for i, _ in ipairs(data.saves) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -4, 0, 26)
        row.BackgroundColor3 = Color3.fromRGB(31, 33, 41)
        row.BorderSizePixel = 0
        row.LayoutOrder = i
        row.Parent = list
        local rc = Instance.new("UICorner")
        rc.CornerRadius = UDim.new(0, 6)
        rc.Parent = row

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -98, 1, 0)
        label.Position = UDim2.fromOffset(8, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamMedium
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = "Save " .. i
        label.Parent = row

        local pick = Instance.new("TextButton")
        pick.Size = UDim2.fromOffset(42, 19)
        pick.Position = UDim2.new(1, -90, 0, 3)
        pick.Text = "PICK"
        pick.Font = Enum.Font.GothamBold
        pick.TextSize = 10
        pick.Parent = row
        local pc = Instance.new("UICorner")
        pc.CornerRadius = UDim.new(0, 5)
        pc.Parent = pick

        local clr = Instance.new("TextButton")
        clr.Size = UDim2.fromOffset(42, 19)
        clr.Position = UDim2.new(1, -45, 0, 3)
        clr.BackgroundColor3 = Color3.fromRGB(64, 42, 46)
        clr.TextColor3 = Color3.fromRGB(240, 200, 200)
        clr.Text = "CLEAR"
        clr.Font = Enum.Font.GothamBold
        clr.TextSize = 10
        clr.Parent = row
        local cc = Instance.new("UICorner")
        cc.CornerRadius = UDim.new(0, 5)
        cc.Parent = clr

        local picked = (data.picked == i)
        pick.BackgroundColor3 = picked and Color3.fromRGB(38, 130, 78) or Color3.fromRGB(46, 48, 58)
        pick.TextColor3 = picked and Color3.fromRGB(200, 255, 220) or Color3.fromRGB(180, 182, 192)
        label.TextColor3 = picked and Color3.fromRGB(140, 235, 180) or Color3.fromRGB(210, 212, 220)

        pick.Activated:Connect(function()
            data.picked = (data.picked == i) and 0 or i
            persist()
            rebuild()
        end)

        clr.Activated:Connect(function()
            table.remove(data.saves, i)
            if data.picked == i then
                data.picked = 0
            elseif data.picked > i then
                data.picked = data.picked - 1
            end
            persist()
            rebuild()
        end)

        rows[#rows + 1] = { parent = row }
    end

    if #data.saves == 1 and data.picked == 0 then
        data.picked = 1
        persist()
        rebuild()
        return
    end

    if data.picked > #data.saves then data.picked = 0 end
end

saveBtn.Activated:Connect(function()
    local hrp = hrpOf()
    if not hrp then return end
    data.saves[#data.saves + 1] = packCF(hrp.CFrame)
    if #data.saves == 1 then data.picked = 1 end
    persist()
    rebuild()
    task.defer(function()
        pcall(function() list.CanvasPosition = Vector2.new(0, list.AbsoluteCanvasSize.Y) end)
    end)
end)

clearAllBtn.Activated:Connect(function()
    data.saves = {}
    data.picked = 0
    persist()
    rebuild()
end)

--============ ROUTE ============
local function canSee(a, b)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LP.Character }
    params.IgnoreWater = true
    return workspace:Raycast(a, b - a, params) == nil
end

local function findHole(from, to)
    local dir = to - from
    local dist = dir.Magnitude
    local flat = Vector3.new(dir.X, 0, dir.Z)
    if flat.Magnitude < 1 then flat = Vector3.new(1, 0, 0) end
    flat = flat.Unit
    local side = Vector3.new(-flat.Z, 0, flat.X)

    local best, bestCost = nil, math.huge
    for _, t in ipairs({ 0.3, 0.5, 0.7 }) do
        local base = from + dir * t
        local cands = {}
        for _, r in ipairs({ 6, 12, 20, 30, 44, 60 }) do
            cands[#cands + 1] = base + side * r
            cands[#cands + 1] = base - side * r
        end
        for _, h in ipairs({ -5, 6, 14, 24, 38, 55 }) do
            cands[#cands + 1] = base + Vector3.new(0, h, 0)
        end
        for _, c in ipairs(cands) do
            if canSee(from, c) and canSee(c, to) then
                local cost = (c - from).Magnitude + (c - to).Magnitude
                if cost < bestCost then best, bestCost = c, cost end
            end
        end
    end
    return best
end

local function findSide(from, to)
    local dir = to - from
    local dist = dir.Magnitude
    local flat = Vector3.new(dir.X, 0, dir.Z)
    if flat.Magnitude < 1 then flat = Vector3.new(1, 0, 0) end
    flat = flat.Unit
    local side = Vector3.new(-flat.Z, 0, flat.X)
    for _, off in ipairs({ 9, 18, 30, 48, 70, 95 }) do
        for _, s in ipairs({ 1, -1 }) do
            local mid = from + flat * (dist * 0.5) + side * (off * s) + Vector3.new(0, 4, 0)
            if canSee(from, mid) and canSee(mid, to) then
                return mid
            end
        end
    end
    return nil
end

local function findClimb(from, to)
    local h = 16
    for _ = 1, 4 do
        local u1 = from + Vector3.new(0, h, 0)
        local u2 = to + Vector3.new(0, h, 0)
        if canSee(from, u1) and canSee(u1, u2) and canSee(u2, to) then
            return { u1, u2 }
        end
        h = h * 1.9
    end
    return nil
end

-- order strategies by what has worked here before
local function routeFor(from, to)
    local order = { "direct", "hole", "side", "climb" }
    table.sort(order, function(a, b)
        return (data.learn[a] or 0) > (data.learn[b] or 0)
    end)

    for _, style in ipairs(order) do
        if style == "direct" then
            if canSee(from, to) then return { to }, "direct" end
        elseif style == "hole" then
            local h = findHole(from, to)
            if h then return { h, to }, "hole" end
        elseif style == "side" then
            local s = findSide(from, to)
            if s then return { s, to }, "side" end
        elseif style == "climb" then
            local c = findClimb(from, to)
            if c then return { c[1], c[2], to }, "climb" end
        end
    end
    return nil, "noclip"
end

--============ TRAVEL ============
local function tweenLeg(dest, myToken)
    local hrp = hrpOf()
    if not hrp then return false end
    local dist = (dest.Position - hrp.Position).Magnitude
    local dur = math.clamp(dist / SPEED, 0.05, 0.5)

    hrp.Anchored = true
    local tw = TweenService:Create(
        hrp,
        TweenInfo.new(dur, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
        { CFrame = dest }
    )
    local done = false
    local c = tw.Completed:Connect(function() done = true end)
    tw:Play()

    local t0 = os.clock()
    while not done and (os.clock() - t0) < (dur + 0.5) do
        if token ~= myToken or not alive() then break end
        RunService.Heartbeat:Wait()
    end

    if c then pcall(function() c:Disconnect() end) end
    local me = hrpOf()
    if me then
        pcall(function()
            me.Anchored = false
            me.AssemblyLinearVelocity = Vector3.zero
        end)
    end
    return token == myToken and alive()
end

local function travel(target)
    if busy then return end
    local hrp = hrpOf()
    if not hrp then return end

    busy = true
    token = token + 1
    local myToken = token
    playBtn.Text = "GOING"
    playBtn.BackgroundColor3 = Color3.fromRGB(70, 110, 60)

    setNoclip(true)

    local route, style = routeFor(hrp.Position, target.Position)

    if route then
        for _, point in ipairs(route) do
            if token ~= myToken or not alive() then break end
            if not tweenLeg(CFrame.lookAt(point, point + target.LookVector), myToken) then break end
        end
    else
        tweenLeg(target, myToken)
    end

    local me = hrpOf()
    if me and token == myToken then pcall(function() me.CFrame = target end) end

    setNoclip(false)
    busy = false
    playBtn.Text = "PLAY"
    playBtn.BackgroundColor3 = Color3.fromRGB(38, 120, 76)

    if token == myToken then
        learnUp(style)
        celebrate()
    end
end

--============ CELEBRATE ============
local function celebrate()
    if bannerBusy then return end
    bannerBusy = true

    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
    local cx, cy = vp.X / 2, vp.Y / 2

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.fromOffset(260, 42)
    txt.Position = UDim2.fromOffset(cx - 130, cy - 21)
    txt.BackgroundTransparency = 1
    txt.Font = Enum.Font.GothamBlack
    txt.Text = "best tween"
    txt.TextSize = 28
    txt.TextColor3 = Color3.fromRGB(255, 255, 255)
    txt.TextTransparency = 1
    txt.Parent = gui
    local tst = Instance.new("UIStroke")
    tst.Color = Color3.fromRGB(90, 180, 255)
    tst.Thickness = 2
    tst.Transparency = 1
    tst.Parent = txt

    TweenService:Create(txt, TweenInfo.new(0.12), { TextTransparency = 0 }):Play()
    TweenService:Create(tst, TweenInfo.new(0.12), { Transparency = 0 }):Play()

    for i = 1, 12 do
        local dot = Instance.new("Frame")
        dot.Size = UDim2.fromOffset(6, 6)
        dot.Position = UDim2.fromOffset(cx - 3, cy - 3)
        dot.BackgroundColor3 = Color3.fromHSV((i * 0.083) % 1, 0.65, 1)
        dot.BorderSizePixel = 0
        dot.Parent = gui
        local dc = Instance.new("UICorner")
        dc.CornerRadius = UDim.new(1, 0)
        dc.Parent = dot

        local ang = math.rad(i * 30 + math.random(-12, 12))
        local d = math.random(65, 145)
        TweenService:Create(
            dot,
            TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {
                Position = UDim2.fromOffset(cx + math.cos(ang) * d - 2, cy + math.sin(ang) * d - 2),
                Size = UDim2.fromOffset(2, 2),
                BackgroundTransparency = 1,
            }
        ):Play()
        task.delay(0.55, function() if dot then dot:Destroy() end end)
    end

    task.delay(0.55, function()
        TweenService:Create(txt, TweenInfo.new(0.22), { TextTransparency = 1 }):Play()
        TweenService:Create(tst, TweenInfo.new(0.22), { Transparency = 1 }):Play()
    end)

    task.delay(0.85, function()
        if txt then txt:Destroy() end
        bannerBusy = false
    end)
end

playBtn.Activated:Connect(function()
    if busy then return end
    local i = data.picked
    if i == 0 or not data.saves[i] then
        playBtn.Text = "NO PICK"
        task.delay(1, function() if not busy then playBtn.Text = "PLAY" end end)
        return
    end
    travel(unpackCF(data.saves[i]))
end)

--============ API / WATCHDOG ============
local function destroy()
    busy = false
    token = token + 1
    setNoclip(false)
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    pcall(function() gui:Destroy() end)
    if getgenv then getgenv().BestTween = nil end
end

local api = { destroy = destroy, version = "1.0", data = data, celebrate = celebrate }
if getgenv then getgenv().BestTween = api end

-- companion patch per place, if the file exists it runs and teaches the script
task.spawn(function()
    pcall(function()
        local body = game:HttpGet(string.format(PATCH_URL, placeKey))
        if typeof(body) == "string" and #body > 20 and not body:find("404: Not Found") then
            local fn = typeof(loadstring) == "function" and loadstring(body)
            if fn then pcall(fn, api) end
        end
    end)
end)

task.spawn(function()
    while getgenv and getgenv().BestTween == api do
        task.wait(1.5)
        pcall(function()
            if not gui.Parent then
                if typeof(gethui) == "function" then
                    local ok, h = pcall(gethui)
                    if ok and h then gui.Parent = h end
                else
                    gui.Parent = cloneref(game:GetService("CoreGui"))
                end
            end
        end)
    end
end)

closeBtn.Activated:Connect(destroy)
rebuild()

end

--============ BOOT ============
local ok, err = xpcall(boot, function(e) return e end)

if not ok then
    warn("[BestTween] " .. tostring(err))
    if bootCount < 2 and typeof(loadstring) == "function" then
        task.wait(1)
        pcall(function()
            loadstring(game:HttpGet(RAW_URL .. "?retry=" .. tostring(os.time())))()
        end)
    end
end
