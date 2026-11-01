-- Monarca Owner Tag v0.6.8
-- Only the exact Roblox username samulucas7419 can use these local controls.
-- This is a client-only nameplate; it is NOT a server-side security boundary.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local OwnerTag = {}
local allowed = player.Name:lower() == "samulucas7419"
local active = false
local text = "MONARCA"
local red, green, blue = 180, 145, 255
local rainbowFast = false
local billboard, nameLabel
local respawnConnection
local latestGeneration = 0
local rgbConnection
local lastFrame = -1

local function cleanText(value)
    local input = tostring(value or ""):gsub("[%c]", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if input == "" then return "MONARCA" end
    -- Use codepoint boundaries to avoid splitting UTF-8 characters.
    local ok, cutoff = pcall(utf8.offset, input, 33)
    if ok and cutoff then input = input:sub(1, cutoff - 1) end
    if #input > 160 then input = input:sub(1, 160) end
    return input
end

local function destroyTag()
    if billboard then billboard:Destroy() end
    billboard, nameLabel = nil, nil
end

local function currentColor()
    if rainbowFast then
        return Color3.fromHSV((os.clock() * 3.5) % 1, 0.92, 1)
    end
    return Color3.fromRGB(red, green, blue)
end

local function render()
    if not active or not nameLabel then return end
    nameLabel.Text = text
    nameLabel.TextColor3 = currentColor()
end

local function showOnCharacter(character, version)
    if not active or not character or version ~= latestGeneration then return end
    local head = character:FindFirstChild("Head")
        or character:WaitForChild("Head", 8)
    if not active or version ~= latestGeneration or player.Character ~= character
        or not head or not head:IsA("BasePart") then return end
    if not billboard then
        local parent = player:FindFirstChildOfClass("PlayerGui")
        if not parent then return end
        billboard = Instance.new("BillboardGui")
        billboard.Name = "MonarcaOwnerTag"
        billboard.Size = UDim2.fromOffset(260, 50)
        billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.25, 0)
        billboard.AlwaysOnTop = true
        billboard.MaxDistance = 225
        billboard.LightInfluence = 0
        billboard.Parent = parent

        nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "CustomTag"
        nameLabel.Size = UDim2.fromScale(1, 1)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = text
        nameLabel.TextSize = 19
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextColor3 = currentColor()
        nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        nameLabel.TextStrokeTransparency = 0.26
        nameLabel.TextScaled = false
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.Parent = billboard
    end
    billboard.Adornee = head
    render()
end

function OwnerTag:configure(config)
    if not allowed then return false, "Nome não autorizado." end
    if type(config) ~= "table" then return false, "Configuração inválida." end
    if config.text ~= nil then text = cleanText(config.text) end
    if config.red ~= nil then
        red = math.clamp(math.floor(tonumber(config.red) or red), 0, 255)
    end
    if config.green ~= nil then
        green = math.clamp(math.floor(tonumber(config.green) or green), 0, 255)
    end
    if config.blue ~= nil then
        blue = math.clamp(math.floor(tonumber(config.blue) or blue), 0, 255)
    end
    if config.rainbowFast ~= nil then rainbowFast = config.rainbowFast == true end
    lastFrame = -1
    render()
    return true
end

function OwnerTag:enable()
    if not allowed then return false, "Tag exclusiva de samulucas7419." end
    if active then return true end
    active = true
    latestGeneration = latestGeneration + 1
    if not respawnConnection then
        respawnConnection = player.CharacterAdded:Connect(function(character)
            latestGeneration = latestGeneration + 1
            local version = latestGeneration
            task.spawn(showOnCharacter, character, version)
        end)
    end
    if not rgbConnection then
        rgbConnection = RunService.RenderStepped:Connect(function()
            if not active or not rainbowFast or not nameLabel then return end
            -- ~30 color frames/s, with 3.5 complete hue cycles each second.
            local colorFrame = math.floor(os.clock() * 30)
            if colorFrame ~= lastFrame then
                lastFrame = colorFrame
                nameLabel.TextColor3 = currentColor()
            end
        end)
    end
    if player.Character then
        local version = latestGeneration
        task.spawn(showOnCharacter, player.Character, version)
    end
    return true
end

function OwnerTag:disable()
    active = false
    latestGeneration = latestGeneration + 1
    if respawnConnection then
        respawnConnection:Disconnect()
        respawnConnection = nil
    end
    if rgbConnection then
        rgbConnection:Disconnect()
        rgbConnection = nil
    end
    destroyTag()
end

function OwnerTag:isActive() return active end
return OwnerTag
