-- Monarca Zombie Walk: original procedural R6 emote. Local-only.
-- Motor6D.Transform applied at PreSimulation after the standard Animator pass.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local Zombie = {}
local active, connection, joints, elapsed = false, nil, nil, 0
local savedAnimate, savedAnimateEnabled

local function clear()
    if connection then connection:Disconnect(); connection = nil end
    if joints then
        for _, motor in pairs(joints) do
            if motor and motor.Parent then
                pcall(function() motor.Transform = CFrame.identity end)
            end
        end
    end
    if savedAnimate and savedAnimate.Parent then
        pcall(function() savedAnimate.Disabled = savedAnimateEnabled end)
    end
    joints, savedAnimate, savedAnimateEnabled = nil, nil, nil
    elapsed, active = 0, false
end
function Zombie:enable()
    if active then return true end
    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    local torso = char and char:FindFirstChild("Torso")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R6
        or not torso or not root then
        return false, "Esse emote exige um corpo R6 real."
    end
    local limbs = {
        shoulderLeft = torso:FindFirstChild("Left Shoulder"),
        shoulderRight = torso:FindFirstChild("Right Shoulder"),
        hipLeft = torso:FindFirstChild("Left Hip"),
        hipRight = torso:FindFirstChild("Right Hip"),
        neck = torso:FindFirstChild("Neck"),
        rootJoint = root:FindFirstChild("RootJoint"),
    }
    for _, motor in pairs(limbs) do
        if not motor:IsA("Motor6D") then
            return false, "Juntas R6 não compatíveis com o emote."
        end
    end
    if not limbs.shoulderLeft or not limbs.shoulderRight
        or not limbs.hipLeft or not limbs.hipRight
        or not limbs.neck or not limbs.rootJoint then
        return false, "Faltam juntas R6."
    end
    joints = limbs
    active = true
    elapsed = 0
    savedAnimate = char:FindFirstChild("Animate")
    if savedAnimate and savedAnimate:IsA("LocalScript") then
        savedAnimateEnabled = savedAnimate.Disabled
        savedAnimate.Disabled = true
    else
        savedAnimate = nil
    end
    local ok, err = pcall(function()
        connection = RunService.PreSimulation:Connect(function(dt)
            if not active then return end
            if player.Character ~= char or humanoid.Health <= 0 then
                clear()
                return
            end
            elapsed = elapsed + math.min(dt, 0.1)
            local step = elapsed * 4.6
            local gait = math.sin(step) * 0.26
            local sway = math.sin(step * 0.5) * 0.06
            -- Characteristic zombie silhouette: arms ahead, spine hunched,
            -- neck drooped; feet shuffle back and forth.
            limbs.shoulderLeft.Transform =
                CFrame.Angles(math.rad(-72) + sway, 0, math.rad(-10))
            limbs.shoulderRight.Transform =
                CFrame.Angles(math.rad(-72) - sway, 0, math.rad(10))
            limbs.hipLeft.Transform = CFrame.Angles(gait, 0, 0)
            limbs.hipRight.Transform = CFrame.Angles(-gait, 0, 0)
            limbs.neck.Transform = CFrame.Angles(math.rad(13), 0, 0)
            limbs.rootJoint.Transform = CFrame.Angles(math.rad(11), 0, sway * 0.3)
        end)
    end)
    if not ok then clear(); return false, tostring(err) end
    return true
end
function Zombie:disable() clear() end
function Zombie:isActive() return active end
return Zombie
