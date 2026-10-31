-- Monarca Script Hub v0.1.0
-- Interface local. Os modulos sao carregados exclusivamente deste repositorio.
local Services = {
    Players = game:GetService("Players"),
    TweenService = game:GetService("TweenService"),
    UserInputService = game:GetService("UserInputService"),
    HttpService = game:GetService("HttpService"),
}
local player = Services.Players.LocalPlayer
if not player then return end

local repository = "https://raw.githubusercontent.com/DiscNet/Monarca/main/"
local settingsPath = "Monarca/settings.json"
local theme = {
    background = Color3.fromRGB(10, 9, 17),
    surface = Color3.fromRGB(17, 16, 29),
    card = Color3.fromRGB(27, 24, 42),
    border = Color3.fromRGB(80, 68, 107),
    accent = Color3.fromRGB(183, 140, 248),
    text = Color3.fromRGB(244, 244, 248),
    muted = Color3.fromRGB(153, 157, 173),
    danger = Color3.fromRGB(214, 106, 106),
}
local defaults = {
    animations = true,
    notifications = true,
    playerCustomized = false,
    fieldOfView = 70,
    walkSpeed = 16,
    jumpPower = 50,
}
local settings = {}
for k, v in pairs(defaults) do settings[k] = v end

local env = _G
if type(getgenv) == "function" then
    local ok, result = pcall(getgenv)
    if ok and type(result) == "table" then env = result end
end
if env.MONARCA_HUB and type(env.MONARCA_HUB.destroy) == "function" then
    pcall(env.MONARCA_HUB.destroy)
end

local connections = {}
local loadedModules, activeModules, catalog = {}, {}, {}
local destroyed = false
local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end
local function save()
    if type(writefile) ~= "function" then return false end
    pcall(function()
        if type(makefolder) == "function" then
            if type(isfolder) ~= "function" or not isfolder("Monarca") then
                makefolder("Monarca")
            end
        end
    end)
    local ok = pcall(function()
        writefile(settingsPath, Services.HttpService:JSONEncode(settings))
    end)
    return ok
end
if type(readfile) == "function" then
    local ok, decoded = pcall(function()
        return Services.HttpService:JSONDecode(readfile(settingsPath))
    end)
    if ok and type(decoded) == "table" then
        for k, v in pairs(defaults) do
            if type(decoded[k]) == type(v) then settings[k] = decoded[k] end
        end
    end
end
settings.fieldOfView = math.clamp(settings.fieldOfView, 60, 110)
settings.walkSpeed = math.clamp(settings.walkSpeed, 8, 32)
settings.jumpPower = math.clamp(settings.jumpPower, 25, 100)

local function new(class, props, parent)
    local object = Instance.new(class)
    for property, value in pairs(props or {}) do object[property] = value end
    object.Parent = parent
    return object
end
local function rounded(object, radius)
    new("UICorner", {CornerRadius = UDim.new(0, radius or 10)}, object)
end
local function outlined(object)
    new("UIStroke", {Color = theme.border, Thickness = 1, Transparency = 0.2}, object)
end
local layoutCounters = setmetatable({}, {__mode = "k"})
local function ordered(parent, object)
    if parent:IsA("ScrollingFrame") or parent.Name == "ModuleArea" then
        layoutCounters[parent] = (layoutCounters[parent] or 0) + 1
        object.LayoutOrder = layoutCounters[parent]
    end
    return object
end
local function label(parent, value, size, color, height)
    return ordered(parent, new("TextLabel", {
        Size = UDim2.new(1, 0, 0, height or 22),
        BackgroundTransparency = 1,
        Text = value,
        TextSize = size or 14,
        Font = Enum.Font.Gotham,
        TextColor3 = color or theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextWrapped = true,
    }, parent))
end
local function button(parent, value, position, size, action, accent)
    local b = new("TextButton", {
        Position = position or UDim2.new(),
        Size = size or UDim2.fromOffset(85, 30),
        BackgroundColor3 = accent and theme.accent or theme.card,
        TextColor3 = accent and theme.background or theme.text,
        Text = value,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
    }, parent)
    rounded(b, 12)
    if action then b.Activated:Connect(action) end
    return b
