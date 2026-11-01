-- Monarca Owner Tag v0.7.0
-- Username-restricted LOCAL nameplate; not a trusted server permission system.
-- ScreenGui projects head location, while avatar-relative screen scaling prevents a giant tag on distant characters.
-- RGB wave: a soft horizontal UIGradient, smoothly animated across the text.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local OwnerTag = {}

local allowed = player.Name:lower() == "samulucas7419"
local active = false
local text = "MONARCA"
local red, green, blue = 180, 145, 255
local rainbowFast = false  -- kept for compatibility with saved settings
local screenGui, container, label, shadow, gradient, labelScale
local currentHead
local respawnConnection, frameConnection
local generation = 0
local waveAccumulator = 0
local MAX_DISTANCE = 110
local REFERENCE_AVATAR_PX = 160
local MIN_AVATAR_PX = 22
local MIN_LABEL_SCALE = 0.12
local WAVE_SPEED = 0.18          -- ~5.6 seconds per color cycle, not strobing
local WAVE_WIDTH = 0.82          -- different colors at different text positions
local WAVE_STOPS = 6             -- bounded to 6 stops for UIGradient performance
local WAVE_INTERVAL = 1 / 20    -- smooth interpolation with modest update cost

local function cleanText(value)
    local input = tostring(value or ""):gsub("[%c]", " ")
        :gsub("^%s+", ""):gsub("%s+$", "")
    if input == "" then return "MONARCA" end
    local ok, cutoff = pcall(utf8.offset, input, 33)
    if ok and cutoff then input = input:sub(1, cutoff - 1) end
    if #input > 160 then input = input:sub(1, 160) end
    return input
end

local function waveColors(now)
    local shift = (now * WAVE_SPEED) % 1
    local keys = {}
    for i = 0, WAVE_STOPS - 1 do
        local position = i / (WAVE_STOPS - 1)
        local hue = (shift + position * WAVE_WIDTH) % 1
        keys[#keys + 1] = ColorSequenceKeypoint.new(
            position, Color3.fromHSV(hue, 0.86, 1)
        )
    end
    return ColorSequence.new(keys)
end

local function destroyGui()
    if screenGui then pcall(function() screenGui:Destroy() end) end
    screenGui, container, label, shadow, gradient, labelScale = nil, nil, nil, nil, nil, nil
end

local function makeLabel(parent, name, position, color, zIndex)
    local value = Instance.new("TextLabel")
    value.Name = name
    value.Position = position
    value.Size = UDim2.fromScale(1, 1)
    value.BackgroundTransparency = 1
    value.Font = Enum.Font.GothamBold
    value.TextSize = 19
    value.TextScaled = false
    value.TextWrapped = false
    value.TextTruncate = Enum.TextTruncate.AtEnd
    value.TextColor3 = color
    value.TextXAlignment = Enum.TextXAlignment.Center
    value.TextYAlignment = Enum.TextYAlignment.Center
    value.ZIndex = zIndex
    value.Parent = parent
    return value
end

local function createGui()
    if screenGui and screenGui.Parent then return true end
    local parent = player:FindFirstChildOfClass("PlayerGui")
        or player:WaitForChild("PlayerGui", 8)
    if not parent then return false end
    destroyGui()

    local gui = Instance.new("ScreenGui")
    gui.Name = "MonarcaOwnerTag"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 105
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = parent

    local frame = Instance.new("Frame")
    frame.Name = "FixedSizeNameplate"
    frame.AnchorPoint = Vector2.new(0.5, 1)
    frame.Size = UDim2.fromOffset(280, 42)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Active = false
    frame.Visible = false
    frame.Parent = gui
    local scale = Instance.new("UIScale")
    scale.Name = "AvatarRelativeScale"
    scale.Scale = 1
    scale.Parent = frame

    -- Flat shadow instead of TextStroke, which can conflict with UIGradient.
    local dark = makeLabel(frame, "TextShadow",
        UDim2.fromOffset(1, 2), Color3.fromRGB(2, 2, 6), 1)
    dark.TextTransparency = 0.35
    local main = makeLabel(frame, "CustomTag",
        UDim2.fromOffset(0, 0), Color3.fromRGB(red, green, blue), 2)

    local wave = Instance.new("UIGradient")
    wave.Name = "RainbowWave"
    wave.Rotation = 0
    wave.Color = waveColors(os.clock())
    wave.Enabled = rainbowFast
    wave.Parent = main

    screenGui, container, label, shadow, gradient, labelScale = gui, frame, main, dark, wave, scale
    return true
end

