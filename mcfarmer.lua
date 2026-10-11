--[[
    ╔══════════════════════════════════════════════╗
    ║           NPC AUTO FARMER v9                 ║
    ║  Astralex style · Warning · Drawn X button   ║
    ╚══════════════════════════════════════════════╝
]]

local Players             = game:GetService("Players")
local UserInputService    = game:GetService("UserInputService")
local TweenService        = game:GetService("TweenService")
local RunService          = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Debris              = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------
local CONFIG = {
    HOME_POS      = Vector3.new(1781.4, 4.5, -1597.6),
    NPC_NAMES     = { "NPC1", "NPC2", "NPC3", "NPC4", "NPC5" },
    E_PRESS_HOME  = 1.5,
    E_PRESS_NPC   = 1.0,
    BETWEEN_NPC   = 1.5,
    WAIT_CYCLE    = 15,
    FACE_DISTANCE = 4.5,
    PRE_E_DELAY   = 1.0,
}

local E_KEY = Enum.KeyCode.E
local VK_E  = 0x45

------------------------------------------------------------
-- STATE
------------------------------------------------------------
local State = {
    running = false,
    conn    = nil,
}

------------------------------------------------------------
-- THEME
------------------------------------------------------------
local Theme = {
    Bg         = Color3.fromRGB(10, 11, 18),
    BgDark     = Color3.fromRGB(8, 9, 14),
    Card       = Color3.fromRGB(19, 22, 34),
    CardHover  = Color3.fromRGB(25, 29, 45),
    Stroke     = Color3.fromRGB(38, 42, 60),
    Accent     = Color3.fromRGB(139, 92, 246),
    Accent2    = Color3.fromRGB(99, 102, 241),
    Accent3    = Color3.fromRGB(59, 130, 246),
    AccentGlow = Color3.fromRGB(167, 139, 250),
    Text       = Color3.fromRGB(240, 242, 248),
    TextDim    = Color3.fromRGB(140, 146, 170),
    TextMuted  = Color3.fromRGB(88, 94, 118),
    Green      = Color3.fromRGB(22, 163, 74),
    GreenGlow  = Color3.fromRGB(34, 197, 94),
    Red        = Color3.fromRGB(185, 28, 28),
    RedGlow    = Color3.fromRGB(220, 38, 38),
    Yellow     = Color3.fromRGB(250, 204, 21),
}

------------------------------------------------------------
-- HELPERS
------------------------------------------------------------
local function tw(obj, time, props, style, dir)
    if not obj then return end
    pcall(function()
        local info = TweenInfo.new(time or 0.25,
            style or Enum.EasingStyle.Quart,
            dir or Enum.EasingDirection.Out)
        TweenService:Create(obj, info, props):Play()
    end)
end

local function addCorner(parent, r)
    if not parent then return nil end
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 12)
    c.Parent = parent
    return c
end

local function addGradient(parent, c1, c2, rot)
    if not parent then return nil end
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(c1, c2)
    g.Rotation = rot or 0
    g.Parent = parent
    return g
end

local function addStroke(parent, color, thickness, transparency)
    if not parent then return nil end
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.Stroke
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function addGlow(parent, color, size)
    if not parent then return nil end
    local g = Instance.new("ImageLabel")
    g.BackgroundTransparency = 1
    g.Image = "rbxassetid://5028857084"
    g.ImageColor3 = color or Theme.Accent
    g.ImageTransparency = 0.4
    g.ScaleType = Enum.ScaleType.Slice
    g.SliceCenter = Rect.new(24, 24, 276, 276)
    g.Size = UDim2.new(1, (size or 30) * 2, 1, (size or 30) * 2)
    g.Position = UDim2.new(0, -(size or 30), 0, -(size or 30))
    g.ZIndex = 0
    g.Parent = parent
    return g
end

