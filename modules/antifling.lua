-- Monarca / 666 / Antifling v0.8.3
-- Local collision protection. Never disables collisions on the local avatar,
-- anchored map geometry or Terrain. Restores the values it touched on disable.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer

local Antifling = {}
local enabled = false
local saved = {}
local listeners = {}
local generation = 0

local function disconnectAll()
    for _, connection in ipairs(listeners) do
        connection:Disconnect()
    end
    table.clear(listeners)
end

local function isOtherCharacter(part)
    local ancestor = part.Parent
    while ancestor and ancestor ~= Workspace do
        if ancestor:IsA("Model") and ancestor:FindFirstChildOfClass("Humanoid") then
            return true
        end
        ancestor = ancestor.Parent
    end
    return false
end

local function shouldBlockCollision(part)
    if not part or not part:IsA("BasePart") or not part:IsDescendantOf(Workspace) then
        return false
    end
    -- Never affect our own avatar, accessories, tools or rig geometry.
    local character = player.Character
    if character and part:IsDescendantOf(character) then
        return false
    end
    -- Other players + NPCs are ignored even if a piece is anchored.
    return not part.Anchored or isOtherCharacter(part)
end

local function restorePart(part)
    local original = saved[part]
    if original == nil then return end
    saved[part] = nil
    if part and part.Parent then
        pcall(function()
            if part.CanCollide ~= original then
                part.CanCollide = original
            end
        end)
    end
end

local function protectPart(part)
    if not enabled or not part or not part:IsA("BasePart") then return end
    if not shouldBlockCollision(part) then
        restorePart(part)
        return
    end
    if saved[part] == nil then
        saved[part] = part.CanCollide
    end
    if part.CanCollide then
        pcall(function() part.CanCollide = false end)
    end
end

local function scanModel(model)
    if not enabled or not model then return end
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then protectPart(descendant) end
    end
end

local function scanWorld(gen)
    local objects = Workspace:GetDescendants()
    for index, descendant in ipairs(objects) do
        if not enabled or generation ~= gen then return end
        if descendant:IsA("BasePart") then
            protectPart(descendant)
        end
        -- Divide the initial scan across frames for low-end Android phones.
        if index % 260 == 0 then task.wait() end
    end
end

function Antifling:enable()
    if enabled then return true, "Antifling já está ativo." end
    if not player.Character then
        return false, "Seu personagem ainda não apareceu."
    end
    enabled = true
    generation = generation + 1
    local gen = generation
    local ok, err = pcall(function()
        table.insert(listeners, Workspace.DescendantAdded:Connect(function(object)
            if not enabled then return end
            if object:IsA("BasePart") then
                protectPart(object)
            elseif object:IsA("Humanoid") then
                -- Handles NPCs assembled with limbs before their Humanoid.
                local model = object.Parent
                if model and model:IsA("Model") then scanModel(model) end
            end
        end))
        table.insert(listeners, Workspace.DescendantRemoving:Connect(function(object)
            if object:IsA("BasePart") then
                restorePart(object)
            end
        end))
        table.insert(listeners, player.CharacterAdded:Connect(function(character)
            -- A freshly spawned avatar might have been seen by DescendantAdded
            -- before LocalPlayer.Character changed: undo those changes.
            for part in pairs(saved) do
                if part:IsDescendantOf(character) then restorePart(part) end
            end
        end))
        -- Scan only once for existing parts; watch new ones with events.
        scanWorld(gen)
        -- Follow changes made by a game controller to CanCollide / Anchored.
        -- Recheck tracked parts periodically, without walking all of Workspace.
        task.spawn(function()
            while enabled and generation == gen do
                for part in pairs(saved) do
                    if not enabled or generation ~= gen then return end
                    protectPart(part)
                end
                task.wait(0.12)
            end
        end)
        -- A fixed block can become loose later. Detect that near the player
        -- without installing property listeners on every map part.
        task.spawn(function()
            while enabled and generation == gen do
                local character = player.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")
                if root and root:IsA("BasePart") then
                    local queryOk, nearby = pcall(function()
                        return Workspace:GetPartBoundsInRadius(root.Position, 42)
                    end)
                    if queryOk and nearby then
                        for _, part in ipairs(nearby) do
                            if not enabled or generation ~= gen then return end
                            if part:IsA("BasePart") then protectPart(part) end
                        end
                    end
                end
                task.wait(0.45)
            end
        end)
    end)
    if not ok then
        self:disable()
        return false, tostring(err)
    end
    return true, "Colisões locais com outros personagens e peças soltas desativadas."
end

function Antifling:disable()
    enabled = false
    generation = generation + 1
    disconnectAll()
    for part in pairs(saved) do
        restorePart(part)
    end
    return true, "Colisões originais restauradas."
end

function Antifling:isActive()
    return enabled
end

return Antifling
