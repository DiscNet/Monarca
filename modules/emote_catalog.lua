-- Monarca / Emote catalog v0.9.0
-- Curated R15 animation sequence IDs (not Marketplace item IDs).
-- Catalog IDs from earlier versions are kept in catalogId for search only.
-- Non-classic animation IDs cross-checked against Eazvy/Public-Scripts.
-- Emote asset access and replication remain subject to Roblox restrictions.
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
    {name = "Point2", id = "3344585679", group = "Gratuitos", aliases = "apontar 2", catalogId = "3576823880"},
    {name = "Shrug", id = "3334392772", group = "Gratuitos", aliases = "ombros duvida", catalogId = "3576968026"},
    {name = "Hello", id = "3344650532", group = "Gratuitos", aliases = "ola acenar", catalogId = "3576686446"},
    {name = "Stadium", id = "3338055167", group = "Gratuitos", aliases = "estadio comemorar", catalogId = "3360686498"},
    {name = "Salute", id = "3333474484", group = "Gratuitos", aliases = "saudar continencia", catalogId = "3360689775"},
    {name = "Tilt", id = "3334538554", group = "Gratuitos", aliases = "inclinar", catalogId = "3360692915"},
    {name = "Applaud", id = "5915693819", group = "Gratuitos", aliases = "aplaudir palmas", catalogId = "5915779043"},
    {name = "Agree", id = "4841397952", group = "Extras", aliases = "concordar sim"},
    {name = "Monkey", id = "3333499508", group = "Catálogo", aliases = "macaco", catalogId = "3716636630"},
    {name = "Curtsy", id = "4555816777", group = "Catálogo", aliases = "reverencia", catalogId = "4646306583"},
    {name = "Godlike", id = "3337994105", group = "Catálogo", aliases = "deus", catalogId = "3823158750"},
    {name = "Confused", id = "4940561610", group = "Extras", aliases = "confuso duvida"},
    {name = "Happy", id = "4841405708", group = "Catálogo", aliases = "feliz", catalogId = "4849499887"},
    {name = "Air Guitar", id = "3695300085", group = "Extras", aliases = "guitarra ar"},
    {name = "Sleep", id = "4686925579", group = "Catálogo", aliases = "dormir sono", catalogId = "4689362868"},
    {name = "Hero Landing", id = "5104344710", group = "Catálogo", aliases = "super heroi pouso", catalogId = "5104377791"},
    {name = "Shy", id = "3337978742", group = "Catálogo", aliases = "timido", catalogId = "3576717965"},
    {name = "Floss Dance", id = "5917459365", group = "Catálogo", aliases = "danca floss", catalogId = "5917570207"},
    {name = "Quiet Waves", id = "7465981288", group = "Catálogo", aliases = "acenar", catalogId = "7466046574"},
    {name = "Baby Dance", id = "4265725525", group = "Catálogo", aliases = "danca bebe", catalogId = "4272484885"},
    {name = "Top Rock", id = "3361276673", group = "Catálogo", aliases = "break dance", catalogId = "3570535774"},
    {name = "Bored", id = "5230599789", group = "Catálogo", aliases = "entediado", catalogId = "5230661597"},
    {name = "Jumping Cheer", id = "5895324424", group = "Extras", aliases = "pular celebrar"},
    {name = "Twirl", id = "3334968680", group = "Catálogo", aliases = "girar", catalogId = "3716633898"},
    {name = "Fashionable", id = "3333331310", group = "Catálogo", aliases = "moda pose", catalogId = "3576745472"},
    {name = "Line Dance", id = "4049037604", group = "Catálogo", aliases = "danca linha", catalogId = "4049646104"},
    {name = "Cower", id = "4940563117", group = "Catálogo", aliases = "medo", catalogId = "4940597758"},
    {name = "High Wave", id = "5915690960", group = "Catálogo", aliases = "acenar", catalogId = "5915776835"},
    {name = "Robot", id = "3338025566", group = "Extras", aliases = "robo robot"},
    {name = "Dolphin Dance", id = "5918726674", group = "Catálogo", aliases = "golfinho", catalogId = "5938365243"},
    {name = "Celebrate", id = "3338097973", group = "Catálogo", aliases = "celebrar", catalogId = "3994127840"},
    {name = "Side to Side", id = "3333136415", group = "Catálogo", aliases = "lado a lado", catalogId = "3762641826"},
    {name = "Dorky Dance", id = "4212455378", group = "Catálogo", aliases = "danca", catalogId = "4212499637"},
    {name = "Shuffle", id = "4349242221", group = "Catálogo", aliases = "danca shuffle", catalogId = "4391208058"},
    {name = "Fancy Feet", id = "3333432454", group = "Catálogo", aliases = "pes danca", catalogId = "3934988903"},
    {name = "Dizzy", id = "3361426436", group = "Catálogo", aliases = "tonto", catalogId = "3934986896"},
    {name = "Bodybuilder", id = "3333387824", group = "Catálogo", aliases = "musculos fisiculturista", catalogId = "3994130516"},
    {name = "Sad", id = "4841407203", group = "Catálogo", aliases = "triste", catalogId = "4849502101"},
    {name = "Break Dance", id = "5915648917", group = "Catálogo", aliases = "danca break", catalogId = "5915773992"},
    {name = "Samba", id = "6869766175", group = "Catálogo", aliases = "samba danca", catalogId = "6869813008"},
    {name = "Zombie", id = "4210116953", group = "Catálogo", aliases = "zumbi", catalogId = "4212496830"},
    {name = "Greatest", id = "3338042785", group = "Catálogo", aliases = "melhor", catalogId = "3762654854"},
    {name = "Haha", id = "3337966527", group = "Catálogo", aliases = "risada", catalogId = "4102315500"},
}
local currentTrack
local currentHumanoid
local characterConnection
-- UGC catalog items are Animation wrappers, not raw animation clips.
-- Track ONLY our temporary emote name, so stop/close cannot erase player emotes.
local temporaryEmote

