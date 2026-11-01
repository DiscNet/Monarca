-- Monarca / 666 / Korblox Deathspeaker Right Leg (139607718)
-- Cosmetic local preview of the ACTUAL Roblox body-part asset, not a fake
-- approximation or ownership bypass. Availability depends on asset loading.
-- In R15, preserve each donor mesh's native proportions and align by joints.
-- In R6, transfer donor CharacterMesh RightLeg to the client character.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local Korblox = {}
local KORBLOX_RIGHT_LEG = 139607718

local enabled = false
local generation = 0
local parts = {}
local removedCharacterMeshes = {}
local donor
local respawnConnection
local renderStep = "MonarcaKorbloxLeg_" .. tostring(player.UserId)

local function restore()
    pcall(function() RunService:UnbindFromRenderStep(renderStep) end)
    for _, state in ipairs(parts) do
        if state.visual then
            pcall(function() state.visual:Destroy() end)
        end
        if state.part and state.part.Parent then
            pcall(function()
                state.part.LocalTransparencyModifier = state.transparency
            end)
        end
    end
    table.clear(parts)
    for _, state in ipairs(removedCharacterMeshes) do
        if state.mesh and state.character and state.character.Parent then
            pcall(function() state.mesh.Parent = state.character end)
        elseif state.mesh then
            pcall(function() state.mesh:Destroy() end)
        end
    end
    table.clear(removedCharacterMeshes)
    if donor then donor:Destroy(); donor = nil end
end