local function ripple(button)
    if not button then return end
    local r = Instance.new("Frame")
    r.AnchorPoint = Vector2.new(0.5, 0.5)
    r.BackgroundColor3 = Color3.new(1, 1, 1)
    r.BackgroundTransparency = 0.6
    r.BorderSizePixel = 0
    r.Size = UDim2.new(0, 0, 0, 0)
    r.Position = UDim2.new(0.5, 0, 0.5, 0)
    r.ZIndex = (button.ZIndex or 1) + 1
    r.Parent = button
    addCorner(r, 999)
    tw(r, 0.55, {
        Size = UDim2.new(0, 220, 0, 220),
        BackgroundTransparency = 1
    }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    Debris:AddItem(r, 0.6)
end

------------------------------------------------------------
-- KEY SIM
------------------------------------------------------------
local hasKP = (type(keypress) == "function" and type(keyrelease) == "function")

local function pressE()
    if hasKP then pcall(function() keypress(VK_E) end) end
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, E_KEY, false, game)
    end)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, E_KEY, false, nil)
    end)
end

local function releaseE()
    if hasKP then pcall(function() keyrelease(VK_E) end) end
    pcall(function()
        VirtualInputManager:SendKeyEvent(false, E_KEY, false, game)
    end)
    pcall(function()
        VirtualInputManager:SendKeyEvent(false, E_KEY, false, nil)
    end)
end

local function holdE(duration)
    pressE()
    task.wait(duration or 1)
    releaseE()
end

------------------------------------------------------------
-- GAME HELPERS
------------------------------------------------------------
local function getHRP()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

local function teleportCFrame(cf)
    local hrp = getHRP()
    if not hrp or not cf then return false end
    pcall(function()
        hrp.CFrame = cf
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
    return true
end

local function waitForGround(timeout)
    timeout = timeout or 2
    local hum = getHumanoid()
    if not hum then return false end
    local t = tick()
    while tick() - t < timeout do
        local ok, mat = pcall(function() return hum.FloorMaterial end)
        if ok and mat and mat ~= Enum.Material.Air then return true end
        task.wait(0.05)
    end
    return false
end

local function findNPC(name)
    if not name then return nil end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == name and obj:IsA("Model") then
            if obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart then
                return obj
            end
        end
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == name and obj:IsA("Model") then
            return obj
        end
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == name then
            return obj
        end
    end
    return nil
end

local function findAllNPCs()
    local result = {}
    for _, name in ipairs(CONFIG.NPC_NAMES) do
        local npc = findNPC(name)
        if npc then
            table.insert(result, { name = name, model = npc })
        end
    end
    return result
end

local function getFaceCFrame(npc)
    if not npc then return nil end
    local npcCF = nil

    if npc:IsA("Model") then
        local hrp = npc:FindFirstChild("HumanoidRootPart")
        if hrp then
            npcCF = hrp.CFrame
        elseif npc.PrimaryPart then
            npcCF = npc.PrimaryPart.CFrame
        else
            local ok, cf = pcall(function() return npc:GetModelCFrame() end)
            if ok and cf then npcCF = cf end
        end
    elseif npc:IsA("BasePart") then
        npcCF = npc.CFrame
    end

    if not npcCF and npc:IsA("Model") then
        for _, p in ipairs(npc:GetDescendants()) do
            if p:IsA("BasePart") then
                npcCF = p.CFrame
                break
            end
        end
    end

    if not npcCF then return nil end

    local lookVec = npcCF.LookVector
    lookVec = Vector3.new(lookVec.X, 0, lookVec.Z)
    if lookVec.Magnitude < 0.01 then
        lookVec = Vector3.new(0, 0, -1)
    end
    lookVec = lookVec.Unit

    local frontPos = npcCF.Position + lookVec * CONFIG.FACE_DISTANCE
    return CFrame.lookAt(frontPos, npcCF.Position)
end

------------------------------------------------------------
-- SCREEN GUI
------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NPCAutoFarm"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 998

local ok1 = pcall(function() screenGui.Parent = (gethui and gethui()) end)
if not ok1 or not screenGui.Parent then
    pcall(function()
        screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end)
end

if not screenGui.Parent then
    warn("[NPCAutoFarm] Could not create GUI")
    return
end

------------------------------------------------------------
-- MAIN WINDOW
------------------------------------------------------------
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 440, 0, 490)
main.Position = UDim2.new(0.5, -220, 0.5, -245)
main.BackgroundColor3 = Theme.Bg
main.BorderSizePixel = 0
main.Active = true
main.ClipsDescendants = true
main.Visible = false
main.Parent = screenGui
addCorner(main, 20)
addGlow(main, Theme.Accent, 40)

