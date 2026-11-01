-- Monarca Script Hub v0.4.1 — stable target poses and third-person view
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
-- SkyNetApi v15: near-black surfaces and restrained violet accents.
local theme = {
    background = Color3.fromRGB(5, 5, 6),
    surface = Color3.fromRGB(11, 11, 13),
    card = Color3.fromRGB(21, 21, 24),
    border = Color3.fromRGB(37, 37, 41),
    accent = Color3.fromRGB(142, 130, 232),
    text = Color3.fromRGB(244, 244, 240),
    whiteLine = Color3.fromRGB(244, 244, 240),
    primary = Color3.fromRGB(244, 244, 240),
    muted = Color3.fromRGB(151, 151, 157),
    danger = Color3.fromRGB(235, 127, 136),
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
    new("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, object)
end
local function outlined(object)
    new("UIStroke", {Color = theme.whiteLine, Thickness = 1, Transparency = 0.86, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, object)
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
        BackgroundColor3 = accent and theme.primary or theme.card,
        TextColor3 = accent and theme.background or theme.text,
        Text = value,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = false,
    }, parent)
    rounded(b, 8)
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

-- Fetch the official image from this repository and adapt it for executors
-- that support local image files. ImageLabel cannot render a raw HTTPS URL.
-- If these APIs are absent, the rest of the hub remains fully functional.
local function loadMonarcaIcon(onLoaded)
    task.spawn(function()
        local resolver = nil
        if type(getcustomasset) == "function" then
            resolver = getcustomasset
        elseif type(getsynasset) == "function" then
            resolver = getsynasset
        end
        if not resolver then return end

        local localPath = "Monarca/monarca-icon-v1.jpg"
        local available = false
        if type(isfile) == "function" then
            local ok, exists = pcall(isfile, localPath)
            available = ok and exists == true
        end
        if not available and type(writefile) == "function" then
            local ok, bytes = pcall(function()
                return game:HttpGet(repository .. "assets/monarca-icon.jpg")
            end)
            -- Check the JPEG signature and cap downloaded data.
            if ok and type(bytes) == "string" and #bytes > 100
                and #bytes < 250000
                and bytes:sub(1, 3) == string.char(255, 216, 255) then
                pcall(function()
                    if type(makefolder) == "function" then
                        if type(isfolder) ~= "function" or not isfolder("Monarca") then
                            makefolder("Monarca")
                        end
                    end
                    writefile(localPath, bytes)
                end)
            end
        end
        local ok, id = pcall(resolver, localPath)
        if ok and type(id) == "string" and id ~= "" and not destroyed then
            onLoaded(id)
        end
    end)
end

-- Play the supplied Arise intro only on initial execution.
-- This requires an executor that supports writefile and getcustomasset/getsynasset.
-- A missing/blocked local sound must never prevent the hub from opening.
local startupSound = nil
local function playStartupAudio()
    task.spawn(function()
        local resolver = type(getcustomasset) == "function" and getcustomasset
            or (type(getsynasset) == "function" and getsynasset or nil)
        if not resolver then return end
        local path = "Monarca/arise-intro-v1.mp3"
        local exists = false
        if type(isfile) == "function" then
            local ok, value = pcall(isfile, path)
            exists = ok and value
        end
        if not exists and type(writefile) == "function" then
            local ok, data = pcall(function()
                return game:HttpGet(repository .. "assets/arise-intro.mp3")
            end)
            if ok and type(data) == "string" and #data > 1000
                and #data < 300000 and
                (data:sub(1, 3) == "ID3"
                    or (data:byte(1) == 255 and data:byte(2) >= 224)) then
                pcall(function()
                    if type(makefolder) == "function" then
                        if type(isfolder) ~= "function" or not isfolder("Monarca") then
                            makefolder("Monarca")
                        end
                    end
                    writefile(path, data)
                    exists = true
                end)
            end
        end
        if not exists and type(isfile) == "function" then return end
        local ok, asset = pcall(resolver, path)
        if not ok or type(asset) ~= "string" or asset == "" or destroyed then return end
        local sound = new("Sound", {
            Name = "MonarcaAriseIntro",
            SoundId = asset,
            Volume = 0.8,
            PlaybackSpeed = 1,
            Looped = false,
        }, game:GetService("SoundService"))
        if destroyed then sound:Destroy(); return end
        startupSound = sound
        local played = pcall(function() sound:Play() end)
        if not played then
            sound:Destroy()
            startupSound = nil
            return
        end
        task.delay(5, function()
            if sound and sound.Parent then pcall(function() sound:Destroy() end) end
            if startupSound == sound then startupSound = nil end
        end)
    end)
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

-- Lightweight, 8px-radius startup scene with a real initialization progress bar.
local introBackdrop = new("Frame", {
    Name = "MonarcaStartup",
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = theme.background,
    BackgroundTransparency = 0.25,
    BorderSizePixel = 0,
    ZIndex = 100,
}, gui)
local introPanel = new("Frame", {
    Name = "StartupPanel",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(308, 166),
    BackgroundColor3 = theme.surface,
    BorderSizePixel = 0,
    ZIndex = 101,
}, introBackdrop)
rounded(introPanel, 8)
new("UIStroke", {
    Color = theme.border, Transparency = 0.4, Thickness = 1,
}, introPanel)
local introScale = new("UIScale", {Scale = 0.9}, introPanel)
local introTitle = new("TextLabel", {
    Position = UDim2.fromOffset(19, 18),
    Size = UDim2.new(1, -38, 0, 34),
    BackgroundTransparency = 1,
    Text = "MONARCA",
    TextSize = 27,
    TextColor3 = theme.text,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 103,
}, introPanel)
local introAccent = new("Frame", {
    Position = UDim2.fromOffset(19, 61),
    Size = UDim2.fromOffset(35, 3),
    BackgroundColor3 = theme.accent,
    BorderSizePixel = 0,
    ZIndex = 103,
}, introPanel)
rounded(introAccent, 2)
local introText = new("TextLabel", {
    Position = UDim2.fromOffset(19, 77),
    Size = UDim2.new(1, -75, 0, 20),
    BackgroundTransparency = 1,
    Text = "INICIALIZANDO...",
    TextSize = 11,
    Font = Enum.Font.GothamMedium,
    TextColor3 = theme.muted,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 103,
}, introPanel)
local introPercent = new("TextLabel", {
    Position = UDim2.new(1, -62, 0, 77),
    Size = UDim2.fromOffset(43, 20),
    BackgroundTransparency = 1,
    Text = "0%",
    TextSize = 12,
    Font = Enum.Font.GothamBold,
    TextColor3 = theme.accent,
    TextXAlignment = Enum.TextXAlignment.Right,
    ZIndex = 103,
}, introPanel)
local introTrack = new("Frame", {
    Position = UDim2.fromOffset(19, 114),
    Size = UDim2.new(1, -38, 0, 6),
    BackgroundColor3 = theme.border,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 103,
}, introPanel)
rounded(introTrack, 3)
local introFill = new("Frame", {
    Size = UDim2.fromScale(0, 1),
    BackgroundColor3 = theme.accent,
    BorderSizePixel = 0,
    ZIndex = 104,
}, introTrack)
rounded(introFill, 3)
local introFooter = new("TextLabel", {
    Position = UDim2.fromOffset(19, 131),
    Size = UDim2.new(1, -38, 0, 15),
    BackgroundTransparency = 1,
    Text = "Criando sua experiência visual",
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextColor3 = theme.muted,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 103,
}, introPanel)
local function introProgress(fraction, message)
    if destroyed or not introPanel.Parent then return end
    local f = math.clamp(fraction, 0, 1)
    introText.Text = message
    introPercent.Text = tostring(math.floor(f * 100 + 0.5)) .. "%"
    tween(introFill, {Size = UDim2.fromScale(f, 1)}, 0.19)
end
tween(introScale, {Scale = 1}, 0.36)
playStartupAudio()

local main = new("Frame", {
    Name = "Window",
    Visible = false,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    BackgroundColor3 = theme.background,
    BackgroundTransparency = 0.03,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, gui)
rounded(main, 8)
outlined(main)

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
    BackgroundTransparency = 0.06,
    BorderSizePixel = 0,
    Active = true,
}, main)
-- Keep the branding image exclusive to the floating launcher.
new("Frame", {
    Position = UDim2.fromOffset(12, 13),
    Size = UDim2.fromOffset(2, 19),
    BackgroundColor3 = theme.whiteLine,
    BackgroundTransparency = 0.10,
    BorderSizePixel = 0,
}, header)
new("TextLabel", {
    Position = UDim2.fromOffset(26, 6),
    Size = UDim2.new(1, -110, 0, 20),
    BackgroundTransparency = 1,
    Text = "MONARCA",
    Font = Enum.Font.GothamBold,
    TextColor3 = theme.text,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
}, header)
new("TextLabel", {
    Position = UDim2.fromOffset(26, 26),
    Size = UDim2.new(1, -110, 0, 12),
    BackgroundTransparency = 1,
    Text = "VISUAL HUB  /  V0.4.1",
    Font = Enum.Font.Gotham,
    TextColor3 = theme.muted,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
}, header)

