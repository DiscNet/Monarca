-- Monarca / 666 / ?
-- Distinct R6-only procedural pose. Local Motor6D.Transform animation.
-- No claims of FE: transforms written locally are not replicated to others.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer

local Mystery = {}
local active = false
local renderConnection, motors, animateScript, animatePreviouslyDisabled
local elapsed = 0

local function release()
    active = false
    if renderConnection then
        renderConnection:Disconnect()
        renderConnection = nil
    end
    if motors then
        for _, motor in pairs(motors) do
            if motor and motor.Parent then
                pcall(function() motor.Transform = CFrame.identity end)
            end
        end
    end
    if animateScript and animateScript.Parent then
        pcall(function()
            animateScript.Disabled = animatePreviouslyDisabled
        end)
    end
    motors, animateScript, animatePreviouslyDisabled = nil, nil, nil
    elapsed = 0
end

function Mystery:disable() release() end
function Mystery:isActive() return active end

local function predictedFrame(motor, transform)
    return motor.Part0.CFrame * motor.C0 * transform * motor.C1:Inverse()
end

local function frontSign(motor, torso)
    local function score(angle)
        local frame = predictedFrame(motor, CFrame.Angles(0, 0, angle))
        return frame:VectorToWorldSpace(Vector3.new(0, -1, 0))
            :Dot(torso.CFrame.LookVector)
    end
    return score(math.pi * 0.5) >= score(-math.pi * 0.5) and 1 or -1
end

-- Find a local shoulder twist that keeps the arm pointed FORWARD, while
-- turning it toward the center of the chest (R6 joints are mirrored).
local function armInward(motor, torso, front, angle, inward, rightArm)
    local base = CFrame.Angles(0, 0, front * angle)
    local inwardWorld = torso.CFrame.RightVector * (rightArm and -1 or 1)
    local goal = (torso.CFrame.LookVector * 0.92 + inwardWorld * 0.36
        - torso.CFrame.UpVector * 0.10).Unit
    local bestTransform, bestScore = base, -math.huge

    local function try(pose)
        local longAxis = predictedFrame(motor, pose)
            :VectorToWorldSpace(Vector3.new(0, -1, 0)).Unit
        local score = longAxis:Dot(goal)
        if score > bestScore then
            bestScore, bestTransform = score, pose
        end
    end
    try(base)
    for _, multiplier in ipairs({-1, 1}) do
        local twist = inward * multiplier
        local yaw = CFrame.Angles(0, twist, 0)
        local roll = CFrame.Angles(twist, 0, 0)
        try(base * yaw)
        try(yaw * base)
        try(base * roll)
        try(roll * base)
    end
    return bestTransform
end

-- Choose the torso's forward-lean axis using the actual R6 RootJoint frame.
local function forwardLean(rootJoint, rootPart, angle)
    local best, score = CFrame.identity, -math.huge
    for _, sign in ipairs({-1, 1}) do
        for _, axis in ipairs({"X", "Z"}) do
            local turn = axis == "X"
                and CFrame.Angles(sign * angle, 0, 0)
                or CFrame.Angles(0, 0, sign * angle)
            local upward = predictedFrame(rootJoint, turn).UpVector
            local forward = upward:Dot(rootPart.CFrame.LookVector)
            local sideways = math.abs(upward:Dot(rootPart.CFrame.RightVector))
            local merit = forward - sideways * 0.5
            if merit > score then best, score = turn, merit end
        end
    end
    return best
end

-- A lifted head offsets the tired, forward-bent chest so the face looks ahead.
local function liftedHead(neck, torso, angle)
    local best, score = CFrame.identity, -math.huge
    for _, sign in ipairs({-1, 1}) do
        for _, axis in ipairs({"X", "Z"}) do
            local turn = axis == "X"
                and CFrame.Angles(sign * angle, 0, 0)
                or CFrame.Angles(0, 0, sign * angle)
            local direction = predictedFrame(neck, turn).LookVector
            local up = direction:Dot(torso.CFrame.UpVector)
            local front = direction:Dot(torso.CFrame.LookVector)
            local sideways = math.abs(direction:Dot(torso.CFrame.RightVector))
            local merit = -math.abs(up - 0.22) + front * 0.2 - sideways
            if merit > score then best, score = turn, merit end
        end
    end
    return best
end

