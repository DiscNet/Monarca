-- Monarca Zombie Walk v0.5.1
-- R6: sagittal Z-axis gait and arms out in front, NOT the old X-axis T-pose.
-- FE option: an authorized, published animation played through the server-created
-- Animator. Motor6D.Transform fallback is explicitly LOCAL ONLY.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local Zombie = {}
local active, loop, joints, elapsed = false, nil, nil, 0
local stoppedAnimate, animateWasEnabled = nil, nil
local clip, track, mode, assetId = nil, nil, "off", ""

local function reset()
    active = false
    if loop then loop:Disconnect(); loop = nil end
    if track then pcall(function() track:Stop(0.15); track:Destroy() end) end
    if clip then clip:Destroy() end
    track, clip = nil, nil
    if joints then
        for _, motor in pairs(joints) do
            if motor and motor.Parent then
                pcall(function() motor.Transform = CFrame.identity end)
            end
        end
    end
    joints = nil
    if stoppedAnimate and stoppedAnimate.Parent then
        pcall(function() stoppedAnimate.Disabled = not animateWasEnabled end)
    end
    stoppedAnimate, animateWasEnabled = nil, nil
    elapsed, mode = 0, "off"
end
function Zombie:disable() reset() end
function Zombie:isActive() return active end
function Zombie:getMode() return mode end
function Zombie:setAnimationId(id)
    local digits = tostring(id or ""):match("^(%d+)$")
    assetId = digits and #digits <= 20 and digits or ""
end

local function getParts()
    local char = player.Character
    local human = char and char:FindFirstChildOfClass("Humanoid")
    local torso = char and char:FindFirstChild("Torso")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not human or human.RigType ~= Enum.HumanoidRigType.R6
        or not torso or not root then
        return nil, "Use um personagem R6 real para este emote."
    end
    local motors = {
        rightArm = torso:FindFirstChild("Right Shoulder"),
        leftArm = torso:FindFirstChild("Left Shoulder"),
        rightLeg = torso:FindFirstChild("Right Hip"),
        leftLeg = torso:FindFirstChild("Left Hip"),
        neck = torso:FindFirstChild("Neck"),
        root = root:FindFirstChild("RootJoint"),
    }
    for key, joint in pairs(motors) do
        if not joint or not joint:IsA("Motor6D") then
            return nil, "Junta R6 indisponível: " .. key
        end
    end
    return {char=char, hum=human, torso=torso, rootPart=root, motors=motors}
end
-- The two shoulders have mirrored C0/C1 rotations in R6. Determine each
-- Z-axis swing sign from its actual joint orientation (not a guessed sign).
local function frontSign(motor, torso)
    local function score(angle)
        local result = motor.Part0.CFrame * motor.C0
            * CFrame.Angles(0, 0, angle) * motor.C1:Inverse()
        local limbDown = result:VectorToWorldSpace(Vector3.new(0, -1, 0))
        return limbDown:Dot(torso.CFrame.LookVector)
    end
    return score(math.pi * 0.5) > score(-math.pi * 0.5) and 1 or -1
end
local function startReplicated(parts)
    if assetId == "" then return false end
    -- Do not create a client-only Animator: that cannot replicate.
    local animator = parts.hum:FindFirstChildOfClass("Animator")
    if not animator then return false end
    local animation = Instance.new("Animation")
    animation.Name = "MonarcaZombieR6"
    animation.AnimationId = "rbxassetid://" .. assetId
    local ok, loaded = pcall(function()
        return animator:LoadAnimation(animation)
    end)
    if not ok or not loaded then animation:Destroy(); return false end
    loaded.Priority = Enum.AnimationPriority.Action4
    loaded.Looped = true
    local started = pcall(function() loaded:Play(0.15, 1, 1) end)
    if not started then
        pcall(function() loaded:Destroy() end)
        animation:Destroy()
        return false
    end
    -- An inaccessible or unauthorized animation often remains length zero.
    local deadline = os.clock() + 1.5
    while loaded.Length == 0 and os.clock() < deadline do task.wait(0.1) end
    if loaded.Length == 0 then
        pcall(function() loaded:Stop(0); loaded:Destroy() end)
        animation:Destroy()
        return false
    end
    clip, track = animation, loaded
    active, mode = true, "FE"
    return true
