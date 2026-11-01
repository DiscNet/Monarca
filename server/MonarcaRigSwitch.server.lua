-- MonarcaRigSwitch.server.lua
-- OPTIONAL: install this as a Script in ServerScriptService of an experience
-- you own. It cannot run from a client-side Script Hub in third-party games.
-- Safely accepts R6/R15 requests from each player for THEIR OWN character.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local REMOTE_NAME = "MonarcaRigSwitch"
local event = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
if not event then
    event = Instance.new("RemoteEvent")
    event.Name = REMOTE_NAME
    event.Parent = ReplicatedStorage
end
local changing = {}
local lastUse = {}
local COOLDOWN = 6

local function copyAnimationScripts(oldCharacter, newCharacter)
    -- Re-use the source game's Animate character script when provided.
    local oldAnimate = oldCharacter:FindFirstChild("Animate")
    if oldAnimate and oldAnimate:IsA("LocalScript") and
        not newCharacter:FindFirstChild("Animate") then
        local copy = oldAnimate:Clone()
        copy.Disabled = false
        copy.Parent = newCharacter
    end
    for _, item in ipairs(StarterPlayer.StarterCharacterScripts:GetChildren()) do
        if item:IsA("LocalScript") or item:IsA("Script") then
            if not newCharacter:FindFirstChild(item.Name) then
                item:Clone().Parent = newCharacter
            end
        end
    end
end

event.OnServerEvent:Connect(function(player, requested)
    if requested ~= "R6" and requested ~= "R15" then return end
    if changing[player] then return end
    local now = os.clock()
    if lastUse[player] and now - lastUse[player] < COOLDOWN then return end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    local newRig = requested == "R6"
        and Enum.HumanoidRigType.R6 or Enum.HumanoidRigType.R15
    if humanoid.RigType == newRig then return end
    changing[player] = true
    lastUse[player] = now

    local ok, err = pcall(function()
        local originalPosition = character:GetPivot()
        local description = humanoid:GetAppliedDescription()
        local replacement = Players:CreateHumanoidModelFromDescriptionAsync(
            description, newRig
        )
        if not replacement then error("Não foi possível criar novo rig.") end
        if player.Parent ~= Players or player.Character ~= character then
            replacement:Destroy()
            return
        end
        replacement.Name = player.Name
        local newHumanoid = replacement:FindFirstChildOfClass("Humanoid")
        if not newHumanoid or newHumanoid.RigType ~= newRig then
            replacement:Destroy()
            error("O modelo gerado não corresponde ao rig solicitado.")
        end
        copyAnimationScripts(character, replacement)
        replacement:PivotTo(originalPosition)
        replacement.Parent = workspace
        player.Character = replacement
        character:Destroy()
    end)
    changing[player] = nil
    if not ok then warn("Monarca rig change failed:", err) end
end)
Players.PlayerRemoving:Connect(function(player)
    changing[player] = nil
    lastUse[player] = nil
end)
