-- Monarca Fly v0.6.8
-- Camera-relative flight: thumbstick/WASD forward climbs or dives with camera.
-- No on-screen UP/DOWN actions. Tilt into forward/backward and lateral motion.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local Fly = {}

local active, speed = false, 40
local snapshot, connection, controls
local ownAttachment, velocity, orientation
local smoothVelocity = Vector3.zero
local smoothOrientation

local function getControls()
    if controls and type(controls.GetMoveVector) == "function" then return controls end
    local playerScripts = player:FindFirstChild("PlayerScripts")
    if not playerScripts then return nil end
    local module = playerScripts:FindFirstChild("PlayerModule")
    if not module then return nil end
    local ok, result = pcall(function()
        return require(module):GetControls()
    end)
    if ok and result then controls = result end
    return controls
end

-- GetMoveVector already contains the virtual joystick / keyboard axes.
-- MoveDirection fallback is reconstructed in camera-yaw coordinates.
local function inputAxes(hum, camera)
    local currentControls = getControls()
    if currentControls then
        local ok, movement = pcall(function()
            return currentControls:GetMoveVector()
        end)
        if ok and typeof(movement) == "Vector3" then
            return math.clamp(movement.X, -1, 1),
                math.clamp(-movement.Z, -1, 1)
        end
    end
    local vector = hum.MoveDirection
    local facing = camera.CFrame.LookVector
    local right = camera.CFrame.RightVector
    local horizontalForward = Vector3.new(facing.X, 0, facing.Z)
    local horizontalRight = Vector3.new(right.X, 0, right.Z)
    if horizontalForward.Magnitude < 0.001 then
        horizontalForward = Vector3.new(0, 0, -1)
    end
    if horizontalRight.Magnitude < 0.001 then
        horizontalRight = Vector3.new(1, 0, 0)
    end
    return math.clamp(vector:Dot(horizontalRight.Unit), -1, 1),
        math.clamp(vector:Dot(horizontalForward.Unit), -1, 1)
end

local function stop()
    active = false
    if connection then connection:Disconnect(); connection = nil end
    for _, mover in ipairs({velocity, orientation, ownAttachment}) do
        if mover then pcall(function() mover:Destroy() end) end
    end
    velocity, orientation, ownAttachment = nil, nil, nil
    smoothVelocity = Vector3.zero
    smoothOrientation = nil
    if snapshot then
        local hum = snapshot.hum
        if hum and hum.Parent then
            pcall(function()
                hum.PlatformStand = snapshot.platform
                hum.AutoRotate = snapshot.rotate
                if hum.Health > 0 then
                    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                end
            end)
        end
        snapshot = nil
    end
end

function Fly:setSpeed(value)
    speed = math.clamp(tonumber(value) or 40, 5, 160)
end

function Fly:enable()
    if active then return true end
    local character = player.Character
    local hum = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then
        return false, "Personagem indisponível para voar."
    end

    getControls()
    active = true
    snapshot = {hum = hum, platform = hum.PlatformStand, rotate = hum.AutoRotate}
    smoothOrientation = root.CFrame.Rotation
    smoothVelocity = Vector3.zero

    local ok, err = pcall(function()
        ownAttachment = Instance.new("Attachment")
        ownAttachment.Name = "MonarcaFlyAttachment"
        ownAttachment.Parent = root

        velocity = Instance.new("LinearVelocity")
        velocity.Name = "MonarcaFlyMotion"
        velocity.Attachment0 = ownAttachment
        velocity.RelativeTo = Enum.ActuatorRelativeTo.World
        velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
        velocity.ForceLimitsEnabled = false
        velocity.VectorVelocity = Vector3.zero
        velocity.Parent = root

        orientation = Instance.new("AlignOrientation")
        orientation.Name = "MonarcaFlyBank"
        orientation.Attachment0 = ownAttachment
        orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
        orientation.RigidityEnabled = false
        orientation.Responsiveness = 35
        orientation.MaxTorque = 2000000
        orientation.MaxAngularVelocity = 70
        orientation.Parent = root

        hum.PlatformStand = true
        hum.AutoRotate = false

        connection = RunService.Heartbeat:Connect(function(dt)
            if not active then return end
            if player.Character ~= character or hum.Parent ~= character
                or root.Parent ~= character or hum.Health <= 0 then
                stop()
                return
            end
            local camera = workspace.CurrentCamera
            if not camera then return end

            local sideways, forward = inputAxes(hum, camera)
            local view = camera.CFrame
            -- Crucial: keep LookVector.Y. Looking up + moving forward ascends,
            -- looking down + moving forward dives; no extra button is needed.
            local requested = view.LookVector * forward
                + view.RightVector * sideways
            if requested.Magnitude > 1 then requested = requested.Unit end
            local moving = requested.Magnitude > 0.06
            if not moving then requested = Vector3.zero end

            local step = math.clamp(dt, 0, 0.08)
            local moveAlpha = 1 - math.exp(-step / 0.12)
            smoothVelocity = smoothVelocity:Lerp(requested * speed, moveAlpha)
            if smoothVelocity.Magnitude < 0.07 and not moving then
                smoothVelocity = Vector3.zero
            end
            if velocity and velocity.Parent then
                velocity.VectorVelocity = smoothVelocity
            end

            local look = view.LookVector
            local yawForward = Vector3.new(look.X, 0, look.Z)
            if yawForward.Magnitude < 0.001 then
                local originalLook = root.CFrame.LookVector
                yawForward = Vector3.new(originalLook.X, 0, originalLook.Z)
            end
            if yawForward.Magnitude < 0.001 then
                yawForward = Vector3.new(0, 0, -1)
            end

            -- Aim pitch: camera elevation plus a forward flying lean.
            -- Sideways input introduces a roll/bank, backward input relaxes
            -- the lean. All three axes are smoothed between directions.
            local cameraPitch = math.asin(math.clamp(look.Y, -1, 1))
            -- Pitch must follow the camera even at zero velocity; previously
            -- movement=false forced pitch to zero and locked the idle body flat.
            local leanPitch = cameraPitch * (moving and 0.90 or 0.97)
                - math.rad(13) * math.max(0, forward)
                + math.rad(7) * math.max(0, -forward)
            local bank = moving and math.rad(-29) * sideways or 0
            local pitch = math.clamp(leanPitch, math.rad(-76), math.rad(76))
            local target = CFrame.lookAt(Vector3.zero, yawForward.Unit)
                * CFrame.Angles(pitch, 0, bank)
            local turnAlpha = 1 - math.exp(-step / 0.15)
            smoothOrientation = smoothOrientation:Lerp(target.Rotation, turnAlpha)
            if orientation and orientation.Parent then
                orientation.CFrame = smoothOrientation
            end
        end)
    end)
    if not ok then
        stop()
        return false, tostring(err)
    end
    return true
end

function Fly:disable() stop() end
function Fly:isActive() return active end
return Fly