end
local function tween(object, properties, duration)
    if settings.animations and not destroyed then
        local animation = Services.TweenService:Create(
            object, TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            properties
        )
        animation:Play()
    else
        for k, v in pairs(properties) do object[k] = v end
    end
end

local gui = new("ScreenGui", {
    Name = "MonarcaHubV1",
    ResetOnSpawn = false,
    IgnoreGuiInset = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 900,
})
local parent
if type(gethui) == "function" then
    local ok, p = pcall(gethui)
    if ok and p then parent = p end
end
if not parent then
    local ok, p = pcall(function() return game:GetService("CoreGui") end)
    if ok then parent = p end
end
if not pcall(function() gui.Parent = parent end) then
    gui.Parent = player:WaitForChild("PlayerGui")
end

local main = new("Frame", {
    Name = "Window",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    BackgroundColor3 = theme.background,
    BackgroundTransparency = 0.16,
    ClipsDescendants = true,
}, gui)
rounded(main, 20)
outlined(main)

-- BlurEffect softens the 3D scene while the Hub is open.
-- Roblox does not provide per-panel background blur via an ordinary Frame.
local hubBlur
pcall(function()
    hubBlur = new("BlurEffect", {
        Name = "MonarcaWindowBlur",
        Enabled = true,
        Size = 0,
    }, game:GetService("Lighting"))
end)
local function setBlur(enabled)
    if not hubBlur or not hubBlur.Parent then return end
    tween(hubBlur, {Size = enabled and 9 or 0}, 0.2)
end

local camera = workspace.CurrentCamera
local originalFov = camera and camera.FieldOfView or 70
local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
local originalWalk = humanoid and humanoid.WalkSpeed or 16
local originalJump = humanoid and humanoid.JumpPower or 50
local windowOffset = Vector2.zero
local HEADER_HEIGHT = 46
local NAV_HEIGHT = 42
local FOOTER_HEIGHT = 22
local function viewport()
    camera = workspace.CurrentCamera
    return camera and camera.ViewportSize or Vector2.new(800, 600)
end
local function layout()
    if destroyed then return end
    local vp = viewport()
    -- Compact on wide screens; preserve a safe margin on portrait and landscape mobile.
    local w = math.max(180, math.min(540, vp.X - 24))
    local h = math.max(165, math.min(340, vp.Y - 36))
    main.Size = UDim2.fromOffset(w, h)
    local maxX = math.max(0, (vp.X - w) / 2)
    local maxY = math.max(0, (vp.Y - h) / 2)
    windowOffset = Vector2.new(
        math.clamp(windowOffset.X, -maxX, maxX),
        math.clamp(windowOffset.Y, -maxY, maxY)
    )
    main.Position = UDim2.new(0.5, windowOffset.X, 0.5, windowOffset.Y)
end
local header = new("Frame", {
    Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
    BackgroundColor3 = theme.surface,
    BackgroundTransparency = 0.16,
    BorderSizePixel = 0,
    Active = true,
}, main)
new("Frame", {
    Position = UDim2.fromOffset(12, 12),
    Size = UDim2.fromOffset(3, 22),
    BackgroundColor3 = theme.accent,
    BorderSizePixel = 0,
}, header)
new("TextLabel", {
    Position = UDim2.fromOffset(23, 6),
    Size = UDim2.new(1, -107, 0, 20),
    BackgroundTransparency = 1,
    Text = "MONARCA",
    Font = Enum.Font.GothamBold,
    TextColor3 = theme.text,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
}, header)
new("TextLabel", {
    Position = UDim2.fromOffset(23, 26),
    Size = UDim2.new(1, -107, 0, 12),
    BackgroundTransparency = 1,
    Text = "SCRIPT HUB  /  V0.1",
    Font = Enum.Font.Gotham,
    TextColor3 = theme.muted,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
}, header)

-- Small independent floating launcher, visible while the window is minimized.
local floating = button(gui, "M", UDim2.fromOffset(14, 92), UDim2.fromOffset(38, 38), nil, true)
floating.Name = "MonarcaFloatingLauncher"
floating.Visible = false
floating.ZIndex = 20
floating.TextSize = 14
floating.TextColor3 = theme.text
floating.Active = true
local floatingCorner = floating:FindFirstChildOfClass("UICorner")
if floatingCorner then floatingCorner.CornerRadius = UDim.new(1, 0) end
new("UIStroke", {
    Color = Color3.fromRGB(213, 185, 255),
    Thickness = 1.4,
    Transparency = 0.15,
}, floating)
local function minimize()
    main.Visible = false
    floating.Visible = true
    setBlur(false)
