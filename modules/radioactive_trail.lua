-- Monarca 666 / Radioactive Trail v0.7.0
-- Client-side green ground contamination with fading neon surfaces, sparks,
-- and a subtle local light. NO permanent map changes or remote replication.
-- Safety/performance: patch cap, raycast rate limit, short particle lifetime.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local Trail = {}

local GREEN = Color3.fromRGB(72, 255, 18)
local GREEN_GLOW = Color3.fromRGB(150, 255, 35)
local MAX_PATCHES = 22
local MIN_SPACING = 1.8
local MIN_INTERVAL = 0.19
local PATCH_LIFETIME = 3.8
local MAX_TINTED_DIMENSION = 9

local running = false
local runId = 0
local heartbeat, characterConnection
local folder
local patches = {}
local tintedParts = {}
local lastPoint
local tickAccumulator = 0

local function clearPatch(record)
    if record.finished then return end
    record.finished = true
    if record.light then pcall(function() record.light:Destroy() end) end
    if record.part then pcall(function() record.part:Destroy() end) end
    if record.tween then pcall(function() record.tween:Cancel() end) end
end

local function restoreTint(part, state)
    if tintedParts[part] ~= state then return end
    tintedParts[part] = nil
    if state.tween then pcall(function() state.tween:Cancel() end) end
    if part and part.Parent then
        pcall(function()
            part.Color = state.originalColor
            part.Material = state.originalMaterial
        end)
    end
end

local function clearAll()
    for _, patch in ipairs(patches) do clearPatch(patch) end
    table.clear(patches)
    for part, state in pairs(tintedParts) do restoreTint(part, state) end
    if folder then folder:Destroy(); folder = nil end
    lastPoint = nil
    tickAccumulator = 0
end

local function tintGroundBlock(part, token)
    if not part or not part:IsA("BasePart") or not part.Anchored
        or part.Transparency >= 0.82
        or part.Size.X > MAX_TINTED_DIMENSION
        or part.Size.Z > MAX_TINTED_DIMENSION then
        return
    end

    local state = tintedParts[part]
    if not state then
        state = {
            originalColor = part.Color,
            originalMaterial = part.Material,
            revision = 0,
        }
        tintedParts[part] = state
    end
    state.revision = state.revision + 1
    local revision = state.revision
    if state.tween then state.tween:Cancel() end
    local ok = pcall(function()
        part.Material = Enum.Material.Neon
        part.Color = GREEN
    end)
    if not ok then
        restoreTint(part, state)
        return
    end

    task.delay(0.65, function()
        if token ~= runId or not running or tintedParts[part] ~= state
            or revision ~= state.revision then return end
        local tween = TweenService:Create(
            part,
            TweenInfo.new(2.7, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
            {Color = state.originalColor}
        )
        state.tween = tween
        tween:Play()
    end)
    task.delay(PATCH_LIFETIME, function()
        if token == runId and tintedParts[part] == state
            and revision == state.revision then
            restoreTint(part, state)
        end
    end)
end

local function createPatch(hit, root, token)
    local normal = hit.Normal
    if normal.Y < 0.60 then return end
    if not folder then return end

    local right = root.CFrame.RightVector
    local flatRight = right - normal * right:Dot(normal)
    if flatRight.Magnitude < 0.1 then
        flatRight = Vector3.new(1, 0, 0) - normal * normal.X
    end
    flatRight = flatRight.Unit
    local along = flatRight:Cross(normal)

    local part = Instance.new("Part")
    part.Name = "RadioactiveResidue"
    part.Size = Vector3.new(2.9, 0.055, 2.7)
    part.Color = GREEN
    part.Material = Enum.Material.Neon
    part.Transparency = 0.26
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part.CFrame = CFrame.fromMatrix(
        hit.Position + normal * 0.038,
        flatRight, normal, along
    )
    part.Parent = folder

    local particles = Instance.new("ParticleEmitter")
    particles.Name = "RadioactiveSparks"
    particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    particles.Color = ColorSequence.new(GREEN, GREEN_GLOW)
    particles.LightEmission = 0.85
    particles.LightInfluence = 0
    particles.Rate = 7
    particles.Lifetime = NumberRange.new(0.32, 0.72)
    particles.Speed = NumberRange.new(0.5, 1.5)
    particles.SpreadAngle = Vector2.new(45, 45)
    particles.EmissionDirection = Enum.NormalId.Top
    particles.RotSpeed = NumberRange.new(-45, 45)
    particles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.24),
        NumberSequenceKeypoint.new(0.5, 0.15),
        NumberSequenceKeypoint.new(1, 0),
    })
    particles.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.25),
        NumberSequenceKeypoint.new(0.7, 0.58),
        NumberSequenceKeypoint.new(1, 1),
    })
    particles.Parent = part
    particles:Emit(5)

    local light
    -- At most three latest residue marks emit PointLight on low-end phones.
    local total = #patches
    if total >= 3 then
        local oldLight = patches[total - 2].light
        if oldLight then
            oldLight.Enabled = false
        end
    end
    light = Instance.new("PointLight")
    light.Name = "RadioactiveGlow"
    light.Color = GREEN
    light.Range = 7
    light.Brightness = 0.6
    light.Shadows = false
    light.Parent = part

    local record = {part = part, light = light, finished = false}
    table.insert(patches, record)
    if #patches > MAX_PATCHES then
        clearPatch(table.remove(patches, 1))
    end

    tintGroundBlock(hit.Instance, token)

    task.delay(1.30, function()
        if token ~= runId or record.finished or not part.Parent then return end
        particles.Rate = 0
        if record.light and record.light.Parent then
            local lightFade = TweenService:Create(
                record.light, TweenInfo.new(0.9), {Brightness = 0}
            )
            lightFade:Play()
        end
        local fade = TweenService:Create(
            part,
            TweenInfo.new(PATCH_LIFETIME - 1.30,
                Enum.EasingStyle.Sine, Enum.EasingDirection.In),
            {Transparency = 1}
        )
        record.tween = fade
        fade:Play()
    end)
    task.delay(PATCH_LIFETIME + 0.05, function()
        clearPatch(record)
    end)