local mainStroke = addStroke(main, Color3.new(1, 1, 1), 1, 0.85)
if mainStroke then
    local sg = Instance.new("UIGradient")
    sg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Theme.Accent),
        ColorSequenceKeypoint.new(0.5, Theme.Accent2),
        ColorSequenceKeypoint.new(1, Theme.Accent3),
    })
    sg.Rotation = 45
    sg.Parent = mainStroke
end

local innerGrad = Instance.new("UIGradient")
innerGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 17, 26)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 9, 14)),
})
innerGrad.Rotation = 135
innerGrad.Parent = main

------------------------------------------------------------
-- HEADER
------------------------------------------------------------
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 72)
header.BackgroundColor3 = Theme.BgDark
header.BackgroundTransparency = 0.15
header.BorderSizePixel = 0
header.ClipsDescendants = true
header.Parent = main
addCorner(header, 20)

local headerBg = Instance.new("Frame")
headerBg.Size = UDim2.new(1, 0, 1, 0)
headerBg.BorderSizePixel = 0
headerBg.Parent = header
addCorner(headerBg, 20)

local headerBgGrad = Instance.new("UIGradient")
headerBgGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 24, 38)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(30, 24, 48)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 24, 38)),
})
headerBgGrad.Parent = headerBg

task.spawn(function()
    local t = 0
    while header.Parent do
        t = t + 0.008
        headerBgGrad.Rotation = math.sin(t) * 20
        task.wait(0.03)
    end
end)

local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1, 0, 0, 20)
headerFix.Position = UDim2.new(0, 0, 1, -20)
headerFix.BackgroundColor3 = Color3.fromRGB(22, 24, 38)
headerFix.BorderSizePixel = 0
headerFix.ZIndex = 1
headerFix.Parent = header

local headerLine = Instance.new("Frame")
headerLine.Size = UDim2.new(1, 0, 0, 1)
headerLine.Position = UDim2.new(0, 0, 1, -1)
headerLine.BackgroundColor3 = Color3.new(1, 1, 1)
headerLine.BorderSizePixel = 0
headerLine.ZIndex = 3
headerLine.Parent = header

local headerLineGrad = Instance.new("UIGradient")
headerLineGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(0.5, 0.7),
    NumberSequenceKeypoint.new(1, 1),
})
headerLineGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Theme.Accent),
    ColorSequenceKeypoint.new(1, Theme.Accent2),
})
headerLineGrad.Parent = headerLine

local logoBox = Instance.new("Frame")
logoBox.Size = UDim2.new(0, 40, 0, 40)
logoBox.Position = UDim2.new(0, 22, 0.5, -20)
logoBox.BackgroundColor3 = Theme.Accent
logoBox.BorderSizePixel = 0
logoBox.ZIndex = 4
logoBox.Parent = header
addCorner(logoBox, 12)
addGlow(logoBox, Theme.AccentGlow, 12)

local logoGrad = addGradient(logoBox, Theme.Accent, Theme.Accent3, 45)

task.spawn(function()
    while logoBox.Parent and logoGrad do
        logoGrad.Rotation = (logoGrad.Rotation + 0.6) % 360
        task.wait(0.03)
    end
end)

local logoText = Instance.new("TextLabel")
logoText.BackgroundTransparency = 1
logoText.Size = UDim2.new(1, 0, 1, 0)
logoText.Font = Enum.Font.GothamBlack
logoText.Text = "N"
logoText.TextSize = 22
logoText.TextColor3 = Color3.new(1, 1, 1)
logoText.ZIndex = 5
logoText.Parent = logoBox

