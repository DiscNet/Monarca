-- MONARCA v0.7.9 - compact diagnostic bootstrap
-- Kept intentionally small: shows UI BEFORE downloading/compiling the hub core.
-- Entrypoint: loadstring(game:HttpGet("https://raw.githubusercontent.com/DiscNet/Monarca/main/Monarca.lua"))()

local Players = game:GetService("Players")
local player = Players.LocalPlayer
if not player then
    local ok, p = pcall(function() return Players.PlayerAdded:Wait() end)
    if ok then player = p end
end
if not player then
    warn("[Monarca/bootstrap] LocalPlayer indisponível")
    return
end

local environment = _G
if type(getgenv) == "function" then
    local ok, result = pcall(getgenv)
    if ok and type(result) == "table" then environment = result end
end

local runKey = tostring({})
environment.MONARCA_BOOTSTRAP_KEY = runKey
local function isCurrent()
    return environment.MONARCA_BOOTSTRAP_KEY == runKey
end

local parent = player:FindFirstChildOfClass("PlayerGui")
if not parent then
    local ok, result = pcall(function() return player:WaitForChild("PlayerGui", 6) end)
    if ok then parent = result end
end
if not parent and type(gethui) == "function" then
    local ok, result = pcall(gethui)
    if ok then parent = result end
end
if not parent then
    local ok, result = pcall(function() return game:GetService("CoreGui") end)
    if ok then parent = result end
end
if not parent then
    warn("[Monarca/bootstrap] Falha ao obter PlayerGui/gethui/CoreGui")
    return
end

local previous = parent:FindFirstChild("MonarcaBootstrap")
if previous then previous:Destroy() end
local previousError = parent:FindFirstChild("MonarcaStartupError")
if previousError then previousError:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "MonarcaBootstrap"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 99998
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = parent

local function element(class, props, owner)
    local object = Instance.new(class)
    for key, value in pairs(props) do object[key] = value end
    object.Parent = owner
    return object
end
local bg = Color3.fromRGB(12, 11, 16)
local fg = Color3.fromRGB(245, 242, 248)
local secondary = Color3.fromRGB(177, 172, 190)
local violet = Color3.fromRGB(177, 130, 229)

local box = element("Frame", {
    Name = "LoadingPanel",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.48),
    Size = UDim2.new(1, -36, 0, 180),
    BackgroundColor3 = bg,
    BorderSizePixel = 0,
}, gui)
element("UISizeConstraint", {
    MaxSize = Vector2.new(344, 200),
    MinSize = Vector2.new(230, 160),
}, box)
element("UICorner", {CornerRadius = UDim.new(0, 8)}, box)
element("UIStroke", {
    Color = Color3.fromRGB(69, 63, 76),
    Transparency = 0.13,
    Thickness = 1,
}, box)
element("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(14, 12),
    Size = UDim2.new(1, -28, 0, 30),
    Text = "MONARCA",
    Font = Enum.Font.GothamBold,
    TextSize = 22,
    TextColor3 = fg,
    TextXAlignment = Enum.TextXAlignment.Left,
}, box)
local status = element("TextLabel", {
    Name = "Status",
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(14, 51),
    Size = UDim2.new(1, -28, 0, 71),
    Text = "Iniciando carregador v0.7.9...",
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextColor3 = secondary,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
}, box)
local progress = element("Frame", {
    Position = UDim2.fromOffset(14, 126),
    Size = UDim2.new(1, -28, 0, 3),
    BackgroundColor3 = Color3.fromRGB(57, 52, 65),
    BorderSizePixel = 0,
}, box)
element("UICorner", {CornerRadius = UDim.new(0, 2)}, progress)
local fill = element("Frame", {
    Size = UDim2.fromScale(0.07, 1),
    BackgroundColor3 = violet,
    BorderSizePixel = 0,
}, progress)
element("UICorner", {CornerRadius = UDim.new(0, 2)}, fill)
local retry = element("TextButton", {
    Name = "Retry",
    Position = UDim2.new(0, 14, 1, -40),
    Size = UDim2.fromOffset(124, 28),
    Text = "TENTAR NOVAMENTE",
    Font = Enum.Font.GothamMedium,
    TextSize = 10,
    TextColor3 = fg,
    BackgroundColor3 = Color3.fromRGB(38, 34, 45),
    BorderSizePixel = 0,
    AutoButtonColor = true,
    Visible = false,
}, box)
element("UICorner", {CornerRadius = UDim.new(0, 6)}, retry)

local attempt = 0
local finished = false
local repository = "https://raw.githubusercontent.com/DiscNet/Monarca/main/"
local function progressTo(value, message)
    if finished or not gui.Parent or not isCurrent() then return end
    fill.Size = UDim2.fromScale(value, 1)
    status.Text = message
end
local function fail(stage, err)
    if finished or not gui.Parent or not isCurrent() then return end
    local detail = tostring(err or "Erro não especificado")
    warn("[Monarca/bootstrap/" .. stage .. "] " .. detail)
    fill.BackgroundColor3 = Color3.fromRGB(235, 127, 136)
    fill.Size = UDim2.fromScale(1, 1)
    status.Text = "Erro em " .. stage .. ":\n" .. detail:sub(1, 550)
    retry.Visible = true
end
local function launch()
    if finished or not isCurrent() then return end
    attempt = attempt + 1
    local id = attempt
    retry.Visible = false
    fill.BackgroundColor3 = violet
    progressTo(0.18, "Baixando núcleo do Monarca...")
    task.delay(10, function()
        if id == attempt and not finished and isCurrent() then
            progressTo(0.18, "A rede está demorando. Se não avançar, toque em TENTAR NOVAMENTE.")
            retry.Visible = true
        end
    end)
    task.spawn(function()
        local ok, source = pcall(function()
            return game:HttpGet(repository .. "hub_core.lua?v=0.7.9-" .. tostring(os.time()))
        end)
        if id ~= attempt or finished or not isCurrent() then return end
        if not ok then fail("download", source); return end
        if type(source) ~= "string" or #source < 5000 then
            fail("download", "Resposta incompleta (" .. tostring(type(source) == "string" and #source or 0) .. " bytes).")
            return
        end
        progressTo(0.56, "Compilando interface...")
        if type(loadstring) ~= "function" then
            fail("ambiente", "Este executor não disponibiliza loadstring.")
            return
        end
        local compiledOk, compiled, parseErr = pcall(loadstring, source)
        if id ~= attempt or finished or not isCurrent() then return end
        if not compiledOk then fail("compilação", compiled); return end
        if type(compiled) ~= "function" then fail("compilação", parseErr); return end
        progressTo(0.83, "Criando interface e funções...")
        local ran, bootOk, bootErr = pcall(compiled)
        if id ~= attempt or finished or not isCurrent() then return end
        if not ran then
            fail("execução", bootOk)
            return
        end
        if bootOk == false then
            fail("inicialização", bootErr)
            return
        end
        progressTo(1, "Painel iniciado.")
        finished = true
        task.defer(function()
            if gui.Parent then gui:Destroy() end
        end)
    end)
end

retry.Activated:Connect(launch)
launch()
