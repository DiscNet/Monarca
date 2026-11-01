-- Monarca / 666 / Fling: Roblox public/private-server opt-in gameplay.
-- Requires server/MonarcaTouchBounce.server.lua in YOUR experience.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bounce = {}
local sending, receiving = false, false

local function request(action, desired)
    local remote = ReplicatedStorage:FindFirstChild("MonarcaTouchBounce")
    if not remote or not remote:IsA("RemoteFunction") then
        return false, "Integração do servidor ausente. Instale no seu jogo."
    end
    local ok, accepted, message = pcall(function()
        return remote:InvokeServer(action, desired)
    end)
    if not ok then return false, "Falha de comunicação com o servidor." end
    if not accepted then return false, tostring(message or "Acesso negado.") end
    return true, tostring(message or "Concluído.")
end

function Bounce:enable()
    if sending then return true, "Fling já ativado." end
    local ok, message = request("sending", true)
    if ok then sending = true end
    return ok, message
end

function Bounce:disable()
    if not sending then return true, "Fling já desligado." end
    local ok, message = request("sending", false)
    if ok then sending = false end
    return ok, message
end

function Bounce:allowReceiving(desired)
    desired = desired == true
    if receiving == desired then return true, "Preferência já aplicada." end
    local ok, message = request("receiving", desired)
    if ok then receiving = desired end
    return ok, message
end

function Bounce:isActive()
    return sending
end

function Bounce:isReceiving()
    return receiving
end

function Bounce:shutdown()
    if sending then pcall(function() request("sending", false) end) end
    if receiving then pcall(function() request("receiving", false) end) end
    sending, receiving = false, false
end

return Bounce