local brandText = Instance.new("TextLabel")
brandText.BackgroundTransparency = 1
brandText.Position = UDim2.new(0, 76, 0, 18)
brandText.Size = UDim2.new(1, -180, 0, 26)
brandText.Font = Enum.Font.GothamBold
brandText.Text = "NPC FARMER"
brandText.TextSize = 20
brandText.TextColor3 = Theme.Text
brandText.TextXAlignment = Enum.TextXAlignment.Left
brandText.ZIndex = 4
brandText.Parent = header

local brandGrad = Instance.new("UIGradient")
brandGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 160, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 180, 255)),
})
brandGrad.Rotation = 15
brandGrad.Parent = brandText

local brandSub = Instance.new("TextLabel")
brandSub.BackgroundTransparency = 1
brandSub.Position = UDim2.new(0, 76, 0, 42)
brandSub.Size = UDim2.new(1, -180, 0, 14)
brandSub.Font = Enum.Font.GothamMedium
brandSub.Text = "AUTO TELEPORT · v9"
brandSub.TextSize = 9
brandSub.TextColor3 = Theme.TextMuted
brandSub.TextXAlignment = Enum.TextXAlignment.Left
brandSub.ZIndex = 4
brandSub.Parent = header

------------------------------------------------------------
-- CLOSE BUTTON (drawn X)
------------------------------------------------------------
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -48, 0.5, -18)
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 40)
closeBtn.BorderSizePixel = 0
closeBtn.Text = ""
closeBtn.AutoButtonColor = false
closeBtn.ZIndex = 5
closeBtn.Parent = header
addCorner(closeBtn, 10)
addStroke(closeBtn, Color3.fromRGB(120, 40, 60), 1, 0.3)

local line1 = Instance.new("Frame")
line1.Name = "Line1"
line1.Size = UDim2.new(0, 16, 0, 3)
line1.Position = UDim2.new(0.5, -8, 0.5, -1.5)
line1.BackgroundColor3 = Color3.fromRGB(255, 200, 200)
line1.BorderSizePixel = 0
line1.Rotation = 45
line1.ZIndex = 6
line1.Parent = closeBtn

local c1 = Instance.new("UICorner")
c1.CornerRadius = UDim.new(1, 0)
c1.Parent = line1

local line2 = Instance.new("Frame")
line2.Name = "Line2"
line2.Size = UDim2.new(0, 16, 0, 3)
line2.Position = UDim2.new(0.5, -8, 0.5, -1.5)
line2.BackgroundColor3 = Color3.fromRGB(255, 200, 200)
line2.BorderSizePixel = 0
line2.Rotation = -45
line2.ZIndex = 6
line2.Parent = closeBtn

local c2 = Instance.new("UICorner")
c2.CornerRadius = UDim.new(1, 0)
c2.Parent = line2

closeBtn.MouseEnter:Connect(function()
    tw(closeBtn, 0.15, {
        BackgroundColor3 = Color3.fromRGB(200, 50, 60)
    })
    tw(line1, 0.15, { BackgroundColor3 = Color3.fromRGB(255, 255, 255) })
    tw(line2, 0.15, { BackgroundColor3 = Color3.fromRGB(255, 255, 255) })
end)

closeBtn.MouseLeave:Connect(function()
    tw(closeBtn, 0.15, {
        BackgroundColor3 = Color3.fromRGB(60, 30, 40)
    })
    tw(line1, 0.15, { BackgroundColor3 = Color3.fromRGB(255, 200, 200) })
    tw(line2, 0.15, { BackgroundColor3 = Color3.fromRGB(255, 200, 200) })
end)

closeBtn.MouseButton1Click:Connect(function()
    State.running = false
    pcall(releaseE)

    if screenGui then
        for _, gui in ipairs(screenGui:GetDescendants()) do
            if gui:IsA("Frame") then
                pcall(function() tw(gui, 0.25, { BackgroundTransparency = 1 }) end)
            elseif gui:IsA("TextLabel") then
                pcall(function() tw(gui, 0.25, { TextTransparency = 1 }) end)
            elseif gui:IsA("TextButton") then
                pcall(function() tw(gui, 0.25, { TextTransparency = 1, BackgroundTransparency = 1 }) end)
            end
        end
        task.wait(0.3)
        screenGui:Destroy()
    end
end)