end

local function tryMarkGround(token)
    local character = player.Character
    local human = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or not human or human.Health <= 0 then return end
    if human.MoveDirection.Magnitude < 0.10 then return end

    local horizontalVelocity = root.AssemblyLinearVelocity
    local horizontalSpeed = Vector3.new(horizontalVelocity.X, 0,
        horizontalVelocity.Z).Magnitude
    if horizontalSpeed < 1.5 then return end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character, folder}
    params.IgnoreWater = true
    local hit = workspace:Raycast(
        root.Position + Vector3.new(0, 1.2, 0),
        Vector3.new(0, -7.5, 0), params
    )
    if not hit or hit.Normal.Y < 0.60 then return end
    -- Do not paint the ground when flying several studs above it.
    if (root.Position - hit.Position).Magnitude > 4.3 then return end
    if lastPoint then
        local step = Vector3.new(hit.Position.X - lastPoint.X, 0,
            hit.Position.Z - lastPoint.Z)
        if step.Magnitude < MIN_SPACING then return end
    end
    lastPoint = hit.Position
    createPatch(hit, root, token)
end

function Trail:enable()
    if running then return true end
    if not player.Character then return false, "Personagem indisponível." end
    running = true
    runId = runId + 1
    local token = runId
    local ok, err = pcall(function()
        folder = Instance.new("Folder")
        folder.Name = "MonarcaRadioactiveTrail_" .. tostring(player.UserId)
        folder.Parent = workspace
        characterConnection = player.CharacterAdded:Connect(function()
            lastPoint = nil
        end)
        heartbeat = RunService.Heartbeat:Connect(function(dt)
            if not running or token ~= runId then return end
            tickAccumulator = tickAccumulator + math.min(dt, 0.12)
            if tickAccumulator < MIN_INTERVAL then return end
            tickAccumulator = 0
            tryMarkGround(token)
        end)
    end)
    if not ok then
        self:disable()
        return false, tostring(err)
    end
    return true
end

function Trail:disable()
    running = false
    runId = runId + 1
    if heartbeat then heartbeat:Disconnect(); heartbeat = nil end
    if characterConnection then
        characterConnection:Disconnect()
        characterConnection = nil
    end
    clearAll()
end

function Trail:isActive() return running end
return Trail
