-- Highlight client-side of other players' characters. No collision/replication edits.
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local module = {}
local enabled = false
local playerConnections = {}
local highlighted = {}
local joined, left

local function clear(player)
    if highlighted[player] then
        highlighted[player]:Destroy()
        highlighted[player] = nil
    end
end

local function attach(player, character)
    clear(player)
    if not enabled or player == localPlayer or not character then return end
    local mark = Instance.new("Highlight")
    mark.Name = "MonarcaCharacterXray"
    mark.Adornee = character
    mark.FillColor = Color3.fromRGB(174, 124, 248)
    mark.OutlineColor = Color3.fromRGB(230, 210, 255)
    mark.FillTransparency = 0.68
    mark.OutlineTransparency = 0.1
    mark.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    mark.Parent = character
    highlighted[player] = mark
end

local function track(player)
    if player == localPlayer or playerConnections[player] then return end
    playerConnections[player] = player.CharacterAdded:Connect(function(character)
        attach(player, character)
    end)
    if player.Character then attach(player, player.Character) end
end

local function untrack(player)
    clear(player)
    if playerConnections[player] then
        playerConnections[player]:Disconnect()
        playerConnections[player] = nil
    end
end

function module:enable()
    if enabled then return end
    enabled = true
    for _, player in ipairs(Players:GetPlayers()) do track(player) end
    joined = Players.PlayerAdded:Connect(track)
    left = Players.PlayerRemoving:Connect(untrack)
end

function module:disable()
    if not enabled then return end
    enabled = false
    if joined then joined:Disconnect(); joined = nil end
    if left then left:Disconnect(); left = nil end
    for player in pairs(playerConnections) do untrack(player) end
    for player in pairs(highlighted) do clear(player) end
end

return module
