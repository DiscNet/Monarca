-- Monarca Reverse / Flashback v0.7.4
-- Adapted from the user-supplied Flashback/Revert script.
-- Keep: CFrame, AssemblyLinearVelocity, Humanoid state, PlatformStand and Tool.
-- 60s ring buffer @ 30 Hz for mobile. Hold E or a HUD button to rewind.
-- This only rewinds local character state, not game time or server history.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

local Reverse = {}
local SECONDS = 60
local SAMPLE_HZ = 30
local SAMPLE_INTERVAL = 1 / SAMPLE_HZ
local CAPACITY = SECONDS * SAMPLE_HZ

local enabled = false
local rewinding = false
local frames = {}
local head = 0
local count = 0
local accumulator = 0
local observedCharacter
local saved
local lastFrame

local heartbeatConnection, beganConnection, endedConnection, respawnConnection

local function clearHistory()
    table.clear(frames)
    head, count, accumulator = 0, 0, 0
    lastFrame = nil
end

local function ownCharacter()
    local character = player.Character
    if not character or not character.Parent then return end
    local root = character:FindFirstChild("HumanoidRootPart")
        or character.PrimaryPart
    local hum = character:FindFirstChildOfClass("Humanoid")
    if not root or not root:IsA("BasePart")
        or not hum or hum.Health <= 0 then return end
    return character, root, hum
end

local function storeFrame(character, root, hum)
    head = head % CAPACITY + 1
    frames[head] = {
        root.CFrame,
        root.AssemblyLinearVelocity,
        hum:GetState(),
        hum.PlatformStand,
        character:FindFirstChildOfClass("Tool"),
    }
    count = math.min(count + 1, CAPACITY)
end

local function popFrame()
    if count == 0 then return nil end
    local result = frames[head]
    frames[head] = nil
    head = (head - 2) % CAPACITY + 1
    count = count - 1
    return result
end

local function restore()
    if not rewinding then return end
    rewinding = false
    local state = saved
    saved = nil
    if not state then return end
    local root = state.root
    local hum = state.hum
    -- Avoid leaving the root anchored or the avatar in PlatformStand after
    -- releasing the button. Stop residual velocity to prevent a large fling.
    if root and root.Parent then
        pcall(function()
            root.Anchored = state.anchored
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
    end
    if hum and hum.Parent then
        pcall(function()
            hum.PlatformStand = state.platformStand
            hum.AutoRotate = state.autoRotate
            if not state.platformStand then
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end)
    end
end

local function equipFromFrame(character, hum, frame)
    local intended = frame[5]
    local equipped = character:FindFirstChildOfClass("Tool")
    if equipped == intended then return end
    -- A destroyed/replaced Tool in a historical frame cannot be resurrected.
    if intended and intended.Parent
        and (intended:IsDescendantOf(character)
            or intended:IsDescendantOf(player:FindFirstChildOfClass("Backpack")
                or character)) then
        pcall(function() hum:EquipTool(intended) end)
    elseif not intended and equipped then
        pcall(function() hum:UnequipTools() end)
    end
end

local function applyFrame(character, root, hum, frame)
    if not frame then return false end
    local ok = pcall(function()
        root.CFrame = frame[1]
        -- Original script uses -Velocity; maintain the value as an available
        -- rewind cue, but leave the root anchored to prevent physics conflict.
        root.AssemblyLinearVelocity = -frame[2]
        local targetState = frame[3]
        if targetState ~= Enum.HumanoidStateType.Dead then
            hum:ChangeState(targetState)
        end
        -- Original PlatformStand is recorded. During active rewind keep it
        -- locked to prevent standard locomotion from fighting the replay.
        if frame[4] then hum.PlatformStand = true end
    end)
    if not ok then return false end
    equipFromFrame(character, hum, frame)
    lastFrame = frame
    return true
end

local function begin()
    if not enabled then return false, "Reverse não está ativado." end
    if rewinding then return true end
    if count < 2 then
        return false, "Aguarde o histórico de movimento ser registrado."
    end
    local character, root, hum = ownCharacter()
    if not character then return false, "Personagem indisponível." end
    if observedCharacter ~= character then
        clearHistory()
        observedCharacter = character
        return false, "O histórico foi reiniciado após troca de avatar."
    end
    -- A local fake avatar does not represent the real server character.
    if character.Name:sub(1, 18) == "MonarcaLocalProxy_" then
        return false, "Desative a invisibilidade experimental antes do Reverse."
    end
    if hum.Sit or hum.SeatPart then
        return false, "Saia do assento antes de rebobinar."
    end
    if root:FindFirstChildOfClass("LinearVelocity")
        or root:FindFirstChildOfClass("AlignOrientation") then
        return false, "Desative o Fly antes de rebobinar."
    end

    saved = {
        root = root, hum = hum,
        anchored = root.Anchored,
        autoRotate = hum.AutoRotate,
        platformStand = hum.PlatformStand,
    }
    local ok, err = pcall(function()
        hum.AutoRotate = false
        hum.PlatformStand = true
        root.Anchored = true
    end)
    if not ok then
        if root and root.Parent then pcall(function() root.Anchored = saved.anchored end) end
        if hum and hum.Parent then
            pcall(function()
                hum.AutoRotate = saved.autoRotate
                hum.PlatformStand = saved.platformStand
            end)
        end
        saved = nil
        return false, tostring(err)
    end
    rewinding = true
    accumulator = 0
    return true
end

local function sample(dt)
    if not enabled then return end
    local char, root, hum = ownCharacter()
    if not char then
        if rewinding then restore() end
        return
    end
    if observedCharacter ~= char then
        if rewinding then restore() end
        observedCharacter = char
        clearHistory()
    end

    accumulator = accumulator + math.min(dt, 0.13)
    if accumulator < SAMPLE_INTERVAL then return end
    -- Avoid giant catch-up loops on slow phones: one position per tick.
    accumulator = accumulator % SAMPLE_INTERVAL
    if not rewinding then
        storeFrame(char, root, hum)
        return
    end
    if not saved or saved.root ~= root then
        restore()
        return
    end
    local frame = popFrame()
    if not frame or not applyFrame(char, root, hum, frame) then
        restore()
        return
    end
    if count == 0 then restore() end
end

function Reverse:enable()
    if enabled then return true end
    enabled = true
    clearHistory()
    observedCharacter = player.Character
    heartbeatConnection = RunService.Heartbeat:Connect(sample)
    beganConnection = UserInputService.InputBegan:Connect(function(input, processed)
        if processed or input.KeyCode ~= Enum.KeyCode.E then return end
        begin()
    end)
    endedConnection = UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.E then restore() end
    end)
    respawnConnection = player.CharacterAdded:Connect(function(character)
        restore()
        observedCharacter = character
        clearHistory()
    end)
    return true
end

function Reverse:disable()
    enabled = false
    restore()
    for _, con in ipairs({
        heartbeatConnection, beganConnection, endedConnection, respawnConnection
    }) do
        if con then con:Disconnect() end
    end
    heartbeatConnection, beganConnection, endedConnection, respawnConnection = nil, nil, nil, nil
    clearHistory()
    observedCharacter = nil
    return true
end

function Reverse:start()
    return begin()
end
function Reverse:stop()
    restore()
    return true
end
function Reverse:isActive()
    return enabled
end
function Reverse:isRewinding()
    return rewinding
end
function Reverse:recordedSeconds()
    return count / SAMPLE_HZ
end
return Reverse
