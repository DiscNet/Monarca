-- Monarca X? / Server invisibility toggle v0.7.1
-- Never claims FE on a purely client-side script: requires the RemoteEvent
-- installed by server/MonarcaInvisibility.server.lua in an owned experience.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Module = {}
local enabled = false
local counter = 0

local function request(desired)
    if player.Name:lower() ~= "samulucas7419" then
        return false, "Acesso reservado a samulucas7419."
    end
    local remote = ReplicatedStorage:FindFirstChild("MonarcaInvisibility")
    if not remote or not remote:IsA("RemoteEvent") then
        return false, "Servidor sem MonarcaInvisibility. Instale o script no ServerScriptService do seu jogo."
    end
    counter = counter + 1
    local id = counter
    local returned = false
    local received = false
    local state, reason = nil, nil
    local listener = remote.OnClientEvent:Connect(function(kind, responseId, success, active, message)
        if kind ~= "result" or responseId ~= id then return end
        received = true
        returned = success == true
        state = active == true
        reason = tostring(message or "")
    end)
    local ok, err = pcall(function()
        remote:FireServer("set", desired, id)
    end)
    if not ok then
        listener:Disconnect()
        return false, "Solicitação ao servidor falhou: " .. tostring(err)
    end

    local deadline = os.clock() + 5
    while not received and os.clock() < deadline do
        task.wait(0.06)
    end
    listener:Disconnect()
    if not received then
        return false, "Servidor não confirmou a alteração. Invisibilidade não verificada."
    end
    if not returned then return false, reason end
    enabled = state
    if state ~= desired then
        return false, "O servidor retornou um estado diferente do solicitado."
    end
    return true, reason
end

function Module:enable()
    if enabled then return true end
    return request(true)
end
function Module:disable()
    -- Ask the server even if our previous acknowledgement timed out:
    -- the remote may have applied invisibility despite losing the reply.
    return request(false)
end
function Module:isActive() return enabled end
return Module