end
button(header, "–", UDim2.new(1, -73, 0, 8), UDim2.fromOffset(28, 28), minimize)
local closeButton = button(header, "×", UDim2.new(1, -40, 0, 8), UDim2.fromOffset(28, 28))
closeButton.TextColor3 = theme.danger

-- Open on pointer release instead of Activated: Activated can fire before
-- InputEnded on touch devices, leaving the previous drag guard stuck.
local floatingDragInput, floatingDragStart, floatingStart
local floatingMoved = false
local function showWindow()
    if destroyed or main.Visible then return end
    floating.Visible = false
    main.Visible = true
    setBlur(true)
end
floating.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Touch
        and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    floatingDragInput = input
    floatingDragStart = Vector2.new(input.Position.X, input.Position.Y)
    floatingStart = Vector2.new(floating.Position.X.Offset, floating.Position.Y.Offset)
    floatingMoved = false
end)
connect(Services.UserInputService.InputChanged, function(input)
    if not floatingDragInput then return end
    if input ~= floatingDragInput and not (
        floatingDragInput.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseMovement
    ) then return end
    local delta = Vector2.new(input.Position.X, input.Position.Y) - floatingDragStart
    if delta.Magnitude > 6 then floatingMoved = true end
    if not floatingMoved then return end
    local vp = viewport()
    floating.Position = UDim2.fromOffset(
        math.clamp(floatingStart.X + delta.X, 4, math.max(4, vp.X - 42)),
        math.clamp(floatingStart.Y + delta.Y, 4, math.max(4, vp.Y - 42))
    )
end)
connect(Services.UserInputService.InputEnded, function(input)
    if not floatingDragInput then return end
    if input ~= floatingDragInput and not (
        floatingDragInput.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseButton1
    ) then return end
    local wasTap = not floatingMoved
    floatingDragInput = nil
    floatingDragStart = nil
    floatingStart = nil
    floatingMoved = false
    if wasTap then showWindow() end
end)
-- Retain keyboard/gamepad support without routing touch/mouse through Activated.
floating.Activated:Connect(function(inputObject)
    if inputObject and inputObject.UserInputType == Enum.UserInputType.Gamepad1 then
        showWindow()
    end
end)

-- Horizontal navigation leaves the full panel width available on mobile.
local sidebar = new("Frame", {
    Name = "TabBar",
    Position = UDim2.fromOffset(0, HEADER_HEIGHT),
    Size = UDim2.new(1, 0, 0, NAV_HEIGHT),
    BackgroundColor3 = theme.surface,
    BackgroundTransparency = 0.18,
    BorderSizePixel = 0,
}, main)
new("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 4),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, sidebar)
new("UIPadding", {
    PaddingLeft = UDim.new(0, 8),
    PaddingRight = UDim.new(0, 8),
}, sidebar)
local area = new("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(0, HEADER_HEIGHT + NAV_HEIGHT),
}, main)

local footer = new("TextLabel", {
    Position = UDim2.new(0, 14, 1, -21),
    Size = UDim2.new(1, -28, 0, 16),
    BackgroundTransparency = 1,
    TextColor3 = theme.muted,
    Text = "Monarca pronto",
    TextSize = 11,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
}, main)
local function status(message)
    if not destroyed and settings.notifications then footer.Text = message end
end
local pages, navButtons = {}, {}
local currentTab = "Home"
local function page(name)
    local scroller = new("ScrollingFrame", {
        Name = name,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = theme.accent,
        Visible = false,
        CanvasSize = UDim2.new(),
    }, area)
    local stack = new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 7),
    }, scroller)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 9),
        PaddingLeft = UDim.new(0, 13),
        PaddingRight = UDim.new(0, 13),
        PaddingBottom = UDim.new(0, 9),
    }, scroller)
    connect(stack:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        scroller.CanvasSize = UDim2.fromOffset(0, stack.AbsoluteContentSize.Y + 18)
    end)
    pages[name] = scroller
    return scroller
