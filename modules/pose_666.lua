-- Monarca / 666 / ?
-- Distinct R6-only procedural idle / walk, anatomically referenced gait & contrapposto.
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

-- Choose shoulder pitch from the true R6 joint basis. At rest the arms
-- hang DOWN, not forward. The twist moves them slightly toward the body.
local function armInward(motor, torso, front, angle, inward, rightArm)
    local base = CFrame.Angles(0, 0, front * angle)
    local inwardWorld = torso.CFrame.RightVector * (rightArm and -1 or 1)
    local forward = torso.CFrame.LookVector
    local down = -torso.CFrame.UpVector
    local goal = (forward * math.sin(angle)
        + down * math.cos(angle)
        + inwardWorld * math.sin(inward)).Unit
    local bestTransform, bestScore = base, -math.huge

    local function try(candidate)
        local axis = predictedFrame(motor, candidate)
            :VectorToWorldSpace(Vector3.new(0, -1, 0)).Unit
        local score = axis:Dot(goal)
        if score > bestScore then
            bestTransform, bestScore = candidate, score
        end
    end
    try(base)
    for _, sign in ipairs({-1, 1}) do
        local twist = inward * sign
        try(base * CFrame.Angles(0, twist, 0))
        try(CFrame.Angles(0, twist, 0) * base)
        try(base * CFrame.Angles(twist, 0, 0))
        try(CFrame.Angles(twist, 0, 0) * base)
    end
    return bestTransform
end

