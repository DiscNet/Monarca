-- Monarca / Anim v0.8.1: 17 Creator Hub R15 packs + Oldschool (community IDs).
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
    astronaut = {
        title = "Astronaut Animation Pack",
        slots = {
            ["idle.Animation1"] = "891621366",
            ["idle.Animation2"] = "891633237",
            ["walk.WalkAnim"] = "891636393",
            ["run.RunAnim"] = "891636393",
            ["jump.JumpAnim"] = "891627522",
            ["fall.FallAnim"] = "891617961",
            ["climb.ClimbAnim"] = "891609353",
            ["swim.Swim"] = "891639666",
            ["swimidle.SwimIdle"] = "891663592",
        },
    },
    bubbly = {
        title = "Bubbly Animation Pack",
        slots = {
            ["idle.Animation1"] = "910004836",
            ["idle.Animation2"] = "910009958",
            ["walk.WalkAnim"] = "910034870",
            ["run.RunAnim"] = "910025107",
            ["jump.JumpAnim"] = "910016857",
            ["fall.FallAnim"] = "910001910",
            ["climb.ClimbAnim"] = "909997997",
            ["swim.Swim"] = "910028158",
            ["swimidle.SwimIdle"] = "910030921",
        },
    },
    cartoony = {
        title = "Cartoony Animation Pack",
        slots = {
            ["idle.Animation1"] = "742637544",
            ["idle.Animation2"] = "742638445",
            ["walk.WalkAnim"] = "742640026",
            ["run.RunAnim"] = "742638842",
            ["jump.JumpAnim"] = "742637942",
            ["fall.FallAnim"] = "742637151",
            ["climb.ClimbAnim"] = "742636889",
            ["swim.Swim"] = "742639220",
            ["swimidle.SwimIdle"] = "742639812",
        },
    },
    elder = {
        title = "Elder Animation Pack",
        slots = {
            ["idle.Animation1"] = "845397899",
            ["idle.Animation2"] = "845400520",
            ["walk.WalkAnim"] = "845403856",
            ["run.RunAnim"] = "845386501",
            ["jump.JumpAnim"] = "845398858",
            ["fall.FallAnim"] = "845396048",
            ["climb.ClimbAnim"] = "845392038",
            ["swim.Swim"] = "845401742",
            ["swimidle.SwimIdle"] = "845403127",
        },
    },
    knight = {
        title = "Knight Animation Pack",
        slots = {
            ["idle.Animation1"] = "657595757",
            ["idle.Animation2"] = "657568135",
            ["walk.WalkAnim"] = "657552124",
            ["run.RunAnim"] = "657564596",
            ["jump.JumpAnim"] = "658409194",
            ["fall.FallAnim"] = "657600338",
            ["climb.ClimbAnim"] = "658360781",
            ["swim.Swim"] = "657560551",
            ["swimidle.SwimIdle"] = "657557095",
        },
    },
    levitation = {
        title = "Levitation Animation Pack",
        slots = {
            ["idle.Animation1"] = "616006778",
            ["idle.Animation2"] = "616008087",
            ["walk.WalkAnim"] = "616013216",
            ["run.RunAnim"] = "616010382",
            ["jump.JumpAnim"] = "616008936",
            ["fall.FallAnim"] = "616005863",
            ["climb.ClimbAnim"] = "616003713",
            ["swim.Swim"] = "616011509",
            ["swimidle.SwimIdle"] = "616012453",
        },
    },
    mage = {
        title = "Mage Animation Pack",
        slots = {
            ["idle.Animation1"] = "707742142",
            ["idle.Animation2"] = "707855907",
            ["walk.WalkAnim"] = "707897309",
            ["run.RunAnim"] = "707861613",
            ["jump.JumpAnim"] = "707853694",
            ["fall.FallAnim"] = "707829716",
            ["climb.ClimbAnim"] = "707826056",
            ["swim.Swim"] = "707876443",
            ["swimidle.SwimIdle"] = "707894699",
        },
    },
    ninja = {
        title = "Ninja Animation Pack",
        slots = {
            ["idle.Animation1"] = "656117400",
            ["idle.Animation2"] = "656118341",
            ["walk.WalkAnim"] = "656121766",
            ["run.RunAnim"] = "656118852",
            ["jump.JumpAnim"] = "656117878",
            ["fall.FallAnim"] = "656115606",
            ["climb.ClimbAnim"] = "656114359",
            ["swim.Swim"] = "656119721",
            ["swimidle.SwimIdle"] = "656121397",
        },
    },
    oldschool = {
        title = "Oldschool Animation Pack",
        slots = {
            ["idle.Animation1"] = "5319828216",
            ["idle.Animation2"] = "5319831086",
            ["walk.WalkAnim"] = "5319847204",
            ["run.RunAnim"] = "5319844329",
            ["jump.JumpAnim"] = "5319841935",
            ["fall.FallAnim"] = "5319839762",
            ["climb.ClimbAnim"] = "5319816685",
            ["swim.Swim"] = "5319850266",
            ["swimidle.SwimIdle"] = "5319852613",
        },
    },
    pirate = {
        title = "Pirate Animation Pack",
        slots = {
            ["idle.Animation1"] = "750781874",
            ["idle.Animation2"] = "750782770",
            ["walk.WalkAnim"] = "750785693",
            ["run.RunAnim"] = "750783738",
            ["jump.JumpAnim"] = "750782230",
            ["fall.FallAnim"] = "750780242",
            ["climb.ClimbAnim"] = "750779899",
            ["swim.Swim"] = "750784579",
            ["swimidle.SwimIdle"] = "750785176",
        },
    },
    robot = {
        title = "Robot Animation Pack",
        slots = {
            ["idle.Animation1"] = "616088211",
            ["idle.Animation2"] = "616089559",
            ["walk.WalkAnim"] = "616095330",
            ["run.RunAnim"] = "616091570",
            ["jump.JumpAnim"] = "616090535",
            ["fall.FallAnim"] = "616087089",
            ["climb.ClimbAnim"] = "616086039",
            ["swim.Swim"] = "616092998",
            ["swimidle.SwimIdle"] = "616094091",
        },
    },
    rthro = {
        title = "Rthro Animation Pack",
        slots = {
            ["idle.Animation1"] = "2510197257",
            ["idle.Animation2"] = "2510196951",
            ["walk.WalkAnim"] = "2510202577",
            ["run.RunAnim"] = "2510198475",
            ["jump.JumpAnim"] = "2510197830",
            ["fall.FallAnim"] = "2510195892",
            ["climb.ClimbAnim"] = "2510192778",
            ["swim.Swim"] = "2510199791",
            ["swimidle.SwimIdle"] = "2510201162",
        },
    },
    stylish = {
        title = "Stylish Animation Pack",
        slots = {
            ["idle.Animation1"] = "616136790",
            ["idle.Animation2"] = "616138447",
            ["walk.WalkAnim"] = "616146177",
            ["run.RunAnim"] = "616140816",
            ["jump.JumpAnim"] = "616139451",
            ["fall.FallAnim"] = "616134815",
            ["climb.ClimbAnim"] = "616133594",
            ["swim.Swim"] = "616143378",
            ["swimidle.SwimIdle"] = "616144772",
        },
    },
    superhero = {
        title = "Superhero Animation Pack",
        slots = {
            ["idle.Animation1"] = "616111295",
            ["idle.Animation2"] = "616113536",
            ["walk.WalkAnim"] = "616122287",
            ["run.RunAnim"] = "616117076",
            ["jump.JumpAnim"] = "616115533",
            ["fall.FallAnim"] = "616108001",
            ["climb.ClimbAnim"] = "616104706",
            ["swim.Swim"] = "616119360",
            ["swimidle.SwimIdle"] = "616120861",
        },
    },
    toy = {
        title = "Toy Animation Pack",
        slots = {
            ["idle.Animation1"] = "782841498",
            ["idle.Animation2"] = "782845736",
            ["walk.WalkAnim"] = "782843345",
            ["run.RunAnim"] = "782842708",
            ["jump.JumpAnim"] = "782847020",
            ["fall.FallAnim"] = "782846423",
            ["climb.ClimbAnim"] = "782843869",
            ["swim.Swim"] = "782844582",
            ["swimidle.SwimIdle"] = "782845186",
        },
    },
    werewolf = {
        title = "Werewolf Animation Pack",
        slots = {
            ["idle.Animation1"] = "1083195517",
            ["idle.Animation2"] = "1083214717",
            ["walk.WalkAnim"] = "1083178339",
            ["run.RunAnim"] = "1083216690",
            ["jump.JumpAnim"] = "1083218792",
            ["fall.FallAnim"] = "1083189019",
            ["climb.ClimbAnim"] = "1083182000",
            ["swim.Swim"] = "1083222527",
            ["swimidle.SwimIdle"] = "1083225406",
        },
    },
    zombie = {
        title = "Zombie Animation Pack",
        slots = {
            ["idle.Animation1"] = "616158929",
            ["idle.Animation2"] = "616160636",
            ["walk.WalkAnim"] = "616168032",
            ["run.RunAnim"] = "616163682",
            ["jump.JumpAnim"] = "616161997",
            ["fall.FallAnim"] = "616157476",
            ["climb.ClimbAnim"] = "616156119",
            ["swim.Swim"] = "616165109",
            ["swimidle.SwimIdle"] = "616166655",
        },
    },
}
-- 17 complete classic animation bundles documented by Roblox Creator Hub.
-- Oldschool separately cross-checked with community source tables.
-- Each has 9 assigned Animate slots; some official bundles offer a third
-- idle variant, which is not used by this default two-idle controller.
-- Source: https://create.roblox.com/docs/animation/using

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