-- Floating icon uses the exact repository image when available, not a plain M.
local floating = new("ImageButton", {
    Name = "MonarcaFloatingLauncher",
    Position = UDim2.fromOffset(14, 92),
    Size = UDim2.fromOffset(40, 40),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Image = "",
    ScaleType = Enum.ScaleType.Fit,
    Visible = false,
    ZIndex = 20,
    Active = true,
}, gui)
rounded(floating, 8)
local floatingPlaceholder = new("TextLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = theme.surface,
    Text = "M",
    Font = Enum.Font.GothamBold,
    TextSize = 19,
    TextColor3 = theme.accent,
    ZIndex = 21,
}, floating)
rounded(floatingPlaceholder, 8)

-- The provided purple image is the floating launcher's full visual.
-- Keep the fallback only when the runtime cannot load local image assets.
loadMonarcaIcon(function(asset)
    if destroyed then return end
    floating.Image = asset
    floatingPlaceholder.Visible = false
end)
local function minimize()
    main.Visible = false
    floating.Visible = true
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
-- Underline tabs preserve horizontal space on mobile.
local sidebar = new("Frame", {
    Name = "TabBar",
    Position = UDim2.fromOffset(0, HEADER_HEIGHT),
    Size = UDim2.new(1, 0, 0, NAV_HEIGHT),
    BackgroundColor3 = theme.surface,
    BackgroundTransparency = 0.06,
    BorderSizePixel = 0,
}, main)
new("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 0),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, sidebar)
new("UIPadding", {
    PaddingLeft = UDim.new(0, 7),
    PaddingRight = UDim.new(0, 7),
}, sidebar)
-- Divider is parented outside the UIListLayout, so it never consumes a tab slot.
new("Frame", {
    Name = "TabsDivider",
    Position = UDim2.new(0, 0, 0, HEADER_HEIGHT + NAV_HEIGHT - 1),
    Size = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = theme.whiteLine,
    BackgroundTransparency = 0.88,
    BorderSizePixel = 0,
    ZIndex = 2,
}, main)

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
local pages, navButtons, navUnderlines = {}, {}, {}
local currentTab = "Home"
local function page(name)
    -- Home retains its current compact profile composition.
    -- Other tabs use a smaller control scale and larger section spacing.
    local isHome = name == "Home"
    local scroller = new("ScrollingFrame", {
        Name = name,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = theme.accent,
        Visible = false,
        CanvasSize = UDim2.new(),
    }, area)
    local stack = new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, isHome and 8 or 15),
    }, scroller)
    new("UIPadding", {
        PaddingTop = UDim.new(0, isHome and 12 or 17),
        PaddingLeft = UDim.new(0, isHome and 15 or 17),
        PaddingRight = UDim.new(0, isHome and 15 or 17),
        PaddingBottom = UDim.new(0, isHome and 14 or 18),
    }, scroller)
    connect(stack:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        scroller.CanvasSize = UDim2.fromOffset(0, stack.AbsoluteContentSize.Y + (isHome and 28 or 35))
    end)
    pages[name] = scroller
    return scroller
end
local function switch(name)
    currentTab = name
    for key, scroller in pairs(pages) do scroller.Visible = key == name end
    for key, b in pairs(navButtons) do
        local selected = key == name
        tween(b, {TextColor3 = selected and theme.text or theme.muted}, 0.16)
        if navUnderlines[key] then
            tween(navUnderlines[key], {BackgroundTransparency = selected and 0 or 1}, 0.16)
        end
    end
