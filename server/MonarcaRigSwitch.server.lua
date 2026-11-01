-- MonarcaRigSwitch.server.lua v0.5.1
-- Install as a real Script in ServerScriptService in an EXPERIENCE YOU OWN.
-- A client-only script or GitHub file cannot gain authority to change rig type.
-- This swaps the player's character model server-side, causing a real respawn.
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

local busy, recentRequest = {}, {}
local COOLDOWN_SECONDS = 4

local function reply(player, rig, ok, description)
    if player.Parent == Players then
        pcall(function()
            event:FireClient(player, rig, ok, description)
        end)
    end
end

local function supplyCharacterScripts(oldCharacter, replacement)
    -- Preserve all StarterCharacterScripts, even if the generated rig
    -- already provides the rig-specific Animate script.
    local scripts = StarterPlayer:FindFirstChild("StarterCharacterScripts")
    if scripts then
        for _, child in ipairs(scripts:GetChildren()) do
            if (child:IsA("LocalScript") or child:IsA("Script"))
                and not replacement:FindFirstChild(child.Name) then
                local scriptCopy = child:Clone()
                scriptCopy.Parent = replacement
            end
        end
    end
    -- The default Animate script can differ between R6 and R15. Copy it
    -- only as a fallback when the newly generated rig has no Animate.
    if not replacement:FindFirstChild("Animate") then
        local oldAnimate = oldCharacter:FindFirstChild("Animate")
        if oldAnimate and oldAnimate:IsA("LocalScript") then
            local fallback = oldAnimate:Clone()
            fallback.Disabled = false
            fallback.Parent = replacement
        end
    end
end

local function replacePlayerRig(player, desiredRig)
    local oldCharacter = player.Character
    local oldHumanoid = oldCharacter
        and oldCharacter:FindFirstChildOfClass("Humanoid")
    if not oldHumanoid or oldHumanoid.Health <= 0 then
        return false, "Personagem não está pronto."
    end
    if oldHumanoid.RigType == desiredRig then
        return true, "Seu corpo já utiliza esse rig."
    end
    local description = oldHumanoid:GetAppliedDescription()
    local position = oldCharacter:GetPivot()
    local replacement = Players:CreateHumanoidModelFromDescriptionAsync(
        description, desiredRig
    )
    if not replacement then return false, "Falha ao gerar o modelo." end
    local newHumanoid = replacement:FindFirstChildOfClass("Humanoid")
    local newRoot = replacement:FindFirstChild("HumanoidRootPart")
    local validTorso = desiredRig == Enum.HumanoidRigType.R6
        and replacement:FindFirstChild("Torso")
        or desiredRig == Enum.HumanoidRigType.R15
        and replacement:FindFirstChild("UpperTorso")
    if not newHumanoid or not newRoot or not validTorso
        or newHumanoid.RigType ~= desiredRig then
        replacement:Destroy()
        return false, "O rig gerado não passou na validação."
    end
    if player.Character ~= oldCharacter or player.Parent ~= Players then
        replacement:Destroy()
        return false, "O jogador mudou de personagem durante a operação."
    end
    supplyCharacterScripts(oldCharacter, replacement)
    replacement.Name = player.Name
    newHumanoid.DisplayName = player.DisplayName
    -- Respawn at the previous position, slightly above the ground.
    replacement:PivotTo(position * CFrame.new(0, 1.5, 0))
    replacement.Parent = workspace
    player.Character = replacement
    -- CharacterAdded is fired by the server assignment; all clients now see
    -- a real R6 or R15 model, not an unreplicated cosmetic transformation.
    oldCharacter:Destroy()
    return true, "Personagem reiniciado como " .. desiredRig.Name .. "."
end

event.OnServerEvent:Connect(function(player, requested)
    if requested ~= "R6" and requested ~= "R15" then return end
    if busy[player] then
        reply(player, requested, false, "Outra troca está em andamento.")
        return
    end
    local now = os.clock()
    if recentRequest[player] and now - recentRequest[player] < COOLDOWN_SECONDS then
        reply(player, requested, false, "Aguarde alguns segundos para trocar novamente.")
        return
    end
    recentRequest[player] = now
    busy[player] = true
    local desired = requested == "R6"
        and Enum.HumanoidRigType.R6 or Enum.HumanoidRigType.R15
    local ok, success, message = pcall(replacePlayerRig, player, desired)
    busy[player] = nil
    if ok then
        reply(player, requested, success, message)
    else
        warn("MonarcaRigSwitch failed for", player.UserId, success)
        reply(player, requested, false, "Falha no servidor: " .. tostring(success))
    end
end)
Players.PlayerRemoving:Connect(function(player)
    busy[player], recentRequest[player] = nil, nil
end)