------------------------------------------------------------
-- CONTENT AREA
------------------------------------------------------------
local content = Instance.new("Frame")
content.Position = UDim2.new(0, 0, 0, 72)
content.Size = UDim2.new(1, 0, 1, -72)
content.BackgroundTransparency = 1
content.Parent = main

local contentPad = Instance.new("UIPadding")
contentPad.PaddingTop = UDim.new(0, 20)
contentPad.PaddingBottom = UDim.new(0, 20)
contentPad.PaddingLeft = UDim.new(0, 22)
contentPad.PaddingRight = UDim.new(0, 22)
contentPad.Parent = content

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 12)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Parent = content

------------------------------------------------------------
-- CARDS
------------------------------------------------------------
local function makeCard(order, height)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, height or 62)
    card.BackgroundColor3 = Theme.Card
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel = 0
    card.LayoutOrder = order
    card.Parent = content
    addCorner(card, 14)
    local stroke = addStroke(card, Theme.Stroke, 1, 0.4)

    card.MouseEnter:Connect(function()
        tw(card, 0.2, { BackgroundColor3 = Theme.CardHover, BackgroundTransparency = 0 })
        if stroke then tw(stroke, 0.2, { Transparency = 0.1 }) end
    end)
    card.MouseLeave:Connect(function()
        tw(card, 0.2, { BackgroundColor3 = Theme.Card, BackgroundTransparency = 0.05 })
        if stroke then tw(stroke, 0.2, { Transparency = 0.4 }) end
    end)

    return card
end

-- STATUS CARD
local statusCard = makeCard(1, 76)
local statusAccent = Instance.new("Frame")
statusAccent.Size = UDim2.new(0, 3, 0, 28)
statusAccent.Position = UDim2.new(0, 12, 0, 16)
statusAccent.BackgroundColor3 = Theme.Accent
statusAccent.BorderSizePixel = 0
statusAccent.Parent = statusCard
addCorner(statusAccent, 4)

local statusTitle = Instance.new("TextLabel")
statusTitle.BackgroundTransparency = 1
statusTitle.Position = UDim2.new(0, 24, 0, 12)
statusTitle.Size = UDim2.new(1, -36, 0, 18)
statusTitle.Font = Enum.Font.GothamBold
statusTitle.Text = "Status"
statusTitle.TextSize = 13
statusTitle.TextColor3 = Theme.Text
statusTitle.TextXAlignment = Enum.TextXAlignment.Left
statusTitle.Parent = statusCard

local statusValue = Instance.new("TextLabel")
statusValue.BackgroundTransparency = 1
statusValue.Position = UDim2.new(0, 24, 0, 34)
statusValue.Size = UDim2.new(1, -36, 0, 32)
statusValue.Font = Enum.Font.GothamMedium
statusValue.Text = "Idle"
statusValue.TextSize = 12
statusValue.TextColor3 = Theme.TextDim
statusValue.TextXAlignment = Enum.TextXAlignment.Left
statusValue.TextWrapped = true
statusValue.Parent = statusCard

local function setStatus(s)
    if not statusValue then return end
    statusValue.Text = s

    if string.find(s, "holding E") or string.find(s, "waiting") then
        statusAccent.BackgroundColor3 = Theme.Yellow
        statusValue.TextColor3 = Theme.Yellow
    elseif string.find(s, "landing") or string.find(s, "Next cycle") then
        statusAccent.BackgroundColor3 = Theme.Accent
        statusValue.TextColor3 = Theme.TextDim
    elseif string.find(s, "Stopped") then
        statusAccent.BackgroundColor3 = Theme.Red
        statusValue.TextColor3 = Theme.Red
    elseif string.find(s, "Started") or string.find(s, "Found") then
        statusAccent.BackgroundColor3 = Theme.Green
        statusValue.TextColor3 = Theme.GreenGlow
    else
        statusAccent.BackgroundColor3 = Theme.Accent
        statusValue.TextColor3 = Theme.TextDim
    end
