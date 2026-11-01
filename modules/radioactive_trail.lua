-- Monarca 666 / Radioactive Trail v0.7.1
-- Dense green afterimage, actual local recoloring of touched BaseParts,
-- directional footprint ribbons with tapering width/length and soft fade.
-- Client-only. Terrain / extremely large bases get a localized surface glow.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local Trail = {}

local GREEN = Color3.fromRGB(62, 255, 14)
local GREEN_SOFT = Color3.fromRGB(165, 255, 65)
local MAX_PATCHES = 90
local MIN_INTERVAL = 0.075
local MIN_SPACING = 0.37
local DURATION = 4.1
local MAX_FULL_TINT_SIZE = 230
local MAX_LIT_PATCHES = 4

local active = false
local version = 0
local heartbeat, respawnListener, effectFolder
local patches = {}
local tinted = {}
local lastPosition
local accumulator = 0

local function removePatch(entry)
    if entry.dead then return end
    entry.dead = true
    if entry.part then entry.part:Destroy() end
end

local function restoreBlock(part, state)
    if tinted[part] ~= state then return end
    tinted[part] = nil
    if state.fade then state.fade:Cancel() end
    if part and part.Parent then
        pcall(function()
            part.Color = state.color
            part.Material = state.material
        end)
    end
end

local function clear()
    for _, mark in ipairs(patches) do removePatch(mark) end
    table.clear(patches)
    for part, state in pairs(tinted) do
        restoreBlock(part, state)
    end
    if effectFolder then effectFolder:Destroy(); effectFolder = nil end
    lastPosition, accumulator = nil, 0
end

