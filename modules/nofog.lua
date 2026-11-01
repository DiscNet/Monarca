-- Locally reduce fog and atmosphere haze, restoring original properties on disable.
local Lighting = game:GetService("Lighting")
local module = {}
local active = false
local oldFog = nil
local atmospheres = {}
local childAdded = nil

local function lighten(atmosphere)
    if not active or not atmosphere:IsA("Atmosphere") then return end
    if not atmospheres[atmosphere] then
        atmospheres[atmosphere] = {
            density = atmosphere.Density,
            haze = atmosphere.Haze,
            glare = atmosphere.Glare,
        }
    end
    atmosphere.Density = 0
    atmosphere.Haze = 0
    atmosphere.Glare = 0
end

function module:enable()
    if active then return end
    active = true
    oldFog = {start = Lighting.FogStart, finish = Lighting.FogEnd}
    Lighting.FogStart = 0
    Lighting.FogEnd = 100000
    for _, child in ipairs(Lighting:GetChildren()) do lighten(child) end
    childAdded = Lighting.ChildAdded:Connect(lighten)
end

function module:disable()
    if not active then return end
    active = false
    if childAdded then childAdded:Disconnect(); childAdded = nil end
    if oldFog then
        Lighting.FogStart = oldFog.start
        Lighting.FogEnd = oldFog.finish
    end
    oldFog = nil
    for atmosphere, values in pairs(atmospheres) do
        if atmosphere.Parent then
            pcall(function()
                atmosphere.Density = values.density
                atmosphere.Haze = values.haze
                atmosphere.Glare = values.glare
            end)
        end
    end
    atmospheres = {}
end

return module
