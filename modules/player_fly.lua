-- Monarca Fly: local flight, mobile/keyboard ascend/descend and cleanup.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CAS = game:GetService("ContextActionService")
local player = Players.LocalPlayer
local Fly = {}
local active, speed = false, 40
local snapshot, connection, up, down = nil, nil, false, false
local controls = nil
pcall(function()
    -- PlayerModule exposes analog movement for mobile virtual thumbsticks even
    -- while the Humanoid is in PlatformStand.
    local scripts = player:FindFirstChild("PlayerScripts")
    local module = scripts and scripts:FindFirstChild("PlayerModule")
    if module then controls = require(module):GetControls() end
end)
local function movementDirection(hum)
    if controls and type(controls.GetMoveVector) == "function" then
        local ok, vector = pcall(function() return controls:GetMoveVector() end)
        local cam = workspace.CurrentCamera
        if ok and typeof(vector) == "Vector3" and cam then
            local cf = cam.CFrame
            local forward = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
            local right = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
            if forward.Magnitude > 0.01 and right.Magnitude > 0.01 then
                return forward.Unit * (-vector.Z) + right.Unit * vector.X
            end
        end
    end
    return hum.MoveDirection
end
local ownAttachment, velocity, orientation

local function stop()
    if connection then connection:Disconnect(); connection = nil end
    CAS:UnbindAction("MonarcaFlyRise")
    CAS:UnbindAction("MonarcaFlyLower")
    for _, part in ipairs({velocity, orientation, ownAttachment}) do
        if part then pcall(function() part:Destroy() end) end
    end
    ownAttachment, velocity, orientation = nil, nil, nil
    if snapshot then
        local hum = snapshot.hum
        if hum and hum.Parent then
            hum.PlatformStand = snapshot.platform
            hum.AutoRotate = snapshot.rotate
            pcall(function()
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end)
        end
        snapshot = nil
    end
    up, down, active = false, false, false
end
local function verticalAction(isUp)
    return function(_, state)
        if state == Enum.UserInputState.Begin then
            if isUp then up = true else down = true end
        elseif state == Enum.UserInputState.End
            or state == Enum.UserInputState.Cancel then
            if isUp then up = false else down = false end
        end
        return Enum.ContextActionResult.Sink
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
        return false, "Personagem indisponível para voar"
    end
    active = true
    snapshot = {hum=hum, platform=hum.PlatformStand, rotate=hum.AutoRotate}
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
        orientation.Name = "MonarcaFlyBalance"
        orientation.Attachment0 = ownAttachment
        orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
        orientation.RigidityEnabled = false
        orientation.Responsiveness = 25
        orientation.MaxTorque = 1000000
        orientation.Parent = root

        hum.PlatformStand = true
        hum.AutoRotate = false
        CAS:BindAction("MonarcaFlyRise", verticalAction(true), true,
            Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
        CAS:BindAction("MonarcaFlyLower", verticalAction(false), true,
            Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonB)
        CAS:SetTitle("MonarcaFlyRise", "SUBIR")
        CAS:SetTitle("MonarcaFlyLower", "DESCER")
        CAS:SetPosition("MonarcaFlyRise", UDim2.new(1, -155, 1, -225))
        CAS:SetPosition("MonarcaFlyLower", UDim2.new(1, -155, 1, -148))
        connection = RunService.Heartbeat:Connect(function()
            if not active then return end
            if hum.Parent ~= character or root.Parent ~= character then
                stop()
                return
            end
            local direction = movementDirection(hum)
            local vertical = (up and 1 or 0) - (down and 1 or 0)
            local movement = direction + Vector3.new(0, vertical, 0)
            if movement.Magnitude > 1 then movement = movement.Unit end
            if velocity and velocity.Parent then
                velocity.VectorVelocity = movement * speed
            end
            local cam = workspace.CurrentCamera
            if cam and orientation and orientation.Parent then
                local look = cam.CFrame.LookVector
                local horizontal = Vector3.new(look.X, 0, look.Z)
                if horizontal.Magnitude > 0.01 then
                    orientation.CFrame = CFrame.lookAt(Vector3.zero, horizontal.Unit)
                end
            end
        end)
    end)
    if not ok then stop(); return false, tostring(err) end
    return true
end
function Fly:disable() stop() end
function Fly:isActive() return active end
return Fly