-- A movement may override just one part of the base package. Idle applies
-- to both weighted idle clips, preserving the natural idle variation.
local GROUPS = {
    {id = "idle", title = "Idle", paths = {"idle.Animation1", "idle.Animation2"}},
    {id = "walk", title = "Walk", paths = {"walk.WalkAnim"}},
    {id = "run", title = "Run", paths = {"run.RunAnim"}},
    {id = "jump", title = "Jump", paths = {"jump.JumpAnim"}},
    {id = "fall", title = "Fall", paths = {"fall.FallAnim"}},
    {id = "climb", title = "Climb", paths = {"climb.ClimbAnim"}},
    {id = "swim", title = "Swim", paths = {"swim.Swim"}},
    {id = "swimidle", title = "Swim Idle", paths = {"swimidle.SwimIdle"}},
}
local VALID_GROUPS, PATH_TO_GROUP = {}, {}
for _, group in ipairs(GROUPS) do
    VALID_GROUPS[group.id] = true
    for _, path in ipairs(group.paths) do PATH_TO_GROUP[path] = group.id end
end

local currentOverrides = {}
local lastAppliedIds = {}

local function copyOverrides(overrides)
    local copy = {}
    for id, preset in pairs(overrides) do copy[id] = preset end
    return copy
end

local function resolvedSlots(base, overrides, originals)
    local values = {}
    for _, path in ipairs(SLOT_PATHS) do
        local chosen = overrides[PATH_TO_GROUP[path]] or base
        values[path] = chosen == "default"
            and originals[path]
            or ("rbxassetid://" .. PRESETS[chosen].slots[path])
    end
    return values