end
local function switch(name)
    currentTab = name
    for key, scroller in pairs(pages) do scroller.Visible = key == name end
    for key, b in pairs(navButtons) do
        tween(b, {BackgroundColor3 = key == name and theme.card or theme.surface}, 0.12)
        b.TextColor3 = key == name and theme.accent or theme.muted
    end
end
for index, name in ipairs({"Home", "Scripts", "Player", "Settings"}) do
    page(name)
    local b = button(sidebar, name, nil, UDim2.new(0.25, -7, 0, 29), function() switch(name) end)
    b.Font = Enum.Font.Gotham
    b.LayoutOrder = index
    b.TextXAlignment = Enum.TextXAlignment.Center
    navButtons[name] = b
end
local function title(section, heading, detail)
    label(section, heading, 17, theme.text, 24).Font = Enum.Font.GothamBold
    label(section, detail, 11, theme.muted, 26)
end
local function card(section, height)
    local frame = new("Frame", {
        Size = UDim2.new(1, -2, 0, height or 70),
        BackgroundColor3 = theme.surface,
    }, section)
    ordered(section, frame)
    frame.BackgroundTransparency = 0.16
    rounded(frame, 15)
    outlined(frame)
    return frame
end
local function cardText(frame, heading, detail, extraRight)
    local t = label(frame, heading, 13, theme.text, 21)
    t.Position = UDim2.fromOffset(12, 7)
    t.Size = UDim2.new(1, -(extraRight or 24), 0, 21)
    t.Font = Enum.Font.GothamBold
    local d = label(frame, detail, 11, theme.muted, 30)
    d.Position = UDim2.fromOffset(12, 29)
    d.Size = UDim2.new(1, -24, 0, 30)
end
local function toggle(section, heading, detail, value, changed)
    local row = card(section, 60)
    local t = label(row, heading, 13, theme.text, 21)
    t.Position = UDim2.fromOffset(12, 8)
    t.Size = UDim2.new(1, -82, 0, 21)
    local d = label(row, detail, 10, theme.muted, 23)
    d.Position = UDim2.fromOffset(12, 30)
    d.Size = UDim2.new(1, -82, 0, 23)
    local b = button(row, "", UDim2.new(1, -61, 0, 18), UDim2.fromOffset(47, 25))
    local knob = new("Frame", {
        Size = UDim2.fromOffset(19, 19),
        BackgroundColor3 = theme.text,
    }, b)
    rounded(knob, 10)
    local selected = value
    local function repaint()
        tween(b, {BackgroundColor3 = selected and theme.accent or theme.border})
        tween(knob, {Position = UDim2.fromOffset(selected and 24 or 3, 3)})
    end
    b.Activated:Connect(function()
        selected = not selected
        repaint()
        changed(selected)
    end)
    repaint()
    return row
end
local function slider(section, heading, minimum, maximum, initial, changed)
    local row = card(section, 66)
    local t = label(row, heading, 13, theme.text, 20)
    t.Position = UDim2.fromOffset(12, 6)
    t.Size = UDim2.new(1, -90, 0, 20)
    local number = label(row, tostring(initial), 12, theme.accent, 20)
    number.Position = UDim2.new(1, -69, 0, 6)
    number.Size = UDim2.fromOffset(55, 20)
    number.TextXAlignment = Enum.TextXAlignment.Right
    local track = new("Frame", {
        Position = UDim2.new(0, 13, 0, 43),
        Size = UDim2.new(1, -26, 0, 5),
        BackgroundColor3 = theme.border,
        BorderSizePixel = 0,
        Active = true,
    }, row)
    rounded(track, 4)
    local fill = new("Frame", {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = theme.accent,
        BorderSizePixel = 0,
    }, track)
    rounded(fill, 4)
    local knob = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(15, 15),
        BackgroundColor3 = theme.accent,
    }, track)
    rounded(knob, 9)
    local current = initial
    local dragging, trackedInput = false, nil
    local function paint(value)
        current = math.clamp(math.floor(value + 0.5), minimum, maximum)
        local fraction = (current - minimum) / (maximum - minimum)
        fill.Size = UDim2.fromScale(fraction, 1)
        knob.Position = UDim2.fromScale(fraction, 0.5)
        number.Text = tostring(current)
    end
    local function updateAt(x)
        if track.AbsoluteSize.X < 1 then return end
        local fraction = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local value = math.floor(minimum + fraction * (maximum - minimum) + 0.5)
        if value ~= current then paint(value); changed(value) end
    end
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            trackedInput = input
            updateAt(input.Position.X)
        end
    end)
    connect(Services.UserInputService.InputChanged, function(input)
        if not dragging then return end
        if trackedInput.UserInputType == Enum.UserInputType.Touch then
            if input == trackedInput then updateAt(input.Position.X) end
        elseif input.UserInputType == Enum.UserInputType.MouseMovement then
            updateAt(input.Position.X)
        end
    end)
    connect(Services.UserInputService.InputEnded, function(input)
        if input == trackedInput
            or (trackedInput and trackedInput.UserInputType == Enum.UserInputType.MouseButton1
                and input.UserInputType == Enum.UserInputType.MouseButton1) then
            dragging = false
            trackedInput = nil
        end
    end)
    paint(initial)
    return row, paint
