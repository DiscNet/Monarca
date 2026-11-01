-- Monarca / 666 / ?
-- Distinct R6-only procedural idle/walk with damped crossfades and secondary motion.
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

    -- Neutral relaxed silhouettes with natural head/chest alignment.
    -- R6 arms have no elbows, so their secondary sway is shoulder-driven.
    local rightWalk = armInward(joints.rightArm, torso, rightFront,
        math.rad(87), math.rad(25), true)
    local leftWalk = armInward(joints.leftArm, torso, leftFront,
        math.rad(87), math.rad(25), false)
    local rightIdle = armInward(joints.rightArm, torso, rightFront,
        math.rad(70), math.rad(29), true)
    local leftIdle = armInward(joints.leftArm, torso, leftFront,
        math.rad(70), math.rad(29), false)
    -- Reduce the previous 19-degree idle lean (which looked like falling).
    local leanWalk = forwardLean(joints.root, rootPart, math.rad(7))
    local leanIdle = forwardLean(joints.root, rootPart, math.rad(8.5))
    local headUp = liftedHead(joints.neck, torso, math.rad(10))

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
    local movementBlend = 0
    local gaitPhase = 0
    local idleClock = 0
    local currentTransforms = {}
    for name in pairs(joints) do currentTransforms[name] = CFrame.identity end

    local ok, err = pcall(function()
        renderConnection = RunService.PreSimulation:Connect(function(deltaTime)
            if not active then return end
            if localPlayer.Character ~= character or human.Health <= 0 then
                release()
                return
            end
            local dt = math.clamp(deltaTime, 0, 0.055)
            idleClock = idleClock + dt
            local v = rootPart.AssemblyLinearVelocity
            local horizontalSpeed = Vector3.new(v.X, 0, v.Z).Magnitude
            local moving = human.MoveDirection.Magnitude > 0.06
                and horizontalSpeed > 0.4

            -- Ease idle -> walk and walk -> idle instead of hard pose swaps.
            -- A mild dead zone avoids flicker from physics velocity noise.
            local targetBlend = moving
                and math.clamp((horizontalSpeed - 0.4) / 3.5, 0, 1) or 0
            local blendTime = targetBlend > movementBlend and 0.24 or 0.34
            movementBlend = movementBlend
                + (targetBlend - movementBlend) * (1 - math.exp(-dt / blendTime))
            if movementBlend < 0.002 and targetBlend == 0 then
                movementBlend = 0
            end
            if movementBlend > 0.002 then
                gaitPhase = gaitPhase + dt * (5.9 + math.min(horizontalSpeed, 20) * 0.11)
            end

            -- Independent rhythms prevent an idle that looks like a frozen pose.
            local breath = math.sin(idleClock * 2.45)
            local breathSlow = math.sin(idleClock * 1.22 + 0.7)
            local weightShift = math.sin(idleClock * 0.8)
            local step = math.sin(gaitPhase)
            local opposite = -step
            local doubleStep = math.sin(2 * gaitPhase)
            local idleWeight = 1 - movementBlend

            -- Head rises slightly during the inhale and follows the chest
            -- without over-correcting into a backward lean.
            local idleNeck = headUp
                * CFrame.Angles(0.018 * breath, 0.025 * weightShift,
                    0.018 * breathSlow)
            local walkNeck = headUp
                * CFrame.Angles(-0.045 * step, 0.035 * doubleStep,
                    -0.036 * step)
            local neck = idleNeck:Lerp(walkNeck, movementBlend)

            -- Elastic shoulders, tiny lag and gentle variation on each side.
            local idleRightArm = rightIdle
                * CFrame.Angles(0.05 * breathSlow, 0.035 * breath,
                    rightFront * (0.075 * breath + 0.045 * weightShift))
            local idleLeftArm = leftIdle
                * CFrame.Angles(-0.05 * breathSlow, -0.035 * breath,
                    leftFront * (0.07 * breath - 0.040 * weightShift))
            local walkRightArm = rightWalk
                * CFrame.Angles(0.065 * doubleStep, 0.05 * step,
                    rightFront * (0.16 * opposite + 0.045 * doubleStep))
            local walkLeftArm = leftWalk
                * CFrame.Angles(-0.065 * doubleStep, -0.05 * step,
                    leftFront * (0.16 * step - 0.045 * doubleStep))
            local rightArm = idleRightArm:Lerp(walkRightArm, movementBlend)
            local leftArm = idleLeftArm:Lerp(walkLeftArm, movementBlend)

            -- Each leg swings in the sagittal plane; opposing steps get a
            -- foot lift while airborne. Small pelvis sway adds weight.
            local stepAmount = 0.72
            local idleRightLeg = CFrame.Angles(0, 0, rightLeg * 0.028 * weightShift)
            local idleLeftLeg = CFrame.Angles(0, 0, -leftLeg * 0.028 * weightShift)
            local walkRightLeg =
                CFrame.new(0, math.max(0, step) * 0.17, 0)
                * CFrame.Angles(0.02 * doubleStep, 0,
                    rightLeg * step * stepAmount)
            local walkLeftLeg =
                CFrame.new(0, math.max(0, opposite) * 0.17, 0)
                * CFrame.Angles(-0.02 * doubleStep, 0,
                    leftLeg * opposite * stepAmount)
            local rightHip = idleRightLeg:Lerp(walkRightLeg, movementBlend)
            local leftHip = idleLeftLeg:Lerp(walkLeftLeg, movementBlend)

            -- Gentle chest expansion and weighted footsteps. Keep lean
            -- within 7-9 degrees to avoid the "toppling" posture.
            local idleChest = leanIdle
                * CFrame.new(0.012 * weightShift, 0.038 * breath, 0)
                * CFrame.Angles(0.023 * breathSlow, 0.018 * weightShift,
                    0.018 * breath)
            local walkChest = leanWalk
                * CFrame.new(0.055 * step, -0.09 * math.abs(step), 0)
                * CFrame.Angles(0.055 * doubleStep, 0.045 * step,
                    0.035 * doubleStep)
            local rootPose = idleChest:Lerp(walkChest, movementBlend)

            -- A short per-joint interpolation also smooths abrupt frame-time
            -- changes without introducing a second state machine.
            local frameAlpha = 1 - math.exp(-dt / 0.095)
            local function animateJoint(name, target)
                local motor = joints[name]
                local previous = currentTransforms[name]
                local nextPose = previous:Lerp(target, frameAlpha)
                currentTransforms[name] = nextPose
                motor.Transform = nextPose
            end
            animateJoint("rightArm", rightArm)
            animateJoint("leftArm", leftArm)
            animateJoint("rightLeg", rightHip)
            animateJoint("leftLeg", leftHip)
            animateJoint("root", rootPose)
            animateJoint("neck", neck)
        end)
    end)

    if not ok then
        release()
        return false, tostring(err)
    end
    return true
end

return Mystery