end

local function trackIds(values)
    local ids = {}
    for _, animationId in pairs(values) do
        local id = tostring(animationId):match("(%d+)$")
        if id then ids[id] = true end
    end
    return ids
end

local function restoreCurrent()
    if originalAnimations and watchedCharacter then
        local character = watchedCharacter
        local animate = character:FindFirstChild("Animate")
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
        if animate then
            local slots = readSlots(animate)
            if slots then
                stopTracksUsing(animator, lastAppliedIds)
                reloadAnimate(animate, slots, originalAnimations)
            end
        end
    end
    originalAnimations, watchedCharacter = nil, nil
    lastAppliedIds = {}
end

local function applyCurrent(character)
    local rig, why = getCharacterRig(character)
    if not rig then return false, why end
    local slots, reason = readSlots(rig.animate)
    if not slots then return false, reason end

    if watchedCharacter ~= character or not originalAnimations then
        local snapshot = {}
        for path, animation in pairs(slots) do snapshot[path] = animation.AnimationId end
        originalAnimations = snapshot
        watchedCharacter = character
        lastAppliedIds = {}
    end

    local newValues = resolvedSlots(currentPreset, currentOverrides, originalAnimations)
    local previousValues = {}
    for path, animation in pairs(slots) do previousValues[path] = animation.AnimationId end
    -- Only stop tracks whose source clip is being replaced. This prevents
    -- an unrelated emote from being interrupted by a partial edit.
    local changedIds = {}
    local changed = false
    for path, previous in pairs(previousValues) do
        if previous ~= newValues[path] then
            changed = true
            local id = previous:match("(%d+)$")
            if id then changedIds[id] = true end
        end
    end
    if changed then
        stopTracksUsing(rig.animator, changedIds)
        local ok, errorText = reloadAnimate(rig.animate, slots, newValues)
        if not ok then
            reloadAnimate(rig.animate, slots, previousValues)
            return false, errorText
        end
    end
    lastAppliedIds = trackIds(newValues)
    return true
