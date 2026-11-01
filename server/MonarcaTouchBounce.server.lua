-- Monarca: consensual touch knockback for experiences you control.
-- Public and private sessions supported when this server integration is installed.
-- Put this Script in ServerScriptService of a Roblox experience you control.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local REMOTE_NAME = "MonarcaTouchBounce"
local SPEED, LIFT, COOLDOWN = 32, 15, 1.5

local remote = RS:FindFirstChild(REMOTE_NAME)
if not remote then
    remote = Instance.new("RemoteFunction")
    remote.Name = REMOTE_NAME
    remote.Parent = RS
end
local states = {}

local function getState(player)
    if states[player] then return states[player] end
    local state = {sending = false, receiving = false, connections = {}, last = {}}
    states[player] = state
    return state
end

local function unbind(state)
    for _, connection in ipairs(state.connections) do connection:Disconnect() end
    table.clear(state.connections)
end

local function vectorAway(source, destination)
    local vector = Vector3.new(destination.X - source.X, 0, destination.Z - source.Z)
    return vector.Magnitude > 0.1 and vector.Unit or Vector3.new(1, 0, 0)
end

local function hit(player, state, touched)
    if not state.sending or not touched:IsA("BasePart") then return end
    local own = player.Character
    local root = own and own:FindFirstChild("HumanoidRootPart")
    local ownHuman = own and own:FindFirstChildOfClass("Humanoid")
    if not root or not ownHuman or ownHuman.Health <= 0 or touched:IsDescendantOf(own) then return end

    local model = touched:FindFirstAncestorOfClass("Model")
    local otherPlayer = model and Players:GetPlayerFromCharacter(model)
    local target = touched
    if otherPlayer then
        local otherState = states[otherPlayer]
        if not otherState or not otherState.receiving then return end
        local otherHuman = model:FindFirstChildOfClass("Humanoid")
        if not otherHuman or otherHuman.Health <= 0 then return end
        target = model:FindFirstChild("HumanoidRootPart")
    elseif model and model:FindFirstChildOfClass("Humanoid") then
        -- Ignore NPCs unless they are explicitly tagged as a test target.
        if not model:GetAttribute("MonarcaBounceTarget") then return end
        target = model.PrimaryPart or touched
    elseif touched.Anchored or touched.AssemblyMass > 120 then
        return
    end
    if not target or target.Anchored then return end
    if (target.Position - root.Position).Magnitude > 10 then return end
    local now = os.clock()
    if state.last[target] and now - state.last[target] < COOLDOWN then return end
    state.last[target] = now
    local impulse = (vectorAway(root.Position, target.Position) * SPEED
        + Vector3.new(0, LIFT, 0)) * target.AssemblyMass
    target:ApplyImpulse(impulse)
end

local function bind(player, state)
    unbind(state)
    local character = player.Character
    if not character or not state.sending then return end
    local function attach(instance)
        if not instance:IsA("BasePart") then return end
        if instance:FindFirstAncestorWhichIsA("Accessory")
            or instance:FindFirstAncestorWhichIsA("Tool") then return end
        table.insert(state.connections, instance.Touched:Connect(function(touched)
            hit(player, state, touched)
        end))
    end
    for _, instance in ipairs(character:GetDescendants()) do attach(instance) end
    table.insert(state.connections, character.DescendantAdded:Connect(attach))
end

remote.OnServerInvoke = function(player, action, desired)
    if (action ~= "sending" and action ~= "receiving") or type(desired) ~= "boolean" then
        return false, "Pedido inválido."
    end
    local state = getState(player)
    state[action] = desired
    if action == "sending" then bind(player, state) end
    return true, desired and "Ativado." or "Desativado."
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        local state = states[player]
        if state and state.sending then task.defer(bind, player, state) end
    end)
end)
Players.PlayerRemoving:Connect(function(player)
    local state = states[player]
    if state then unbind(state) end
    states[player] = nil
end)
