-- Monarca / 666 / </>
-- Local-only invisible HEAD. Accessories, hair, hats, face accessories and
-- every other BasePart remain untouched. No rig joints are removed.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local Headless = {}
local active = false
local currentHead
local previousModifier
local faceTransparency = {}
local characterConnection, headChildConnection
local renderStep = "MonarcaHeadless_" .. tostring(player.UserId)

local function releaseHead()
    if headChildConnection then
        headChildConnection:Disconnect()
        headChildConnection = nil
    end
    for surface, value in pairs(faceTransparency) do
        if surface and surface.Parent then
            pcall(function() surface.Transparency = value end)
        end
        faceTransparency[surface] = nil
    end
    if currentHead and currentHead.Parent and previousModifier ~= nil then
        pcall(function()
            currentHead.LocalTransparencyModifier = previousModifier
        end)
    end
    currentHead, previousModifier = nil, nil
end

local function hideHeadFace(surface)
    -- Face decals/textures belong to Head. Accessories are separate objects.
    if not (surface:IsA("Decal") or surface:IsA("Texture")) then return end
    if faceTransparency[surface] == nil then
        faceTransparency[surface] = surface.Transparency
    end
    surface.Transparency = 1
end

local function applyToHead(head)
    if not active or not head or not head:IsA("BasePart") then return end
    if currentHead == head then return end
    releaseHead()
    currentHead = head
    previousModifier = head.LocalTransparencyModifier
    head.LocalTransparencyModifier = 1
    for _, descendant in ipairs(head:GetDescendants()) do
        hideHeadFace(descendant)
    end
    headChildConnection = head.DescendantAdded:Connect(function(descendant)
        if active and currentHead == head then hideHeadFace(descendant) end
    end)
end

local function watchCharacter(character)
    if not active then return end
    releaseHead()
    local head = character:FindFirstChild("Head")
    if head and head:IsA("BasePart") then
        applyToHead(head)
    else
        task.spawn(function()
            local discovered = character:WaitForChild("Head", 8)
            if active and player.Character == character and discovered then
                applyToHead(discovered)
            end
        end)
    end
end

function Headless:enable()
    if active then return true end
    local character = player.Character
    if not character then return false, "Personagem ainda não apareceu." end
    active = true
    local ok, err = pcall(function()
        characterConnection = player.CharacterAdded:Connect(watchCharacter)
        watchCharacter(character)
        -- Camera scripts may overwrite LocalTransparencyModifier. Override only
        -- the single Head after the camera has updated, never the accessories.
        RunService:BindToRenderStep(
            renderStep,
            Enum.RenderPriority.Camera.Value + 2,
            function()
                if not active then return end
                if currentHead and currentHead.Parent then
                    currentHead.LocalTransparencyModifier = 1
                end
            end
        )
    end)
    if not ok then
        self:disable()
        return false, tostring(err)
    end
    return true
end

function Headless:disable()
    active = false
    pcall(function() RunService:UnbindFromRenderStep(renderStep) end)
    if characterConnection then
        characterConnection:Disconnect()
        characterConnection = nil
    end
    releaseHead()
end

function Headless:isActive() return active end
return Headless