end

local function onRespawn(character)
    originalAnimations, watchedCharacter = nil, nil
    lastAppliedIds = {}
    if not active then return end
    task.spawn(function()
        if not character then return end
        character:WaitForChild("Animate", 8)
        local humanoid = character:WaitForChild("Humanoid", 8)
        if not humanoid then return end
        task.wait(0.25)
        if active and player.Character == character then
            local ok, reason = applyCurrent(character)
            if not ok then warn("[Monarca/Anim] Respawn: " .. tostring(reason)) end
        end
    end)
end

function AnimPacks:enableMixed(basePreset, overrides)
    if type(basePreset) ~= "string" or (basePreset ~= "default" and not PRESETS[basePreset]) then
        return false, "Pacote base desconhecido: " .. tostring(basePreset)
    end
    if type(overrides) ~= "table" then
        return false, "Configuração de movimentos inválida."
    end
    local cleaned = {}
    for movement, preset in pairs(overrides) do
        if not VALID_GROUPS[movement] then
            return false, "Movimento desconhecido: " .. tostring(movement)
        end
        if type(preset) ~= "string" or (preset ~= "default" and not PRESETS[preset]) then
            return false, "Animação desconhecida para " .. movement .. "."
        end
        cleaned[movement] = preset
    end

    if basePreset == "default" and next(cleaned) == nil then
        return self:disable()
    end

    local previousBase, previousOverrides, previouslyActive =
        currentPreset, currentOverrides, active
    currentPreset, currentOverrides = basePreset, cleaned
    local ok, reason = applyCurrent(player.Character)
    if not ok then
        currentPreset, currentOverrides = previousBase, previousOverrides
        active = previouslyActive
        if previouslyActive then
            -- Keep the previously selected mix when a new one fails.
            pcall(applyCurrent, player.Character)
        else
            restoreCurrent()
        end
        return false, reason
    end
    active = true
    if not characterConnection then
        characterConnection = player.CharacterAdded:Connect(onRespawn)
    end
    return true, "Mistura aplicada ao Animate R15. Confirme a visibilidade com outro jogador."
end

function AnimPacks:enable(presetName)
    return self:enableMixed(presetName, {})
end

function AnimPacks:disable()
    active = false
    if characterConnection then
        characterConnection:Disconnect()
        characterConnection = nil
    end
    restoreCurrent()
    currentPreset = "default"
    currentOverrides = {}
    return true, "Animações originais restauradas."
end

function AnimPacks:isActive()
    return active
end

function AnimPacks:getPreset()
    return currentPreset
end

function AnimPacks:getConfig()
    return {base = currentPreset, overrides = copyOverrides(currentOverrides)}
end

function AnimPacks:getGroups()
    local result = {}
    for _, group in ipairs(GROUPS) do
        table.insert(result, {id = group.id, title = group.title})
    end
    return result
end

function AnimPacks:getPresets()
    local result = {{id = "default", title = "Padrão do mapa"}}
    for id, preset in pairs(PRESETS) do
        table.insert(result, {id = id, title = preset.title})
    end
    table.sort(result, function(a, b)
        if a.id == "default" then return true end
        if b.id == "default" then return false end
        return a.title < b.title
    end)
    return result
end

return AnimPacks
