-- Client-side ESP with visible display name and distance, updated at 5 Hz.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer
local module = {}
local active = false
local tracked, listeners = {}, {}
local joined, removed, heartbeat
local accumulator = 0

local function removeBillboard(player)
    local record = tracked[player]
    if record then
        record.gui:Destroy()
        tracked[player] = nil
    end
end

local function addBillboard(player, character)
    removeBillboard(player)
    if not active or player == localPlayer then return end
    local head = character:FindFirstChild("Head") or character:WaitForChild("Head", 6)
    if not active or player.Character ~= character or not head then return end
    local target = localPlayer:FindFirstChildOfClass("PlayerGui")
    if not target then return end

    local gui = Instance.new("BillboardGui")
    gui.Name = "MonarcaESP_" .. tostring(player.UserId)
    gui.Adornee = head
    gui.Size = UDim2.fromOffset(180, 43)
    gui.StudsOffsetWorldSpace = Vector3.new(0, 2.3, 0)
    gui.AlwaysOnTop = true
    gui.MaxDistance = 500
    gui.ResetOnSpawn = false

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(216, 183, 255)
    label.TextStrokeColor3 = Color3.fromRGB(12, 9, 18)
    label.TextStrokeTransparency = 0.2
    label.TextWrapped = true
    label.Text = player.DisplayName
    label.Parent = gui
    gui.Parent = target
    tracked[player] = {gui = gui, label = label, character = character}
end

local function track(player)
    if player == localPlayer or listeners[player] then return end
    listeners[player] = player.CharacterAdded:Connect(function(character)
        task.spawn(addBillboard, player, character)
    end)
    if player.Character then
        task.spawn(addBillboard, player, player.Character)
    end
end

local function untrack(player)
    removeBillboard(player)
    if listeners[player] then
        listeners[player]:Disconnect()
        listeners[player] = nil
    end
end

local function refreshDistances(dt)
    accumulator = accumulator + dt
    if accumulator < 0.2 then return end
    accumulator = 0
    local ownCharacter = localPlayer.Character
    local ownRoot = ownCharacter and ownCharacter:FindFirstChild("HumanoidRootPart")
    for player, record in pairs(tracked) do
        if player.Character ~= record.character or not record.gui.Parent then
            removeBillboard(player)
        else
            local targetRoot = record.character:FindFirstChild("HumanoidRootPart")
            if ownRoot and targetRoot then
                local distance = math.floor((targetRoot.Position - ownRoot.Position).Magnitude + 0.5)
                record.label.Text = player.DisplayName .. "\n" .. tostring(distance) .. " studs"
            else
                record.label.Text = player.DisplayName
            end
        end
    end
end

function module:enable()
    if active then return end
    active = true
    accumulator = 0
    for _, player in ipairs(Players:GetPlayers()) do track(player) end
    joined = Players.PlayerAdded:Connect(track)
    removed = Players.PlayerRemoving:Connect(untrack)
    heartbeat = RunService.Heartbeat:Connect(refreshDistances)
end

function module:disable()
    if not active then return end
    active = false
    if joined then joined:Disconnect(); joined = nil end
    if removed then removed:Disconnect(); removed = nil end
    if heartbeat then heartbeat:Disconnect(); heartbeat = nil end
    for player in pairs(listeners) do untrack(player) end
    for player in pairs(tracked) do removeBillboard(player) end
end

return module