local function getActualKorbloxModel(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return nil, "Humanoid indisponível." end
    local ok, description = pcall(function()
        return humanoid:GetAppliedDescription()
    end)
    if not ok or not description then
        return nil, "Não foi possível ler o visual atual."
    end
    description.RightLeg = KORBLOX_RIGHT_LEG
    -- Roblox creates the correct body-part geometry based on its catalog ID.
    local generated, model = pcall(function()
        return Players:CreateHumanoidModelFromDescriptionAsync(
            description, humanoid.RigType
        )
    end)
    description:Destroy()
    if not generated or not model then
        return nil, "Carregamento do asset bloqueado pelo Roblox: " ..
            tostring(model)
    end
    return model
end

-- An R15 package deliberately uses different source sizes for thigh, shin
-- and foot. Forcing Size = player's old limb Size stretches Korblox into a
-- thick/long mesh. Preserve the actual package dimensions instead.
--
-- Match the incoming package's joint attachment to the live rig joint.
-- The source CFrame and old CFrame centers need not coincide, especially for
-- small stylized limbs and invisible foot segments.
local R15_SEGMENTS = {
    {name = "RightUpperLeg", attachment = "RightHipRigAttachment"},
    {name = "RightLowerLeg", attachment = "RightKneeRigAttachment"},
    {name = "RightFoot", attachment = "RightAnkleRigAttachment"},
}
local function rigAttachment(part, name)
    local attachment = part:FindFirstChild(name, true)
    if attachment and attachment:IsA("Attachment") then
        return attachment
    end
    return nil
end

local function applyR15(character, generated, states)
    local verified = {}
    local changed = false

    -- Resolve all three segments first; never leave a half-equipped leg.
    for _, segment in ipairs(R15_SEGMENTS) do
        local original = character:FindFirstChild(segment.name)
        local actual = generated:FindFirstChild(segment.name)
        if not original or not original:IsA("BasePart")
            or not actual or not actual:IsA("BasePart") then
            return false, "Parte R15 ausente: " .. segment.name
        end
        local targetAttachment = rigAttachment(original, segment.attachment)
        local sourceAttachment = rigAttachment(actual, segment.attachment)
        if not targetAttachment or not sourceAttachment then
            return false, "Encaixe R15 indisponível: " .. segment.attachment
        end

        if original:IsA("MeshPart") and actual:IsA("MeshPart") then
            if original.MeshId ~= actual.MeshId
                or original.TextureID ~= actual.TextureID then
                changed = true
            end
        else
            changed = true
        end

        table.insert(verified, {
            original = original,
            actual = actual,
            originalAttachment = targetAttachment,
            sourceAttachment = sourceAttachment,
            name = segment.name,
        })
    end

    if not changed then
        return false, "O Roblox não aplicou uma geometria diferente."
    end

    for _, entry in ipairs(verified) do
        local original = entry.original
        local actual = entry.actual
        local visual = actual:Clone()
        visual.Name = "MonarcaKorblox_" .. entry.name
        for _, child in ipairs(visual:GetDescendants()) do
            if child:IsA("JointInstance") or child:IsA("Constraint")
                or child:IsA("Script") or child:IsA("LocalScript") then
                child:Destroy()
            end
        end

        -- IMPORTANT: Do NOT assign visual.Size = original.Size.
        -- Clone retains the true Korblox MeshPart.Size and shape.
        visual.Anchored = false
        visual.CanCollide = false
        visual.CanTouch = false
        visual.CanQuery = false
        visual.Massless = true

        -- Align joint origins, rather than forcing the small Korblox mesh's
        -- center to the center of the previous, potentially bulkier leg.
        local sourceJoint = rigAttachment(visual, entry.sourceAttachment.Name)
        if not sourceJoint then
            visual:Destroy()
            return false, "Encaixe de visualização ausente: " .. entry.name
        end
        local goal = original.CFrame * entry.originalAttachment.CFrame
        visual.CFrame = goal * sourceJoint.CFrame:Inverse()
        visual.Parent = character

        local weld = Instance.new("WeldConstraint")
        weld.Name = "MonarcaKorbloxWeld"
        weld.Part0 = original
        weld.Part1 = visual
        weld.Parent = visual

        table.insert(states, {
            part = original,
            visual = visual,
            transparency = original.LocalTransparencyModifier,
        })
        original.LocalTransparencyModifier = 1
    end

    return true
end

local function applyR6(character, generated)
    local sourceMesh
    for _, child in ipairs(generated:GetChildren()) do
        if child:IsA("CharacterMesh")
            and child.BodyPart == Enum.BodyPart.RightLeg then
            sourceMesh = child
            break
        end
    end
    if not sourceMesh then
        return false, "A perna Korblox não gerou CharacterMesh compatível com R6."
    end
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("CharacterMesh")
            and child.BodyPart == Enum.BodyPart.RightLeg then
            table.insert(removedCharacterMeshes, {
                mesh = child,
                character = character
            })
            child.Parent = nil
        end
    end
    local clone = sourceMesh:Clone()
    clone.Name = "MonarcaKorbloxRightLeg"
    clone.Parent = character
    table.insert(parts, {visual = clone})
    return true
end

local function install(character, ticket)
    restore()
    if not enabled or generation ~= ticket or player.Character ~= character then
        return false, "Personagem alterado durante o carregamento."
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false, "Humanoid indisponível." end
    local model, err = getActualKorbloxModel(character)
    if not model then return false, err end
    if not enabled or generation ~= ticket or player.Character ~= character then
        model:Destroy()
        return false, "Ativação cancelada."
    end
    donor = model
    local ok, message
    if humanoid.RigType == Enum.HumanoidRigType.R15 then
        ok, message = applyR15(character, model, parts)
    else
        ok, message = applyR6(character, model)
    end
    if not ok then
        restore()
        return false, message
    end
    donor:Destroy()
    donor = nil
    if humanoid.RigType == Enum.HumanoidRigType.R15 then
        -- The default camera can modify local transparency for nearby body
        -- parts. Hide only the original right-leg segments after it updates.
        RunService:BindToRenderStep(renderStep,
            Enum.RenderPriority.Camera.Value + 2, function()
                if not enabled then return end
                for _, state in ipairs(parts) do
                    if state.part and state.part.Parent then
                        state.part.LocalTransparencyModifier = 1
                    end
                end
            end
        )
    end
    return true
end

function Korblox:enable()
    if enabled then return true end
    local character = player.Character
    if not character then return false, "Personagem indisponível." end
    enabled = true
    generation = generation + 1
    local ticket = generation
    if not respawnConnection then
        respawnConnection = player.CharacterAdded:Connect(function(newCharacter)
            if not enabled then return end
            generation = generation + 1
            local respawnTicket = generation
            task.spawn(function()
                newCharacter:WaitForChild("Humanoid", 8)
                if enabled and generation == respawnTicket then
                    local ok, reason = install(newCharacter, respawnTicket)
                    if not ok then
                        warn("[Monarca Korblox] " .. tostring(reason))
                    end
                end
            end)
        end)
    end
    local ok, installed, why = pcall(install, character, ticket)
    if not ok or not installed then
        self:disable()
        return false, tostring(ok and why or installed)
    end
    return true
end

function Korblox:disable()
    enabled = false
    generation = generation + 1
    if respawnConnection then respawnConnection:Disconnect(); respawnConnection = nil end
    restore()
end
function Korblox:isActive() return enabled end
return Korblox