function Mystery:enable()
    if active then return true end
    local character = localPlayer.Character
    local human = character and character:FindFirstChildOfClass("Humanoid")
    local torso = character and character:FindFirstChild("Torso")
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not human or human.RigType ~= Enum.HumanoidRigType.R6
        or human.Health <= 0 or not torso or not rootPart then
        return false, "A função ? exige um personagem R6 real e vivo."
    end

    local joints = {
        rightArm = torso:FindFirstChild("Right Shoulder"),
        leftArm = torso:FindFirstChild("Left Shoulder"),
        rightLeg = torso:FindFirstChild("Right Hip"),
        leftLeg = torso:FindFirstChild("Left Hip"),
        neck = torso:FindFirstChild("Neck"),
        root = rootPart:FindFirstChild("RootJoint"),
    }
    for _, key in ipairs({"rightArm", "leftArm", "rightLeg", "leftLeg", "neck", "root"}) do
        local motor = joints[key]
        if not motor or not motor:IsA("Motor6D") then
            return false, "Articulação R6 incompatível: " .. key
        end
    end

    local rightFront = frontSign(joints.rightArm, torso)
    local leftFront = frontSign(joints.leftArm, torso)
    local rightLeg = frontSign(joints.rightLeg, torso)
    local leftLeg = frontSign(joints.leftLeg, torso)

    -- Sample the target transformations only once, not in every frame.
    local rightWalk = armInward(joints.rightArm, torso, rightFront,
        math.rad(103), math.rad(27), true)
    local leftWalk = armInward(joints.leftArm, torso, leftFront,
        math.rad(103), math.rad(27), false)
    local rightIdle = armInward(joints.rightArm, torso, rightFront,
        math.rad(78), math.rad(31), true)
    local leftIdle = armInward(joints.leftArm, torso, leftFront,
        math.rad(78), math.rad(31), false)
    local leanWalk = forwardLean(joints.root, rootPart, math.rad(14))
    local leanIdle = forwardLean(joints.root, rootPart, math.rad(19))
    local headUp = liftedHead(joints.neck, torso, math.rad(19))

    animateScript = character:FindFirstChild("Animate")
    if animateScript and animateScript:IsA("LocalScript") then
        animatePreviouslyDisabled = animateScript.Disabled
        animateScript.Disabled = true
    else
        animateScript = nil
    end
    local animator = human:FindFirstChildOfClass("Animator")
    if animator then
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            pcall(function() track:Stop(0.10) end)
        end
    end

    motors, active, elapsed = joints, true, 0
    local ok, err = pcall(function()
        renderConnection = RunService.PreSimulation:Connect(function(dt)
            if not active then return end
            if localPlayer.Character ~= character or human.Health <= 0 then
                release()
                return
            end

            local velocity = rootPart.AssemblyLinearVelocity
            local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
            local walking = human.MoveDirection.Magnitude > 0.09
                and horizontalSpeed > 0.55
            elapsed = elapsed + math.clamp(dt, 0, 0.06)
                * (walking and math.clamp(horizontalSpeed / 6, 1.3, 3.7) or 0.45)

            local phase = elapsed * 2.55
            local step = math.sin(phase)
            local breathing = math.sin(elapsed * 2.15)
            local stride = walking and 0.58 or 0.04
            local rightStep, leftStep = step, -step
            local liftRight = walking and math.max(0, rightStep) * 0.12 or 0
            local liftLeft = walking and math.max(0, leftStep) * 0.12 or 0

            -- Walking: both arms project ahead and inward with a restrained sway.
            -- Idle: arms sag slightly, chest heaves, weight shifts as if exhausted.
            joints.rightArm.Transform =
                (walking and rightWalk or rightIdle)
                * CFrame.Angles(0, 0, rightFront *
                    (walking and 0.055 * step or 0.022 * breathing))
            joints.leftArm.Transform =
                (walking and leftWalk or leftIdle)
                * CFrame.Angles(0, 0, leftFront *
                    (walking and -0.055 * step or -0.022 * breathing))

            joints.rightLeg.Transform = CFrame.new(0, liftRight, 0)
                * CFrame.Angles(0, 0, rightLeg * stride * rightStep)
            joints.leftLeg.Transform = CFrame.new(0, liftLeft, 0)
                * CFrame.Angles(0, 0, leftLeg * stride * leftStep)

            local bob = walking and math.abs(step) * 0.065
                or 0.017 * breathing
            joints.root.Transform = (walking and leanWalk or leanIdle)
                * CFrame.new(0, -bob, 0)
                * CFrame.Angles(0, 0, walking and step * 0.022
                    or 0.018 * math.sin(elapsed * 0.7))
            joints.neck.Transform = headUp * CFrame.Angles(0, 0,
                walking and -step * 0.018 or 0.012 * breathing)
        end)
    end)
    if not ok then
        release()
        return false, tostring(err)
    end
    return true
end

return Mystery