end
for index, name in ipairs({"Home", "Alvo", "Visual", "Player", "Settings"}) do
    page(name)
    local b = new("TextButton", {
        Name = "Tab" .. name,
        Size = UDim2.new(0.2, -1, 0, NAV_HEIGHT),
        LayoutOrder = index,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = name,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = theme.muted,
        TextXAlignment = Enum.TextXAlignment.Center,
    }, sidebar)
    navUnderlines[name] = new("Frame", {
        Name = "SelectedUnderline",
        Position = UDim2.new(0.17, 0, 1, -3),
        Size = UDim2.new(0.66, 0, 0, 1),
        BackgroundColor3 = theme.whiteLine,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, b)
    b.Activated:Connect(function() switch(name) end)
    navButtons[name] = b
end

local function title(section, heading, detail)
    label(section, heading, 16, theme.text, 23).Font = Enum.Font.GothamBold
    label(section, detail, 11, theme.muted, 22)
end
-- Borderless controls; muted divider lines replace stacked boxed cards.
local function card(section, height)
    local frame = new("Frame", {
        Size = UDim2.new(1, -2, 0, height or 70),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, section)
    ordered(section, frame)
    new("Frame", {
        Name = "RowDivider",
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = theme.whiteLine,
        BackgroundTransparency = 0.91,
        BorderSizePixel = 0,
    }, frame)
    return frame
end

local function cardText(frame, heading, detail, extraRight)
    local t = label(frame, heading, 13, theme.text, 20)
    t.Position = UDim2.fromOffset(10, 7)
    t.Size = UDim2.new(1, -(extraRight or 20), 0, 20)
    t.Font = Enum.Font.GothamBold
    local d = label(frame, detail, 11, theme.muted, 37)
    d.Position = UDim2.fromOffset(10, 28)
    d.Size = UDim2.new(1, -20, 0, 37)
end
local function toggle(section, heading, detail, value, changed)
    local row = card(section, 55)
    local t = label(row, heading, 13, theme.text, 20)
    t.Position = UDim2.fromOffset(10, 7)
    t.Size = UDim2.new(1, -74, 0, 20)
    local d = label(row, detail, 11, theme.muted, 22)
    d.Position = UDim2.fromOffset(10, 28)
    d.Size = UDim2.new(1, -74, 0, 22)
    local b = button(row, "", UDim2.new(1, -55, 0, 16), UDim2.fromOffset(43, 23))
    local knob = new("Frame", {
        Size = UDim2.fromOffset(17, 17),
        BackgroundColor3 = theme.text,
    }, b)
    rounded(knob, 8)
    local selected = value
    local function repaint()
        tween(b, {BackgroundColor3 = selected and theme.accent or theme.border})
        tween(knob, {Position = UDim2.fromOffset(selected and 23 or 3, 3)})
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
    local row = card(section, 61)
    local t = label(row, heading, 13, theme.text, 19)
    t.Position = UDim2.fromOffset(10, 7)
    t.Size = UDim2.new(1, -83, 0, 19)
    local number = label(row, tostring(initial), 12, theme.accent, 19)
    number.Position = UDim2.new(1, -65, 0, 7)
    number.Size = UDim2.fromOffset(53, 19)
    number.TextXAlignment = Enum.TextXAlignment.Right
    local track = new("Frame", {
        Position = UDim2.new(0, 11, 0, 40),
        Size = UDim2.new(1, -22, 0, 4),
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
        Size = UDim2.fromOffset(13, 13),
        BackgroundColor3 = theme.accent,
    }, track)
    rounded(knob, 8)
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

-- Borderless profile hero inspired by information-first mobile profile layouts.
-- No profile card, backing rectangles, frames, badges or avatar borders.
local profile = ordered(home, new("Frame", {
    Name = "PlayerProfile",
    Size = UDim2.new(1, -2, 0, 212),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
}, home))

local avatar = new("ImageLabel", {
    Name = "PlayerAvatar",
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Position = UDim2.fromOffset(4, 8),
    Size = UDim2.fromOffset(180, 196),
    ScaleType = Enum.ScaleType.Fit,
    Image = "",
}, profile)

local details = new("Frame", {
    Name = "ProfileInformation",
    Position = UDim2.fromOffset(194, 10),
    Size = UDim2.new(1, -200, 0, 194),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
}, profile)

local infoLayout = new("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 2),
}, details)

local function profileLabel(order, value, font, color, height, fontSize)
    return new("TextLabel", {
        Name = "ProfileLine" .. tostring(order),
        LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = tostring(value),
        TextSize = fontSize,
        Font = font,
        TextColor3 = color,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextWrapped = false,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, details)
end

local eyebrow = profileLabel(1, "PERFIL DO JOGADOR", Enum.Font.GothamBold, theme.muted, 16, 11)
local displayNameLabel = profileLabel(2, player.DisplayName, Enum.Font.GothamBold, theme.text, 28, 22)
local nickLabel = profileLabel(3, "@" .. player.Name, Enum.Font.GothamMedium, theme.accent, 24, 18)
local idLabel = profileLabel(4, "ID  " .. tostring(player.UserId), Enum.Font.GothamMedium, theme.text, 26, 17)
local createdLabel = profileLabel(5, "Criação: carregando...", Enum.Font.GothamMedium, theme.text, 26, 17)
local dateLabel = profileLabel(6, "Hoje: --/--/----", Enum.Font.GothamMedium, theme.text, 26, 17)
local timeLabel = profileLabel(7, "Hora: --:--:--", Enum.Font.GothamMedium, theme.text, 26, 17)

local function updateProfileLayout()
    -- Expand the player photo wherever possible, without squeezing the metadata.
    -- On exceptionally narrow windows, stack content rather than truncate everything.
    local width = profile.AbsoluteSize.X
    if width <= 0 then return end
    if width < 285 then
        profile.Size = UDim2.new(1, -2, 0, 375)
        avatar.Size = UDim2.fromOffset(154, 166)
        avatar.Position = UDim2.new(0.5, -77, 0, 2)
        details.Position = UDim2.fromOffset(10, 177)
        details.Size = UDim2.new(1, -20, 0, 195)
    else
        profile.Size = UDim2.new(1, -2, 0, 212)
        local imageWidth
        if width < 350 then
            imageWidth = 126
        elseif width < 455 then
            imageWidth = 158
        else
            imageWidth = 192
        end
        avatar.Size = UDim2.fromOffset(imageWidth, 200)
        avatar.Position = UDim2.fromOffset(0, 5)
        local left = imageWidth + 10
        details.Position = UDim2.fromOffset(left, 10)
        details.Size = UDim2.new(1, -left - 5, 0, 194)
    end
    -- Main values stay readable on small phones; larger widths get stronger type.
    local compact = width < 350
    eyebrow.TextSize = compact and 10 or 11
    displayNameLabel.TextSize = compact and 19 or 23
    nickLabel.TextSize = compact and 16 or 19
    for _, info in ipairs({idLabel, createdLabel, dateLabel, timeLabel}) do
        info.TextSize = compact and 15 or 17
    end
end
connect(profile:GetPropertyChangedSignal("AbsoluteSize"), updateProfileLayout)
updateProfileLayout()

-- Bust thumbnail shows the character more prominently than a tiny headshot.
task.spawn(function()
    local ok, image = pcall(function()
        return Services.Players:GetUserThumbnailAsync(
            player.UserId, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size420x420
        )
    end)
    if destroyed then return end
    if ok and type(image) == "string" and image ~= "" then
        avatar.Image = image
    else
        avatar.Image = "rbxthumb://type=AvatarBust&id=" ..
            tostring(player.UserId) .. "&w=420&h=420"
    end
end)

-- Get exact profile creation date where possible; label fallback as approximate.
task.spawn(function()
    local estimated = DateTime.fromUnixTimestamp(os.time() - math.max(0, player.AccountAge) * 86400)
    local date = "~" .. estimated:FormatLocalTime("DD/MM/YYYY", "pt-br")
    local ok, value = pcall(function()
        local raw = game:HttpGet("https://users.roblox.com/v1/users/" .. tostring(player.UserId))
        local parsed = Services.HttpService:JSONDecode(raw)
        if type(parsed) ~= "table" or type(parsed.created) ~= "string" then return nil end
        local y, m, d = parsed.created:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")
        if y then return d .. "/" .. m .. "/" .. y end
        return nil
    end)
    if ok and type(value) == "string" then date = value end
    if not destroyed then createdLabel.Text = "Criação: " .. date end
end)

-- Day and local time refresh without rebuilding or shifting the profile layout.
task.spawn(function()
    while not destroyed do
        if home.Visible and main.Visible then
            local now = DateTime.now()
            local okDate, d = pcall(function()
                return now:FormatLocalTime("DD/MM/YYYY", "pt-br")
            end)
            local okTime, t = pcall(function()
                return now:FormatLocalTime("HH:mm:ss", "pt-br")
            end)
            if okDate then dateLabel.Text = "Hoje: " .. d end
            if okTime then timeLabel.Text = "Hora: " .. t end
        end
        task.wait(1)
    end
end)


-- ALVO. All actions run on the local player's character/camera only.
local alvo = pages.Alvo
local alvoHeading = ordered(alvo, new("TextLabel", {
    Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1,
    Text = "Alvo", Font = Enum.Font.GothamBold, TextSize = 16,
    TextColor3 = theme.text, TextXAlignment = Enum.TextXAlignment.Left,
}, alvo))
local alvoSearchBox = ordered(alvo, new("Frame", {
    Size = UDim2.new(1, 0, 0, 37), BackgroundColor3 = theme.surface,
    BorderSizePixel = 0,
}, alvo))
rounded(alvoSearchBox, 3)
new("UIStroke", {
    Color = theme.whiteLine, Thickness = 1, Transparency = 0.63,
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
}, alvoSearchBox)
local alvoSearch = new("TextBox", {
    Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0),
    Text = "", PlaceholderText = "Pesquisar nick ou apelido...",
    PlaceholderColor3 = theme.muted, ClearTextOnFocus = false,
    TextColor3 = theme.text, TextSize = 12, Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
}, alvoSearchBox)

local matchesFrame = ordered(alvo, new("Frame", {
    Name = "AlvoMatches", Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
}, alvo))
new("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5),
}, matchesFrame)
local alvoProfile = ordered(alvo, new("Frame", {
    Name = "AlvoProfile", Size = UDim2.new(1, 0, 0, 98),
    BackgroundTransparency = 1,
}, alvo))
local alvoAvatar = new("ImageLabel", {
    Position = UDim2.fromOffset(0, 1), Size = UDim2.fromOffset(88, 96),
    BackgroundTransparency = 1, Image = "", ScaleType = Enum.ScaleType.Fit,
}, alvoProfile)
local profileDetails = new("Frame", {
    Position = UDim2.fromOffset(100, 5),
    Size = UDim2.new(1, -100, 1, -10), BackgroundTransparency = 1,
}, alvoProfile)
new("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2),
}, profileDetails)
local function infoLine(n, text, sz, color)
    return new("TextLabel", {
        Name = "TargetInfo" .. n, LayoutOrder = n,
        Size = UDim2.new(1, 0, 0, n == 1 and 24 or 19),
        BackgroundTransparency = 1, Text = text,
        TextColor3 = color, TextSize = sz,
        Font = n == 1 and Enum.Font.GothamBold or Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, profileDetails)
end
local alvoName = infoLine(1, "Selecione um jogador", 15, theme.text)
local alvoNick = infoLine(2, "Nick ou apelido", 12, theme.accent)
local alvoId = infoLine(3, "ID: —", 11, theme.muted)
local alvoDist = infoLine(4, "Distância: —", 11, theme.muted)
local alvoDivider = ordered(alvo, new("Frame", {
    Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = theme.whiteLine,
    BackgroundTransparency = 0.86, BorderSizePixel = 0,
}, alvo))
local actionCaption = ordered(alvo, new("TextLabel", {
    Size = UDim2.new(1, 0, 0, 19), BackgroundTransparency = 1,
    Text = "CONTROLES", TextSize = 10, Font = Enum.Font.GothamBold,
    TextColor3 = theme.muted, TextXAlignment = Enum.TextXAlignment.Left,
}, alvo))
local actionGrid = ordered(alvo, new("Frame", {
    Name = "ActionGrid", Size = UDim2.new(1, 0, 0, 123),
    BackgroundTransparency = 1,
}, alvo))
new("UIGridLayout", {
    CellSize = UDim2.new(0.5, -5, 0, 34),
    CellPadding = UDim2.fromOffset(10, 10),
    FillDirection = Enum.FillDirection.Horizontal,
    SortOrder = Enum.SortOrder.LayoutOrder,
}, actionGrid)
local alvoFootnote = ordered(alvo, new("TextLabel", {
    Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1,
    Text = "Headsit e Backpack têm alinhamento físico; View segue em terceira pessoa.",
    TextSize = 10, Font = Enum.Font.Gotham, TextColor3 = theme.muted,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
}, alvo))
local selectedPlayer, savedPose, savedCamera = nil, nil, nil
local targetRespawnConnection = nil
local modes = {Headsit=false, Follow=false, View=false, TP=false, Backpack=false}
local modeButtons = {}
local rankedMatches = {}
local hiddenMatches = true
local thumbVersion = 0
local tickFollow, tickDistance = 0, 0
local runService = game:GetService("RunService")

local function root(char)
    return char and char:FindFirstChild("HumanoidRootPart")
end
local function targetParts()
    if not selectedPlayer or not selectedPlayer.Parent then return nil, nil end
    local char = selectedPlayer.Character
    return root(char), char and char:FindFirstChild("Head")
end

-- The solver follows a target-relative attachment rather than teleporting
-- HumanoidRootPart on every rendered frame. Only the local character receives
-- forces; the target stays unaffected.
local function restorePose()
    if not savedPose then return end
    local pose = savedPose
    savedPose = nil
    for _, obj in ipairs(pose.objects) do
        if obj and obj.Parent then pcall(function() obj:Destroy() end) end
    end
    for part, oldValue in pairs(pose.collisions) do
        if part.Parent then pcall(function() part.CanCollide = oldValue end) end
    end
    if pose.hum and pose.hum.Parent then
        pcall(function()
            pose.hum.AutoRotate = pose.rotate
            pose.hum.Sit = false
            pose.hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
    end
end
local function createPose(mode)
    local char = player.Character
    local own = root(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local target, head = targetParts()
    if not own or not hum or not target or
        (mode == "Headsit" and not head) then
        return false, "Personagem não disponível."
    end
    if hum.Health <= 0 then return false, "Seu personagem está sem vida." end
    -- Stable target root reference avoids bobbing with head animations.
    local elevation = 0
    if mode == "Headsit" then
        elevation = math.max(2.5,
            target.CFrame:PointToObjectSpace(head.Position).Y
            + head.Size.Y * 0.5 + 1.05)
    end
    local pose = {hum=hum,rotate=hum.AutoRotate,objects={},collisions={}}
    local function make(kind, fields, parent)
        local obj = new(kind, fields, parent)
        table.insert(pose.objects,obj)
        return obj
    end
    local ok, errorMessage = pcall(function()
        local attachOwn = make("Attachment",{
            Name="MonarcaPoseOwn",CFrame=CFrame.identity
        },own)
        local attachTarget = make("Attachment",{
            Name="MonarcaPoseTarget",
            Position=mode=="Headsit" and Vector3.new(0,elevation,0)
                or Vector3.new(0,0.3,1.35),
            -- Headsit faces the SAME way as target; Backpack faces backward.
            Orientation=Vector3.new(0,mode=="Headsit" and 0 or 180,0),
        },target)
        make("AlignPosition",{
            Name="MonarcaPosition",Attachment0=attachOwn,Attachment1=attachTarget,
            Mode=Enum.PositionAlignmentMode.TwoAttachment,
            ReactionForceEnabled=false,ApplyAtCenterOfMass=true,
            RigidityEnabled=false,Responsiveness=125,
            MaxForce=1000000000,MaxVelocity=250,
        },own)
        make("AlignOrientation",{
            Name="MonarcaRotation",Attachment0=attachOwn,Attachment1=attachTarget,
            Mode=Enum.OrientationAlignmentMode.TwoAttachment,
            ReactionTorqueEnabled=false,RigidityEnabled=false,
            Responsiveness=125,MaxTorque=1000000000,MaxAngularVelocity=200,
        },own)
        for _,part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                pose.collisions[part]=part.CanCollide
                part.CanCollide=false
            end
        end
        hum.AutoRotate=false
        hum.Sit=true
        own.AssemblyAngularVelocity=Vector3.zero
    end)
    if not ok then
        savedPose=pose
        restorePose()
        return false,tostring(errorMessage)
    end
    savedPose=pose
    return true
end
local function restoreCamera()
    if not savedCamera then return end
    local old=savedCamera
    savedCamera=nil
    pcall(function()
        player.CameraMaxZoomDistance=math.max(old.maxZoom,player.CameraMinZoomDistance)
        player.CameraMinZoomDistance=old.minZoom
        player.CameraMaxZoomDistance=old.maxZoom
        player.CameraMode=old.mode
    end)
    local cam=workspace.CurrentCamera
    if cam then
        pcall(function()
            cam.CameraType=old.kind
            if old.subject and old.subject.Parent then
                cam.CameraSubject=old.subject
            else
                local char=player.Character
                local hum=char and char:FindFirstChildOfClass("Humanoid")
                if hum then cam.CameraSubject=hum end
            end
            if old.kind==Enum.CameraType.Scriptable then cam.CFrame=old.cframe end
        end)
    end
end
local function activateView()
    local char=selectedPlayer and selectedPlayer.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local cam=workspace.CurrentCamera
    if not cam or not hum then return false,"Câmera ou alvo indisponível." end
    savedCamera={
        kind=cam.CameraType,subject=cam.CameraSubject,cframe=cam.CFrame,
        mode=player.CameraMode,minZoom=player.CameraMinZoomDistance,
        maxZoom=player.CameraMaxZoomDistance,
    }
    local ok,err=pcall(function()
        player.CameraMode=Enum.CameraMode.Classic
        player.CameraMaxZoomDistance=math.max(18,player.CameraMinZoomDistance)
        player.CameraMinZoomDistance=7
        player.CameraMaxZoomDistance=18
        cam.CameraType=Enum.CameraType.Custom
        cam.CameraSubject=hum
    end)
    if not ok then
        restoreCamera()
        return false,tostring(err)
    end
    return true
end

local function redrawModes()
    for name, ui in pairs(modeButtons) do
        local on = modes[name]
        ui.button.BackgroundColor3 = on and theme.primary or theme.background
        ui.button.TextColor3 = on and theme.background or theme.text
        ui.stroke.Thickness = on and 2 or 1
        ui.stroke.Transparency = on and 0 or 0.28
        ui.glow.Transparency = on and 0.78 or 1
    end
end
local function resetModes()
    if modes.Follow then
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local ownRoot = root(char)
        if hum and ownRoot then pcall(function() hum:MoveTo(ownRoot.Position) end) end
    end
    for name in pairs(modes) do modes[name] = false end
    restorePose()
    restoreCamera()
    redrawModes()
end

local function setMode(name, enabled)
    if enabled and not selectedPlayer then
        status("Selecione um jogador primeiro.")
        return
    end
    if modes.Follow and (name~="Follow" or not enabled) then
        local char=player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local own=root(char)
        if hum and own then pcall(function() hum:MoveTo(own.Position) end) end
    end
    if name=="Headsit" or name=="Backpack" or name=="Follow" then
        for _,other in ipairs({"Headsit","Backpack","Follow","TP"}) do
            modes[other]=false
        end
        restorePose()
        if enabled then
            if name=="Follow" then modes.Follow=true
            else
                local ok,err=createPose(name)
                modes[name]=ok
                if not ok then status(err or "Não foi possível posicionar.") end
            end
        end
    elseif name=="View" then
        if enabled then
            if not modes.View then
                local ok,err=activateView()
                modes.View=ok
                if not ok then status(err or "Câmera indisponível.") end
            end
        else
            restoreCamera()
            modes.View=false
        end
    elseif name=="TP" and enabled then
        for _,other in ipairs({"Headsit","Backpack","Follow"}) do
            modes[other]=false
        end
        restorePose()
        local own=root(player.Character)
        local their=targetParts()
        if own and their then
            own.CFrame=their.CFrame*CFrame.new(0,0,3.5)
            modes.TP=true
        else
            modes.TP=false
            status("O alvo não está com o personagem disponível.")
        end
    else
        modes[name]=enabled
    end
    redrawModes()
end

local function choosePlayer(candidate)
    if not candidate or candidate == player or not candidate.Parent then return end
    if selectedPlayer ~= candidate then
        resetModes()
        if targetRespawnConnection then
            targetRespawnConnection:Disconnect()
            targetRespawnConnection=nil
        end
    end
    selectedPlayer = candidate
    if not targetRespawnConnection then
        targetRespawnConnection=candidate.CharacterRemoving:Connect(function()
            resetModes()
            status("O alvo reapareceu. Reative o modo desejado.")
        end)
    end
    alvoName.Text = candidate.DisplayName
    alvoNick.Text = "@" .. candidate.Name
    alvoId.Text = "ID: " .. candidate.UserId
    alvoDist.Text = "Distância: —"
    alvoAvatar.Image = ""
    thumbVersion = thumbVersion + 1
    local ticket = thumbVersion
    hiddenMatches = true
    alvoSearch.Text = candidate.DisplayName
    matchesFrame.Visible = false
    task.spawn(function()
        local ok, image = pcall(function()
            return Services.Players:GetUserThumbnailAsync(
                candidate.UserId, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size420x420
            )
        end)
        if ok and image and not destroyed and thumbVersion == ticket then
            alvoAvatar.Image = image
        end
    end)
    status("Alvo: @" .. candidate.Name)
end
local function normalize(value)
    return tostring(value or ""):lower():gsub("^%s+", ""):gsub("%s+$", ""):gsub("^@", "")
end
local function edits(a,b)
    if math.abs(#a-#b)>3 then return 99 end
    local last={}
    for j=0,#b do last[j]=j end
    for i=1,#a do
        local row={[0]=i}
        for j=1,#b do
            local cost=a:sub(i,i)==b:sub(j,j) and 0 or 1
            row[j]=math.min(row[j-1]+1,last[j]+1,last[j-1]+cost)
        end
        last=row
    end
    return last[#b]
end
local function nameRank(name,q)
    local n=normalize(name)
    if n==q then return 0 end
    if n:sub(1,#q)==q then return 10+(#n-#q)*0.01 end
    if n:find(q,1,true) then return 30 end
    if #q>=3 and edits(q:sub(1,32),n:sub(1,32)) <= math.min(3,math.max(2,math.floor(#q*.35))) then
        return 50+edits(q:sub(1,32),n:sub(1,32))
    end
    return nil
end
local function searchPlayers()
    local q=normalize(alvoSearch.Text)
    local result={}
    for _,candidate in ipairs(Services.Players:GetPlayers()) do
        if candidate~=player then
            local a,b=q=="" and 100 or nameRank(candidate.Name,q),
                      q=="" and 100 or nameRank(candidate.DisplayName,q)
            local score=a and b and math.min(a,b) or a or b
            if score then table.insert(result,{player=candidate,score=score}) end
        end
    end
    table.sort(result,function(a,b)
        if a.score==b.score then return a.player.Name:lower()<b.player.Name:lower() end
        return a.score<b.score
    end)
    return result
end
local function showMatches()
    rankedMatches=searchPlayers()
    for _,ui in ipairs(matchesFrame:GetChildren()) do
        if ui:IsA("GuiObject") then ui:Destroy() end
    end
    matchesFrame.Visible=not hiddenMatches
    if hiddenMatches then return end
    for i=1,math.min(4,#rankedMatches) do
        local candidate=rankedMatches[i].player
        local b=new("TextButton",{
            LayoutOrder=i,Size=UDim2.new(1,0,0,31),BackgroundColor3=theme.surface,
            Text="  "..candidate.DisplayName.."   /  @"..candidate.Name,
            TextSize=12,Font=Enum.Font.GothamMedium,TextColor3=theme.text,
            TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,
            BorderSizePixel=0,AutoButtonColor=false,
        },matchesFrame)
        rounded(b,2)
        b.Activated:Connect(function() choosePlayer(candidate) end)
    end
    if #rankedMatches==0 then
        new("TextLabel",{
            Size=UDim2.new(1,0,0,30),BackgroundTransparency=1,
            Text="Nenhum jogador encontrado.",TextColor3=theme.muted,
            TextSize=11,TextXAlignment=Enum.TextXAlignment.Left,
        },matchesFrame)
    end
end
connect(alvoSearch.Focused,function()
    hiddenMatches=false
    showMatches()
end)
connect(alvoSearch:GetPropertyChangedSignal("Text"),function()
    if not hiddenMatches then showMatches() end
end)
connect(alvoSearch.FocusLost,function(entered)
    if entered then
        rankedMatches=searchPlayers()
        if #rankedMatches>0 then choosePlayer(rankedMatches[1].player) end
    end
end)
for i,name in ipairs({"Headsit","Follow","View","TP","Backpack"}) do
    local b=new("TextButton",{
        Name="Action"..name,LayoutOrder=i,BackgroundColor3=theme.background,
        Text=name,TextSize=12,Font=Enum.Font.GothamBold,TextColor3=theme.text,
        BorderSizePixel=0,AutoButtonColor=false,
    },actionGrid)
    rounded(b,2)
    local stroke=new("UIStroke",{
        Color=theme.whiteLine,Thickness=1,Transparency=.28,
        ApplyStrokeMode=Enum.ApplyStrokeMode.Border,
    },b)
    local glow=new("UIStroke",{
        Color=theme.whiteLine,Thickness=4,Transparency=1,
        ApplyStrokeMode=Enum.ApplyStrokeMode.Border,
    },b)
    modeButtons[name]={button=b,stroke=stroke,glow=glow}
    b.Activated:Connect(function() setMode(name,not modes[name]) end)
end
redrawModes()
showMatches()
connect(Services.Players.PlayerAdded,function() if not hiddenMatches then showMatches() end end)
connect(Services.Players.PlayerRemoving,function(leaving)
    if leaving==selectedPlayer then
        resetModes()
        if targetRespawnConnection then
            targetRespawnConnection:Disconnect()
            targetRespawnConnection=nil
        end
        selectedPlayer=nil
        thumbVersion=thumbVersion+1
        alvoAvatar.Image=""
        alvoName.Text="Selecione um jogador"
        alvoNick.Text="Alvo saiu da sessão"
        alvoId.Text="ID: —"
        alvoDist.Text="Distância: —"
        hiddenMatches=false
        alvoSearch.Text=""
    end
    if not hiddenMatches then showMatches() end
end)
connect(player.CharacterAdded,function()
    for _,name in ipairs({"Headsit","Follow","Backpack","TP"}) do modes[name]=false end
    restorePose()
    redrawModes()
end)
-- Physics constraints maintain Headsit and Backpack without per-frame CFrame writes.
connect(runService.Heartbeat,function(dt)
    if destroyed or not selectedPlayer then return end
    tickDistance=tickDistance+dt
    tickFollow=tickFollow+dt
    local their=targetParts()
    if tickDistance>.35 then
        tickDistance=0
        local own=root(player.Character)
        alvoDist.Text=own and their and ("Distância: %d studs"):format(
            math.floor((own.Position-their.Position).Magnitude+0.5)
        ) or "Distância: —"
    end
    if tickFollow>.3 then
        tickFollow=0
        if modes.Follow and their then
            local char=player.Character
            local hum=char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health>0 then
                hum:MoveTo(their.Position+their.CFrame.LookVector*3)
            end
        end
    end
end)
local function stopAlvo()
    resetModes()
    if targetRespawnConnection then
        targetRespawnConnection:Disconnect()
        targetRespawnConnection=nil
    end
    selectedPlayer=nil
    thumbVersion=thumbVersion+1
end

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
local resetPlayer = card(playerPage, 49)
button(resetPlayer, "RESTAURAR PADRÕES", UDim2.fromOffset(10, 10), UDim2.new(1, -20, 0, 29), function()
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
local storage = card(settingsPage, 75)
cardText(storage, "Persistência", type(writefile) == "function" and
    "O ambiente oferece writefile. Preferências podem ser gravadas em Monarca/settings.json." or
    "Sem writefile: as preferências valem somente nesta sessão.")
local resetSettings = card(settingsPage, 49)
button(resetSettings, "REDEFINIR PREFERÊNCIAS", UDim2.fromOffset(10, 10), UDim2.new(1, -20, 0, 29), function()
    for k, v in pairs(defaults) do settings[k] = v end
    playerAdjusted = false
    paintFov(70); paintWalk(16); paintJump(50)
    applyPlayer()
    save()
    status("Preferências restauradas. Reabra o Hub para atualizar os controles.")
end)


local visualPage = pages.Visual
title(visualPage, "Visual", "Ajustes visuais locais e reversíveis.")

-- Minimal toolbar, with no large script cards or search controls.
local visualToolbar = ordered(visualPage, new("Frame", {
    Size = UDim2.new(1, -2, 0, 32),
    BackgroundTransparency = 1,
}, visualPage))
local updateButton = button(visualToolbar, "ATUALIZAR",
    UDim2.new(0, 0, 0, 2), UDim2.new(0.5, -6, 0, 27), nil, true)
local resetVisualButton = button(visualToolbar, "RESTAURAR",
    UDim2.new(0.5, 6, 0, 2), UDim2.new(0.5, -6, 0, 27))

local moduleArea = new("Frame", {
    Name = "ModuleArea",
    LayoutOrder = 1000,
    Size = UDim2.new(1, -2, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
}, visualPage)
new("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 10),
}, moduleArea)
local visualGroups = {"Personagens", "Iluminação", "Interface", "Desempenho"}
local timeMode = "Padrão"
local renderModules

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
    timeMode = "Padrão"
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

local function headingFor(group)
    local h = ordered(moduleArea, new("TextLabel", {
        Name = "Section" .. group,
        Size = UDim2.new(1, 0, 0, 29),
        BackgroundTransparency = 1,
        Text = string.upper(group),
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextColor3 = theme.muted,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Bottom,
    }, moduleArea))
    return h
end

local function separator(row)
    new("Frame", {
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = theme.whiteLine,
        BackgroundTransparency = 0.92,
        BorderSizePixel = 0,
    }, row)
end

local function optionRow(info)
    local row = ordered(moduleArea, new("Frame", {
        Size = UDim2.new(1, 0, 0, 59),
        BackgroundTransparency = 1,
    }, moduleArea))
    new("TextLabel", {
        Position = UDim2.fromOffset(1, 5),
        Size = UDim2.new(1, -72, 0, 20),
        BackgroundTransparency = 1,
        Text = info.name,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextColor3 = theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)
    new("TextLabel", {
        Position = UDim2.fromOffset(1, 27),
        Size = UDim2.new(1, -72, 0, 24),
        BackgroundTransparency = 1,
        Text = info.description,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextColor3 = theme.muted,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)
    local active = activeModules[info.id] == true
    local toggleButton = button(row, "", UDim2.new(1, -55, 0, 16), UDim2.fromOffset(43, 23))
    toggleButton.BackgroundColor3 = active and theme.accent or theme.border
    local knob = new("Frame", {
        Position = UDim2.fromOffset(active and 23 or 3, 3),
        Size = UDim2.fromOffset(17, 17),
        BackgroundColor3 = theme.text,
        BorderSizePixel = 0,
    }, toggleButton)
    rounded(knob, 8)
    toggleButton.Activated:Connect(function()
        local ok, err = pcall(function()
            if activeModules[info.id] then
                disableModule(info.id)
            else
                enableModule(info.id)
            end
        end)
        if ok then
            status(info.name .. (activeModules[info.id] and " ativado" or " desativado"))
        else
            status("Falha em " .. info.name .. ": " .. tostring(err))
        end
        renderModules()
    end)
    separator(row)
end

local function timeRow(info)
    local row = ordered(moduleArea, new("Frame", {
        Size = UDim2.new(1, 0, 0, 88),
        BackgroundTransparency = 1,
    }, moduleArea))
    new("TextLabel", {
        Position = UDim2.fromOffset(1, 5),
        Size = UDim2.new(1, -2, 0, 20),
        BackgroundTransparency = 1,
        Text = info.name,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextColor3 = theme.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    new("TextLabel", {
        Position = UDim2.fromOffset(1, 26),
        Size = UDim2.new(1, -2, 0, 18),
        BackgroundTransparency = 1,
        Text = info.description,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextColor3 = theme.muted,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)
    for i, mode in ipairs({"Padrão", "Dia", "Noite"}) do
        local isSelected = timeMode == mode
        local b = button(row, mode,
            UDim2.new((i - 1) / 3, 4, 0, 51),
            UDim2.new(1 / 3, -8, 0, 26), nil, isSelected)
        b.TextSize = 11
        b.BackgroundColor3 = isSelected and theme.primary or theme.card
        b.TextColor3 = isSelected and theme.background or theme.text
        b.Activated:Connect(function()
            local ok, err = pcall(function()
                if mode == "Padrão" then
                    disableModule("timecycle")
                else
                    if not activeModules.timecycle then enableModule("timecycle") end
                    assert(type(loadedModules.timecycle.setMode) == "function",
                        "Módulo de horário incompatível")
                    loadedModules.timecycle:setMode(mode)
                end
            end)
            if ok then
                timeMode = mode
                status("Horário visual: " .. mode)
            else
                status("Falha no horário: " .. tostring(err))
            end
            renderModules()
        end)
    end
    separator(row)
end

renderModules = function()
    local scrollPosition = visualPage.CanvasPosition
    for _, child in ipairs(moduleArea:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
    local count = 0
    for _, group in ipairs(visualGroups) do
        local hasItems = false
        for _, info in ipairs(catalog) do
            if info.group == group then
                if not hasItems then
                    headingFor(group)
                    hasItems = true
                end
                if info.id == "timecycle" then
                    timeRow(info)
                else
                    optionRow(info)
                end
                count = count + 1
            end
        end
    end
    if count == 0 then
        ordered(moduleArea, new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 45),
            BackgroundTransparency = 1,
            Text = "Nenhuma opção disponível. Use ATUALIZAR.",
            TextColor3 = theme.muted,
            Font = Enum.Font.Gotham,
            TextSize = 13,
            TextWrapped = true,
        }, moduleArea))
    end
    task.defer(function()
        if not destroyed and visualPage.Parent then visualPage.CanvasPosition = scrollPosition end
    end)
end

local function refresh()
    status("Buscando opções visuais no GitHub...")
    updateButton.Text = "CARREGANDO..."
    local ok, value = pcall(function()
        local source = fetch("manifest.lua")
        local data = compile(source, "Monarca/manifest")()
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
                local allowedGroup = false
                for _, group in ipairs(visualGroups) do
                    if entry.group == group then allowedGroup = true end
                end
                entry.group = allowedGroup and entry.group or "Interface"
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
        status("Visual atualizado: " .. tostring(#catalog) .. " opções")
    else
        status("Falha na atualização: " .. tostring(value))
    end
    updateButton.Text = "ATUALIZAR"
end

updateButton.Activated:Connect(refresh)
resetVisualButton.Activated:Connect(function()
    disableAll()
    renderModules()
    status("Visual restaurado para o padrão do mapa.")
end)

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
    stopAlvo()
    disableAll()
    destroyed = true
    for _, connection in ipairs(connections) do connection:Disconnect() end
    if startupSound then pcall(function() startupSound:Destroy() end); startupSound = nil end
    if introBackdrop and introBackdrop.Parent then introBackdrop:Destroy() end
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
if playerAdjusted then applyPlayer() end

-- Animate actual setup phases; catalogue fetch determines when the final stage
-- completes. A timeout keeps the panel usable if the network is unavailable.
task.spawn(function()
    if destroyed then return end
    introProgress(0.15, "PREPARANDO INTERFACE")
    task.wait(0.22)
    if destroyed then return end
    introProgress(0.36, "CARREGANDO CONFIGURAÇÕES")
    task.wait(0.26)
    if destroyed then return end
    introProgress(0.58, "SINCRONIZANDO VISUAL")
    local finished = false
    task.spawn(function()
        pcall(refresh)
        finished = true
    end)
    local deadline = os.clock() + 5
    local progress = 0.58
    while not finished and os.clock() < deadline and not destroyed do
        progress = math.min(0.90, progress + 0.013)
        introProgress(progress, "SINCRONIZANDO VISUAL")
        task.wait(0.085)
    end
    if destroyed then return end
    introProgress(1, "PRONTO")
    task.wait(0.27)
    if destroyed then return end
    main.Visible = true
    local mainScale = new("UIScale", {Scale = 0.95}, main)
    tween(mainScale, {Scale = 1}, 0.25)
    tween(introBackdrop, {BackgroundTransparency = 1}, 0.22)
    tween(introPanel, {BackgroundTransparency = 1}, 0.22)
    task.wait(0.23)
    if introBackdrop and introBackdrop.Parent then introBackdrop:Destroy() end
    if mainScale and mainScale.Parent then mainScale:Destroy() end
end)
