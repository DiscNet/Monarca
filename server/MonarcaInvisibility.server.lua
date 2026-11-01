-- Monarca X? / Server-authorized invisibility for experiences you own
-- Install as a Script under ServerScriptService. This is NOT runnable by a
-- client-side executor in another developer's game.
-- Only the exact verified Roblox username below is authorized by the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AUTHORIZED_USERNAME = "samulucas7419"
local REMOTE = "MonarcaInvisibility"
local remote = ReplicatedStorage:FindFirstChild(REMOTE)
if not remote then
    remote = Instance.new("RemoteEvent")
    remote.Name = REMOTE
    remote.Parent = ReplicatedStorage
end

local stateByPlayer = {}

local function accepted(player)
    return player.Name:lower() == AUTHORIZED_USERNAME
end

local function kind(instance)
    if instance:IsA("BasePart") or instance:IsA("Decal")
        or instance:IsA("Texture") then return "Transparency" end
    if instance:IsA("ParticleEmitter") or instance:IsA("Trail")
        or instance:IsA("Beam") or instance:IsA("Fire")
        or instance:IsA("Smoke") or instance:IsA("Sparkles")
        or instance:IsA("Highlight") or instance:IsA("BillboardGui")
        or instance:IsA("SurfaceGui") then return "Enabled" end
    return nil
end

local function hide(instance, state)
    if state.original[instance] then return end
    local property = kind(instance)
    if not property then return end
    local ok, original = pcall(function() return instance[property] end)
    if not ok then return end
    state.original[instance] = {property = property, value = original}
    pcall(function()
        if property == "Enabled" then
            instance.Enabled = false
        else
            instance.Transparency = 1
        end
    end)
end

local function reveal(state)
    if state.descendantConnection then
        state.descendantConnection:Disconnect()
        state.descendantConnection = nil
    end
    for instance, entry in pairs(state.original) do
        if instance and instance.Parent then
            pcall(function() instance[entry.property] = entry.value end)
        end
    end
    table.clear(state.original)
    if state.humanoid and state.humanoid.Parent
        and state.originalDisplayDistanceType then
        pcall(function()
            state.humanoid.DisplayDistanceType = state.originalDisplayDistanceType
        end)
    end
    state.humanoid, state.originalDisplayDistanceType = nil, nil
end

local function applyToCharacter(player, state, character)
    reveal(state)
    if not state.enabled or not character then return end
    local human = character:FindFirstChildOfClass("Humanoid")
    if human then
        state.humanoid = human
        state.originalDisplayDistanceType = human.DisplayDistanceType
        human.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    end
    for _, descendant in ipairs(character:GetDescendants()) do
        hide(descendant, state)
    end
    state.descendantConnection = character.DescendantAdded:Connect(function(item)
        if state.enabled and player.Character == character then
            hide(item, state)
        end
    end)
end

local function ensureState(player)
    if stateByPlayer[player] then return stateByPlayer[player] end
    local state = {
        enabled = false,
        original = {},
        humanoid = nil,
        originalDisplayDistanceType = nil,
    }
    state.characterConnection = player.CharacterAdded:Connect(function(character)
        if not state.enabled then return end
        -- CharacterAdded may fire before the appearance is complete.
        task.defer(function()
            character:WaitForChild("Humanoid", 8)
            if player.Character ~= character or not state.enabled then return end
            applyToCharacter(player, state, character)
        end)
    end)
    stateByPlayer[player] = state
    return state
end

remote.OnServerEvent:Connect(function(player, operation, desired, requestId)
    if operation ~= "set" or type(desired) ~= "boolean"
        or type(requestId) ~= "number" then return end
    local normalizedRequest = math.floor(requestId)
    if requestId ~= normalizedRequest or normalizedRequest < 0
        or normalizedRequest > 2000000000 then return end
    if not accepted(player) then
        remote:FireClient(player, "result", normalizedRequest, false,
            false, "Acesso não autorizado neste servidor.")
        return
    end
    local state = ensureState(player)
    if desired then
        local char = player.Character
        local human = char and char:FindFirstChildOfClass("Humanoid")
        if not char or not human or human.Health <= 0 then
            remote:FireClient(player, "result", normalizedRequest, false,
                state.enabled, "Personagem não está pronto.")
            return
        end
    end

    local ok, err = pcall(function()
        state.enabled = desired
        if desired then
            applyToCharacter(player, state, player.Character)
        else
            reveal(state)
        end
    end)
    if not ok then
        state.enabled = false
        reveal(state)
        remote:FireClient(player, "result", normalizedRequest, false,
            false, "Servidor não conseguiu aplicar a invisibilidade.")
        warn("[MonarcaInvisibility]", tostring(err))
        return
    end
    remote:FireClient(player, "result", normalizedRequest, true,
        state.enabled, state.enabled
            and "Invisibilidade replicada ativada."
            or "Personagem visível novamente.")
end)

Players.PlayerRemoving:Connect(function(player)
    local state = stateByPlayer[player]
    if not state then return end
    state.enabled = false
    reveal(state)
    if state.characterConnection then state.characterConnection:Disconnect() end
    stateByPlayer[player] = nil
end)