local function updateAppearance()
    if not label then return end
    label.Text = text
    if shadow then shadow.Text = text end
    label.TextColor3 = rainbowFast and Color3.new(1, 1, 1)
        or Color3.fromRGB(red, green, blue)
    if gradient then
        gradient.Enabled = rainbowFast
        if rainbowFast then gradient.Color = waveColors(os.clock()) end
    end
end

local function bindHead(character, token)
    if not active or generation ~= token or player.Character ~= character then return end
    local head = character:FindFirstChild("Head")
        or character:WaitForChild("Head", 8)
    if not active or generation ~= token or player.Character ~= character then return end
    currentHead = head and head:IsA("BasePart") and head or nil
    if container and not currentHead then container.Visible = false end
end

local function updatePosition()
    if not active or not container then return end
    local head = currentHead
    local camera = workspace.CurrentCamera
    if not head or not head.Parent or not camera then
        container.Visible = false
        return
    end
    -- A fully fixed-pixel ScreenGui appeared to GROW as the avatar shrank
    -- during zoom-out. Derive the label's scale from a projected 3D body
    -- reference, so both avatar and tag shrink together in screen space.
    local above = head.Position + Vector3.new(0, head.Size.Y * 0.5 + 0.85, 0)
    local pos, onScreen = camera:WorldToViewportPoint(above)
    local distance = (camera.CFrame.Position - above).Magnitude
    local lower = head.Position - Vector3.new(0, 3.4, 0)
    local bottom = camera:WorldToViewportPoint(lower)
    local avatarHeightPx = math.abs(bottom.Y - pos.Y)
    local visible = onScreen and pos.Z > 0 and distance <= MAX_DISTANCE
        and avatarHeightPx >= MIN_AVATAR_PX
    container.Visible = visible
    if visible then
        -- Cap close-up growth, but shrink proportional to the avatar at
        -- distance; no zoom-out enlargement relative to the character.
        local desired = math.clamp(
            avatarHeightPx / REFERENCE_AVATAR_PX, MIN_LABEL_SCALE, 1
        )
        if labelScale then labelScale.Scale = desired end
        container.Position = UDim2.fromOffset(
            math.floor(pos.X + 0.5), math.floor(pos.Y + 0.5)
        )
    end
end

function OwnerTag:configure(config)
    if not allowed then return false, "Nome não autorizado." end
    if type(config) ~= "table" then return false, "Configuração inválida." end
    if config.text ~= nil then text = cleanText(config.text) end
    if config.red ~= nil then
        red = math.clamp(math.floor(tonumber(config.red) or red), 0, 255)
    end
    if config.green ~= nil then
        green = math.clamp(math.floor(tonumber(config.green) or green), 0, 255)
    end
    if config.blue ~= nil then
        blue = math.clamp(math.floor(tonumber(config.blue) or blue), 0, 255)
    end
    if config.rainbowFast ~= nil then rainbowFast = config.rainbowFast == true end
    waveAccumulator = 0
    updateAppearance()
    return true
end

function OwnerTag:enable()
    if not allowed then return false, "Tag exclusiva de samulucas7419." end
    if active then return true end
    local success, err = pcall(createGui)
    if not success or not err then
        return false, success and "PlayerGui indisponível." or tostring(err)
    end

    active = true
    generation = generation + 1
    local token = generation
    currentHead = nil
    if respawnConnection then respawnConnection:Disconnect() end
    respawnConnection = player.CharacterAdded:Connect(function(character)
        generation = generation + 1
        local nextToken = generation
        currentHead = nil
        if container then container.Visible = false end
        task.spawn(bindHead, character, nextToken)
    end)
    if frameConnection then frameConnection:Disconnect() end
    frameConnection = RunService.RenderStepped:Connect(function(dt)
        if not active then return end
        updatePosition()
        if rainbowFast and gradient and label then
            waveAccumulator = waveAccumulator + math.min(dt, 0.1)
            if waveAccumulator >= WAVE_INTERVAL then
                waveAccumulator = waveAccumulator % WAVE_INTERVAL
                gradient.Color = waveColors(os.clock())
            end
        else
            waveAccumulator = 0
        end
    end)
    if player.Character then
        task.spawn(bindHead, player.Character, token)
    end
    updateAppearance()
    return true
end

function OwnerTag:disable()
    active = false
    generation = generation + 1
    currentHead = nil
    if respawnConnection then
        respawnConnection:Disconnect()
        respawnConnection = nil
    end
    if frameConnection then
        frameConnection:Disconnect()
        frameConnection = nil
    end
    waveAccumulator = 0
    destroyGui()
end

function OwnerTag:isActive() return active end
return OwnerTag