end

------------------------------------------------------------
-- START BUTTON
------------------------------------------------------------
local startCard = makeCard(2, 60)
local startBtn = Instance.new("TextButton")
startBtn.Size = UDim2.new(1, 0, 1, 0)
startBtn.BackgroundColor3 = Theme.Green
startBtn.BorderSizePixel = 0
startBtn.Font = Enum.Font.GothamSemibold
startBtn.TextSize = 16
startBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
startBtn.Text = "▶  START FARMING"
startBtn.TextStrokeTransparency = 0
startBtn.TextStrokeColor3 = Color3.fromRGB(0, 55, 20)
startBtn.AutoButtonColor = false
startBtn.ZIndex = 5
startBtn.Parent = startCard
addCorner(startBtn, 14)
addGradient(startBtn, Theme.Green, Theme.GreenGlow, 20)
addStroke(startBtn, Color3.new(1, 1, 1), 1, 0.6)

------------------------------------------------------------
-- STOP BUTTON
------------------------------------------------------------
local stopCard = makeCard(3, 60)
local stopBtn = Instance.new("TextButton")
stopBtn.Size = UDim2.new(1, 0, 1, 0)
stopBtn.BackgroundColor3 = Theme.Red
stopBtn.BorderSizePixel = 0
stopBtn.Font = Enum.Font.GothamSemibold
stopBtn.TextSize = 16
stopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
stopBtn.Text = "■  STOP"
stopBtn.TextStrokeTransparency = 0
stopBtn.TextStrokeColor3 = Color3.fromRGB(75, 0, 0)
stopBtn.AutoButtonColor = false
stopBtn.ZIndex = 5
stopBtn.Parent = stopCard
addCorner(stopBtn, 14)
addGradient(stopBtn, Theme.Red, Theme.RedGlow, 20)
addStroke(stopBtn, Color3.new(1, 1, 1), 1, 0.6)

------------------------------------------------------------
-- TEST BUTTON
------------------------------------------------------------
local testCard = makeCard(4, 46)
local testBtn = Instance.new("TextButton")
testBtn.Size = UDim2.new(1, 0, 1, 0)
testBtn.BackgroundColor3 = Theme.CardHover
testBtn.BorderSizePixel = 0
testBtn.Font = Enum.Font.GothamBold
testBtn.TextSize = 12
testBtn.TextColor3 = Theme.TextDim
testBtn.Text = "TEST E KEY (3s)"
testBtn.AutoButtonColor = false
testBtn.Parent = testCard
addCorner(testBtn, 14)
addStroke(testBtn, Theme.Stroke, 1, 0.3)

