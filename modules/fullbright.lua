-- Modulo visual local e reversivel.
local Lighting = game:GetService("Lighting")
local module = {}
local original = nil

function module:enable()
    if original then return end
    original = {
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        Brightness = Lighting.Brightness,
        GlobalShadows = Lighting.GlobalShadows,
        ClockTime = Lighting.ClockTime,
        ExposureCompensation = Lighting.ExposureCompensation,
    }
    Lighting.Ambient = Color3.fromRGB(210, 210, 210)
    Lighting.OutdoorAmbient = Color3.fromRGB(210, 210, 210)
    Lighting.Brightness = 2
    Lighting.GlobalShadows = false
    Lighting.ClockTime = 12
    Lighting.ExposureCompensation = 0
end

function module:disable()
    if not original then return end
    for property, value in pairs(original) do
        pcall(function() Lighting[property] = value end)
    end
    original = nil
end

return module