end

local home = pages.Home
title(home, "Bem-vindo ao Monarca", "Seu painel pessoal para ferramentas locais e visuais.")
local homeCard = card(home, 92)
cardText(homeCard, "Scripts modulares", "Os scripts são obtidos deste repositório GitHub. Abra Scripts para ativá-los.")
button(homeCard, "VER SCRIPTS", UDim2.new(0, 12, 1, -33), UDim2.fromOffset(118, 26), function()
    switch("Scripts")
end, true)
local homeInfo = card(home, 70)
cardText(homeInfo, "Compatibilidade", "Modificações locais podem ser substituídas pelo jogo. O salvamento depende do executor.")

local playerPage = pages.Player
title(playerPage, "Player", "Ajustes locais do personagem e da câmera.")
local function applyPlayer()
    local cam = workspace.CurrentCamera
    if cam then pcall(function() cam.FieldOfView = settings.fieldOfView end) end
    local character = player.Character
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            hum.WalkSpeed = settings.walkSpeed
            hum.UseJumpPower = true
            hum.JumpPower = settings.jumpPower
        end)
    end
end
local playerAdjusted = settings.playerCustomized
local _, paintFov = slider(playerPage, "Campo de visão (FOV)", 60, 110, settings.fieldOfView, function(v)
    settings.fieldOfView = v
    settings.playerCustomized = true
    playerAdjusted = true
    applyPlayer()
    save()
end)
local _, paintWalk = slider(playerPage, "Velocidade local", 8, 32, settings.walkSpeed, function(v)
    settings.walkSpeed = v
    settings.playerCustomized = true
    playerAdjusted = true
    applyPlayer()
    save()
end)
local _, paintJump = slider(playerPage, "Força de salto", 25, 100, settings.jumpPower, function(v)
    settings.jumpPower = v
    settings.playerCustomized = true
    playerAdjusted = true
    applyPlayer()
    save()
end)
local resetPlayer = card(playerPage, 57)
button(resetPlayer, "RESTAURAR PADRÕES", UDim2.fromOffset(11, 12), UDim2.new(1, -22, 0, 33), function()
    settings.fieldOfView, settings.walkSpeed, settings.jumpPower = 70, 16, 50
    paintFov(70); paintWalk(16); paintJump(50)
    settings.playerCustomized = false
    playerAdjusted = false
    applyPlayer()
    save()
    status("Controles do Player restaurados.")
end, true)
connect(player.CharacterAdded, function()
    task.delay(0.8, function()
        if not destroyed and playerAdjusted then applyPlayer() end
    end)
end)

local settingsPage = pages.Settings
title(settingsPage, "Settings", "Preferências da interface e armazenamento.")
toggle(settingsPage, "Animações", "Transições suaves na interface", settings.animations, function(v)
    settings.animations = v
    save()
end)
toggle(settingsPage, "Notificações", "Mensagens de status na parte inferior", settings.notifications, function(v)
    settings.notifications = v
    footer.Text = v and "Notificações ativadas" or ""
    save()
end)
local storage = card(settingsPage, 80)
cardText(storage, "Persistência", type(writefile) == "function" and
    "O ambiente oferece writefile. Preferências podem ser gravadas em Monarca/settings.json." or
    "Sem writefile: as preferências valem somente nesta sessão.")