local function restoreTemporary()
    local saved = temporaryEmote
    temporaryEmote = nil
    if not saved then return end
    local description = saved.description
    if not description or not description.Parent then return end
    if saved.changedEquipped and saved.equipped then
        pcall(function()
            description:SetEquippedEmotes(saved.equipped)
        end)
    end
    pcall(function()
        description:RemoveEmote(saved.name)
    end)
end

local function releaseTrack()
    if currentTrack then
        local track = currentTrack
        currentTrack = nil
        pcall(function() track:Stop(0.15) end)
        pcall(function() track:Destroy() end)
    end
    currentHumanoid = nil
    restoreTemporary()
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


-- Marketplace returns an EmoteAnimation asset (Animation object) whose
-- AnimationId points to the underlying CurveAnimation. Sending the outer
-- asset id to Animator:LoadAnimation leaves the track Length at zero.
-- Instead register the emote as an emote asset and ask the Humanoid to play it.
local function playMarketplaceEmote(humanoid, animator, item, id)
    local description = humanoid:FindFirstChildOfClass("HumanoidDescription")
    if not description then
        return false, "HumanoidDescription não disponível no personagem deste jogo."
    end

    -- Avoid altering the avatar if this UGC emote is already present.
    local existingName
    local got, equipped = pcall(function() return description:GetEmotes() end)
    if got and type(equipped) == "table" then
        for name, ids in pairs(equipped) do
            if type(name) == "string" and type(ids) == "table" then
                for _, asset in ipairs(ids) do
                    local assetId = type(asset) == "number"
                        and string.format("%.0f", asset) or tostring(asset)
                    if assetId == id then
                        existingName = name
                        break
                    end
                end
            end
            if existingName then break end
        end
    end

    local emoteName = existingName or ("MonarcaUGC_" .. id)
    if not existingName then
        local added, addError = pcall(function()
            description:AddEmote(emoteName, tonumber(id))
        end)
        if not added then
            return false, "O jogo não permitiu registrar este emote UGC: " ..
                tostring(addError)
        end
        temporaryEmote = {description = description, name = emoteName}
    end

    local alreadyPlaying = {}
    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        alreadyPlaying[track] = true
    end
    -- Capture the actual track when Roblox starts the emote, rather than
    -- assuming the catalog asset ID is its internal animation clip ID.
    local observedTrack
    local nativeConnection = animator.AnimationPlayed:Connect(function(track)
        if not alreadyPlaying[track] then observedTrack = track end
    end)
    local function tryNative()
        return pcall(function()
            return humanoid:PlayEmoteAsync(emoteName)
        end)
    end
    local ok, playedOrError = tryNative()

    -- Some avatar implementations need the emote equipped in a free wheel slot.
    -- Never displace any of the player's original eight emotes.
    if (not ok or playedOrError ~= true) and temporaryEmote then
        local gotEquipped, original = pcall(function()
            return description:GetEquippedEmotes()
        end)
        if gotEquipped and type(original) == "table" and #original < 8 then
            local temporarySlot = #original + 1
            for _, entry in ipairs(original) do
                if type(entry) == "table" and type(entry.Slot) == "number" then
                    temporarySlot = math.max(temporarySlot, entry.Slot + 1)
                end
            end
            if temporarySlot <= 8 then
                local replacement = {}
                for _, entry in ipairs(original) do
                    table.insert(replacement, entry)
                end
                table.insert(replacement, {Slot = temporarySlot, Name = emoteName})
                local changed = pcall(function()
                    description:SetEquippedEmotes(replacement)
                end)
                if changed then
                    temporaryEmote.equipped = original
                    temporaryEmote.changedEquipped = true
                    ok, playedOrError = tryNative()
                end
            end
        end
    end

    nativeConnection:Disconnect()
    if not ok or playedOrError ~= true then
        restoreTemporary()
        return false, "Roblox recusou este emote UGC. Ele pode exigir posse, " ..
            "estar indisponível ou ter seu uso bloqueado pelo jogo. Detalhe: " ..
            tostring(playedOrError)
    end

    currentTrack = observedTrack
    if not currentTrack then
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            if not alreadyPlaying[track] then
                currentTrack = track
                break
            end
        end
    end
    currentHumanoid = humanoid
    return true, "Emote UGC iniciado pela API oficial. Visibilidade para outros " ..
        "jogadores depende da experiência."
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

    if item.marketplace == true then
        return playMarketplaceEmote(humanoid, animator, item, id)
    end

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
    -- Roblox may return an AnimationTrack and report IsPlaying=true even when
    -- its requested asset cannot load. Length stays 0 in that case.
    local deadline = os.clock() + 3
    while track.Length <= 0 and os.clock() < deadline and
        currentTrack == track and humanoid.Parent do
        task.wait(0.1)
    end
    if currentTrack ~= track then
        return false, "A reprodução foi interrompida."
    end
    if track.Length <= 0 then
        releaseTrack()
        return false, "Animação não carregada pelo Roblox. O ativo pode não estar disponível ou autorizado neste jogo."
    end
    return true, "Emote carregado. A replicação ainda depende do jogo."
end

function Catalog:isPlaying()
    return currentTrack ~= nil and currentTrack.IsPlaying
end

return Catalog
