-- Monarca / Emote catalog v0.8.7
-- Curated R15 emote animations. Catalog IDs are references, NOT ownership bypass.
-- Sources: Roblox /e defaults and curated avatar marketplace asset IDs.
-- Playback uses the player's pre-existing server-created Animator.
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local Catalog = {}

local STATIC = {
    {name = "Acenar (Wave)", id = "507770239", group = "Clássicos", aliases = "wave aceno"},
    {name = "Apontar (Point)", id = "507770453", group = "Clássicos", aliases = "point apontar"},
    {name = "Comemorar (Cheer)", id = "507770677", group = "Clássicos", aliases = "cheer comemorar"},
    {name = "Rir (Laugh)", id = "507770818", group = "Clássicos", aliases = "laugh risada"},
    {name = "Dance 1", id = "507771019", group = "Clássicos", aliases = "danca dance"},
    {name = "Dance 2", id = "507776043", group = "Clássicos", aliases = "danca dance2"},
    {name = "Dance 3", id = "507777268", group = "Clássicos", aliases = "danca dance3"},
    {name = "Point2", id = "3576823880", group = "Gratuitos", aliases = "apontar 2"},
    {name = "Shrug", id = "3576968026", group = "Gratuitos", aliases = "ombros duvida"},
    {name = "Hello", id = "3576686446", group = "Gratuitos", aliases = "ola acenar"},
    {name = "Stadium", id = "3360686498", group = "Gratuitos", aliases = "estadio comemorar"},
    {name = "Salute", id = "3360689775", group = "Gratuitos", aliases = "saudar continencia"},
    {name = "Tilt", id = "3360692915", group = "Gratuitos", aliases = "inclinar"},
    {name = "Applaud", id = "5915779043", group = "Gratuitos", aliases = "aplaudir palmas"},
    {name = "Floating Aura", id = "79795305221612", group = "Catálogo", aliases = "flutuar aura"},
    {name = "Monkey", id = "3716636630", group = "Catálogo", aliases = "macaco"},
    {name = "Curtsy", id = "4646306583", group = "Catálogo", aliases = "reverencia"},
    {name = "Godlike", id = "3823158750", group = "Catálogo", aliases = "deus"},
    {name = "Helicopter", id = "110553756436163", group = "Catálogo", aliases = "helicoptero"},
    {name = "Happy", id = "4849499887", group = "Catálogo", aliases = "feliz"},
    {name = "Rat Dance", id = "83606297144428", group = "Catálogo", aliases = "rato"},
    {name = "Sleep", id = "4689362868", group = "Catálogo", aliases = "dormir sono"},
    {name = "Hero Landing", id = "5104377791", group = "Catálogo", aliases = "super heroi pouso"},
    {name = "Shy", id = "3576717965", group = "Catálogo", aliases = "timido"},
    {name = "Floss Dance", id = "5917570207", group = "Catálogo", aliases = "danca floss"},
    {name = "Quiet Waves", id = "7466046574", group = "Catálogo", aliases = "acenar"},
    {name = "Baby Dance", id = "4272484885", group = "Catálogo", aliases = "danca bebe"},
    {name = "Top Rock", id = "3570535774", group = "Catálogo", aliases = "break dance"},
    {name = "Bored", id = "5230661597", group = "Catálogo", aliases = "entediado"},
    {name = "Take The L", id = "75633408126191", group = "Catálogo", aliases = "danca"},
    {name = "Twirl", id = "3716633898", group = "Catálogo", aliases = "girar"},
    {name = "Fashionable", id = "3576745472", group = "Catálogo", aliases = "moda pose"},
    {name = "Line Dance", id = "4049646104", group = "Catálogo", aliases = "danca linha"},
    {name = "Cower", id = "4940597758", group = "Catálogo", aliases = "medo"},
    {name = "High Wave", id = "5915776835", group = "Catálogo", aliases = "acenar"},
    {name = "Worm", id = "108956933782219", group = "Catálogo", aliases = "minhoca danca"},
    {name = "Dolphin Dance", id = "5938365243", group = "Catálogo", aliases = "golfinho"},
    {name = "Celebrate", id = "3994127840", group = "Catálogo", aliases = "celebrar"},
    {name = "Side to Side", id = "3762641826", group = "Catálogo", aliases = "lado a lado"},
    {name = "Dorky Dance", id = "4212499637", group = "Catálogo", aliases = "danca"},
    {name = "Shuffle", id = "4391208058", group = "Catálogo", aliases = "danca shuffle"},
    {name = "Fancy Feet", id = "3934988903", group = "Catálogo", aliases = "pes danca"},
    {name = "Dizzy", id = "3934986896", group = "Catálogo", aliases = "tonto"},
    {name = "Bodybuilder", id = "3994130516", group = "Catálogo", aliases = "musculos fisiculturista"},
    {name = "Sad", id = "4849502101", group = "Catálogo", aliases = "triste"},
    {name = "Break Dance", id = "5915773992", group = "Catálogo", aliases = "danca break"},
    {name = "Samba", id = "6869813008", group = "Catálogo", aliases = "samba danca"},
    {name = "Zombie", id = "4212496830", group = "Catálogo", aliases = "zumbi"},
    {name = "Greatest", id = "3762654854", group = "Catálogo", aliases = "melhor"},
    {name = "Haha", id = "4102315500", group = "Catálogo", aliases = "risada"},
}
local currentTrack
local currentHumanoid
local characterConnection