local resetSettings = card(settingsPage, 58)
button(resetSettings, "REDEFINIR PREFERÊNCIAS", UDim2.fromOffset(10, 11), UDim2.new(1, -20, 0, 35), function()
    for k, v in pairs(defaults) do settings[k] = v end
    playerAdjusted = false
    paintFov(70); paintWalk(16); paintJump(50)
    applyPlayer()
    save()
    status("Preferências restauradas. Reabra o Hub para atualizar os controles.")
end)

local scriptsPage = pages.Scripts
title(scriptsPage, "Scripts", "Módulos locais, organizados por categoria.")
local controls = card(scriptsPage, 82)
local search = new("TextBox", {
    Position = UDim2.fromOffset(10, 8),
    Size = UDim2.new(1, -20, 0, 28),
    BackgroundColor3 = theme.card,
    TextColor3 = theme.text,
    PlaceholderColor3 = theme.muted,
    PlaceholderText = "Buscar scripts...",
    Text = "",
    TextSize = 12,
    Font = Enum.Font.Gotham,
    ClearTextOnFocus = false,
}, controls)
rounded(search, 12)
new("UIPadding", {PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9)}, search)
local category = "Todos"
local renderModules
local filterButton = button(controls, "TODOS  ▾", UDim2.fromOffset(10, 44), UDim2.new(0.5, -14, 0, 28))
local updateButton = button(controls, "ATUALIZAR", UDim2.new(0.5, 4, 0, 44), UDim2.new(0.5, -14, 0, 28), nil, true)
local dropdown = card(scriptsPage, 103)
dropdown.Visible = false
for index, name in ipairs({"Todos", "Visual", "Utilidades"}) do
    button(dropdown, name, UDim2.new(0, 8, 0, 6 + (index - 1) * 31), UDim2.new(1, -16, 0, 27), function()
        category = name
        filterButton.Text = string.upper(name) .. "  ▾"
        dropdown.Visible = false
        if renderModules then renderModules() end
    end)
end
filterButton.Activated:Connect(function()
    dropdown.Visible = not dropdown.Visible
end)
local moduleArea = new("Frame", {
    Name = "ModuleArea",
    LayoutOrder = 1000,
    Size = UDim2.new(1, -2, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
}, scriptsPage)
new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 7)}, moduleArea)

local function fetch(path)
    local url = repository .. path .. "?t=" .. tostring(os.time())
    return game:HttpGet(url)
end
local function compile(source, chunk)
    if type(loadstring) ~= "function" then error("Este ambiente não oferece loadstring") end
    local fn, err = loadstring(source, chunk)
    if not fn then error(err or "Erro ao compilar script") end
    return fn
end
local function disableModule(id)
    local module = loadedModules[id]
    if activeModules[id] and module and type(module.disable) == "function" then
        local ok, err = pcall(module.disable, module)
        if not ok then status("Erro ao desativar " .. id .. ": " .. tostring(err)) end
    end
    activeModules[id] = nil
end
local function disableAll()
    for id in pairs(activeModules) do disableModule(id) end
end
local function enableModule(id)
    local mod = loadedModules[id]
    if not mod then
        local source = fetch("modules/" .. id .. ".lua")
        mod = compile(source, "Monarca/" .. id)()
        assert(type(mod) == "table" and type(mod.enable) == "function"
            and type(mod.disable) == "function", "Módulo inválido: " .. id)
        loadedModules[id] = mod
    end
    mod:enable()
    activeModules[id] = true
