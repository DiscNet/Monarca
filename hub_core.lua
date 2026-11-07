-- Monarca Script Hub v0.9.3 CORE — scoped Player/Visual builders below 200 local registers
-- This entrypoint guards startup separately from user-selected modules.
local bootStage = "Criando interface"
local function bootMonarca()
    -- Original Monarca implementation
    -- Interface local. Os modulos sao carregados exclusivamente deste repositorio.
    local Services = {
        Players = game:GetService("Players"),
        TweenService = game:GetService("TweenService"),
        UserInputService = game:GetService("UserInputService"),
        HttpService = game:GetService("HttpService"),
    }
    local player = Services.Players.LocalPlayer
    if not player then
        local deadline = os.clock() + 12
        repeat
            task.wait(0.1)
            player = Services.Players.LocalPlayer
        until player or os.clock() >= deadline
    end
    assert(player, "Players.LocalPlayer indisponível após 12 segundos.")
    
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
        flySpeed = 40,
        zombieAnimationId = "",
        ownerTagEnabled = false,
        ownerTagText = "MONARCA",
        ownerTagR = 180,
        ownerTagG = 145,
        ownerTagB = 255,
        ownerTagRainbowFast = false,
        invisibilityHudEnabled = false,
        reverseHudEnabled = true,
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
    settings.walkSpeed = math.clamp(settings.walkSpeed, 8, 160)
    settings.jumpPower = math.clamp(settings.jumpPower, 25, 500)
    settings.flySpeed = math.clamp(settings.flySpeed, 5, 160)
    settings.ownerTagR = math.clamp(settings.ownerTagR, 0, 255)
    settings.ownerTagG = math.clamp(settings.ownerTagG, 0, 255)
    settings.ownerTagB = math.clamp(settings.ownerTagB, 0, 255)
    
    -- Start the Flashback recorder immediately after settings and the previous
    -- Monarca instance have been processed; do not wait for intro, tabs, or HUD.
    local auxiliaryModules = {}
    local auxiliaryLoading = {}
    local function loadAuxiliary(name)
        if auxiliaryModules[name] then return auxiliaryModules[name] end
        -- One in-flight fetch per module: avoids creating duplicate listeners
        -- when early startup and a fast HUD tap request the same file.
        if auxiliaryLoading[name] then
            while auxiliaryLoading[name] and not destroyed do
                task.wait(0.05)
            end
            if auxiliaryModules[name] then return auxiliaryModules[name] end
            if destroyed then error("Monarca encerrado.") end
        end
        auxiliaryLoading[name] = true
        local ok, moduleOrError = pcall(function()
            if type(loadstring) ~= "function" then error("Ambiente sem loadstring.") end
            local source = game:HttpGet(repository .. "modules/" .. name
                .. ".lua?v=0.9.3-" .. tostring(os.time()))
            if type(source) ~= "string" or #source < 20 then
                error("Resposta vazia ao carregar " .. name)
            end
            local compiled, err = loadstring(source, "Monarca/" .. name)
            if not compiled then error(err or "Módulo inválido.") end
            local module = compiled()
            assert(type(module) == "table" and type(module.enable) == "function"
                and type(module.disable) == "function", "Módulo incompleto.")
            if destroyed then error("Monarca encerrado.") end
            auxiliaryModules[name] = module
            return module
        end)
        auxiliaryLoading[name] = nil
        if not ok then error(tostring(moduleOrError), 2) end
        return moduleOrError
    end

    -- Start recording as the script starts, but NEVER block construction
    -- of the UI on HTTP requests. Old v0.7.5 awaited game:HttpGet here.
    local reverseEarlyError = nil
    task.spawn(function()
        local ok, started, reason = pcall(function()
            if destroyed then return false, "Monarca encerrado." end
            return loadAuxiliary("player_reverse"):enable()
        end)
        if not ok or not started then
            reverseEarlyError = tostring(ok and reason or started)
            warn("[Monarca] Reverse startup: " .. reverseEarlyError)
        end
    end)

    local function new(class, props, parent)
        local object = Instance.new(class)
        for property, value in pairs(props or {}) do
            local ok, reason = pcall(function() object[property] = value end)
            if not ok then
                error("UI " .. class .. "." .. tostring(property) ..
                    ": " .. tostring(reason), 2)
            end
        end
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
    -- PlayerGui is the most compatible container across mobile executors.
    -- Never count gui.Parent = nil as a successful mount.
    bootStage = "Montando interface no PlayerGui"
    local parent = player:WaitForChild("PlayerGui", 10)
    if parent then
        local ok = pcall(function() gui.Parent = parent end)
        if not ok then parent = nil end
    end
    if not parent and type(gethui) == "function" then
        local ok, p = pcall(gethui)
        if ok and p then
            local mounted = pcall(function() gui.Parent = p end)
            if mounted then parent = p end
        end
    end
    if not parent then
        local ok, p = pcall(function() return game:GetService("CoreGui") end)
        if ok and p then
            local mounted = pcall(function() gui.Parent = p end)
            if mounted then parent = p end
        end
    end
    assert(gui.Parent ~= nil, "Não foi possível anexar a interface ao PlayerGui/CoreGui.")
    
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
    
    bootStage = "Construindo painel e navegação"
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
        Text = "VISUAL HUB  /  V0.7.4",
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
    -- Seven tabs use an independently scrolling navigation strip on small screens.
    -- A fixed readable tab width avoids squeezing labels into 40 px.
    local sidebar = new("ScrollingFrame", {
        Name = "TabBar",
        Position = UDim2.fromOffset(0, HEADER_HEIGHT),
        Size = UDim2.new(1, 0, 0, NAV_HEIGHT),
        BackgroundColor3 = theme.surface,
        BackgroundTransparency = 0.06,
        BorderSizePixel = 0,
        CanvasSize = UDim2.fromOffset(0, 0),
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.X,
        ScrollingEnabled = true,
        ClipsDescendants = true,
    }, main)
    local tabLayout = new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 1),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, sidebar)
    new("UIPadding", {
        PaddingLeft = UDim.new(0, 7),
        PaddingRight = UDim.new(0, 7),
    }, sidebar)
    connect(tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        sidebar.CanvasSize = UDim2.fromOffset(
            tabLayout.AbsoluteContentSize.X + 14, 0
        )
    end)
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
        -- Home retains its compact profile layout, while Player/Emote use tighter lists.
        local isHome = name == "Home"
        local compactList = name == "Player" or name == "Waypoints" or name == "Emote" or name == "Anim" or name == "666" or name == "X?"
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
            Padding = UDim.new(0, isHome and 8 or (compactList and 7 or 15)),
        }, scroller)
        new("UIPadding", {
            PaddingTop = UDim.new(0, isHome and 12 or (compactList and 10 or 17)),
            PaddingLeft = UDim.new(0, isHome and 15 or 17),
            PaddingRight = UDim.new(0, isHome and 15 or 17),
            PaddingBottom = UDim.new(0, isHome and 14 or (compactList and 12 or 18)),
        }, scroller)
        connect(stack:GetPropertyChangedSignal("AbsoluteContentSize"), function()
            scroller.CanvasSize = UDim2.fromOffset(0, stack.AbsoluteContentSize.Y + (isHome and 28 or (compactList and 18 or 35)))
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
        -- Bring the active tab into view when it lives off-screen.
        local activeButton = navButtons[name]
        if activeButton and sidebar.AbsoluteSize.X > 0 then
            local left = sidebar.CanvasPosition.X +
                activeButton.AbsolutePosition.X - sidebar.AbsolutePosition.X
            local desired = left - (sidebar.AbsoluteSize.X - activeButton.AbsoluteSize.X) / 2
            local endOfScroll = math.max(0,
                sidebar.CanvasSize.X.Offset - sidebar.AbsoluteSize.X)
            tween(sidebar, {
                CanvasPosition = Vector2.new(math.clamp(desired, 0, endOfScroll), 0)
            }, 0.22)
        end
    end
    for index, name in ipairs({"Home", "Alvo", "Visual", "X?", "Player", "Waypoints", "Emote", "Anim", "666", "Settings"}) do
        page(name)
        local b = new("TextButton", {
            Name = "Tab" .. name,
            Size = UDim2.fromOffset(67, NAV_HEIGHT),
            LayoutOrder = index,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = name,
            Font = Enum.Font.GothamMedium,
            TextSize = 11,
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
    
    -- Isolated initialization: stays below Luau's 200-local limit.
    local function initializeHome()
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
    
    
    
    end
    bootStage = "Home construído"
    initializeHome()
    
    bootStage = "Construindo aba Alvo"
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
    
    -- Tool for selecting a player directly by tapping their character (mobile + PC).
    local grantTargetTool = ordered(alvo, new("TextButton", {
        Name = "GrantTargetTool", Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = theme.background,
        Text = "OBTER FERRAMENTA DE ALVO",
        TextColor3 = theme.text, TextSize = 11,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false, BorderSizePixel = 0,
    }, alvo))
    rounded(grantTargetTool, 2)
    new("UIStroke", {
        Color = theme.whiteLine, Thickness = 1, Transparency = 0.38,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, grantTargetTool)
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
    local modes = {Headsit=false, Follow=false, View=false, Backpack=false}
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
    
    -- Assigned below after the Player page is created. Avoid concurrent physics movers.
    local stopFlyForTarget = function() end
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
            if enabled then stopFlyForTarget() end
            for _,other in ipairs({"Headsit","Backpack","Follow"}) do
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
        elseif name=="TP" then
            stopFlyForTarget()
            for _,other in ipairs({"Headsit","Backpack","Follow"}) do
                modes[other]=false
            end
            restorePose()
            local own=root(player.Character)
            local their=targetParts()
            if own and their then
                own.CFrame=their.CFrame*CFrame.new(0,0,3.5)
                status("Teletransportado para @" .. selectedPlayer.Name)
            else
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
    -- Target-picker hotbar shortcut. It has no Handle and immediately returns
    -- to Backpack after activation, so Animate does not keep a held-tool pose.
    -- The hotbar uses a built-in Roblox crosshair texture instead of an item.
    local targetTool
    local targetToolConnections = {}
    local targetSelectionActive = false
    local selectionArmedAt = 0
    local pendingTap

    local function cleanupTargetTool()
        targetSelectionActive = false
        pendingTap = nil
        for _, connection in ipairs(targetToolConnections) do
            connection:Disconnect()
        end
        table.clear(targetToolConnections)
        if targetTool and targetTool.Parent then targetTool:Destroy() end
        targetTool = nil
    end

    local function playerAtTap(point)
        local camera = workspace.CurrentCamera
        if not camera or not point then return nil end
        local ray = camera:ViewportPointToRay(point.X, point.Y)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = player.Character
            and {player.Character} or {}
        local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
        local part = result and result.Instance
        while part and part ~= workspace do
            if part:IsA("Model") and part:FindFirstChildOfClass("Humanoid") then
                local candidate = Services.Players:GetPlayerFromCharacter(part)
                if candidate and candidate ~= player then return candidate end
            end
            part = part.Parent
        end
        return nil
    end

    local Input = Services.UserInputService
    -- A tap, rather than a drag or camera swipe, selects the world character.
    connect(Input.InputBegan, function(input, processed)
        if destroyed or not targetSelectionActive or processed
            or os.clock() < selectionArmedAt then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        pendingTap = {
            object = input,
            point = Vector2.new(input.Position.X, input.Position.Y),
            time = os.clock(),
        }
    end)
    connect(Input.InputEnded, function(input)
        if not targetSelectionActive or not pendingTap
            or pendingTap.object ~= input then return end
        local tap = pendingTap
        pendingTap = nil
        local endPoint = Vector2.new(input.Position.X, input.Position.Y)
        if (endPoint - tap.point).Magnitude > 24
            or os.clock() - tap.time > 0.7 then return end
        local candidate = playerAtTap(endPoint)
        if candidate then
            choosePlayer(candidate)
            targetSelectionActive = false
            status("Alvo marcado: @" .. candidate.Name)
        else
            status("Nenhum jogador atingido. Toque em um personagem ou use o ícone de mira para cancelar.")
        end
    end)

    grantTargetTool.Activated:Connect(function()
        local backpack = player:FindFirstChildOfClass("Backpack")
            or player:WaitForChild("Backpack", 5)
        if not backpack then
            status("Mochila não disponível.")
            return
        end
        if targetTool and targetTool.Parent then
            status("O marcador já está na mochila. Toque no ícone de mira para selecionar.")
            return
        end
        cleanupTargetTool()
        local tool = new("Tool", {
            Name = "Marcar Alvo",
            RequiresHandle = false,
            CanBeDropped = false,
            ManualActivationOnly = true,
            TextureId = "rbxasset://textures/MouseLockedCursor.png",
            ToolTip = "Toque para marcar um jogador sem segurar um objeto.",
        }, backpack)
        targetTool = tool
        table.insert(targetToolConnections, tool.Equipped:Connect(function()
            targetSelectionActive = not targetSelectionActive
            pendingTap = nil
            selectionArmedAt = os.clock() + 0.30
            -- Returning the Tool to Backpack immediately clears the default
            -- pose which many R6/R15 Animate scripts apply to equipped Tools.
            task.defer(function()
                if destroyed or not tool.Parent then return end
                local own = player.Character
                local humanoid = own and own:FindFirstChildOfClass("Humanoid")
                if humanoid and tool.Parent == own then
                    humanoid:UnequipTools()
                end
            end)
            if targetSelectionActive then
                status("Mira ativa: toque no personagem que deseja marcar.")
            else
                status("Seleção de alvo cancelada.")
            end
        end))
        table.insert(targetToolConnections, tool.AncestryChanged:Connect(function()
            if not tool.Parent then
                targetSelectionActive = false
                pendingTap = nil
            end
        end))
        status("Marcador de alvo adicionado à mochila (ícone de mira).")
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
        b.Activated:Connect(function()
            if name == "TP" then
                setMode("TP", true)
                -- Momentary click feedback; the TP action never stays enabled.
                b.BackgroundColor3 = theme.primary
                b.TextColor3 = theme.background
                task.delay(0.18, function()
                    if not destroyed and b.Parent then redrawModes() end
                end)
            else
                setMode(name, not modes[name])
            end
        end)
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
        for _,name in ipairs({"Headsit","Follow","Backpack"}) do modes[name]=false end
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
    
    -- X? is deliberately separate from the purely client-only Visual tab.
    -- A successful result needs a remote installed by the game's OWNER.
    local function initializeXPage()
        local section = pages["X?"]
        title(section, "X?", "Invisibilidade de servidor e testes experimentais")
        local row = card(section, 68)
        new("TextLabel", {
            Position = UDim2.fromOffset(11, 7),
            Size = UDim2.new(1, -113, 0, 23),
            BackgroundTransparency = 1,
            Text = "Invisível · servidor",
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextColor3 = theme.text,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, row)
        new("TextLabel", {
            Position = UDim2.fromOffset(11, 33),
            Size = UDim2.new(1, -113, 0, 23),
            BackgroundTransparency = 1,
            Text = "FE somente com suporte do servidor",
            Font = Enum.Font.GothamMedium,
            TextSize = 10,
            TextColor3 = theme.muted,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, row)
        local toggleButton = new("TextButton", {
            Name = "XServerInvisibility",
            Position = UDim2.new(1, -98, 0, 18),
            Size = UDim2.fromOffset(86, 31),
            BackgroundColor3 = theme.background,
            TextColor3 = theme.text,
            Text = "OFF",
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            AutoButtonColor = false,
            BorderSizePixel = 0,
        }, row)
        rounded(toggleButton, 2)
        local stroke = new("UIStroke", {
            Color = theme.whiteLine,
            Thickness = 1,
            Transparency = 0.22,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, toggleButton)
        local glow = new("UIStroke", {
            Color = theme.whiteLine,
            Thickness = 3,
            Transparency = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, toggleButton)
        local enabled = false
        local busy = false
        local experimentEnabled = false
        local experimentBusy = false
        local function repaint()
            toggleButton.Text = busy and "..." or (enabled and "ON" or "OFF")
            toggleButton.BackgroundColor3 = enabled and theme.primary or theme.background
            toggleButton.TextColor3 = enabled and theme.background or theme.text
            stroke.Transparency = enabled and 0 or 0.22
            glow.Transparency = enabled and 0.82 or 1
        end
        toggleButton.Activated:Connect(function()
            if busy or experimentBusy then return end
            if not enabled and experimentEnabled then
                status("Desative o clone experimental antes de ligar o modo de servidor.")
                return
            end
            busy = true
            repaint()
            task.spawn(function()
                local desired = not enabled
                local ok, result, reason = pcall(function()
                    local module = loadAuxiliary("server_invisibility")
                    if desired then return module:enable() end
                    return module:disable()
                end)
                if destroyed then
                    local mod = auxiliaryModules.server_invisibility
                    if mod then pcall(mod.disable, mod) end
                    return
                end
                local module = auxiliaryModules.server_invisibility
                enabled = module and module.isActive
                    and module:isActive() or false
                busy = false
                repaint()
                if ok and result then
                    status(enabled and "Invisibilidade confirmada pelo servidor."
                        or "Personagem visível novamente.")
                else
                    status("X? indisponível: " .. tostring(ok and reason or result))
                end
            end)
        end)
        repaint()
        local footnote = label(section,
            "Requer MonarcaInvisibility em ServerScriptService de um jogo próprio. Sem resposta do servidor, o botão não simula FE.",
            10, theme.muted, 53)
        footnote.TextWrapped = true
        footnote.TextYAlignment = Enum.TextYAlignment.Top

        -- An explicitly opt-in LOCAL prototype. It does not pretend that
        -- another player's client has confirmed real invisibility.
        local experimentalRow = card(section, 70)
        new("TextLabel", {
            Name = "CloneInvisibilityLabel",
            Position = UDim2.fromOffset(11, 7),
            Size = UDim2.new(1, -113, 0, 24),
            BackgroundTransparency = 1,
            Text = "Invisível · experimental",
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = theme.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, experimentalRow)
        new("TextLabel", {
            Position = UDim2.fromOffset(11, 34),
            Size = UDim2.new(1, -113, 0, 22),
            BackgroundTransparency = 1,
            Text = "Proxy local · pode causar desync",
            Font = Enum.Font.GothamMedium,
            TextSize = 10,
            TextColor3 = theme.muted,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, experimentalRow)
        local experimentButton = new("TextButton", {
            Name = "XCloneInvisibility",
            Position = UDim2.new(1, -98, 0, 19),
            Size = UDim2.fromOffset(86, 31),
            BackgroundColor3 = theme.background,
            TextColor3 = theme.text,
            Text = "OFF",
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            AutoButtonColor = false,
            BorderSizePixel = 0,
        }, experimentalRow)
        rounded(experimentButton, 2)
        local experimentStroke = new("UIStroke", {
            Color = theme.whiteLine, Thickness = 1, Transparency = 0.22,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, experimentButton)
        local experimentGlow = new("UIStroke", {
            Color = theme.whiteLine, Thickness = 3, Transparency = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, experimentButton)

        -- Separate, fixed-position HUD button, independent of the main panel.
        -- Never use the draggable floating launcher for this control.
        local hudButton = nil
        local hudShadow = nil
        local hudStroke = nil
        local hudGlow = nil
        local hudEyeStrokes = {}
        local hudSlash = nil
        if player.Name:lower() == "samulucas7419" then
            hudShadow = new("Frame", {
                Name = "MonarcaInvisibleHUDShadow",
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -18, 0.38, 4),
                Size = UDim2.fromOffset(48, 48),
                BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                BackgroundTransparency = 0.42,
                BorderSizePixel = 0,
                Active = false,
                Visible = settings.invisibilityHudEnabled,
                ZIndex = 39,
            }, gui)
            rounded(hudShadow, 11)
            hudButton = new("TextButton", {
                Name = "MonarcaInvisibleHUD",
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -18, 0.38, 0),
                Size = UDim2.fromOffset(48, 48),
                BackgroundColor3 = theme.card,
                BackgroundTransparency = 0.02,
                Text = "", -- vector eye, never a letter
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Active = true,
                Visible = settings.invisibilityHudEnabled,
                ZIndex = 40,
            }, gui)
            rounded(hudButton, 11)
            hudStroke = new("UIStroke", {
                Color = theme.whiteLine, Thickness = 1.25,
                Transparency = 0.36,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            }, hudButton)
            hudGlow = new("UIStroke", {
                Color = theme.accent, Thickness = 3,
                Transparency = 1,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            }, hudButton)
            local bevel = new("Frame", {
                Name = "EyeBevel",
                Position = UDim2.fromOffset(9, 4),
                Size = UDim2.new(1, -18, 0, 1),
                BackgroundColor3 = theme.whiteLine,
                BackgroundTransparency = 0.65,
                BorderSizePixel = 0,
                ZIndex = 41,
            }, hudButton)
            local eye = new("Frame", {
                Name = "EyeVector",
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromOffset(30, 30),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ZIndex = 42,
            }, hudButton)
            local function eyeLine(ax, ay, bx, by, thick)
                local dx, dy = bx - ax, by - ay
                local part = new("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2),
                    Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy), thick),
                    Rotation = math.deg(math.atan2(dy, dx)),
                    BackgroundColor3 = theme.text,
                    BorderSizePixel = 0,
                    ZIndex = 43,
                }, eye)
                rounded(part, 2)
                table.insert(hudEyeStrokes, part)
                return part
            end
            local top = {
                {2,15}, {8,10}, {15,8}, {22,10}, {28,15}
            }
            local bottom = {
                {2,15}, {8,20}, {15,22}, {22,20}, {28,15}
            }
            for _, arc in ipairs({top, bottom}) do
                for i = 1, #arc - 1 do
                    eyeLine(arc[i][1], arc[i][2],
                        arc[i + 1][1], arc[i + 1][2], 2.4)
                end
            end
            local pupil = new("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromOffset(15, 15),
                Size = UDim2.fromOffset(7, 7),
                BackgroundColor3 = theme.text,
                BorderSizePixel = 0,
                ZIndex = 43,
            }, eye)
            rounded(pupil, 7)
            table.insert(hudEyeStrokes, pupil)
            hudSlash = eyeLine(5, 26, 26, 4, 2.8)
            hudSlash.Visible = false
        end
        local function repaintExperimental()
            experimentButton.Text = experimentBusy and "..." or
                (experimentEnabled and "ON" or "OFF")
            experimentButton.BackgroundColor3 = experimentEnabled
                and theme.primary or theme.background
            experimentButton.TextColor3 = experimentEnabled
                and theme.background or theme.text
            experimentStroke.Transparency = experimentEnabled and 0 or 0.22
            experimentGlow.Transparency = experimentEnabled and 0.82 or 1
            if hudButton then
                hudButton.Visible = settings.invisibilityHudEnabled and not destroyed
                hudShadow.Visible = hudButton.Visible
                hudButton.Position = UDim2.new(1, -18, 0.38,
                    experimentBusy and 3 or 0)
                hudButton.BackgroundColor3 = experimentEnabled
                    and theme.primary or theme.card
                local strokeColor = experimentEnabled
                    and theme.background or theme.text
                for _, eyePart in ipairs(hudEyeStrokes) do
                    eyePart.BackgroundColor3 = strokeColor
                end
                hudSlash.Visible = experimentEnabled
                hudStroke.Transparency = experimentEnabled and 0.02 or 0.36
                hudGlow.Transparency = experimentEnabled and 0.66 or 1
            end
        end
        local function toggleExperimentalMode()
            if experimentBusy or busy then return end
            if not experimentEnabled and enabled then
                status("Desative a invisibilidade do servidor antes de testar o clone.")
                return
            end
            experimentBusy = true
            repaintExperimental()
            task.spawn(function()
                local desired = not experimentEnabled
                if desired then
                    stopFlyForTarget()
                    resetModes()
                end
                local ok, result, message = pcall(function()
                    local module = loadAuxiliary("clone_invisibility")
                    if desired then return module:enable() end
                    return module:disable()
                end)
                if destroyed then
                    local module = auxiliaryModules.clone_invisibility
                    if module then pcall(module.disable, module) end
                    return
                end
                local module = auxiliaryModules.clone_invisibility
                experimentEnabled = module and module.isActive
                    and module:isActive() or false
                experimentBusy = false
                repaintExperimental()
                if ok and result then
                    status(desired and "Clone ativo (local). Verifique com outro jogador."
                        or "Personagem original restaurado.")
                else
                    status("Clone indisponível: " .. tostring(ok and message or result))
                end
            end)
        end
        experimentButton.Activated:Connect(toggleExperimentalMode)
        if hudButton then hudButton.Activated:Connect(toggleExperimentalMode) end
        repaintExperimental()
        -- Clone mode may turn itself off on respawn/death. Update both UI
        -- buttons even if the user leaves X? or minimizes the hub.
        local refreshAccumulator = 0
        connect(game:GetService("RunService").Heartbeat, function(dt)
            if destroyed then return end
            refreshAccumulator = refreshAccumulator + math.min(dt, 0.1)
            if refreshAccumulator < 0.25 then return end
            refreshAccumulator = 0
            if experimentBusy then return end
            local module = auxiliaryModules.clone_invisibility
            local actual = module and module.isActive and module:isActive() or false
            if experimentEnabled ~= actual then
                experimentEnabled = actual
                repaintExperimental()
            end
        end)
        local prototypeInfo = label(section,
            "Teste arriscado: corpo real fica longe; clone visível só para você. Pode falhar, sofrer anticheat ou causar respawn. Não é FE garantido.",
            10, theme.muted, 69)
        prototypeInfo.TextWrapped = true
        prototypeInfo.TextYAlignment = Enum.TextYAlignment.Top

        if hudButton then
            toggle(section, "Botão fixo no HUD",
                "Ligar/desligar invisibilidade sem abrir o painel",
                settings.invisibilityHudEnabled, function(show)
                    settings.invisibilityHudEnabled = show
                    repaintExperimental()
                    save()
                end)
        end
    end
    local okX, errorX = pcall(initializeXPage)
    if not okX then
        warn("[Monarca] Aba X? indisponível: " .. tostring(errorX))
        status("Aba X? indisponível; os demais menus continuam funcionando.")
    end

    bootStage = "Construindo aba Player"
    -- Export only the controls used by Settings or late startup.
    -- All other Player/Emote locals die at the end of this lexical scope.
    local applyPlayer, playerAdjusted, paintFov, paintWalk, paintJump
    do
    local playerPage = pages.Player
    title(playerPage, "Player", "Movimento, câmera e aparência do personagem.")
    applyPlayer = function()
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
    playerAdjusted = settings.playerCustomized
    local unusedFov; unusedFov, paintFov = slider(playerPage, "Campo de visão (FOV)", 60, 110, settings.fieldOfView, function(v)
        settings.fieldOfView = v
        settings.playerCustomized = true
        playerAdjusted = true
        applyPlayer()
        save()
    end)
    local unusedWalk; unusedWalk, paintWalk = slider(playerPage, "Velocidade (até 10×)", 8, 160, settings.walkSpeed, function(v)
        settings.walkSpeed = v
        settings.playerCustomized = true
        playerAdjusted = true
        applyPlayer()
        save()
    end)
    local unusedJump; unusedJump, paintJump = slider(playerPage, "Pulo (até 10×)", 25, 500, settings.jumpPower, function(v)
        settings.jumpPower = v
        settings.playerCustomized = true
        playerAdjusted = true
        applyPlayer()
        save()
    end)
    
    -- Fly can be activated without reopening the panel, using touch and keyboard
    -- controls created by ContextActionService.
    local flyActive = false
    stopFlyForTarget = function()
        if flyActive and auxiliaryModules.player_fly then
            pcall(auxiliaryModules.player_fly.disable, auxiliaryModules.player_fly)
            flyActive = false
            -- repaintFly is defined later; the button will be refreshed below.
            status("Fly desativado para executar a ação do Alvo.")
        end
    end
    local flyRow = card(playerPage, 54)
    local flyTitle = new("TextLabel", {
        Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -113, 0, 21),
        BackgroundTransparency = 1, Text = "Fly",
        TextSize = 13, Font = Enum.Font.GothamMedium,
        TextColor3 = theme.text, TextXAlignment = Enum.TextXAlignment.Left,
    }, flyRow)
    local flyLabel = new("TextLabel", {
        Position = UDim2.fromOffset(10, 29), Size = UDim2.new(1, -113, 0, 18),
        BackgroundTransparency = 1, Text = "Voe na direção da câmera",
        TextSize = 11, Font = Enum.Font.Gotham,
        TextColor3 = theme.muted, TextXAlignment = Enum.TextXAlignment.Left,
    }, flyRow)
    local flyToggle = button(flyRow, "OFF", UDim2.new(1, -91, 0, 12),
        UDim2.fromOffset(80, 28))
    local function repaintFly()
        flyToggle.Text = flyActive and "ON" or "OFF"
        flyToggle.BackgroundColor3 = flyActive and theme.primary or theme.background
        flyToggle.TextColor3 = flyActive and theme.background or theme.text
    end
    local stopFlyOriginal = stopFlyForTarget
    stopFlyForTarget = function()
        stopFlyOriginal()
        repaintFly()
    end
    flyToggle.Activated:Connect(function()
        if flyActive then
            local mod = auxiliaryModules.player_fly
            if mod then pcall(mod.disable, mod) end
            flyActive = false
            status("Fly desativado.")
        else
            -- Avoid fighting the target's positioning constraints.
            for _, targetMode in ipairs({"Headsit", "Backpack", "Follow"}) do
                if modes[targetMode] then setMode(targetMode, false) end
            end
            local ok, success, why = pcall(function()
                local mod = loadAuxiliary("player_fly")
                mod:setSpeed(settings.flySpeed)
                return mod:enable()
            end)
            flyActive = ok and success == true
            if flyActive then status("Fly ativo: mova o joystick/WASD na direção da câmera.")
            else status("Falha no Fly: " .. tostring(ok and why or success)) end
        end
        repaintFly()
    end)
    repaintFly()
    local _, paintFly = slider(playerPage, "Velocidade do Fly", 5, 160, settings.flySpeed, function(v)
        settings.flySpeed = v
        if auxiliaryModules.player_fly then auxiliaryModules.player_fly:setSpeed(v) end
        save()
    end)
    
    -- Reverse / Flashback (original user-supplied E-held script, made mobile-safe).
    -- A compact, tactile, ICON-ONLY HUD control remains visible when minimized.
    local reverseShadow = new("Frame", {
        Name = "ReverseHUDShadow",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -18, 0.54, 4),
        Size = UDim2.fromOffset(48, 48),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.40,
        BorderSizePixel = 0,
        Visible = settings.reverseHudEnabled,
        Active = false,
        ZIndex = 34,
    }, gui)
    rounded(reverseShadow, 11)
    local reverseButton = new("TextButton", {
        Name = "MonarcaReverseHUD",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -18, 0.54, 0),
        Size = UDim2.fromOffset(48, 48),
        BackgroundColor3 = theme.card,
        BackgroundTransparency = 0.02,
        Text = "", -- icon made from real UI line segments, not a font glyph
        Font = Enum.Font.GothamBold,
        TextSize = 32,
        TextColor3 = theme.text,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Active = true,
        Visible = settings.reverseHudEnabled,
        ZIndex = 36,
    }, gui)
    rounded(reverseButton, 11)
    local reverseOutline = new("UIStroke", {
        Color = theme.whiteLine, Thickness = 1.25, Transparency = 0.36,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, reverseButton)
    local reverseGlow = new("UIStroke", {
        Color = theme.accent, Thickness = 3, Transparency = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, reverseButton)
    local reverseTopLine = new("Frame", {
        Name = "ReverseBevel",
        Position = UDim2.fromOffset(9, 4),
        Size = UDim2.new(1, -18, 0, 1),
        BackgroundColor3 = theme.whiteLine,
        BackgroundTransparency = 0.65,
        BorderSizePixel = 0,
        Active = false,
        ZIndex = 37,
    }, reverseButton)

    -- Draw a curved counterclockwise arrow with Roblox Frames.
    -- A geometric icon remains legible even if the phone's font lacks glyphs.
    local reverseIcon = new("Frame", {
        Name = "ReverseVectorIcon",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(28, 28),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Active = false,
        ZIndex = 38,
    }, reverseButton)
    local reverseIconLines = {}
    local function lineBetween(x1, y1, x2, y2, thickness)
        local dx, dy = x2 - x1, y2 - y1
        local length = math.sqrt(dx * dx + dy * dy)
        local line = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2),
            Size = UDim2.fromOffset(length + 0.6, thickness),
            Rotation = math.deg(math.atan2(dy, dx)),
            BackgroundColor3 = theme.text,
            BorderSizePixel = 0,
            Active = false,
            ZIndex = 39,
        }, reverseIcon)
        rounded(line, 2)
        table.insert(reverseIconLines, line)
    end
    -- Nearly full ring, with a leftward-pointing arrowhead at the top.
    for i = 0, 11 do
        local a = math.rad(150 - i * 20)
        local b = math.rad(150 - (i + 1) * 20)
        lineBetween(
            14 + math.cos(a) * 10, 14 + math.sin(a) * 10,
            14 + math.cos(b) * 10, 14 + math.sin(b) * 10, 2.4
        )
    end
    lineBetween(14, 4, 20, 1, 2.4)
    lineBetween(14, 4, 20, 7, 2.4)

    local reversePressed = nil
    local reverseInitBusy = false
    local reverseClock = 0
    local function repaintReverse()
        local module = auxiliaryModules.player_reverse
        local goingBack = module and module.isRewinding and module:isRewinding() or false
        local pressed = reversePressed ~= nil or goingBack
        reverseButton.Visible = settings.reverseHudEnabled and not destroyed
        reverseShadow.Visible = reverseButton.Visible
        reverseButton.Position = UDim2.new(1, -18, 0.54, pressed and 3 or 0)
        reverseShadow.Position = UDim2.new(1, -18, 0.54, pressed and 4 or 4)
        reverseButton.BackgroundColor3 = pressed and theme.primary or theme.card
        reverseButton.TextColor3 = pressed and theme.background or theme.text
        for _, line in ipairs(reverseIconLines) do
            line.BackgroundColor3 = pressed and theme.background or theme.text
        end
        reverseOutline.Transparency = pressed and 0.02 or 0.36
        reverseGlow.Transparency = pressed and 0.66 or 1
        reverseTopLine.BackgroundTransparency = pressed and 0.88 or 0.65
    end

    local function ensureReverseModule()
        -- The deferred startup load and a quick HUD tap can overlap. Serialize
        -- module loading so no orphan Heartbeat/input listeners are created.
        while reverseInitBusy and not destroyed do task.wait(0.04) end
        if destroyed then
            return false, "Monarca encerrado."
        end
        reverseInitBusy = true
        local ok, success, message = pcall(function()
            local module = loadAuxiliary("player_reverse")
            local started, why = module:enable()
            if not started then return false, why end
            return true
        end)
        reverseInitBusy = false
        if not ok or not success then
            return false, tostring(ok and message or success)
        end
        return true
    end

    -- GUI InputBegan/InputEnded accepts touch on Android and left mouse on PC.
    -- It is a hold-to-rewind button rather than a tap toggle.
    connect(reverseButton.InputBegan, function(input)
        if destroyed or not settings.reverseHudEnabled or reversePressed then return end
        if input.UserInputType ~= Enum.UserInputType.Touch
            and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        reversePressed = input
        repaintReverse()
        task.spawn(function()
            local started, reason = ensureReverseModule()
            if destroyed then return end
            if not started then
                status("Reverse indisponível: " .. tostring(reason))
            elseif reversePressed == input and settings.reverseHudEnabled then
                -- Avoid simultaneous physics constraints while rewinding.
                stopFlyForTarget()
                for _, targetMode in ipairs({"Headsit", "Backpack", "Follow"}) do
                    if modes[targetMode] then setMode(targetMode, false) end
                end
                local module = auxiliaryModules.player_reverse
                local ok, success, why = pcall(module.start, module)
                if not ok or not success then
                    status("Reverse: " .. tostring(ok and why or success))
                end
            end
            repaintReverse()
        end)
    end)

    local function releaseReverse(input)
        if not reversePressed or (input and reversePressed ~= input) then return end
        reversePressed = nil
        local module = auxiliaryModules.player_reverse
        if module then pcall(module.stop, module) end
        repaintReverse()
    end
    connect(reverseButton.InputEnded, releaseReverse)
    connect(Services.UserInputService.InputEnded, releaseReverse)
    -- Keyboard E is handled by the module. Refresh visual state at low cost.
    connect(game:GetService("RunService").Heartbeat, function(dt)
        if destroyed then return end
        reverseClock = reverseClock + math.min(dt, 0.1)
        if reverseClock < 0.12 then return end
        reverseClock = 0
        if not reversePressed then repaintReverse() end
    end)

    toggle(playerPage, "Reverse no HUD",
        "Segure o ícone ⟲ ou a tecla E · até 60 s",
        settings.reverseHudEnabled, function(value)
            settings.reverseHudEnabled = value
            if value then
                task.spawn(function()
                    local ok, reason = ensureReverseModule()
                    if not ok and not destroyed then
                        status("Reverse indisponível: " .. tostring(reason))
                    end
                end)
            else
                -- Only hide the HUD; keep recording history and keyboard E.
                releaseReverse()
            end
            repaintReverse()
            save()
        end)
    repaintReverse()
    if settings.reverseHudEnabled then
        task.defer(function()
            if destroyed or not settings.reverseHudEnabled then return end
            local ok, reason = ensureReverseModule()
            if not ok and not destroyed then
                status("Falha ao inicializar Reverse: " .. tostring(reason))
            end
        end)
    end

    -- Owner-only personal label controls. Hidden from all other usernames.
    -- This whitelist affects the local UI, not a permission granted by Roblox.
    local function initializeOwnerTag()
        if player.Name:lower() ~= "samulucas7419" then return end
        title(playerPage, "Tag pessoal", "Somente @samulucas7419 · efeito local")

        local function options()
            return {
                text = settings.ownerTagText,
                red = settings.ownerTagR,
                green = settings.ownerTagG,
                blue = settings.ownerTagB,
                rainbowFast = settings.ownerTagRainbowFast,
            }
        end
        local function applyTag()
            if not settings.ownerTagEnabled then
                if auxiliaryModules.owner_tag then
                    pcall(auxiliaryModules.owner_tag.disable, auxiliaryModules.owner_tag)
                end
                return true
            end
            local ok, success, reason = pcall(function()
                local module = loadAuxiliary("owner_tag")
                local configured, configReason = module:configure(options())
                if not configured then return false, configReason end
                return module:enable()
            end)
            if not ok or not success then
                status("Erro na tag: " .. tostring(ok and reason or success))
                return false
            end
            return true
        end
        toggle(playerPage, "Exibir tag", "Mostrar acima do personagem", settings.ownerTagEnabled, function(v)
            settings.ownerTagEnabled = v
            if not applyTag() then
                settings.ownerTagEnabled = false
            end
            save()
        end)

        local textRow = card(playerPage, 71)
        local nameLabel = label(textRow, "Texto da tag", 12, theme.text, 18)
        nameLabel.Position = UDim2.fromOffset(10, 4)
        nameLabel.Size = UDim2.new(1, -20, 0, 18)
        local tagInput = new("TextBox", {
            Name = "OwnerTagTextInput",
            Position = UDim2.fromOffset(10, 28),
            Size = UDim2.new(1, -20, 0, 29),
            BackgroundColor3 = theme.surface,
            Text = settings.ownerTagText,
            TextColor3 = theme.text,
            PlaceholderColor3 = theme.muted,
            PlaceholderText = "Escreva sua tag...",
            Font = Enum.Font.GothamMedium,
            TextSize = 13,
            ClearTextOnFocus = false,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            BorderSizePixel = 0,
        }, textRow)
        rounded(tagInput, 3)
        new("UIStroke", {
            Color = theme.whiteLine,
            Thickness = 1,
            Transparency = 0.78,
        }, tagInput)
        connect(tagInput.FocusLost, function()
            local typed = tostring(tagInput.Text or "")
            typed = typed:gsub("[%c]", " "):gsub("^%s+", ""):gsub("%s+$", "")
            if typed == "" then typed = "MONARCA" end
            local valid, pos = pcall(utf8.offset, typed, 33)
            if valid and pos then typed = typed:sub(1, pos - 1) end
            settings.ownerTagText = typed
            tagInput.Text = typed
            applyTag()
            save()
        end)

        local previewRow = card(playerPage, 48)
        local previewLabel = label(previewRow, "COR PERSONALIZADA", 11, theme.muted, 17)
        previewLabel.Position = UDim2.fromOffset(10, 12)
        previewLabel.Size = UDim2.new(1, -83, 0, 18)
        local sample = new("Frame", {
            Name = "TagColorPreview",
            Position = UDim2.new(1, -70, 0, 9),
            Size = UDim2.fromOffset(57, 28),
            BackgroundColor3 = Color3.fromRGB(settings.ownerTagR,
                settings.ownerTagG, settings.ownerTagB),
            BorderSizePixel = 0,
        }, previewRow)
        rounded(sample, 3)
        new("UIStroke", {
            Color = theme.whiteLine,
            Thickness = 1,
            Transparency = 0.55,
        }, sample)
        -- Preview matches the moving multi-color wave used on the nameplate.
        -- Keep the saved setting key for backward compatibility.
        local previewGradient = new("UIGradient", {
            Name = "OwnerWavePreview",
            Rotation = 0,
            Enabled = settings.ownerTagRainbowFast,
        }, sample)
        local function previewColor()
            local wave = settings.ownerTagRainbowFast
            previewGradient.Enabled = wave
            if wave then
                sample.BackgroundColor3 = Color3.new(1, 1, 1)
                local base = (os.clock() * 0.18) % 1
                local stops = {}
                for index = 0, 5 do
                    local fraction = index / 5
                    stops[#stops + 1] = ColorSequenceKeypoint.new(
                        fraction,
                        Color3.fromHSV((base + 0.82 * fraction) % 1, 0.86, 1)
                    )
                end
                previewGradient.Color = ColorSequence.new(stops)
            else
                sample.BackgroundColor3 = Color3.fromRGB(
                    settings.ownerTagR, settings.ownerTagG, settings.ownerTagB
                )
            end
        end
        local function setChannel(channel, value)
            settings[channel] = value
            previewColor()
            applyTag()
            save()
        end
        slider(playerPage, "Vermelho (R)", 0, 255, settings.ownerTagR, function(v)
            setChannel("ownerTagR", v)
        end)
        slider(playerPage, "Verde (G)", 0, 255, settings.ownerTagG, function(v)
            setChannel("ownerTagG", v)
        end)
        slider(playerPage, "Azul (B)", 0, 255, settings.ownerTagB, function(v)
            setChannel("ownerTagB", v)
        end)

        local rgbRow = card(playerPage, 53)
        local rgbLabel = label(rgbRow, "RGB ONDA", 13, theme.text, 21)
        rgbLabel.Position = UDim2.fromOffset(10, 6)
        rgbLabel.Size = UDim2.new(1, -102, 0, 22)
        local rgbHint = label(rgbRow, "Onda suave · ciclo ~5,6 s",
            10, theme.muted, 18)
        rgbHint.Position = UDim2.fromOffset(10, 28)
        rgbHint.Size = UDim2.new(1, -105, 0, 18)
        local rgbButton = new("TextButton", {
            Position = UDim2.new(1, -91, 0, 10),
            Size = UDim2.fromOffset(80, 29),
            BackgroundColor3 = theme.background,
            TextColor3 = theme.text,
            TextSize = 11,
            Font = Enum.Font.GothamBold,
            AutoButtonColor = false,
            BorderSizePixel = 0,
        }, rgbRow)
        rounded(rgbButton, 2)
        local rgbOutline = new("UIStroke", {
            Color = theme.whiteLine,
            Thickness = 1,
            Transparency = 0.28,
        }, rgbButton)
        local function repaintRgb()
            local enabled = settings.ownerTagRainbowFast
            rgbButton.Text = enabled and "ON" or "OFF"
            rgbButton.BackgroundColor3 = enabled and theme.primary or theme.background
            rgbButton.TextColor3 = enabled and theme.background or theme.text
            rgbOutline.Transparency = enabled and 0 or 0.28
            previewColor()
        end
        rgbButton.Activated:Connect(function()
            settings.ownerTagRainbowFast = not settings.ownerTagRainbowFast
            repaintRgb()
            applyTag()
            save()
        end)
        repaintRgb()
        local previewClock = 0
        connect(game:GetService("RunService").RenderStepped, function(dt)
            if destroyed or not settings.ownerTagRainbowFast then return end
            previewClock = previewClock + dt
            if previewClock >= 1/20 then
                previewClock = 0
                previewColor()
            end
        end)
        if settings.ownerTagEnabled then
            task.defer(function()
                if not destroyed then applyTag() end
            end)
        end
    end
    initializeOwnerTag()

    -- R6/R15 is a real server-side respawn operation. These buttons send a request
    -- ONLY if the experience explicitly installs a supported RemoteEvent.
    local rigStatus = ordered(playerPage, new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 35),
        BackgroundTransparency = 1, Text = "Corpo atual: verificando...",
        TextSize = 11, Font = Enum.Font.GothamMedium,
        TextColor3 = theme.muted, TextXAlignment = Enum.TextXAlignment.Left,
    }, playerPage))
    local rigRow = ordered(playerPage, new("Frame", {
        Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1,
    }, playerPage))
    local rigButtons = {}
    local function updateRigUI()
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local rig = hum and hum.RigType.Name or "Desconhecido"
        rigStatus.Text = "Corpo atual: " .. rig .. "  •  R6 / R15"
        for name, b in pairs(rigButtons) do
            b.BackgroundColor3 = name == rig and theme.primary or theme.background
            b.TextColor3 = name == rig and theme.background or theme.text
        end
    end
    -- The optional server script replies to confirm/fail a real respawn.
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local rigEventConnection
    local function bindRigResponses(remote)
        if not remote or remote.Name ~= "MonarcaRigSwitch"
            or not remote:IsA("RemoteEvent") or rigEventConnection then return end
        rigEventConnection = connect(remote.OnClientEvent, function(rig, success, message)
            if destroyed then return end
            rigStatus.Text = (success and "Reiniciando como " or "Falha ao trocar para ")
                .. tostring(rig) .. ": " .. tostring(message or "")
            if not success then status(tostring(message or "Servidor recusou a troca.")) end
            if success then
                task.delay(0.6, function()
                    if not destroyed then updateRigUI() end
                end)
            end
        end)
    end
    bindRigResponses(replicatedStorage:FindFirstChild("MonarcaRigSwitch"))
    connect(replicatedStorage.ChildAdded, bindRigResponses)
    for i, rig in ipairs({"R6","R15"}) do
        local b = button(rigRow, rig, UDim2.new((i - 1) * .5, i == 1 and 0 or 5, 0, 2),
            UDim2.new(.5, -5, 0, 30))
        rounded(b, 2)
        new("UIStroke", {
            Color = theme.whiteLine, Thickness = 1,
            Transparency = .26, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, b)
        rigButtons[rig] = b
        b.Activated:Connect(function()
            local service = replicatedStorage:FindFirstChild("MonarcaRigSwitch")
            if not service or not service:IsA("RemoteEvent") then
                rigStatus.Text = "R6/R15: servidor sem MonarcaRigSwitch."
                status("Troca real exige instalar a integração no servidor do seu jogo.")
                return
            end
            bindRigResponses(service)
            local own = player.Character
            local human = own and own:FindFirstChildOfClass("Humanoid")
            if human and human.RigType.Name == rig then
                status("Seu personagem já está em " .. rig .. ".")
                return
            end
            rigStatus.Text = "Solicitando respawn em " .. rig .. "..."
            service:FireServer(rig)
            -- Do not report success merely because FireServer returned.
        end)
    end
    updateRigUI()
    local resetPlayer = card(playerPage, 49)
    button(resetPlayer, "RESTAURAR PADRÕES", UDim2.fromOffset(10, 10),
        UDim2.new(1, -20, 0, 29), function()
        if flyActive and auxiliaryModules.player_fly then
            pcall(auxiliaryModules.player_fly.disable, auxiliaryModules.player_fly)
            flyActive = false
            repaintFly()
        end
        settings.fieldOfView, settings.walkSpeed, settings.jumpPower, settings.flySpeed = 70, 16, 50, 40
        paintFov(70); paintWalk(16); paintJump(50); paintFly(40)
        settings.playerCustomized = false
        playerAdjusted = false
        applyPlayer()
        save()
        status("Controles do Player restaurados.")
    end, true)
    connect(player.CharacterAdded, function()
        if flyActive and auxiliaryModules.player_fly then
            pcall(auxiliaryModules.player_fly.disable, auxiliaryModules.player_fly)
            flyActive = false
            repaintFly()
        end
        task.delay(0.8, function()
            if destroyed then return end
            updateRigUI()
            if playerAdjusted then applyPlayer() end
        end)
    end)
    -- Isolated initialization: stays below Luau's 200-local limit.
    local function initializeEmoteTabs()
        -- Emote: original procedural R6 zombie walk, no external animation asset.
        local emotePage = pages.Emote
        title(emotePage, "Emote", "Animações locais para seu personagem.")

        -- Searchable Roblox emotes, separate from the R6 zombie emote.
        -- Isolated function keeps the hub below Luau's 200-local-register cap.
        local function initializeCatalogUI()
            title(emotePage, "Catálogo de emotes",
                "50 de referência + emotes do avatar + busca online Roblox/UGC · R15.")
            local pickerRow = card(emotePage, 61)
            cardText(pickerRow, "Selecionar emote", "Toque para buscar.", 176)
            local pickerButton = button(pickerRow, "EMOTES  ▾",
                UDim2.new(1, -172, 0, 14), UDim2.fromOffset(160, 32))
            pickerButton.Name = "EmoteCatalogPicker"
            pickerButton.TextSize = 12
            pickerButton.TextTruncate = Enum.TextTruncate.AtEnd

            local dropdown = ordered(emotePage, new("Frame", {
                Name = "EmoteCatalogDropdown",
                Size = UDim2.new(1, -2, 0, 0),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ClipsDescendants = true,
                Visible = false,
            }, emotePage))
            local searchBox = new("TextBox", {
                Name = "EmoteSearch",
                Position = UDim2.fromOffset(6, 5),
                Size = UDim2.new(1, -12, 0, 33),
                BackgroundColor3 = theme.card,
                BackgroundTransparency = 0.08,
                TextColor3 = theme.text,
                PlaceholderColor3 = theme.muted,
                PlaceholderText = "Buscar emote, ID ou UGC...",
                ClearTextOnFocus = false,
                Text = "",
                Font = Enum.Font.Gotham,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, dropdown)
            rounded(searchBox, 6)
            new("UIPadding", {
                PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9),
            }, searchBox)
            local emoteList = new("ScrollingFrame", {
                Name = "EmoteSearchResults",
                Position = UDim2.fromOffset(6, 43),
                Size = UDim2.new(1, -12, 0, 172),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ScrollBarThickness = 3,
                ScrollBarImageColor3 = theme.accent,
                ScrollingDirection = Enum.ScrollingDirection.Y,
                CanvasSize = UDim2.fromOffset(0, 0),
            }, dropdown)
            new("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 4),
            }, emoteList)

            local selected, choices, choiceButtons = nil, {}, {}
            local baseline, marketResults = {}, {}
            local marketQuery, hasNextPage, marketBusy = "", false, false
            local opened, loading, playing = true, false, false
            local selectionRow = card(emotePage, 46)
            local selectedName = label(selectionRow,
                "Escolha um emote na lista acima.", 11, theme.muted, 27)
            selectedName.Position = UDim2.fromOffset(10, 9)
            selectedName.Size = UDim2.new(1, -20, 0, 26)
            selectedName.TextTruncate = Enum.TextTruncate.AtEnd

            local controlsRow = card(emotePage, 48)
            local playButton = button(controlsRow, "REPRODUZIR",
                UDim2.fromOffset(9, 9), UDim2.new(0.5, -15, 0, 31), nil, true)
            playButton.Name = "EmotePlay"
            local stopButton = button(controlsRow, "PARAR",
                UDim2.new(0.5, 6, 0, 9), UDim2.new(0.5, -15, 0, 31))
            stopButton.Name = "EmoteStop"
            local countRow = card(emotePage, 39)
            local countLabel = label(countRow,
                "Carregando catálogo...", 11, theme.muted, 24)
            countLabel.Position = UDim2.fromOffset(10, 6)
            countLabel.Size = UDim2.new(1, -106, 0, 24)
            local reloadButton = button(countRow, "ATUALIZAR",
                UDim2.new(1, -101, 0, 4), UDim2.fromOffset(90, 28))
            reloadButton.Name = "EmoteRefresh"
            reloadButton.TextSize = 11

            local marketRow = card(emotePage, 48)
            local marketSearchButton = button(marketRow, "BUSCAR UGC",
                UDim2.fromOffset(9, 8), UDim2.new(0.5, -15, 0, 31), nil, true)
            marketSearchButton.Name = "EmoteMarketplaceSearch"
            local marketNextButton = button(marketRow, "MAIS EMOTES",
                UDim2.new(0.5, 6, 0, 8), UDim2.new(0.5, -15, 0, 31))
            marketNextButton.Name = "EmoteMarketplaceNext"
            marketNextButton.TextSize = 11
            marketNextButton.Visible = false

            local feedback = label(emotePage,
                "Emotes UGC agora usam a API nativa do Roblox. Posse e permissões da experiência ainda são exigidas.",
                11, theme.muted, 56)
            feedback.TextWrapped = true

            local function filterResults()
                local term = string.lower(searchBox.Text)
                local visibleCount = 0
                for i, item in ipairs(choices) do
                    local haystack = string.lower(item.name .. " " ..
                        (item.aliases or "") .. " " .. (item.group or "") ..
                        " " .. (item.id or "") .. " " .. (item.catalogId or ""))
                    local shown = term == ""
                        or string.find(haystack, term, 1, true) ~= nil
                        or (item.marketplace and term == string.lower(marketQuery))
                    choiceButtons[i].Visible = shown
                    if shown then visibleCount = visibleCount + 1 end
                end
                emoteList.CanvasSize = UDim2.fromOffset(
                    0, visibleCount > 0 and visibleCount * 37 + 5 or 0)
                emoteList.CanvasPosition = Vector2.zero
                if not loading then
                    countLabel.Text = tostring(visibleCount) .. " / " ..
                        tostring(#choices) .. " emotes"
                end
            end
            connect(searchBox:GetPropertyChangedSignal("Text"), filterResults)

            local function repaintPicker()
                dropdown.Visible = opened
                dropdown.Size = UDim2.new(1, -2, 0, opened and 222 or 0)
                pickerButton.Text = selected and
                    ((selected.name:sub(1, 15)) .. (opened and "  ▴" or "  ▾"))
                    or (opened and "EMOTES  ▴" or "EMOTES  ▾")
                pickerButton.BackgroundColor3 = opened and theme.primary or theme.card
                pickerButton.TextColor3 = opened and theme.background or theme.text
                selectedName.Text = selected and
                    (selected.name .. "  ·  " .. selected.group .. "  ·  " .. selected.id)
                    or "Nenhum emote selecionado."
            end
            local function rebuildCatalog()
                local previousId = selected and selected.id
                choices, selected = {}, nil
                local seen = {}
                for _, collection in ipairs({baseline, marketResults}) do
                    for _, item in ipairs(collection) do
                        local key = tostring(item.catalogId or item.id)
                        if not seen[key] then
                            seen[key] = true
                            table.insert(choices, item)
                        end
                    end
                end
                for _, previousButton in ipairs(choiceButtons) do
                    previousButton:Destroy()
                end
                table.clear(choiceButtons)
                for i, item in ipairs(choices) do
                    local rowButton = button(emoteList,
                        item.name .. "  ·  " .. (item.group or "Emote"),
                        UDim2.new(), UDim2.new(1, -7, 0, 33))
                    rowButton.LayoutOrder = i
                    rowButton.Name = "EmoteChoice_" .. tostring(i)
                    rowButton.TextSize = 12
                    rowButton.TextXAlignment = Enum.TextXAlignment.Left
                    rowButton.TextTruncate = Enum.TextTruncate.AtEnd
                    new("UIPadding", {PaddingLeft = UDim.new(0, 9)}, rowButton)
                    table.insert(choiceButtons, rowButton)
                    rowButton.Activated:Connect(function()
                        selected = item
                        opened = false
                        searchBox.Text = ""
                        repaintPicker()
                        if item.marketplace then
                            feedback.Text = "UGC: o Monarca usará HumanoidDescription e PlayEmoteAsync para este item. A reprodução depende da posse e das permissões."
                        end
                    end)
                    if item.id == previousId and not selected then selected = item end
                end
                filterResults()
                repaintPicker()
            end

            local function searchMarketplace(more)
                if marketBusy or loading then return end
                if more and not hasNextPage then return end
                local requested = more and marketQuery
                    or searchBox.Text:match("^%s*(.-)%s*$")
                if #requested > 70 then requested = requested:sub(1, 70) end
                marketBusy = true
                marketSearchButton.Text = "..."
                marketNextButton.Text = "..."
                countLabel.Text = "Consultando Marketplace..."
                task.spawn(function()
                    local ok, result, nextPageOrError = pcall(function()
                        return loadAuxiliary("emote_marketplace"):search(requested, more)
                    end)
                    if destroyed then return end
                    marketBusy = false
                    marketSearchButton.Text = "BUSCAR UGC"
                    marketNextButton.Text = "MAIS EMOTES"
                    if not ok or type(result) ~= "table" then
                        local reason = tostring(ok and nextPageOrError or result)
                        feedback.Text = "Busca online indisponível: " .. reason
                        status("UGC: " .. reason)
                        marketNextButton.Visible = hasNextPage
                        filterResults()
                        return
                    end
                    if not more then
                        marketResults = {}
                        marketQuery = requested
                    end
                    local seen = {}
                    for _, item in ipairs(marketResults) do
                        seen[tostring(item.catalogId or item.id)] = true
                    end
                    for _, item in ipairs(result) do
                        local key = tostring(item.catalogId or item.id)
                        if not seen[key] then
                            seen[key] = true
                            table.insert(marketResults, item)
                        end
                    end
                    hasNextPage = nextPageOrError == true
                    marketNextButton.Visible = hasNextPage
                    rebuildCatalog()
                    feedback.Text = "Marketplace: " .. tostring(#marketResults) ..
                        " emotes online encontrados, inclusive UGC. Os próximos resultados são carregados por página; reprodução requer acesso ao ativo."
                    status("UGC: " .. tostring(#marketResults) .. " emotes encontrados.")
                end)
            end

            local function refreshCatalog()
                if loading then return end
                loading = true
                reloadButton.Text = "..."
                countLabel.Text = "Carregando catálogo..."
                task.spawn(function()
                    local ok, result = pcall(function()
                        return loadAuxiliary("emote_catalog"):getCatalog()
                    end)
                    if destroyed then return end
                    loading = false
                    reloadButton.Text = "ATUALIZAR"
                    if not ok or type(result) ~= "table" then
                        local reason = tostring(result)
                        countLabel.Text = "Não foi possível carregar."
                        feedback.Text = "Emotes: " .. reason
                        status("Emotes: " .. reason)
                        return
                    end
                    baseline = result
                    rebuildCatalog()
                    feedback.Text = "Catálogo local carregado. Use BUSCAR UGC para consultar emotes de todos os criadores."
                    -- Load the first page without blocking the fixed catalog.
                    if #marketResults == 0 then searchMarketplace(false) end
                end)
            end

            -- Enter on the mobile keyboard submits the Marketplace query.
            connect(searchBox.FocusLost, function(enterPressed)
                if enterPressed then searchMarketplace(false) end
            end)
            marketSearchButton.Activated:Connect(function()
                searchMarketplace(false)
            end)
            marketNextButton.Activated:Connect(function()
                searchMarketplace(true)
            end)

            pickerButton.Activated:Connect(function()
                opened = not opened
                if opened then searchBox.Text = "" end
                repaintPicker()
            end)
            reloadButton.Activated:Connect(refreshCatalog)
            playButton.Activated:Connect(function()
                if playing then return end
                if not selected then
                    feedback.Text = "Selecione um emote na lista primeiro."
                    return
                end
                playing = true
                playButton.Text = "..."
                local choice = selected
                task.spawn(function()
                    local ok, worked, reason = pcall(function()
                        return loadAuxiliary("emote_catalog"):play(choice)
                    end)
                    if destroyed then
                        if auxiliaryModules.emote_catalog then
                            pcall(auxiliaryModules.emote_catalog.disable,
                                auxiliaryModules.emote_catalog)
                        end
                        return
                    end
                    playing = false
                    playButton.Text = "REPRODUZIR"
                    if ok and worked then
                        feedback.Text = "Emote iniciado: " .. choice.name ..
                            ". Confirme a replicação com outro jogador."
                        status("Emote: " .. choice.name .. " iniciado.")
                    else
                        local message = tostring(ok and reason or worked)
                        feedback.Text = "Falha: " .. message
                        status("Emote: " .. message)
                    end
                end)
            end)
            stopButton.Activated:Connect(function()
                if playing then return end
                local module = auxiliaryModules.emote_catalog
                if module then pcall(module.stop, module) end
                feedback.Text = "Emote interrompido."
                status("Emote: reprodução interrompida.")
            end)
            -- Open the search results immediately; no empty collapsed selector.
            repaintPicker()
            task.defer(refreshCatalog)
        end
        initializeCatalogUI()

        local zombieRow = card(emotePage, 63)
        local zombieTitle = new("TextLabel", {
            Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -94, 0, 22),
            BackgroundTransparency = 1, Text = "Zumbi andando",
            TextSize = 13, Font = Enum.Font.GothamBold,
            TextColor3 = theme.text, TextXAlignment = Enum.TextXAlignment.Left,
        }, zombieRow)
        new("TextLabel", {
            Position = UDim2.fromOffset(10, 31), Size = UDim2.new(1, -94, 0, 20),
            BackgroundTransparency = 1, Text = "R6 • FE se publicado / local",
            TextSize = 11, Font = Enum.Font.Gotham,
            TextColor3 = theme.muted, TextXAlignment = Enum.TextXAlignment.Left,
        }, zombieRow)
        local zombieButton = button(zombieRow, "ATIVAR",
            UDim2.new(1, -85, 0, 17), UDim2.fromOffset(76, 29))
        local zombieActive = false
        local function repaintZombie()
            zombieButton.Text = zombieActive and "PARAR" or "ATIVAR"
            zombieButton.BackgroundColor3 = zombieActive and theme.primary or theme.background
            zombieButton.TextColor3 = zombieActive and theme.background or theme.text
        end
        -- Assigned by the 666 page after the Zombie controls are constructed.
        local stop666ForZombie = function() end
        zombieButton.Activated:Connect(function()
            if zombieActive then
                if auxiliaryModules.zombie_r6 then
                    pcall(auxiliaryModules.zombie_r6.disable, auxiliaryModules.zombie_r6)
                end
                zombieActive = false
                status("Emote encerrado.")
            else
                stop666ForZombie()
                local ok, enabled, err = pcall(function()
                    local module = loadAuxiliary("zombie_r6")
                    module:setAnimationId(settings.zombieAnimationId)
                    return module:enable()
                end)
                zombieActive = ok and enabled == true
                if zombieActive then
                    local mode = auxiliaryModules.zombie_r6:getMode()
                    if mode == "FE" then
                        status("Zumbi R6 FE: animação via Animator.")
                    else
                        status("Zumbi R6 local: FE precisa de animação publicada e autorizada.")
                    end
                else
                    status("Emote: " .. tostring(ok and err or enabled))
                end
            end
            repaintZombie()
        end)
        repaintZombie()
    
        local animationIdFrame = ordered(emotePage, new("Frame", {
            Size = UDim2.new(1, 0, 0, 35),
            BackgroundColor3 = theme.surface,
            BorderSizePixel = 0,
        }, emotePage))
        rounded(animationIdFrame, 3)
        new("UIStroke", {
            Color = theme.whiteLine,
            Thickness = 1,
            Transparency = 0.76,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, animationIdFrame)
        local zombieAssetInput = new("TextBox", {
            Position = UDim2.fromOffset(10, 0),
            Size = UDim2.new(1, -20, 1, 0),
            BackgroundTransparency = 1,
            Text = settings.zombieAnimationId,
            PlaceholderText = "ID da animação R6 publicada para FE",
            PlaceholderColor3 = theme.muted,
            TextColor3 = theme.text,
            Font = Enum.Font.Gotham,
            TextSize = 11,
            ClearTextOnFocus = false,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, animationIdFrame)
        local emoteInfo = ordered(emotePage, new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 44),
            BackgroundTransparency = 1,
            Text = "Sem ID: emote local corrigido. Para FE, publique a animação R6 em Studio e autorize a experiência.",
            TextSize = 10,
            TextWrapped = true,
            TextColor3 = theme.muted,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
        }, emotePage))
        connect(zombieAssetInput.FocusLost, function()
            local id = zombieAssetInput.Text:match("^(%d+)$") or
                zombieAssetInput.Text:match("^rbxassetid://(%d+)$") or ""
            if #id > 20 then id = "" end
            settings.zombieAnimationId = id
            zombieAssetInput.Text = id
            save()
            if zombieActive then
                status("ID salvo. Desative e reative o emote para aplicar.")
            elseif id ~= "" then
                status("ID configurado. FE depende da permissão da experiência.")
            end
        end)
    
        connect(player.CharacterAdded, function()
            if auxiliaryModules.zombie_r6 then
                pcall(auxiliaryModules.zombie_r6.disable, auxiliaryModules.zombie_r6)
            end
            zombieActive = false
            repaintZombie()
        end)
    
        -- 666: one deliberately minimal R6-only toggle named "?".
        -- The pose is procedural and local unless a separately published animation
        -- is played through an authorized server-created Animator.
        local mysteryPage = pages["666"]
        title(mysteryPage, "666", "Postura R6")
        local mysteryRow = card(mysteryPage, 59)
        local mysteryName = new("TextLabel", {
            Name = "MysteryLabel",
            Position = UDim2.fromOffset(11, 8),
            Size = UDim2.new(1, -112, 0, 24),
            BackgroundTransparency = 1,
            Text = "?",
            Font = Enum.Font.GothamBold,
            TextSize = 17,
            TextColor3 = theme.text,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, mysteryRow)
        local mysterySubtitle = new("TextLabel", {
            Position = UDim2.fromOffset(11, 34),
            Size = UDim2.new(1, -113, 0, 17),
            BackgroundTransparency = 1,
            Text = "R6  •  Idle e caminhada fluida",
            TextSize = 10,
            Font = Enum.Font.GothamMedium,
            TextColor3 = theme.muted,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, mysteryRow)
        local mysteryToggle = new("TextButton", {
            Name = "MysteryToggle",
            Position = UDim2.new(1, -98, 0, 13),
            Size = UDim2.fromOffset(86, 31),
            BackgroundColor3 = theme.background,
            TextColor3 = theme.text,
            Text = "OFF",
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            AutoButtonColor = false,
            BorderSizePixel = 0,
        }, mysteryRow)
        rounded(mysteryToggle, 2)
        local mysteryStroke = new("UIStroke", {
            Color = theme.whiteLine, Thickness = 1,
            Transparency = 0.22, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, mysteryToggle)
        local mysteryGlow = new("UIStroke", {
            Color = theme.whiteLine, Thickness = 3,
            Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, mysteryToggle)
        local mysteryActive = false
        local function refreshMystery()
            mysteryToggle.Text = mysteryActive and "ON" or "OFF"
            mysteryToggle.BackgroundColor3 = mysteryActive and theme.primary or theme.background
            mysteryToggle.TextColor3 = mysteryActive and theme.background or theme.text
            mysteryStroke.Transparency = mysteryActive and 0 or 0.22
            mysteryGlow.Transparency = mysteryActive and 0.82 or 1
        end
        local function stopMystery()
            if auxiliaryModules.pose_666 then
                pcall(auxiliaryModules.pose_666.disable, auxiliaryModules.pose_666)
            end
            mysteryActive = false
            refreshMystery()
        end
        stop666ForZombie = stopMystery
        mysteryToggle.Activated:Connect(function()
            if mysteryActive then
                stopMystery()
                status("? desativado.")
                return
            end
            -- The two R6 animation modules must never fight over Motor6D.Transform.
            if zombieActive then
                if auxiliaryModules.zombie_r6 then
                    pcall(auxiliaryModules.zombie_r6.disable, auxiliaryModules.zombie_r6)
                end
                zombieActive = false
                repaintZombie()
            end
            local ok, success, why = pcall(function()
                return loadAuxiliary("pose_666"):enable()
            end)
            mysteryActive = ok and success == true
            refreshMystery()
            if mysteryActive then
                status("? ativado: postura e idle R6.")
            else
                status("Não foi possível ativar ?: " .. tostring(ok and why or success))
            end
        end)
        refreshMystery()
        connect(player.CharacterAdded, function()
            stopMystery()
        end)

        -- 666 / </> : independent head visibility control.
        -- This affects Head only; accessories and hair stay attached.
        local headlessRow = card(mysteryPage, 59)
        local headlessTitle = new("TextLabel", {
            Name = "HeadlessLabel",
            Position = UDim2.fromOffset(11, 8),
            Size = UDim2.new(1, -112, 0, 24),
            BackgroundTransparency = 1,
            Text = "</>",
            Font = Enum.Font.GothamBold,
            TextSize = 17,
            TextColor3 = theme.text,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, headlessRow)
        local headlessSubtitle = new("TextLabel", {
            Position = UDim2.fromOffset(11, 34),
            Size = UDim2.new(1, -113, 0, 17),
            BackgroundTransparency = 1,
            Text = "Ocultar somente a cabeça",
            TextSize = 10,
            Font = Enum.Font.GothamMedium,
            TextColor3 = theme.muted,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, headlessRow)
        local headlessToggle = new("TextButton", {
            Name = "HeadlessToggle",
            Position = UDim2.new(1, -98, 0, 13),
            Size = UDim2.fromOffset(86, 31),
            BackgroundColor3 = theme.background,
            TextColor3 = theme.text,
            Text = "OFF",
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            AutoButtonColor = false,
            BorderSizePixel = 0,
        }, headlessRow)
        rounded(headlessToggle, 2)
        local headlessStroke = new("UIStroke", {
            Color = theme.whiteLine,
            Thickness = 1,
            Transparency = 0.22,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, headlessToggle)
        local headlessGlow = new("UIStroke", {
            Color = theme.whiteLine,
            Thickness = 3,
            Transparency = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, headlessToggle)
        local headlessActive = false
        local function refreshHeadless()
            headlessToggle.Text = headlessActive and "ON" or "OFF"
            headlessToggle.BackgroundColor3 =
                headlessActive and theme.primary or theme.background
            headlessToggle.TextColor3 =
                headlessActive and theme.background or theme.text
            headlessStroke.Transparency = headlessActive and 0 or 0.22
            headlessGlow.Transparency = headlessActive and 0.82 or 1
        end
        headlessToggle.Activated:Connect(function()
            if headlessActive then
                if auxiliaryModules.headless_local then
                    pcall(auxiliaryModules.headless_local.disable,
                        auxiliaryModules.headless_local)
                end
                headlessActive = false
                status("</> desativado: cabeça restaurada.")
            else
                local ok, success, why = pcall(function()
                    return loadAuxiliary("headless_local"):enable()
                end)
                headlessActive = ok and success == true
                if headlessActive then
                    status("</> ativado: cabeça oculta apenas para você.")
                else
                    status("Falha ao ocultar cabeça: " .. tostring(ok and why or success))
                end
            end
            refreshHeadless()
        end)
        refreshHeadless()

        -- Third 666 option: authentic Korblox Deathspeaker Right Leg preview.
        -- The Roblox item is a body-part asset, not an ordinary Accessory.
        local korbloxRow = card(mysteryPage, 64)
        new("TextLabel", {
            Name = "KorbloxRightLeg",
            Position = UDim2.fromOffset(11, 7),
            Size = UDim2.new(1, -113, 0, 23),
            BackgroundTransparency = 1,
            Text = "Korblox · Perna direita",
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = theme.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, korbloxRow)
        new("TextLabel", {
            Position = UDim2.fromOffset(11, 32),
            Size = UDim2.new(1, -113, 0, 22),
            BackgroundTransparency = 1,
            Text = "139607718  ·  Visual local",
            Font = Enum.Font.GothamMedium,
            TextSize = 10,
            TextColor3 = theme.muted,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, korbloxRow)
        local korbloxButton = new("TextButton", {
            Name = "KorbloxToggle",
            Position = UDim2.new(1, -98, 0, 15),
            Size = UDim2.fromOffset(86, 32),
            Text = "OFF",
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = theme.text,
            BackgroundColor3 = theme.background,
            BorderSizePixel = 0,
            AutoButtonColor = false,
        }, korbloxRow)
        rounded(korbloxButton, 2)
        local korbloxBorder = new("UIStroke", {
            Color = theme.whiteLine, Thickness = 1, Transparency = 0.22,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, korbloxButton)
        local korbloxGlow = new("UIStroke", {
            Color = theme.whiteLine, Thickness = 3, Transparency = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, korbloxButton)
        local korbloxActive, korbloxBusy = false, false
        local function paintKorblox()
            korbloxButton.Text = korbloxBusy and "..." or
                (korbloxActive and "ON" or "OFF")
            korbloxButton.BackgroundColor3 =
                korbloxActive and theme.primary or theme.background
            korbloxButton.TextColor3 =
                korbloxActive and theme.background or theme.text
            korbloxBorder.Transparency = korbloxActive and 0 or 0.22
            korbloxGlow.Transparency = korbloxActive and 0.82 or 1
        end
        korbloxButton.Activated:Connect(function()
            if korbloxBusy then return end
            if korbloxActive then
                if auxiliaryModules.korblox_right_leg then
                    pcall(auxiliaryModules.korblox_right_leg.disable,
                        auxiliaryModules.korblox_right_leg)
                end
                korbloxActive = false
                status("Perna direita original restaurada.")
                paintKorblox()
                return
            end
            korbloxBusy = true
            paintKorblox()
            status("Carregando geometria original Korblox...")
            task.spawn(function()
                local ok, applied, reason = pcall(function()
                    return loadAuxiliary("korblox_right_leg"):enable()
                end)
                if destroyed then
                    if auxiliaryModules.korblox_right_leg then
                        pcall(auxiliaryModules.korblox_right_leg.disable,
                            auxiliaryModules.korblox_right_leg)
                    end
                    return
                end
                korbloxActive = ok and applied == true
                korbloxBusy = false
                paintKorblox()
                if korbloxActive then
                    status("Korblox Right Leg: prévia local ativada.")
                else
                    status("Korblox indisponível: " ..
                        tostring(ok and reason or applied))
                end
            end)
        end)
        paintKorblox()

        -- Fourth 666 option: radioactive footsteps / ground contamination.
        -- Client-only visual effect, with no permanent world modification.
        local radioactiveRow = card(mysteryPage, 64)
        new("TextLabel", {
            Name = "RadioactiveTrailTitle",
            Position = UDim2.fromOffset(11, 7),
            Size = UDim2.new(1, -113, 0, 23),
            BackgroundTransparency = 1,
            Text = "Rastro radioativo",
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = theme.text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, radioactiveRow)
        new("TextLabel", {
            Name = "RadioactiveTrailHint",
            Position = UDim2.fromOffset(11, 32),
            Size = UDim2.new(1, -113, 0, 22),
            BackgroundTransparency = 1,
            Text = "Chão verde · brilho · partículas",
            Font = Enum.Font.GothamMedium,
            TextSize = 10,
            TextColor3 = theme.muted,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, radioactiveRow)
        local radioactiveButton = new("TextButton", {
            Name = "RadioactiveTrailToggle",
            Position = UDim2.new(1, -98, 0, 15),
            Size = UDim2.fromOffset(86, 32),
            Text = "OFF",
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = theme.text,
            BackgroundColor3 = theme.background,
            BorderSizePixel = 0,
            AutoButtonColor = false,
        }, radioactiveRow)
        rounded(radioactiveButton, 2)
        local radioactiveBorder = new("UIStroke", {
            Color = theme.whiteLine,
            Thickness = 1, Transparency = 0.22,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, radioactiveButton)
        local radioactiveGlow = new("UIStroke", {
            Color = theme.whiteLine,
            Thickness = 3, Transparency = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, radioactiveButton)
        local radioactiveActive = false
        local function paintRadioactive()
            radioactiveButton.Text = radioactiveActive and "ON" or "OFF"
            radioactiveButton.BackgroundColor3 = radioactiveActive
                and theme.primary or theme.background
            radioactiveButton.TextColor3 = radioactiveActive
                and theme.background or theme.text
            radioactiveBorder.Transparency = radioactiveActive and 0 or 0.22
            radioactiveGlow.Transparency = radioactiveActive and 0.82 or 1
        end
        radioactiveButton.Activated:Connect(function()
            if radioactiveActive then
                if auxiliaryModules.radioactive_trail then
                    pcall(auxiliaryModules.radioactive_trail.disable,
                        auxiliaryModules.radioactive_trail)
                end
                radioactiveActive = false
                status("Rastro radioativo desativado; chão restaurado.")
            else
                local ok, success, reason = pcall(function()
                    return loadAuxiliary("radioactive_trail"):enable()
                end)
                radioactiveActive = ok and success == true
                if radioactiveActive then
                    status("Rastro radioativo ativado: caminhe pelo mapa.")
                else
                    status("Falha no rastro: " .. tostring(ok and reason or success))
                end
            end
            paintRadioactive()
        end)
        paintRadioactive()

        -- 666: independent anti-fling control. Does not touch the local rig,
        -- anchored ground, walls or existing visual/pose toggles.
        do
            local antiflingRow = card(mysteryPage, 60)
            new("TextLabel", {
                Name = "AntiflingLabel",
                Position = UDim2.fromOffset(11, 8),
                Size = UDim2.new(1, -113, 0, 23),
                BackgroundTransparency = 1,
                Text = "Antifling",
                Font = Enum.Font.GothamBold,
                TextSize = 13,
                TextColor3 = theme.text,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, antiflingRow)
            new("TextLabel", {
                Position = UDim2.fromOffset(11, 33),
                Size = UDim2.new(1, -113, 0, 19),
                BackgroundTransparency = 1,
                Text = "Sem colisão: jogadores e peças soltas",
                TextTruncate = Enum.TextTruncate.AtEnd,
                Font = Enum.Font.GothamMedium,
                TextSize = 10,
                TextColor3 = theme.muted,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, antiflingRow)
            local antiflingToggle = button(antiflingRow, "OFF",
                UDim2.new(1, -98, 0, 14), UDim2.fromOffset(86, 31))
            antiflingToggle.Name = "AntiflingToggle"
            rounded(antiflingToggle, 2)
            local outline = new("UIStroke", {
                Color = theme.whiteLine, Thickness = 1,
                Transparency = 0.22, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            }, antiflingToggle)
            local activeAntifling, busyAntifling = false, false
            local function paintAntifling()
                antiflingToggle.Text = busyAntifling and "..." or
                    (activeAntifling and "ON" or "OFF")
                antiflingToggle.BackgroundColor3 =
                    activeAntifling and theme.primary or theme.background
                antiflingToggle.TextColor3 =
                    activeAntifling and theme.background or theme.text
                outline.Transparency = activeAntifling and 0 or 0.22
            end
            antiflingToggle.Activated:Connect(function()
                if busyAntifling then return end
                if activeAntifling then
                    local module = auxiliaryModules.antifling
                    local ok, worked, reason = pcall(function()
                        if module then return module:disable() end
                        return true
                    end)
                    if ok and worked then
                        activeAntifling = false
                        status("Antifling OFF: colisões locais restauradas.")
                    else
                        status("Falha ao desligar Antifling: " ..
                            tostring(ok and reason or worked))
                    end
                    paintAntifling()
                    return
                end
                busyAntifling = true
                paintAntifling()
                task.spawn(function()
                    local ok, applied, reason = pcall(function()
                        return loadAuxiliary("antifling"):enable()
                    end)
                    if destroyed then
                        local module = auxiliaryModules.antifling
                        if module then pcall(module.disable, module) end
                        return
                    end
                    activeAntifling = ok and applied == true
                    busyAntifling = false
                    paintAntifling()
                    if activeAntifling then
                        status("Antifling ON: proteção contra colisões locais ativada.")
                    else
                        status("Antifling indisponível: " ..
                            tostring(ok and reason or applied))
                    end
                end)
            end)
            paintAntifling()
        end


        -- 666 / Fling: server-authorized touch knockback in consenting private games.
        do
            local function addFlingControl(titleText, descriptionText, remoteOperation)
                local row = card(mysteryPage, 60)
                new("TextLabel", {
                    Position = UDim2.fromOffset(11, 8),
                    Size = UDim2.new(1, -113, 0, 23),
                    BackgroundTransparency = 1,
                    Text = titleText,
                    Font = Enum.Font.GothamBold,
                    TextSize = 13,
                    TextColor3 = theme.text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                }, row)
                new("TextLabel", {
                    Position = UDim2.fromOffset(11, 33),
                    Size = UDim2.new(1, -113, 0, 19),
                    BackgroundTransparency = 1,
                    Text = descriptionText,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    Font = Enum.Font.GothamMedium,
                    TextSize = 10,
                    TextColor3 = theme.muted,
                    TextXAlignment = Enum.TextXAlignment.Left,
                }, row)
                local toggleButton = button(row, "OFF",
                    UDim2.new(1, -98, 0, 14), UDim2.fromOffset(86, 31))
                toggleButton.Name = remoteOperation == "sending"
                    and "FlingToggle" or "FlingConsentToggle"
                rounded(toggleButton, 2)
                local outline = new("UIStroke", {
                    Color = theme.whiteLine, Thickness = 1,
                    Transparency = 0.22, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                }, toggleButton)
                local active, busy = false, false
                local function repaint()
                    toggleButton.Text = busy and "..." or (active and "ON" or "OFF")
                    toggleButton.BackgroundColor3 =
                        active and theme.primary or theme.background
                    toggleButton.TextColor3 =
                        active and theme.background or theme.text
                    outline.Transparency = active and 0 or 0.22
                end
                toggleButton.Activated:Connect(function()
                    if busy then return end
                    busy = true
                    repaint()
                    local desired = not active
                    task.spawn(function()
                        local ok, applied, message = pcall(function()
                            local module = loadAuxiliary("fling_touch")
                            if remoteOperation == "receiving" then
                                return module:allowReceiving(desired)
                            elseif desired then
                                return module:enable()
                            else
                                return module:disable()
                            end
                        end)
                        if destroyed then
                            if auxiliaryModules.fling_touch then
                                pcall(auxiliaryModules.fling_touch.shutdown,
                                    auxiliaryModules.fling_touch)
                            end
                            return
                        end
                        if ok and applied then
                            active = desired
                            status(titleText .. ": " .. (active and "ON" or "OFF"))
                        else
                            status(titleText .. ": " ..
                                tostring(ok and message or applied))
                        end
                        busy = false
                        repaint()
                    end)
                end)
                repaint()
            end
            addFlingControl("Fling", "Empurrar ao tocar · jogo integrado", "sending")
            addFlingControl("Aceitar Fling", "Permite ser empurrado por amigos", "receiving")
            local hint = label(mysteryPage,
                "Fling: servidores públicos ou privados com integração no jogo. Participantes precisam aceitar Fling.",
                11, theme.muted, 49)
            hint.TextWrapped = true
        end

    end
    bootStage = "Construindo Emote e 666"
    initializeEmoteTabs()
    end -- Player/Emote/666 block: release its many UI locals.

    -- Dedicated Anim page: animation PACKS, not R6 procedural emotes.
    -- Scope remains isolated to avoid the 200-local-register executor limit.
    bootStage = "Construindo Anim"
    do
        local animPage = pages.Anim
        title(animPage, "Anim", "Pacote completo ou animações individuais · R15.")

        local choices = {
            {id = "vampire", name = "Vampire Animation Pack", short = "Vampire"},
            {id = "astronaut", name = "Astronaut Animation Pack", short = "Astronaut"},
            {id = "bubbly", name = "Bubbly Animation Pack", short = "Bubbly"},
            {id = "cartoony", name = "Cartoony Animation Pack", short = "Cartoony"},
            {id = "elder", name = "Elder Animation Pack", short = "Elder"},
            {id = "knight", name = "Knight Animation Pack", short = "Knight"},
            {id = "levitation", name = "Levitation Animation Pack", short = "Levitation"},
            {id = "mage", name = "Mage Animation Pack", short = "Mage"},
            {id = "ninja", name = "Ninja Animation Pack", short = "Ninja"},
            {id = "oldschool", name = "Oldschool Animation Pack", short = "Oldschool"},
            {id = "pirate", name = "Pirate Animation Pack", short = "Pirate"},
            {id = "robot", name = "Robot Animation Pack", short = "Robot"},
            {id = "rthro", name = "Rthro Animation Pack", short = "Rthro"},
            {id = "stylish", name = "Stylish Animation Pack", short = "Stylish"},
            {id = "superhero", name = "Superhero Animation Pack", short = "Superhero"},
            {id = "toy", name = "Toy Animation Pack", short = "Toy"},
            {id = "werewolf", name = "Werewolf Animation Pack", short = "Werewolf"},
            {id = "zombie", name = "Zombie Animation Pack", short = "Zombie"},
            {id = "default", name = "Padrão do mapa", short = "Padrão"},
        }
        local selected, selectedLabel, selectedShort =
            "vampire", "Vampire Animation Pack", "Vampire"
        local selectedDetail
        local chooseRow = card(animPage, 65)
        cardText(chooseRow, "Pacote", "Selecione na lista.", 176)
        local chooseButton = button(chooseRow, "Vampire  ▾",
            UDim2.new(1, -172, 0, 15), UDim2.fromOffset(160, 32))
        chooseButton.TextSize = 12
        chooseButton.TextTruncate = Enum.TextTruncate.AtEnd

        -- Searchable list within a bounded dropdown: no huge vertical panel.
        local drop = ordered(animPage, new("Frame", {
            Name = "AnimationChoices",
            Size = UDim2.new(1, -2, 0, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ClipsDescendants = true,
            Visible = false,
        }, animPage))
        local searchBox = new("TextBox", {
            Name = "AnimationSearch",
            Position = UDim2.fromOffset(6, 5),
            Size = UDim2.new(1, -12, 0, 31),
            BackgroundColor3 = theme.card,
            BackgroundTransparency = 0.08,
            TextColor3 = theme.text,
            PlaceholderColor3 = theme.muted,
            PlaceholderText = "Buscar pacote...",
            ClearTextOnFocus = false,
            Text = "",
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, drop)
        rounded(searchBox, 6)
        new("UIPadding", {
            PaddingLeft = UDim.new(0, 9),
            PaddingRight = UDim.new(0, 9),
        }, searchBox)
        local list = new("ScrollingFrame", {
            Name = "AnimationPackList",
            Position = UDim2.fromOffset(6, 43),
            Size = UDim2.new(1, -12, 0, 162),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = theme.accent,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            CanvasSize = UDim2.fromOffset(0, 0),
        }, drop)
        local layout = new("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 4),
        }, list)
        local dropdownOpened = false
        local buttons = {}
        local function repaintSelection()
            chooseButton.Text = selectedShort .. (dropdownOpened and "  ▴" or "  ▾")
            chooseButton.BackgroundColor3 = dropdownOpened and theme.primary or theme.card
            chooseButton.TextColor3 = dropdownOpened and theme.background or theme.text
            drop.Size = UDim2.new(1, -2, 0, dropdownOpened and 211 or 0)
            drop.Visible = dropdownOpened
            if selectedDetail then
                selectedDetail.Text = selected == "default"
                    and "Animações originais do personagem."
                    or (selectedLabel .. " · R15 · 9 movimentos")
            end
        end
        for i, choice in ipairs(choices) do
            local item = button(list, choice.name,
                UDim2.new(), UDim2.new(1, -8, 0, 33))
            item.LayoutOrder = i
            item.TextXAlignment = Enum.TextXAlignment.Left
            item.TextTruncate = Enum.TextTruncate.AtEnd
            item.TextSize = 12
            table.insert(buttons, item)
            item.Activated:Connect(function()
                selected = choice.id
                selectedLabel = choice.name
                selectedShort = choice.short
                dropdownOpened = false
                searchBox.Text = ""
                repaintSelection()
            end)
        end
        local function filterChoices()
            local term = string.lower(searchBox.Text)
            local visibleCount = 0
            for i, entry in ipairs(choices) do
                local show = term == ""
                    or string.find(string.lower(entry.name), term, 1, true) ~= nil
                    or string.find(entry.id, term, 1, true) ~= nil
                buttons[i].Visible = show
                if show then visibleCount = visibleCount + 1 end
            end
            list.CanvasSize = UDim2.fromOffset(
                0, visibleCount > 0 and visibleCount * 37 + 5 or 0)
            list.CanvasPosition = Vector2.zero
        end
        connect(searchBox:GetPropertyChangedSignal("Text"), filterChoices)
        chooseButton.Activated:Connect(function()
            dropdownOpened = not dropdownOpened
            if dropdownOpened then searchBox.Text = "" end
            repaintSelection()
        end)
        local selectedRow = card(animPage, 51)
        local selectedCaption = label(selectedRow, "Selecionado", 13, theme.text, 21)
        selectedCaption.Position = UDim2.fromOffset(10, 4)
        selectedDetail = label(selectedRow,
            "Vampire Animation Pack · R15 · 9 movimentos",
            11, theme.muted, 21)
        selectedDetail.Position = UDim2.fromOffset(10, 27)
        selectedDetail.Size = UDim2.new(1, -20, 0, 21)
        selectedDetail.TextTruncate = Enum.TextTruncate.AtEnd
        filterChoices()
        repaintSelection()
        local actionsRow = card(animPage, 49)
        local applyButton = button(actionsRow, "APLICAR",
            UDim2.fromOffset(9, 10),
            UDim2.new(0.5, -15, 0, 30), nil, true)
        local restoreButton = button(actionsRow, "RESTAURAR",
            UDim2.new(0.5, 6, 0, 10),
            UDim2.new(0.5, -15, 0, 30))
        local info = label(animPage,
            "R15: usa Animate/Animator existentes. Visibilidade para outros depende do jogo e dos assets.",
            11, theme.muted, 54)
        info.TextWrapped = true
        local busy = false
        local resetOverrides = function() end
        local function updateInfo(textValue, success)
            info.Text = textValue
            info.TextColor3 = success and theme.accent or theme.muted
        end
        local function restoreSelected()
            if busy then return end
            busy = true
            local ok, worked, reason = pcall(function()
                local module = auxiliaryModules.anim_packs
                if module then return module:disable() end
                return true, "Nenhum pacote ativo."
            end)
            busy = false
            if ok and worked then
                selected, selectedLabel, selectedShort =
                    "default", "Padrão do mapa", "Padrão"
                resetOverrides()
                repaintSelection()
                updateInfo("Padrão do mapa restaurado.", true)
                status("Anim: pacote restaurado.")
            else
                updateInfo("Erro ao restaurar: " .. tostring(ok and reason or worked), false)
            end
        end
        applyButton.Activated:Connect(function()
            if busy then return end
            if selected == "default" then
                restoreSelected()
                return
            end
            busy = true
            local requestPreset, requestLabel = selected, selectedLabel
            applyButton.Text = "APLICANDO..."
            task.spawn(function()
                local ok, applied, reason = pcall(function()
                    local module = loadAuxiliary("anim_packs")
                    return module:enable(requestPreset)
                end)
                if destroyed then
                    local module = auxiliaryModules.anim_packs
                    if module then pcall(module.disable, module) end
                    return
                end
                busy = false
                applyButton.Text = "APLICAR"
                if ok and applied then
                    resetOverrides()
                    updateInfo("Ativo: " .. requestLabel .. " · R15. Confirme FE com outro jogador.", true)
                    status("Anim: " .. requestLabel .. " aplicado ao seu personagem.")
                else
                    local message = tostring(ok and reason or applied)
                    updateInfo("Não foi possível aplicar: " .. message, false)
                    status("Anim: " .. message)
                end
            end)
        end)
        restoreButton.Activated:Connect(restoreSelected)

        -- Mix-and-match editor: each movement can use a different pack.
        -- Only one bounded picker opens at once, to keep the mobile list compact.
        title(animPage, "Personalizar movimentos",
            "Ex.: Idle Elder + Walk Cartoony. Herda o pacote base quando não definido.")
        local movements = {
            {id = "idle", name = "Idle · Parado"},
            {id = "walk", name = "Walk · Andando"},
            {id = "run", name = "Run · Correndo"},
            {id = "jump", name = "Jump · Pulando"},
            {id = "fall", name = "Fall · Caindo"},
            {id = "climb", name = "Climb · Escalando"},
            {id = "swim", name = "Swim · Nadando"},
            {id = "swimidle", name = "Swim Idle · Na água"},
        }
        local overrides = {}
        local refreshButtons = {}
        local closePicker
        local pickerChoices = {{id = "inherit", name = "Herdar pacote base", short = "Herdar"}}
        for _, choice in ipairs(choices) do
            table.insert(pickerChoices, choice)
        end
        for _, movement in ipairs(movements) do
            local row = card(animPage, 47)
            local movementLabel = label(row, movement.name, 12, theme.text, 31)
            movementLabel.Position = UDim2.fromOffset(10, 7)
            movementLabel.Size = UDim2.new(1, -174, 0, 31)
            movementLabel.TextTruncate = Enum.TextTruncate.AtEnd
            local moveButton = button(row, "Herdar  ▾",
                UDim2.new(1, -166, 0, 7), UDim2.fromOffset(155, 31))
            moveButton.TextSize = 12
            moveButton.TextTruncate = Enum.TextTruncate.AtEnd
            local picker = ordered(animPage, new("Frame", {
                Name = "AnimPicker_" .. movement.id,
                Size = UDim2.new(1, -2, 0, 0),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ClipsDescendants = true,
                Visible = false,
            }, animPage))
            local search = new("TextBox", {
                Position = UDim2.fromOffset(6, 4),
                Size = UDim2.new(1, -12, 0, 31),
                BackgroundColor3 = theme.card,
                TextColor3 = theme.text,
                PlaceholderColor3 = theme.muted,
                PlaceholderText = "Buscar animação...",
                ClearTextOnFocus = false,
                Text = "",
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                Font = Enum.Font.Gotham,
            }, picker)
            rounded(search, 6)
            new("UIPadding", {
                PaddingLeft = UDim.new(0, 9),
                PaddingRight = UDim.new(0, 9),
            }, search)
            local entries = new("ScrollingFrame", {
                Position = UDim2.fromOffset(6, 42),
                Size = UDim2.new(1, -12, 0, 145),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ScrollBarThickness = 3,
                ScrollBarImageColor3 = theme.accent,
                ScrollingDirection = Enum.ScrollingDirection.Y,
                CanvasSize = UDim2.fromOffset(0, 0),
            }, picker)
            new("UIListLayout", {
                Padding = UDim.new(0, 4),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }, entries)
            local entryButtons = {}
            local function selectedName()
                local value = overrides[movement.id]
                if not value then return "Herdar" end
                for _, choice in ipairs(choices) do
                    if choice.id == value then return choice.short end
                end
                return "Herdar"
            end
            local function paintButton()
                moveButton.Text = selectedName() .. (picker.Visible and "  ▴" or "  ▾")
                moveButton.BackgroundColor3 = picker.Visible and theme.primary or theme.card
                moveButton.TextColor3 = picker.Visible and theme.background or theme.text
            end
            refreshButtons[movement.id] = paintButton
            local function closeThis()
                picker.Visible = false
                picker.Size = UDim2.new(1, -2, 0, 0)
                paintButton()
            end
            for j, choice in ipairs(pickerChoices) do
                local entry = button(entries, choice.name,
                    UDim2.new(), UDim2.new(1, -8, 0, 32))
                entry.LayoutOrder = j
                entry.TextXAlignment = Enum.TextXAlignment.Left
                entry.TextTruncate = Enum.TextTruncate.AtEnd
                entry.TextSize = 12
                entryButtons[j] = entry
                entry.Activated:Connect(function()
                    if busy then return end
                    overrides[movement.id] = choice.id ~= "inherit" and choice.id or nil
                    closeThis()
                    closePicker = nil
                    search.Text = ""
                end)
            end
            local function filterPicker()
                local term = string.lower(search.Text)
                local count = 0
                for j, choice in ipairs(pickerChoices) do
                    local show = term == ""
                        or string.find(string.lower(choice.name), term, 1, true) ~= nil
                        or string.find(choice.id, term, 1, true) ~= nil
                    entryButtons[j].Visible = show
                    if show then count = count + 1 end
                end
                entries.CanvasSize = UDim2.fromOffset(0, count * 36 + 4)
                entries.CanvasPosition = Vector2.zero
            end
            connect(search:GetPropertyChangedSignal("Text"), filterPicker)
            moveButton.Activated:Connect(function()
                if busy then return end
                local wasOpen = picker.Visible
                if closePicker then closePicker() end
                closePicker = nil
                if not wasOpen then
                    picker.Visible = true
                    picker.Size = UDim2.new(1, -2, 0, 193)
                    search.Text = ""
                    filterPicker()
                    closePicker = closeThis
                end
                paintButton()
            end)
            filterPicker()
            paintButton()
        end
        resetOverrides = function()
            for movement in pairs(overrides) do overrides[movement] = nil end
            if closePicker then closePicker() end
            closePicker = nil
            for _, repaint in pairs(refreshButtons) do repaint() end
        end
        local mixActions = card(animPage, 52)
        local mixApply = button(mixActions, "APLICAR MISTURA",
            UDim2.fromOffset(9, 10), UDim2.new(0.5, -15, 0, 32), nil, true)
        mixApply.TextSize = 12
        local mixClear = button(mixActions, "LIMPAR CAMPOS",
            UDim2.new(0.5, 6, 0, 10), UDim2.new(0.5, -15, 0, 32))
        mixClear.TextSize = 12
        local mixInfo = label(animPage,
            "Pacote base acima + alterações individuais. Use APLICAR MISTURA para ativar.",
            11, theme.muted, 53)
        mixInfo.TextWrapped = true
        mixClear.Activated:Connect(function()
            if busy then return end
            resetOverrides()
            mixInfo.Text = "Campos limpos. A animação ativa não foi alterada."
            mixInfo.TextColor3 = theme.muted
        end)
        mixApply.Activated:Connect(function()
            if busy then return end
            busy = true
            local base = selected
            local mixture = {}
            for id, value in pairs(overrides) do mixture[id] = value end
            mixApply.Text = "APLICANDO..."
            task.spawn(function()
                local ok, applied, reason = pcall(function()
                    local module = loadAuxiliary("anim_packs")
                    return module:enableMixed(base, mixture)
                end)
                if destroyed then
                    local module = auxiliaryModules.anim_packs
                    if module then pcall(module.disable, module) end
                    return
                end
                busy = false
                mixApply.Text = "APLICAR MISTURA"
                if ok and applied then
                    mixInfo.Text = "Mistura R15 aplicada. Teste com outro jogador para confirmar FE."
                    mixInfo.TextColor3 = theme.accent
                    status("Anim: movimentos personalizados aplicados.")
                else
                    local message = tostring(ok and reason or applied)
                    mixInfo.Text = "Não foi possível aplicar: " .. message
                    mixInfo.TextColor3 = theme.muted
                    status("Anim: " .. message)
                end
            end)
        end)
    end -- Anim page: release temporary UI locals.

    -- Waypoints use their own module/scoped UI to avoid the Luau 200-local cap.
    bootStage = "Construindo Waypoints"
    do
        local waypointPage = pages.Waypoints
        title(waypointPage, "Waypoints",
            "Salve vários locais e crie atalhos flutuantes arrastáveis.")
        local loadingText = label(waypointPage,
            "Carregando locais e atalhos...",
            11, theme.muted, 32)
        task.spawn(function()
            local ok, worked, reason = pcall(function()
                local module = loadAuxiliary("waypoints")
                if destroyed then return false, "Monarca encerrado." end
                return module:mount(waypointPage, gui, theme, function(message)
                    status(message)
                end)
            end)
            if destroyed then return end
            if ok and worked then
                if loadingText.Parent then loadingText:Destroy() end
            else
                local detail = tostring(ok and reason or worked)
                loadingText.Text = "Waypoints não pôde carregar: " .. detail
                status("Waypoints: " .. detail)
            end
        end)
    end

    bootStage = "Construindo Settings e Visual"
    -- Keep only the functions needed by the final destroy/intro sequence.
    local disableAll, refresh
    do
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
    disableAll = function()
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
    
    refresh = function()
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
    end -- Settings + Visual block: release temporary UI registers.

    -- Dragging has its own scope; no 4 persistent locals leaked into boot.
    do
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
    end -- drag-only locals
    local function destroy()
        if destroyed then return end
        stopAlvo()
        cleanupTargetTool()
        if auxiliaryModules.fling_touch then
            pcall(auxiliaryModules.fling_touch.shutdown, auxiliaryModules.fling_touch)
        end
        for _, name in ipairs({"player_fly", "zombie_r6", "pose_666", "headless_local", "korblox_right_leg", "owner_tag", "radioactive_trail", "antifling", "waypoints", "emote_catalog", "emote_marketplace", "server_invisibility", "clone_invisibility", "anim_packs", "player_reverse"}) do
            if auxiliaryModules[name] then
                pcall(auxiliaryModules[name].disable, auxiliaryModules[name])
            end
        end
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
    bootStage = "Ativando janela"
    updateLayout()
    switch("Home")
    if playerAdjusted then applyPlayer() end
    
    -- Animate actual setup phases; catalogue fetch determines when the final stage
    -- completes. A timeout keeps the panel usable if the network is unavailable.
    task.spawn(function()
        if destroyed then return end
        local ok, err = xpcall(function()
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
        end, function(e) return tostring(e) end)
        if not ok and not destroyed then
            warn("[Monarca] Falha de abertura: " .. tostring(err))
            if introBackdrop and introBackdrop.Parent then introBackdrop:Destroy() end
            main.Visible = true
            footer.Text = "Erro na animação inicial: " .. tostring(err)
        end
    end)
    -- Prevent an animation/network issue from leaving the panel invisible forever.
    task.delay(9, function()
        if destroyed or not main.Parent or main.Visible then return end
        warn("[Monarca] Tempo limite da abertura; mostrando painel.")
        if introBackdrop and introBackdrop.Parent then introBackdrop:Destroy() end
        main.Visible = true
    end)
    
end

local ok, failure = xpcall(bootMonarca, function(err)
    local detail = tostring(err)
    if debug and type(debug.traceback) == "function" then
        local good, trace = pcall(debug.traceback, detail, 2)
        if good then detail = tostring(trace) end
    end
    return detail
end)

if not ok then
    local message = "Monarca: falha na inicialização (" .. bootStage .. ")\\n" .. tostring(failure)
    warn("[Monarca] " .. message)
    -- Visible, persistent error notice even if the regular menu never mounted.
    pcall(function()
        local players = game:GetService("Players")
        local user = players.LocalPlayer
        local playerGui = user and user:WaitForChild("PlayerGui", 8)
        if not playerGui then return end
        local previous = playerGui:FindFirstChild("MonarcaStartupError")
        if previous then previous:Destroy() end
        local overlay = Instance.new("ScreenGui")
        overlay.Name = "MonarcaStartupError"
        overlay.IgnoreGuiInset = true
        overlay.ResetOnSpawn = false
        overlay.DisplayOrder = 99999
        overlay.Parent = playerGui
        local banner = Instance.new("TextBox")
        banner.Name = "ErrorDetail"
        banner.Size = UDim2.new(1, -24, 0, 146)
        banner.Position = UDim2.new(0, 12, 0, 50)
        banner.BackgroundColor3 = Color3.fromRGB(22, 15, 24)
        banner.BorderSizePixel = 0
        banner.ClearTextOnFocus = false
        banner.TextEditable = false
        banner.TextColor3 = Color3.fromRGB(255, 225, 225)
        banner.TextXAlignment = Enum.TextXAlignment.Left
        banner.TextYAlignment = Enum.TextYAlignment.Top
        banner.TextWrapped = true
        banner.TextSize = 13
        banner.Font = Enum.Font.Code
        banner.Text = message .. "\\n(Faça uma captura desta mensagem.)"
        banner.Parent = overlay
        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 12)
        padding.PaddingRight = UDim.new(0, 12)
        padding.PaddingTop = UDim.new(0, 12)
        padding.PaddingBottom = UDim.new(0, 10)
        padding.Parent = banner
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = banner
    end)
end

-- Return startup result so Monarca.lua can surface even errors from the core.
return ok, failure
