-- Independent day/night view. "Padrao" restores the saved map time.
local Lighting = game:GetService("Lighting")
local module = {}
local active = false
local original
local currentMode = "Padrão"
local connection, elapsed = nil, 0

local function apply()
    if not active then return end
    if currentMode == "Dia" then
        Lighting.ClockTime = 12
    elseif currentMode == "Noite" then
        Lighting.ClockTime = 0
    end
end

function module:enable()
    if active then return end
    original = Lighting.ClockTime
    active = true
    elapsed = 0
    connection = game:GetService("RunService").Heartbeat:Connect(function(dt)
        elapsed = elapsed + dt
        if elapsed >= 2 then
            elapsed = 0
            apply()
        end
    end)
end

function module:setMode(mode)
    if mode ~= "Dia" and mode ~= "Noite" then return end
    if not active then self:enable() end
    currentMode = mode
    apply()
end

function module:disable()
    if not active then return end
    active = false
    if connection then connection:Disconnect(); connection = nil end
    currentMode = "Padrão"
    if original then pcall(function() Lighting.ClockTime = original end) end
    original = nil
end

return module