end
local function startLocal(parts)
    -- Stop the ordinary R6 Animate script only during local fallback.
    -- Other people will not see Transform changes; be explicit in UI.
    local char, hum, motor = parts.char, parts.hum, parts.motors
    stoppedAnimate = char:FindFirstChild("Animate")
    if stoppedAnimate and stoppedAnimate:IsA("LocalScript") then
        animateWasEnabled = not stoppedAnimate.Disabled
        stoppedAnimate.Disabled = true
    else
        stoppedAnimate = nil
    end
    local animator = hum:FindFirstChildOfClass("Animator")
    if animator then
        for _, currentTrack in ipairs(animator:GetPlayingAnimationTracks()) do
            pcall(function() currentTrack:Stop(0.12) end)
        end
    end
    local rightArm = frontSign(motor.rightArm, parts.torso)
    local leftArm = frontSign(motor.leftArm, parts.torso)
    local rightLeg = frontSign(motor.rightLeg, parts.torso)
    local leftLeg = frontSign(motor.leftLeg, parts.torso)
    joints, active, mode = motor, true, "local"
    elapsed = 0
    loop = RunService.PreSimulation:Connect(function(dt)
        if not active then return end
        if player.Character ~= char or hum.Health <= 0 then
            reset()
            return
        end
        local v = parts.rootPart.AssemblyLinearVelocity
        local horizontalSpeed = Vector3.new(v.X, 0, v.Z).Magnitude
        -- Meaningful footsteps on movement; small idle sway, not walking in place.
        local moving = hum.MoveDirection.Magnitude > 0.08 and horizontalSpeed > 0.5
        elapsed = elapsed + math.clamp(dt, 0, 0.06)
            * (moving and math.clamp(horizontalSpeed / 5.5, 1.5, 4) or 0.65)
        local phase = elapsed * 2.4
        local stride = moving and 0.63 or 0.035
        local rightStep = math.sin(phase)
        local leftStep = -rightStep
        local rightLift = moving and math.max(0, rightStep) * 0.10 or 0
        local leftLift = moving and math.max(0, leftStep) * 0.10 or 0

        -- R6 joint Z is the pitch axis after the shoulder/hip's mirrored C0.
        -- Both arms point forward ~85 degrees with a modest claw sway.
        motor.rightArm.Transform = CFrame.Angles(0, 0,
            rightArm * (math.rad(86) + math.sin(phase) * 0.055))
        motor.leftArm.Transform = CFrame.Angles(0, 0,
            leftArm * (math.rad(86) - math.sin(phase) * 0.055))
        -- Alternating forward/backward stride plus an actual vertical foot lift.
        motor.rightLeg.Transform = CFrame.new(0, rightLift, 0)
            * CFrame.Angles(0, 0, rightLeg * rightStep * stride)
        motor.leftLeg.Transform = CFrame.new(0, leftLift, 0)
            * CFrame.Angles(0, 0, leftLeg * leftStep * stride)
        local bob = moving and math.abs(rightStep) * 0.07 or 0.008 * math.sin(phase)
        motor.root.Transform = CFrame.new(0, -bob, 0)
            * CFrame.Angles(0, 0, 0.025 * math.sin(phase))
        motor.neck.Transform = CFrame.Angles(0, 0, 0.045 * math.sin(phase * 0.5))
    end)
end
function Zombie:enable()
    if active then return true end
    local parts, err = getParts()
    if not parts then return false, err end
    if startReplicated(parts) then return true end
    local ok, msg = pcall(startLocal, parts)
    if not ok then reset(); return false, tostring(msg) end
    return true
end
return Zombie
