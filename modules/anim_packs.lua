-- Monarca / Anim: catalog R15 locomotion packs, starting with Vampire.
-- Roblox official asset IDs: https://create.roblox.com/docs/animation/using
-- Replication uses the EXISTING Animator in the local player's actual character.
-- Do not create a client Animator or use a local fake character.
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local AnimPacks = {}
local currentPreset = "default"
local active = false
local watchedCharacter, originalAnimations, characterConnection

local PRESETS = {
    vampire = {
        title = "Vampire Animation Pack",
        slots = {
            ["idle.Animation1"] = "1083445855",
            ["idle.Animation2"] = "1083450166",
            ["walk.WalkAnim"] = "1083473930",
            ["run.RunAnim"] = "1083462077",
            ["jump.JumpAnim"] = "1083455352",
            ["fall.FallAnim"] = "1083443587",
            ["climb.ClimbAnim"] = "1083439238",
            ["swim.Swim"] = "1083464683",
            ["swimidle.SwimIdle"] = "1083467779",
        },
    },
}
-- 1088037547 is an additional Roblox Vampire idle variant; the default
-- Animate controller has two Idle slots, both assigned above.

local SLOT_PATHS = {
    "idle.Animation1", "idle.Animation2", "walk.WalkAnim",
    "run.RunAnim", "jump.JumpAnim", "fall.FallAnim",
    "climb.ClimbAnim", "swim.Swim", "swimidle.SwimIdle",
}

local function locate(animate, path)
    local node = animate
    for token in string.gmatch(path, "[^.]+") do
        node = node and node:FindFirstChild(token)
        if not node then return nil end
    end
    return node and node:IsA("Animation") and node or nil
end

local function getCharacterRig(character)
    if not character or not character.Parent or player.Character ~= character then
        return nil, "Personagem indisponível."
    end
    if character.Name:match("^MonarcaLocalProxy_") then
        return nil, "Desative a invisibilidade experimental antes de usar Anim."
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return nil, "Humanoid indisponível."
    end
    if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
        return nil, "Este pacote usa R15; troque para R15 antes de aplicar."
    end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        return nil, "Animator original não encontrado; nenhum Animator local foi criado."
    end
    local animate = character:FindFirstChild("Animate")
    if not animate or not animate:IsA("LocalScript") then
        return nil, "Script Animate padrão não encontrado neste jogo."
    end
    return {humanoid = humanoid, animator = animator, animate = animate}
end

local function readSlots(animate)
    local items = {}
    for _, path in ipairs(SLOT_PATHS) do
        local animation = locate(animate, path)
        if not animation then
            return nil, "Este Animate não possui o campo " .. path .. "."
        end
        items[path] = animation
    end
    return items
end

local function stopTracksUsing(animator, ids)
    if not animator or not animator.Parent then return end
    local ok, tracks = pcall(function() return animator:GetPlayingAnimationTracks() end)
    if not ok then return end
    for _, track in ipairs(tracks) do
        pcall(function()
            local anim = track.Animation
            local id = anim and anim.AnimationId:match("(%d+)$")
            if id and ids[id] then track:Stop(0.18) end
        end)
    end
end

local function reloadAnimate(animate, slots, values)
    if not animate or not animate.Parent then return false, "Animate desapareceu." end
    local wasDisabled = animate.Disabled
    -- Stop the old controller while changing all nine slots; avoid
    -- mixed-walk/idle animation sets in the same render frame.
    local ok, why = pcall(function()
        animate.Disabled = true
        for _, path in ipairs(SLOT_PATHS) do
            local obj = slots[path]
            if obj and obj.Parent then obj.AnimationId = values[path] end
        end
        animate.Disabled = wasDisabled
    end)
    if not ok then
        pcall(function() animate.Disabled = wasDisabled end)
        return false, tostring(why)
    end
    return true
end

local function restoreCurrent()
    if not originalAnimations or not watchedCharacter then
        originalAnimations, watchedCharacter = nil, nil
        return
    end
    local character = watchedCharacter
    local animate = character:FindFirstChild("Animate")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    if animate then
        local slots = readSlots(animate)
        if slots then
            local ids = {}
            for _, id in pairs(PRESETS.vampire.slots) do ids[id] = true end
            stopTracksUsing(animator, ids)
            reloadAnimate(animate, slots, originalAnimations)
        end
    end
    originalAnimations, watchedCharacter = nil, nil
end

local function applyCurrent(character)
    local preset = PRESETS[currentPreset]
    if not preset then return false, "Pacote desconhecido." end
    local rig, why = getCharacterRig(character)
    if not rig then return false, why end
    local slots, reason = readSlots(rig.animate)
    if not slots then return false, reason end

    if watchedCharacter ~= character then
        originalAnimations, watchedCharacter = nil, nil
        local snapshot = {}
        for path, animation in pairs(slots) do snapshot[path] = animation.AnimationId end
        originalAnimations = snapshot
        watchedCharacter = character
    end
    local previouslyPlaying = {}
    for _, animationId in pairs(preset.slots) do previouslyPlaying[animationId] = true end
    stopTracksUsing(rig.animator, previouslyPlaying)
    local newIds = {}
    for path, id in pairs(preset.slots) do newIds[path] = "rbxassetid://" .. id end
    return reloadAnimate(rig.animate, slots, newIds)
end

local function onRespawn(character)
    originalAnimations, watchedCharacter = nil, nil
    if not active then return end
    task.spawn(function()
        if not character then return end
        character:WaitForChild("Animate", 8)
        local humanoid = character:WaitForChild("Humanoid", 8)
        if not humanoid then return end
        -- Allow built-in Animate to initialize its default clips first.
        task.wait(0.25)
        if active and player.Character == character then
            local ok, reason = applyCurrent(character)
            if not ok then warn("[Monarca/Anim] Respawn: " .. tostring(reason)) end
        end
    end)
end

function AnimPacks:enable(presetName)
    if presetName == "default" then return self:disable() end
    if not PRESETS[presetName] then
        return false, "Pacote desconhecido: " .. tostring(presetName)
    end
    if active and currentPreset == presetName and watchedCharacter == player.Character then
        return true, "Pacote já aplicado."
    end
    if active then restoreCurrent() end
    local previousPreset = currentPreset
    currentPreset = presetName
    local ok, reason = applyCurrent(player.Character)
    if not ok then
        currentPreset = previousPreset
        active = false
        restoreCurrent()
        return false, reason
    end
    active = true
    if not characterConnection then
        characterConnection = player.CharacterAdded:Connect(onRespawn)
    end
    return true, "Vampire aplicado ao Animate R15 original. Confirme FE com outra conta."
end

function AnimPacks:disable()
    active = false
    currentPreset = "default"
    if characterConnection then
        characterConnection:Disconnect()
        characterConnection = nil
    end
    restoreCurrent()
    return true, "Animações originais restauradas."
end

function AnimPacks:isActive()
    return active
end

function AnimPacks:getPreset()
    return currentPreset
end

function AnimPacks:getPresets()
    return {
        {id = "default", title = "Padrão do mapa"},
        {id = "vampire", title = "Vampire Animation Pack"},
    }
end

return AnimPacks
