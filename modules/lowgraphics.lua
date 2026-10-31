-- Reduz efeitos exclusivamente no cliente e restaura os valores originais.
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Terrain = Workspace:FindFirstChildOfClass("Terrain")
local module = {}
local saved = setmetatable({}, {__mode = "k"})
local changedConnection = nil
local water = nil
local active = false

local visualTypes = {
    ParticleEmitter = true, Trail = true, Beam = true,
    Fire = true, Smoke = true, Sparkles = true,
    BloomEffect = true, BlurEffect = true, SunRaysEffect = true,
    DepthOfFieldEffect = true,
}

local function quiet(object)
    if not active or not object or not visualTypes[object.ClassName] then return end
    if saved[object] == nil then
        local ok, wasEnabled = pcall(function() return object.Enabled end)
        if ok then saved[object] = wasEnabled end
    end
    pcall(function() object.Enabled = false end)
end

function module:enable()
    if active then return end
    active = true
    saved = setmetatable({}, {__mode = "k"})
    for _, object in ipairs(Workspace:GetDescendants()) do quiet(object) end
    for _, object in ipairs(Lighting:GetDescendants()) do quiet(object) end
    changedConnection = Workspace.DescendantAdded:Connect(quiet)
    if Terrain then
        water = {
            size = Terrain.WaterWaveSize,
            speed = Terrain.WaterWaveSpeed,
            reflectance = Terrain.WaterReflectance,
        }
        Terrain.WaterWaveSize = 0
        Terrain.WaterWaveSpeed = 0
        Terrain.WaterReflectance = 0
    end
end

function module:disable()
    if not active then return end
    active = false
    if changedConnection then changedConnection:Disconnect(); changedConnection = nil end
    for object, value in pairs(saved) do
        if object and object.Parent then
            pcall(function() object.Enabled = value end)
        end
    end
    saved = setmetatable({}, {__mode = "k"})
    if Terrain and water then
        pcall(function()
            Terrain.WaterWaveSize = water.size
            Terrain.WaterWaveSpeed = water.speed
            Terrain.WaterReflectance = water.reflectance
        end)
    end
    water = nil
end

return module