-- A pose may lean forwards OR backwards: pick the actual motor axis from
-- the resulting torso orientation instead of assuming C0 uses world X.
local function bodyLean(rootJoint, rootPart, angle, backwards)
    local best, bestScore = CFrame.identity, -math.huge
    for _, sign in ipairs({-1, 1}) do
        for _, axis in ipairs({"X", "Z"}) do
            local frame = axis == "X"
                and CFrame.Angles(sign * angle, 0, 0)
                or CFrame.Angles(0, 0, sign * angle)
            local torsoUp = predictedFrame(rootJoint, frame).UpVector
            local forward = torsoUp:Dot(rootPart.CFrame.LookVector)
            local lateral = math.abs(torsoUp:Dot(rootPart.CFrame.RightVector))
            local rating = (backwards and -forward or forward) - lateral
            if rating > bestScore then
                best, bestScore = frame, rating
            end
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

    -- Stance: arms lowered, a staggered right foot, weight on left leg,
    -- and a modest backwards chest lean. Walk is much more animated.
    local rightIdle = armInward(joints.rightArm, torso, rightFront,
        math.rad(14), math.rad(12), true)
    local leftIdle = armInward(joints.leftArm, torso, leftFront,
        math.rad(11), math.rad(13), false)
    local rightWalk = armInward(joints.rightArm, torso, rightFront,
        math.rad(28), math.rad(9), true)
    local leftWalk = armInward(joints.leftArm, torso, leftFront,
        math.rad(25), math.rad(10), false)
    local idleLean = bodyLean(joints.root, rootPart, math.rad(9), true)
    local walkingLean = bodyLean(joints.root, rootPart, math.rad(3), false)
    -- The head counters the thorax incline and stays directed forwards.
    local headUp = liftedHead(joints.neck, torso, math.rad(6))

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
    local transition = 0
    local gaitPhase = 0
    local idleTime = 0
    local transforms = {}
    for jointName in pairs(joints) do transforms[jointName] = CFrame.identity end

    local ok, err = pcall(function()
        renderConnection = RunService.PreSimulation:Connect(function(frameDelta)
            if not active then return end
            if localPlayer.Character ~= character or human.Health <= 0 then
                release()
                return
            end

            local dt = math.clamp(frameDelta, 0, 0.05)
            idleTime = idleTime + dt
            local velocity = rootPart.AssemblyLinearVelocity
            local flatSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
            local moving = human.MoveDirection.Magnitude > 0.075
                and flatSpeed > 0.6

            -- Hysteresis + exponential ramp for smooth starts/stops.
            local desiredWalk = moving
                and math.clamp((flatSpeed - 0.4) / 4.1, 0, 1)
                or 0
            local fadeSeconds = desiredWalk > transition and 0.26 or 0.39
            transition = transition + (desiredWalk - transition)
                * (1 - math.exp(-dt / fadeSeconds))
            if transition < 0.001 and desiredWalk == 0 then transition = 0 end

            local motion = rootPart.CFrame:VectorToObjectSpace(human.MoveDirection)
            local backwardStep = motion.Z > 0.35 and -1 or 1
            local sideStep = math.clamp(motion.X, -1, 1)

            -- Contact -> Down -> Passing -> Up. Each leg is half a cycle apart.
            -- Faster movement shortens the gait period without hard snapping.
            if transition > 0.002 then
                gaitPhase = gaitPhase + dt
                    * math.clamp(5.7 + flatSpeed * 0.115, 5.7, 11)
            end
            local phase = gaitPhase
            local contact = math.cos(phase)
            local pass = math.sin(phase)
            local downUp = math.sin(2 * phase)
            local secondHarmonic = math.cos(2 * phase)
            local rightSwing = contact * backwardStep
            local leftSwing = -rightSwing
            local rightLift = math.max(pass, 0) ^ 1.4
            local leftLift = math.max(-pass, 0) ^ 1.4

            -- Breathing and weight shifting run on different frequencies,
            -- preventing a stiff, mechanically repeating idle.
            local inhale = math.sin(idleTime * 2.0)
            local exhale = math.sin(idleTime * 1.0 + 0.55)
            local weight = math.sin(idleTime * 0.74)
            local shoulderLag = math.sin(phase - 0.34)
            local oppositeLag = math.sin(phase + math.pi - 0.34)
            local walkWeight = transition

            -- IDLE: arms hang beside the torso and sway in small, asymmetric
            -- arcs. WALK: arms counter-swing relative to each leading leg.
            local idleArmRight = rightIdle
                * CFrame.Angles(0.028 * inhale, 0.037 * exhale,
                    rightFront * (0.043 * weight + 0.034 * inhale))
            local idleArmLeft = leftIdle
                * CFrame.Angles(-0.022 * inhale, -0.035 * exhale,
                    leftFront * (-0.035 * weight + 0.038 * inhale))
            local walkingArmRight = rightWalk
                * CFrame.Angles(0.13 * shoulderLag, 0.075 * sideStep,
                    rightFront * (-0.46 * rightSwing
                        + 0.075 * shoulderLag + 0.025 * secondHarmonic))
            local walkingArmLeft = leftWalk
                * CFrame.Angles(-0.13 * oppositeLag, -0.075 * sideStep,
                    leftFront * (-0.46 * leftSwing
                        + 0.075 * oppositeLag - 0.025 * secondHarmonic))
            local rightArm = idleArmRight:Lerp(walkingArmRight, walkWeight)
            local leftArm = idleArmLeft:Lerp(walkingArmLeft, walkWeight)

            -- IDLE: right foot clearly in front, left leg slightly behind,
            -- with weight borne on the left. R6 has no knee joints.
            local idleRightHip = CFrame.new(0, 0.035, -0.045)
                * CFrame.Angles(0.014 * weight, 0.015,
                    rightLeg * (math.rad(21) + 0.022 * weight))
            local idleLeftHip = CFrame.new(0, -0.023, 0.02)
                * CFrame.Angles(-0.012 * weight, -0.026,
                    leftLeg * (-math.rad(11) + 0.019 * weight))

            -- Big opposing thigh swing + swing-foot lift, slight toe-in/out,
            -- and small independent hip slides to stop the "fixed legs" look.
            -- These are hip-joint edits, not fake knee bends on the R6 rig.
            local stride = math.clamp(0.87 + (flatSpeed - 8) * 0.013, 0.75, 1.05)
            local walkingRightHip = CFrame.new(
                0.022 * downUp,
                0.25 * rightLift - 0.028 * math.max(-pass, 0),
                -0.095 * rightSwing
            ) * CFrame.Angles(
                0.085 * pass,
                0.038 * sideStep + 0.055 * contact,
                rightLeg * (stride * rightSwing + 0.10 * downUp)
            )
            local walkingLeftHip = CFrame.new(
                -0.022 * downUp,
                0.25 * leftLift - 0.028 * math.max(pass, 0),
                -0.095 * leftSwing
            ) * CFrame.Angles(
                -0.085 * pass,
                0.038 * sideStep - 0.055 * contact,
                leftLeg * (stride * leftSwing - 0.10 * downUp)
            )
            local rightHip = idleRightHip:Lerp(walkingRightHip, walkWeight)
            local leftHip = idleLeftHip:Lerp(walkingLeftHip, walkWeight)

            -- The body actually transfers weight: low after foot impact,
            -- high while the opposite foot passes, with a counter-rotation.
            local idleChest = idleLean
                * CFrame.new(0.045 * weight, 0.027 * inhale, 0)
                * CFrame.Angles(0.020 * exhale, 0.024 * weight,
                    0.018 * inhale)
            local walkingChest = walkingLean
                * CFrame.new(0.068 * contact + 0.016 * sideStep,
                    -0.065 - 0.086 * downUp, 0)
                * CFrame.Angles(0.040 * downUp, -0.081 * contact,
                    0.055 * pass)
            local torsoPose = idleChest:Lerp(walkingChest, walkWeight)

            -- Counterweight from the neck (eyes forward) with delayed
            -- walking nod and an inhale lift.
            local idleHead = headUp
                * CFrame.Angles(-0.018 * inhale, -0.017 * weight,
                    -0.021 * exhale)
            local walkingHead = headUp
                * CFrame.Angles(0.067 * downUp, 0.028 * contact,
                    -0.038 * pass + 0.012 * secondHarmonic)
            local headPose = idleHead:Lerp(walkingHead, walkWeight)

            -- Per-joint damping prevents instantaneous pose updates while
            -- preserving distinct rhythms in arms, hips, torso and head.
            local alpha = 1 - math.exp(-dt / 0.083)
            local function animateJoint(name, targetPose)
                local pose = transforms[name]:Lerp(targetPose, alpha)
                transforms[name] = pose
                joints[name].Transform = pose
            end
            animateJoint("rightArm", rightArm)
            animateJoint("leftArm", leftArm)
            animateJoint("rightLeg", rightHip)
            animateJoint("leftLeg", leftHip)
            animateJoint("root", torsoPose)
            animateJoint("neck", headPose)
        end)
    end)

    if not ok then
        release()
        return false, tostring(err)
    end
    return true
end

return Mystery