local function tintActualBlock(part, ticket)
    -- Color the real touched block rather than only creating an overlay.
    -- A Terrain voxel isn't a BasePart, and painting the entire huge map
    -- foundation would be destructive/visually wrong; those get an overlay.
    if not part or not part:IsA("BasePart") or not part.Anchored
        or part.Transparency > 0.7 or part.Size.X > MAX_FULL_TINT_SIZE
        or part.Size.Z > MAX_FULL_TINT_SIZE then return end

    local state = tinted[part]
    if not state then
        state = {
            color = part.Color,
            material = part.Material,
            revision = 0,
        }
        tinted[part] = state
    end
    state.revision = state.revision + 1
    local revision = state.revision
    if state.fade then state.fade:Cancel(); state.fade = nil end
    local success = pcall(function()
        part.Color = GREEN
        part.Material = Enum.Material.Neon
    end)
    if not success then
        restoreBlock(part, state)
        return
    end
    task.delay(0.8, function()
        if not active or ticket ~= version
            or tinted[part] ~= state or state.revision ~= revision then return end
        local fade = TweenService:Create(part,
            TweenInfo.new(2.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
            {Color = state.color}
        )
        state.fade = fade
        fade:Play()
    end)
    task.delay(3.25, function()
        if ticket == version and tinted[part] == state
            and state.revision == revision then restoreBlock(part, state) end
    end)
end

local function emitMark(hit, movement, distance, ticket)
    if not effectFolder or not active or ticket ~= version then return end
    local normal = hit.Normal
    if normal.Y < 0.54 then return end
    local projected = movement - normal * movement:Dot(normal)
    if projected.Magnitude < 0.01 then return end
    local along = projected.Unit
    local right = normal:Cross(along).Unit
    local length = math.clamp(distance + 0.9, 1.3, 6.5)
    local width = 3.15

    local slab = Instance.new("Part")
    slab.Name = "RadioactiveGroundFlow"
    slab.Size = Vector3.new(width, 0.045, length)
    slab.CFrame = CFrame.fromMatrix(
        hit.Position - along * math.min(distance * 0.45, 2)
            + normal * 0.028, right, normal, along
    )
    slab.Color = GREEN
    slab.Material = Enum.Material.Neon
    slab.Transparency = 0.36
    slab.Anchored = true
    slab.CanCollide = false
    slab.CanTouch = false
    slab.CanQuery = false
    slab.CastShadow = false
    slab.Parent = effectFolder

    local sparks = Instance.new("ParticleEmitter")
    sparks.Name = "RadioactiveDust"
    sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    sparks.Color = ColorSequence.new(GREEN, GREEN_SOFT)
    sparks.LightEmission = 1
    sparks.LightInfluence = 0
    sparks.Rate = 9
    sparks.Speed = NumberRange.new(0.45, 1.6)
    sparks.Lifetime = NumberRange.new(0.24, 0.7)
    sparks.SpreadAngle = Vector2.new(30, 30)
    sparks.EmissionDirection = Enum.NormalId.Top
    sparks.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.21),
        NumberSequenceKeypoint.new(0.6, 0.13),
        NumberSequenceKeypoint.new(1, 0),
    })
    sparks.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.18),
        NumberSequenceKeypoint.new(0.7, 0.55),
        NumberSequenceKeypoint.new(1, 1),
    })
    sparks.Parent = slab
    sparks:Emit(4)

    local light = Instance.new("PointLight")
    light.Color = GREEN
    light.Range = 7
    light.Brightness = 0.75
    light.Shadows = false
    light.Parent = slab

    local mark = {part = slab, light = light, dead = false}
    table.insert(patches, mark)
    if #patches > MAX_LIT_PATCHES then
        local older = patches[#patches - MAX_LIT_PATCHES]
        if older.light then older.light.Enabled = false end
    end
    if #patches > MAX_PATCHES then
        removePatch(table.remove(patches, 1))
    end

    -- Width and length taper together while fading; the residue progressively
    -- contracts instead of remaining a fixed-size rectangle until vanishing.
    task.delay(0.30, function()
        if mark.dead or ticket ~= version or not slab.Parent then return end
        sparks.Rate = 0
        local shrink = TweenService:Create(slab,
            TweenInfo.new(DURATION - 0.30, Enum.EasingStyle.Quad,
                Enum.EasingDirection.In),
            {
                Transparency = 1,
                Size = Vector3.new(0.07, 0.035, 0.08),
                Color = GREEN_SOFT,
            }
        )
        shrink:Play()
        if light.Enabled then
            TweenService:Create(light,
                TweenInfo.new(1.0), {Brightness = 0}):Play()
        end
    end)
    task.delay(DURATION, function()
        removePatch(mark)
    end)
    tintActualBlock(hit.Instance, ticket)
end

local function traceMovement(ticket)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root or humanoid.Health <= 0 then return end
    if humanoid.MoveDirection.Magnitude < 0.05 then
        lastPosition = nil
        return
    end
    local currentVelocity = root.AssemblyLinearVelocity
    local flatVelocity = Vector3.new(currentVelocity.X, 0, currentVelocity.Z)
    if flatVelocity.Magnitude < 0.8 then return end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character, effectFolder}
    params.IgnoreWater = true
    local hit = workspace:Raycast(
        root.Position + Vector3.new(0, 1.4, 0),
        Vector3.new(0, -8.4, 0), params
    )
    if not hit or hit.Normal.Y < 0.54 then
        lastPosition = nil
        return
    end
    if (root.Position - hit.Position).Magnitude > 4.3 then
        lastPosition = nil
        return
    end
    local old = lastPosition
    local delta = old and hit.Position - old or flatVelocity.Unit * 0.5
    local flat = Vector3.new(delta.X, 0, delta.Z)
    if old and flat.Magnitude < MIN_SPACING then return end
    if not old then
        flat = Vector3.new(flatVelocity.X, 0, flatVelocity.Z).Unit * 0.75
    end
    lastPosition = hit.Position
    emitMark(hit, flat, math.clamp(flat.Magnitude, 0.4, 5.5), ticket)
end

function Trail:enable()
    if active then return true end
    if not player.Character then
        return false, "Personagem indisponível."
    end
    active = true
    version = version + 1
    local ticket = version
    local success, reason = pcall(function()
        effectFolder = Instance.new("Folder")
        effectFolder.Name = "MonarcaRadioactive_" .. tostring(player.UserId)
        effectFolder.Parent = workspace
        respawnListener = player.CharacterAdded:Connect(function()
            lastPosition = nil
        end)
        heartbeat = RunService.Heartbeat:Connect(function(dt)
            if not active or version ~= ticket then return end
            accumulator = accumulator + math.min(dt, 0.11)
            if accumulator < MIN_INTERVAL then return end
            accumulator = 0
            traceMovement(ticket)
        end)
    end)
    if not success then
        self:disable()
        return false, tostring(reason)
    end
    return true
end

function Trail:disable()
    active = false
    version = version + 1
    if heartbeat then heartbeat:Disconnect(); heartbeat = nil end
    if respawnListener then
        respawnListener:Disconnect()
        respawnListener = nil
    end
    clear()
end

function Trail:isActive() return active end
return Trail