local function releaseTrack()
    if currentTrack then
        local track = currentTrack
        currentTrack = nil
        pcall(function() track:Stop(0.15) end)
        pcall(function() track:Destroy() end)
    end
    currentHumanoid = nil
end

local function usableRig()
    local character = player.Character
    if not character or not character:IsDescendantOf(workspace) then
        return nil, nil, "Personagem não está pronto."
    end
    if character:GetAttribute("MonarcaLocalProxy") then
        return nil, nil, "Restaure o personagem real antes de usar emotes."
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return nil, nil, "Humanoid indisponível."
    end
    if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
        return nil, nil, "Catálogo de emotes requer R15."
    end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        return nil, nil, "Animator original não encontrado; não criaremos um local."
    end
    return humanoid, animator
end

local function catalogFromAvatar(humanoid)
    local result = {}
    local ok, description = pcall(function()
        return humanoid:GetAppliedDescription()
    end)
    if not ok or not description then return result end
    local got, emotes = pcall(function()
        return description:GetEmotes()
    end)
    if not got or type(emotes) ~= "table" then return result end
    for name, ids in pairs(emotes) do
        if type(name) == "string" and #name <= 100 and type(ids) == "table" then
            local id = ids[1]
            if type(id) == "number" then id = string.format("%.0f", id) end
            if type(id) == "string" and id:match("^%d+$") then
                table.insert(result, {
                    name = name, id = id,
                    group = "Meus emotes", aliases = "equipado avatar",
                    nativeName = name,
                })
            end
        end
    end
    table.sort(result, function(a, b) return a.name:lower() < b.name:lower() end)
    return result
end

function Catalog:getCatalog()
    local result, seen = {}, {}
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        for _, item in ipairs(catalogFromAvatar(humanoid)) do
            seen[item.id] = true
            table.insert(result, item)
        end
    end
    for _, item in ipairs(STATIC) do
        if not seen[item.id] then
            table.insert(result, item)
            seen[item.id] = true
        end
    end
    return result
end

function Catalog:stop()
    releaseTrack()
    return true, "Emote interrompido."
end

function Catalog:disable()
    releaseTrack()
    if characterConnection then
        characterConnection:Disconnect()
        characterConnection = nil
    end
end

-- Hub's loadAuxiliary validates both enable() and disable().
-- This explicit lifecycle was missing in 0.8.6 and prevented the entire
-- emote module from loading even when its static catalog was valid.
function Catalog:enable()
    if not characterConnection then
        characterConnection = player.CharacterAdded:Connect(releaseTrack)
    end
    return true
end

function Catalog:play(item)
    if type(item) ~= "table" then return false, "Escolha um emote da lista." end
    local id = tostring(item.id or "")
    if not id:match("^%d+$") or #id > 20 then
        return false, "ID de emote inválido."
    end
    local humanoid, animator, issue = usableRig()
    if not humanoid then return false, issue end
    self:enable()
    releaseTrack()

    if type(item.nativeName) == "string" then
        -- Avatar-equipped emotes have the canonical API as first choice.
        local before = {}
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            before[track] = true
        end
        local ok, played = pcall(function()
            return humanoid:PlayEmoteAsync(item.nativeName)
        end)
        if ok and played == true then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                if not before[track] then
                    currentTrack = track
                    break
                end
            end
            currentHumanoid = humanoid
            return true, "Emote do avatar iniciado."
        end
    end

    -- Some assets (especially paid emotes not owned/equipped) cannot be loaded
    -- in arbitrary experiences. This is not circumvented.
    local animation = Instance.new("Animation")
    animation.Name = "MonarcaEmote_" .. id
    animation.AnimationId = "rbxassetid://" .. id
    local ok, trackOrIssue = pcall(function()
        return animator:LoadAnimation(animation)
    end)
    animation:Destroy()
    if not ok or not trackOrIssue then
        return false, "Emote indisponível ou sem permissão neste jogo: " ..
            tostring(trackOrIssue)
    end
    local track = trackOrIssue
    track.Priority = Enum.AnimationPriority.Action
    local started, errorMessage = pcall(function()
        track.Looped = false
        track:Play(0.15, 1, 1)
    end)
    if not started then
        pcall(function() track:Destroy() end)
        return false, "Não foi possível reproduzir: " .. tostring(errorMessage)
    end
    currentTrack = track
    currentHumanoid = humanoid
    return true, "Reprodução solicitada; disponibilidade e replicação dependem do jogo e do asset."
end

function Catalog:isPlaying()
    return currentTrack ~= nil and currentTrack.IsPlaying
end

return Catalog