------------------------------------------------------------
-- MAIN LOOP
------------------------------------------------------------
local function mainLoop()
    setStatus("Started")

    while State.running do
        if not State.running then break end
        teleportCFrame(CFrame.new(CONFIG.HOME_POS))
        setStatus("Home — landing...")
        waitForGround(2)
        task.wait(0.4)
        if not State.running then break end

        setStatus("Home — holding E (1.5s)")
        holdE(CONFIG.E_PRESS_HOME)
        if not State.running then break end

        local npcs = findAllNPCs()
        setStatus("Found " .. #npcs .. " NPC(s)")
        task.wait(0.3)

        for i, entry in ipairs(npcs) do
            if not State.running then break end
            local faceCF = getFaceCFrame(entry.model)

            if faceCF then
                teleportCFrame(faceCF)
                setStatus("NPC " .. i .. "/" .. #npcs .. " — landing...")
                waitForGround(1.5)

                setStatus("NPC " .. i .. "/" .. #npcs .. " — waiting 1s...")
                task.wait(CONFIG.PRE_E_DELAY)

                if not State.running then break end

                setStatus("NPC " .. i .. "/" .. #npcs .. " — holding E")
                holdE(CONFIG.E_PRESS_NPC)

                if i < #npcs then
                    if not State.running then break end
                    task.wait(CONFIG.BETWEEN_NPC)
                end
            else
                setStatus("NPC " .. i .. " — position not found")
                task.wait(0.5)
            end
        end

        if not State.running then break end

        teleportCFrame(CFrame.new(CONFIG.HOME_POS))
        setStatus("Returned home — waiting 15s")

        local waitUntil = tick() + CONFIG.WAIT_CYCLE
        while State.running and tick() < waitUntil do
            local left = math.ceil(waitUntil - tick())
            setStatus("Next cycle in " .. left .. "s")
            task.wait(0.5)
        end
    end

    releaseE()
    setStatus("Stopped")
end

------------------------------------------------------------
-- BUTTON ACTIONS
------------------------------------------------------------
startBtn.MouseButton1Click:Connect(function()
    ripple(startBtn)
    if State.running then return end
    State.running = true
    setStatus("Starting...")
    State.conn = task.spawn(mainLoop)
end)

stopBtn.MouseButton1Click:Connect(function()
    ripple(stopBtn)
    if not State.running then return end
    State.running = false
    releaseE()
    setStatus("Stopped")
end)

testBtn.MouseButton1Click:Connect(function()
    ripple(testBtn)
    setStatus("Testing E for 3s...")
    task.spawn(function()
        holdE(3)
        setStatus("E test finished")
    end)
end)

------------------------------------------------------------
-- DRAG
------------------------------------------------------------
do
    local dragging, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

------------------------------------------------------------
-- WARNING POPUP
------------------------------------------------------------
local warnDim = Instance.new("Frame")
warnDim.Size = UDim2.new(1, 0, 1, 0)
warnDim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
warnDim.BackgroundTransparency = 0.5
warnDim.BorderSizePixel = 0
warnDim.ZIndex = 1000
warnDim.Parent = screenGui

local warn = Instance.new("Frame")
warn.Size = UDim2.new(0, 500, 0, 340)
warn.Position = UDim2.new(0.5, -250, 0.5, -170)
warn.BackgroundColor3 = Theme.Bg
warn.BorderSizePixel = 0
warn.Active = true
warn.ZIndex = 1001
warn.Parent = screenGui
addCorner(warn, 20)
addGlow(warn, Theme.Yellow, 40)

local warnStroke = addStroke(warn, Theme.Yellow, 2, 0.3)

local warnInnerGrad = Instance.new("UIGradient")
warnInnerGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 20, 30)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 13, 22)),
})
warnInnerGrad.Rotation = 135
warnInnerGrad.Parent = warn

local warnIcon = Instance.new("Frame")
warnIcon.Size = UDim2.new(0, 70, 0, 70)
warnIcon.Position = UDim2.new(0.5, -35, 0, 26)
warnIcon.BackgroundColor3 = Theme.Yellow
warnIcon.BorderSizePixel = 0
warnIcon.ZIndex = 1002
warnIcon.Parent = warn
addCorner(warnIcon, 35)
addGlow(warnIcon, Theme.Yellow, 16)

local warnIconText = Instance.new("TextLabel")
warnIconText.BackgroundTransparency = 1
warnIconText.Size = UDim2.new(1, 0, 1, 0)
warnIconText.Font = Enum.Font.GothamBlack
warnIconText.Text = "!"
warnIconText.TextSize = 42
warnIconText.TextColor3 = Color3.fromRGB(30, 20, 0)
warnIconText.ZIndex = 1003
warnIconText.Parent = warnIcon

local warnTitle = Instance.new("TextLabel")
warnTitle.BackgroundTransparency = 1
warnTitle.Position = UDim2.new(0, 30, 0, 108)
warnTitle.Size = UDim2.new(1, -60, 0, 32)
warnTitle.Font = Enum.Font.GothamBlack
warnTitle.Text = "IMPORTANT"
warnTitle.TextSize = 24
warnTitle.TextColor3 = Theme.Yellow
warnTitle.ZIndex = 1002
warnTitle.Parent = warn

