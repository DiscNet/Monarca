-- Run in ROBLOX STUDIO Command Bar (edit mode), not inside an executor.
-- Creates an original R6 KeyframeSequence ready to preview/publish.
-- To publish: right-click ServerStorage/MonarcaZombieR6 in Explorer and
-- choose "Save to Roblox" / edit with Animation Editor -> Publish to Roblox.
-- Publishing and asset permission are required for genuine FE replication.
assert(game:GetService("RunService"):IsStudio(), "Somente Roblox Studio")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local sample = Players:CreateHumanoidModelFromDescriptionAsync(
    Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6
)
local torso = sample:FindFirstChild("Torso")
assert(torso, "Não foi possível gerar rig R6")
local motors = {
    rightArm = torso:FindFirstChild("Right Shoulder"),
    leftArm = torso:FindFirstChild("Left Shoulder"),
    rightLeg = torso:FindFirstChild("Right Hip"),
    leftLeg = torso:FindFirstChild("Left Hip"),
}
local function frontSign(motor)
    assert(motor and motor:IsA("Motor6D"), "Junta R6 ausente")
    local function test(angle)
        local cf = motor.Part0.CFrame * motor.C0
            * CFrame.Angles(0, 0, angle) * motor.C1:Inverse()
        return cf:VectorToWorldSpace(Vector3.new(0, -1, 0))
            :Dot(torso.CFrame.LookVector)
    end
    return test(math.pi * .5) > test(-math.pi * .5) and 1 or -1
end
local signs = {}
for name, motor in pairs(motors) do signs[name] = frontSign(motor) end
sample:Destroy()

local sequence = Instance.new("KeyframeSequence")
sequence.Name = "MonarcaZombieR6"
sequence.Loop = true
sequence.Priority = Enum.AnimationPriority.Action4

local function addPose(parent, name, cf)
    local p = Instance.new("Pose")
    p.Name = name
    p.CFrame = cf
    p.Weight = 1
    p.EasingStyle = Enum.PoseEasingStyle.Linear
    p.EasingDirection = Enum.PoseEasingDirection.InOut
    p.Parent = parent
    return p
end
local length = 1.32
local frames = 12
for n = 0, frames do
    local t = n / frames
    local wave = math.sin(t * math.pi * 2)
    local alt = -wave
    local kf = Instance.new("Keyframe")
    kf.Name = n == frames and "End" or ("Step%02d"):format(n)
    kf.Time = t * length
    local root = addPose(kf, "HumanoidRootPart", CFrame.identity)
    local body = addPose(root, "Torso",
        CFrame.new(0, -math.abs(wave) * .055, 0)
        * CFrame.Angles(0, 0, math.sin(t * 2 * math.pi) * .028))
    addPose(body, "Right Arm",
        CFrame.Angles(0, 0, signs.rightArm
            * (math.rad(86) + wave * .075)))
    addPose(body, "Left Arm",
        CFrame.Angles(0, 0, signs.leftArm
            * (math.rad(86) - wave * .075)))
    addPose(body, "Right Leg",
        CFrame.new(0, math.max(wave, 0) * .10, 0)
        * CFrame.Angles(0, 0, signs.rightLeg * wave * .63))
    addPose(body, "Left Leg",
        CFrame.new(0, math.max(alt, 0) * .10, 0)
        * CFrame.Angles(0, 0, signs.leftLeg * alt * .63))
    addPose(body, "Head", CFrame.Angles(0, 0, math.sin(t * math.pi * 2) * .04))
    kf.Parent = sequence
end
local prior = ServerStorage:FindFirstChild(sequence.Name)
if prior then prior:Destroy() end
sequence.Parent = ServerStorage
print("MonarcaZombieR6 criado em ServerStorage. Publique como animação Roblox.")
print("Depois configure o ID publicado na aba Emote do Monarca.")