end
renderModules = function()
    for _, child in ipairs(moduleArea:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
    local count = 0
    for _, info in ipairs(catalog) do
        local query = search.Text:lower()
        local matching = query == "" or info.name:lower():find(query, 1, true)
            or info.description:lower():find(query, 1, true)
        if matching and (category == "Todos" or info.category == category) then
            count = count + 1
            local frame = card(moduleArea, 100)
            cardText(frame, info.name, info.description)
            local active = activeModules[info.id] == true
            local action = button(frame, active and "DESATIVAR" or "ATIVAR",
                UDim2.new(1, -100, 1, -34), UDim2.fromOffset(90, 26), function()
                    local ok, err
                    if activeModules[info.id] then
                        ok, err = pcall(disableModule, info.id)
                    else
                        ok, err = pcall(enableModule, info.id)
                    end
                    if ok then
                        status(info.name .. (activeModules[info.id] and " ativado" or " desativado"))
                    else
                        status("Falha em " .. info.name .. ": " .. tostring(err))
                    end
                    renderModules()
                end, not active)
            if active then action.TextColor3 = theme.muted end
            local badge = label(frame, string.upper(info.category), 10, theme.accent, 18)
            badge.Position = UDim2.fromOffset(12, 78)
            badge.Size = UDim2.new(1, -110, 0, 18)
        end
    end
    if count == 0 then
        local noResults = card(moduleArea, 64)
        cardText(noResults, "Nenhum script", "Atualize o catálogo ou altere seus filtros.")
    end
end
local function refresh()
    status("Buscando catálogo no GitHub...")
    updateButton.Text = "CARREGANDO..."
    local ok, value = pcall(function()
        local raw = fetch("manifest.lua")
        local data = compile(raw, "Monarca/manifest")()
        assert(type(data) == "table" and type(data.modules) == "table", "Manifesto inválido")
        local filtered, used = {}, {}
        for _, entry in ipairs(data.modules) do
            if type(entry) == "table"
                and type(entry.id) == "string"
                and entry.id:match("^[a-z0-9_-]+$")
                and #entry.id <= 40
                and not used[entry.id]
                and type(entry.name) == "string"
                and type(entry.description) == "string"
                and (entry.category == "Visual" or entry.category == "Utilidades") then
                used[entry.id] = true
                table.insert(filtered, entry)
            end
        end
        return filtered
    end)
    if ok then
        disableAll()
        loadedModules, catalog = {}, value
        renderModules()
        status("Catálogo atualizado: " .. #catalog .. " módulos")
    else
        status("Falha na atualização: " .. tostring(value))
    end
    updateButton.Text = "ATUALIZAR"
end
updateButton.Activated:Connect(refresh)
search:GetPropertyChangedSignal("Text"):Connect(renderModules)
 
local dragging, dragInput, dragStart, offsetStart = false, nil, nil, nil
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging, dragInput = true, input
        dragStart, offsetStart = input.Position, windowOffset
    end
end)
connect(Services.UserInputService.InputChanged, function(input)
    if not dragging then return end
    if (dragInput.UserInputType == Enum.UserInputType.Touch and input == dragInput)
        or (dragInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement) then
        local delta = input.Position - dragStart
        windowOffset = offsetStart + Vector2.new(delta.X, delta.Y)
        layout()
    end
end)
connect(Services.UserInputService.InputEnded, function(input)
    if input == dragInput or (dragInput
        and dragInput.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseButton1) then
        dragging, dragInput = false, nil
    end
end)
local function destroy()
    if destroyed then return end
    disableAll()
    if hubBlur then
        pcall(function() hubBlur:Destroy() end)
        hubBlur = nil
    end
    destroyed = true
    for _, connection in ipairs(connections) do connection:Disconnect() end
     if env.MONARCA_HUB then env.MONARCA_HUB = nil end
    pcall(function() gui:Destroy() end)
end
closeButton.Activated:Connect(destroy)
env.MONARCA_HUB = {destroy = destroy}
local function updateLayout()
    layout()
    sidebar.Size = UDim2.new(1, 0, 0, NAV_HEIGHT)
    area.Position = UDim2.fromOffset(0, HEADER_HEIGHT + NAV_HEIGHT)
    area.Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + NAV_HEIGHT + FOOTER_HEIGHT))
    local vp = viewport()
    floating.Position = UDim2.fromOffset(
        math.clamp(floating.Position.X.Offset, 4, math.max(4, vp.X - 42)),
        math.clamp(floating.Position.Y.Offset, 4, math.max(4, vp.Y - 42))
    )
end
if camera then
    connect(camera:GetPropertyChangedSignal("ViewportSize"), updateLayout)
end
connect(workspace:GetPropertyChangedSignal("CurrentCamera"), function()
    updateLayout()
end)
updateLayout()
switch("Home")
setBlur(true)
if playerAdjusted then applyPlayer() end
task.spawn(refresh)