local warnBody = Instance.new("TextLabel")
warnBody.BackgroundTransparency = 1
warnBody.Position = UDim2.new(0, 40, 0, 148)
warnBody.Size = UDim2.new(1, -80, 0, 110)
warnBody.Font = Enum.Font.GothamMedium
warnBody.Text = "If the script does NOT start working right away, please DO NOT stop it. It will automatically start its second cycle and everything will work fine.\n\nJust wait a few seconds before pressing any buttons."
warnBody.TextSize = 13
warnBody.TextColor3 = Color3.fromRGB(220, 220, 235)
warnBody.TextWrapped = true
warnBody.TextYAlignment = Enum.TextYAlignment.Top
warnBody.ZIndex = 1002
warnBody.Parent = warn

local warnOk = Instance.new("TextButton")
warnOk.Size = UDim2.new(1, -80, 0, 46)
warnOk.Position = UDim2.new(0, 40, 1, -62)
warnOk.BackgroundColor3 = Theme.Accent
warnOk.BorderSizePixel = 0
warnOk.Font = Enum.Font.GothamSemibold
warnOk.TextSize = 15
warnOk.TextColor3 = Color3.new(1, 1, 1)
warnOk.Text = "✓  I UNDERSTAND"
warnOk.TextStrokeTransparency = 0
warnOk.TextStrokeColor3 = Color3.fromRGB(30, 20, 60)
warnOk.AutoButtonColor = false
warnOk.ZIndex = 1002
warnOk.Parent = warn
addCorner(warnOk, 12)
addGradient(warnOk, Theme.Accent, Theme.Accent3, 20)
addStroke(warnOk, Color3.new(1, 1, 1), 1, 0.7)

warnOk.MouseEnter:Connect(function()
    tw(warnOk, 0.15, {
        Size = UDim2.new(1, -76, 0, 48),
        Position = UDim2.new(0, 38, 1, -63)
    })
end)
warnOk.MouseLeave:Connect(function()
    tw(warnOk, 0.15, {
        Size = UDim2.new(1, -80, 0, 46),
        Position = UDim2.new(0, 40, 1, -62)
    })
end)

warn.Position = UDim2.new(0.5, -250, 0.5, -140)
warn.BackgroundTransparency = 1
task.spawn(function()
    task.wait(0.1)
    tw(warn, 0.45, {
        Position = UDim2.new(0.5, -250, 0.5, -170),
        BackgroundTransparency = 0
    }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
end)

warnOk.MouseButton1Click:Connect(function()
    ripple(warnOk)
    task.wait(0.15)

    local fadeInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

    if warn then
        TweenService:Create(warn, fadeInfo, {
            BackgroundTransparency = 1,
            Position = UDim2.new(0.5, -250, 0.5, -120)
        }):Play()
    end
    if warnDim then
        TweenService:Create(warnDim, fadeInfo, { BackgroundTransparency = 1 }):Play()
    end
    if warnStroke then
        TweenService:Create(warnStroke, fadeInfo, { Transparency = 1 }):Play()
    end

    for _, obj in ipairs(warn:GetDescendants()) do
        if obj:IsA("TextLabel") then
            TweenService:Create(obj, fadeInfo, { TextTransparency = 1 }):Play()
        elseif obj:IsA("TextButton") then
            TweenService:Create(obj, fadeInfo, {
                TextTransparency = 1,
                BackgroundTransparency = 1
            }):Play()
        elseif obj:IsA("Frame") then
            TweenService:Create(obj, fadeInfo, { BackgroundTransparency = 1 }):Play()
        end
    end

    task.wait(0.4)
    if warn then warn:Destroy() end
    if warnDim then warnDim:Destroy() end

    if main then
        main.Visible = true
        main.BackgroundTransparency = 1
        main.Position = UDim2.new(0.5, -220, 0.5, -215)

        tw(main, 0.45, {
            BackgroundTransparency = 0,
            Position = UDim2.new(0.5, -220, 0.5, -245)
        }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    end
end)

print("[NPCAutoFarm v9] loaded successfully.")
print("  keypress available: " .. tostring(hasKP))
