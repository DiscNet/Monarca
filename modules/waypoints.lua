-- Monarca / Waypoints v0.9.1
-- Named, per-place saved positions and optional draggable teleport shortcuts.
-- CRITICAL: touch/mouse use InputBegan/InputChanged/InputEnded; NEVER Activated
-- for pointer activation. A release after movement must not teleport.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

local Waypoints = {}
local MAX_POINTS = 30
local DRAG_THRESHOLD = 9 -- screen pixels; any movement >= threshold permanently cancels tap
local MAX_TAP_SECONDS = 0.75
local BUTTON_W, BUTTON_H = 112, 34
local FILE = "Monarca/waypoints_" .. tostring(game.PlaceId) .. ".json"

local points = {}
local nextId = 1
local globalVisible = true
local enabled = false
local loadedOnce = false
local mounted = false
local persistent = type(readfile) == "function" and type(writefile) == "function"
local gui, page, theme, notify
local floatButtons = {}
local pageRows = {}
local connections = {}
local gesture = nil
local refreshRows, refreshFloats, refreshHeader
local counter, persistInfo

local function report(message)
    if notify then pcall(notify, "Waypoints: " .. tostring(message)) end
end

local function track(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end

local function isNumber(n)
    return type(n) == "number" and n == n and math.abs(n) < 10000000
end

local function validComponents(cf)
    if type(cf) ~= "table" or #cf ~= 12 then return false end
    for _, n in ipairs(cf) do
        if not isNumber(n) then return false end
    end
    return true
end

local function cleanName(text)
    text = tostring(text or ""):gsub("[%c]", ""):match("^%s*(.-)%s*$") or ""
    return text:sub(1, 30)
end

local function freshId()
    local id = tostring(nextId)
    nextId += 1
    return id
end

local function findPoint(id)
    id = tostring(id)
    for i, point in ipairs(points) do
        if point.id == id then return point, i end
    end
    return nil
end

local function persist()
    if not persistent then
        return false, "Sem armazenamento de arquivos: os pontos duram apenas esta execução."
    end
    local data = {version = 1, placeId = tostring(game.PlaceId),
        nextId = nextId, visible = globalVisible, points = points}
    local ok, errorMessage = pcall(function()
        if type(makefolder) == "function" then
            if type(isfolder) ~= "function" or not isfolder("Monarca") then
                makefolder("Monarca")
            end
        end
        writefile(FILE, HttpService:JSONEncode(data))
    end)
    if not ok then return false, "Não foi possível salvar: " .. tostring(errorMessage) end
    return true, "Salvo neste dispositivo."
end

local function loadSaved()
    if type(readfile) ~= "function" then return end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(FILE))
    end)
    if not ok or type(data) ~= "table" or
        tostring(data.placeId) ~= tostring(game.PlaceId) then return end
    nextId = math.clamp(math.floor(tonumber(data.nextId) or 1), 1, 100000000)
    globalVisible = data.visible ~= false
    if type(data.points) ~= "table" then return end
    local used = {}
    for _, point in ipairs(data.points) do
        if #points >= MAX_POINTS then break end
        if type(point) == "table" and validComponents(point.cf) then
            local name = cleanName(point.name)
            local id = tostring(point.id or "")
            if name ~= "" and id:match("^%d+$") and not used[id] then
                used[id] = true
                nextId = math.max(nextId, math.min(tonumber(id) + 1, 100000000))
                table.insert(points, {
                    id = id,
                    name = name,
                    cf = point.cf,
                    floating = point.floating == true,
                    x = isNumber(point.x) and point.x or nil,
                    y = isNumber(point.y) and point.y or nil,
                })
            end
        end
    end
end

local function findCharacter()
    local character = player and player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not character or not character:IsDescendantOf(workspace)
        or not root or not root:IsA("BasePart")
        or not humanoid or humanoid.Health <= 0 then
        return nil, "Personagem ainda não está pronto."
    end
    return character, root
end

function Waypoints:enable()
    if enabled then return true end
    enabled = true
    if not loadedOnce then
        loadedOnce = true
        loadSaved()
    end
    return true
end

function Waypoints:list()
    local result = {}
    for _, item in ipairs(points) do
        table.insert(result, {id = item.id, name = item.name,
            position = Vector3.new(item.cf[1], item.cf[2], item.cf[3]),
            floating = item.floating})
    end
    return result
end

function Waypoints:add(name)
    self:enable()
    name = cleanName(name)
    if name == "" then return false, "Informe um nome para a localização." end
    if #points >= MAX_POINTS then return false, "Limite de 30 localizações." end
    local character, errorMessage = findCharacter()
    if not character then return false, errorMessage end
    local ok, components = pcall(function()
        return {character:GetPivot():GetComponents()}
    end)
    if not ok or not validComponents(components) then
        return false, "Não foi possível ler as coordenadas atuais."
    end
    local point = {id = freshId(), name = name, cf = components,
        floating = false}
    table.insert(points, point)
    local saved, note = persist()
    if refreshRows then refreshRows() end
    if refreshHeader then refreshHeader() end
    return true, (saved and "Local salvo: " or "Local criado temporariamente: ") ..
        name .. (saved and "" or (" · " .. note)), point
end

function Waypoints:rename(id, name)
    local point = findPoint(id)
    if not point then return false, "Localização não encontrada." end
    name = cleanName(name)
    if name == "" then return false, "O nome não pode ficar vazio." end
    point.name = name
    persist()
    if refreshRows then refreshRows() end
    if refreshFloats then refreshFloats() end
    return true, "Nome alterado para " .. name .. "."
end

function Waypoints:remove(id)
    local point, index = findPoint(id)
    if not point then return false, "Localização não encontrada." end
    if gesture and gesture.id == point.id then gesture = nil end
    table.remove(points, index)
    persist()
    if refreshRows then refreshRows() end
    if refreshFloats then refreshFloats() end
    if refreshHeader then refreshHeader() end
    return true, "Local " .. point.name .. " excluído."
end

function Waypoints:teleport(id)
    local point = findPoint(id)
    if not point then return false, "Localização não encontrada." end
    local character, rootOrError = findCharacter()
    if not character then return false, rootOrError end
    local target = CFrame.new(table.unpack(point.cf))
    local ok, errorMessage = pcall(function()
        character:PivotTo(target)
        local root = rootOrError
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)
    if not ok then return false, "Falha no teleporte: " .. tostring(errorMessage) end
    return true, "Movido para " .. point.name ..
        ". O servidor do jogo pode corrigir a posição."
end

function Waypoints:setFloating(id, desired)
    local point = findPoint(id)
    if not point then return false, "Localização não encontrada." end
    point.floating = desired == true
    persist()
    if refreshFloats then refreshFloats() end
    if refreshRows then refreshRows() end
    return true, point.floating and "Atalho flutuante criado." or "Atalho ocultado."
end

function Waypoints:setVisible(desired)
    globalVisible = desired == true
    persist()
    if refreshFloats then refreshFloats() end
    if refreshHeader then refreshHeader() end
    return true
end

local function make(class, properties, parent)
    local object = Instance.new(class)
    for key, value in pairs(properties or {}) do object[key] = value end
    object.Parent = parent
    return object
end

local function corner(target, radius)
    make("UICorner", {CornerRadius = UDim.new(0, radius or 6)}, target)
end

local function action(parent, titleText, name, position, size, callback, highlighted)
    local b = make("TextButton", {
        Name = name,
        Position = position,
        Size = size,
        BackgroundColor3 = highlighted and theme.primary or theme.card,
        TextColor3 = highlighted and theme.background or theme.text,
        Text = titleText,
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextTruncate = Enum.TextTruncate.AtEnd,
        AutoButtonColor = false,
        BorderSizePixel = 0,
    }, parent)
    corner(b, 5)
    if callback then b.Activated:Connect(callback) end
    return b
end

local function message(parent, text, size, height, name)
    return make("TextLabel", {
        Name = name or "WaypointLabel",
        Size = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1,
        TextColor3 = theme.muted,
        Font = Enum.Font.Gotham,
        TextSize = size or 11,
        Text = text,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, parent)
end

local function pageElement(class, properties)
    counter += 1
    properties.LayoutOrder = counter
    local object = make(class, properties, page)
    table.insert(pageRows, object)
    return object
end

local function pageMessage(text, height, name)
    return pageElement("TextLabel", {
        Name = name or "WaypointLabel",
        Size = UDim2.new(1, -2, 0, height),
        BackgroundTransparency = 1,
        TextColor3 = theme.muted,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        Text = text,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
end

local function viewportSize()
    local camera = workspace.CurrentCamera
    if camera then return camera.ViewportSize end
    return Vector2.new(700, 500)
end

local function clampXY(x, y)
    local vp = viewportSize()
    return math.clamp(x, 4, math.max(4, vp.X - BUTTON_W - 4)),
        math.clamp(y, 4, math.max(4, vp.Y - BUTTON_H - 4))
end

local function defaultXY(index)
    local vp = viewportSize()
    local availableRows = math.max(1, math.floor((vp.Y - 100) / 40))
    local col = math.floor((index - 1) / availableRows)
    local row = (index - 1) % availableRows
    return clampXY(vp.X - 120 - col * 120, 68 + row * 40)
end

local function movedPointer(input)
    if not gesture then return end
    if gesture.input.UserInputType == Enum.UserInputType.Touch then
        if input ~= gesture.input then return end
    elseif gesture.input.UserInputType == Enum.UserInputType.MouseButton1 then
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    else
        return
    end
    local now = Vector2.new(input.Position.X, input.Position.Y)
    local delta = now - gesture.start
    if delta.Magnitude >= DRAG_THRESHOLD then
        gesture.moved = true
    end
    if not gesture.moved then return end
    local x, y = clampXY(gesture.origin.X + delta.X, gesture.origin.Y + delta.Y)
    gesture.button.Position = UDim2.fromOffset(x, y)
end

local function pointerEnded(input)
    if not gesture then return end
    local active = gesture
    if input ~= active.input and not (
        active.input.UserInputType == Enum.UserInputType.MouseButton1 and
        input.UserInputType == Enum.UserInputType.MouseButton1
    ) then return end
    gesture = nil
    if active.moved then
        local point = findPoint(active.id)
        if point then
            point.x = active.button.Position.X.Offset
            point.y = active.button.Position.Y.Offset
            persist()
        end
        return -- Drag always cancels click, even when released over same button.
    end
    local now = Vector2.new(input.Position.X, input.Position.Y)
    local distance = (now - active.start).Magnitude
    if distance >= DRAG_THRESHOLD or os.clock() - active.started > MAX_TAP_SECONDS then
        return
    end
    local position, size = active.button.AbsolutePosition, active.button.AbsoluteSize
    if now.X < position.X or now.X > position.X + size.X
        or now.Y < position.Y or now.Y > position.Y + size.Y then
        return
    end
    local ok, messageText = Waypoints:teleport(active.id)
    report(messageText)
end

local function drawFloat(point, index)
    local x, y = point.x, point.y
    if not isNumber(x) or not isNumber(y) then x, y = defaultXY(index) end
    x, y = clampXY(x, y)
    local b = make("TextButton", {
        Name = "WaypointFloat_" .. point.id,
        Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(BUTTON_W, BUTTON_H),
        BackgroundColor3 = theme.surface,
        BackgroundTransparency = 0.10,
        BorderSizePixel = 0,
        TextColor3 = theme.text,
        Text = "⌖ " .. point.name,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextTruncate = Enum.TextTruncate.AtEnd,
        AutoButtonColor = false,
        Active = true,
        ZIndex = 45,
    }, gui)
    corner(b, 6)
    make("UIStroke", {
        Color = theme.whiteLine, Thickness = 1, Transparency = 0.46,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, b)
    -- Activated only handles keyboard/gamepad. Touch and mouse are handled
    -- exclusively after pointerEnded confirms a non-drag tap.
    b.Activated:Connect(function(input)
        if input and (input.UserInputType == Enum.UserInputType.Gamepad1
            or input.UserInputType == Enum.UserInputType.Keyboard) then
            local ok, info = Waypoints:teleport(point.id)
            report(info)
        end
    end)
    b.InputBegan:Connect(function(input)
        if gesture then return end
        if input.UserInputType ~= Enum.UserInputType.Touch
            and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        gesture = {
            id = point.id,
            input = input,
            button = b,
            start = Vector2.new(input.Position.X, input.Position.Y),
            origin = Vector2.new(b.Position.X.Offset, b.Position.Y.Offset),
            moved = false,
            started = os.clock(),
        }
    end)
    floatButtons[point.id] = b
end

function Waypoints:mount(scroller, screenGui, palette, onStatus)
    self:enable()
    if mounted then return true end
    if not scroller or not screenGui then return false, "Interface não encontrada." end
    page, gui, theme, notify = scroller, screenGui, palette, onStatus
    mounted, counter = true, 1000
    local nameFrame = pageElement("Frame", {
        Name = "WaypointNameRow",
        Size = UDim2.new(1, -2, 0, 44),
        BackgroundTransparency = 1,
    })
    local nameInput = make("TextBox", {
        Name = "WaypointName",
        Position = UDim2.fromOffset(0, 4),
        Size = UDim2.new(1, -112, 0, 34),
        BackgroundColor3 = theme.card,
        TextColor3 = theme.text,
        PlaceholderText = "Nome do ponto (ex.: Casa)",
        PlaceholderColor3 = theme.muted,
        Text = "",
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
    }, nameFrame)
    corner(nameInput, 5)
    make("UIPadding", {
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
    }, nameInput)
    local saveButton = action(nameFrame, "SALVAR", "WaypointSave",
        UDim2.new(1, -103, 0, 4), UDim2.fromOffset(103, 34), nil, true)
    local globalBar = pageElement("Frame", {
        Name = "WaypointsHeader",
        Size = UDim2.new(1, -2, 0, 38),
        BackgroundTransparency = 1,
    })
    local countLabel = message(globalBar, "", 11, 27, "WaypointCount")
    countLabel.Position = UDim2.fromOffset(0, 4)
    countLabel.Size = UDim2.new(1, -132, 0, 27)
    local visibility = action(globalBar, "OCULTAR BOTÕES", "WaypointVisibility",
        UDim2.new(1, -131, 0, 2), UDim2.fromOffset(131, 30))
    visibility.TextSize = 10
    persistInfo = pageMessage(
        persistent and "Os pontos são salvos por jogo neste dispositivo."
            or "Sem readfile/writefile: pontos disponíveis só durante esta execução.",
        36, "WaypointStorage")
    pageMessage("Toque no nome de um ponto para renomear. Criar botão é opcional; arraste o flutuante sem ativar teleporte.", 38)
    local listTitle = pageMessage("LOCAIS SALVOS", 24, "WaypointListHeading")
    listTitle.TextColor3 = theme.text
    listTitle.Font = Enum.Font.GothamBold

    refreshHeader = function()
        if not mounted then return end
        countLabel.Text = tostring(#points) .. " / " .. tostring(MAX_POINTS) .. " pontos"
        visibility.Text = globalVisible and "OCULTAR BOTÕES" or "MOSTRAR BOTÕES"
    end
    refreshFloats = function()
        if not mounted then return end
        gesture = nil
        for _, b in pairs(floatButtons) do b:Destroy() end
        table.clear(floatButtons)
        if not globalVisible then return end
        local index = 0
        for _, point in ipairs(points) do
            if point.floating then
                index += 1
                drawFloat(point, index)
            end
        end
    end
    refreshRows = function()
        if not mounted then return end
        for _, object in ipairs(pageRows) do
            if object.Name:sub(1, 12) == "WaypointItem" then object:Destroy() end
        end
        local preserved = {}
        for _, object in ipairs(pageRows) do
            if object.Parent then table.insert(preserved, object) end
        end
        pageRows = preserved
        counter = 1005
        if #points == 0 then
            pageMessage("Nenhum ponto salvo. Dê um nome acima e toque em SALVAR para registrar a posição atual.", 48, "WaypointItemEmpty")
        end
        for _, point in ipairs(points) do
            local row = pageElement("Frame", {
                Name = "WaypointItem_" .. point.id,
                Size = UDim2.new(1, -2, 0, 85),
                BackgroundTransparency = 1,
            })
            local renameBox = make("TextBox", {
                Name = "WaypointRename_" .. point.id,
                Position = UDim2.fromOffset(7, 1),
                Size = UDim2.new(1, -19, 0, 26),
                BackgroundTransparency = 1,
                Text = point.name,
                ClearTextOnFocus = false,
                TextColor3 = theme.text,
                TextSize = 13,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }, row)
            renameBox.FocusLost:Connect(function()
                if not mounted then return end
                if renameBox.Text ~= point.name then
                    local ok, detail = Waypoints:rename(point.id, renameBox.Text)
                    report(detail)
                    if not ok and renameBox.Parent then renameBox.Text = point.name end
                end
            end)
            local coord = make("TextLabel", {
                Position = UDim2.fromOffset(7, 26),
                Size = UDim2.new(1, -14, 0, 18),
                BackgroundTransparency = 1,
                Text = string.format("X %.1f  ·  Y %.1f  ·  Z %.1f",
                    point.cf[1], point.cf[2], point.cf[3]),
                TextColor3 = theme.muted,
                TextSize = 10,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, row)
            action(row, "IR", "WaypointTeleport_" .. point.id,
                UDim2.new(0, 7, 0, 49), UDim2.new(0.24, -9, 0, 30),
                function()
                    local _, result = Waypoints:teleport(point.id)
                    report(result)
                end, true)
            action(row, point.floating and "REMOVER BOTÃO" or "CRIAR BOTÃO",
                "WaypointFloating_" .. point.id,
                UDim2.new(0.24, 2, 0, 49), UDim2.new(0.51, -13, 0, 30),
                function()
                    local _, result = Waypoints:setFloating(point.id, not point.floating)
                    report(result)
                end)
            local removeButton = action(row, "×", "WaypointDelete_" .. point.id,
                UDim2.new(0.75, 2, 0, 49), UDim2.new(0.25, -11, 0, 30),
                function()
                    local _, result = Waypoints:remove(point.id)
                    report(result)
                end)
            removeButton.TextColor3 = theme.danger
        end
    end

    track(UserInputService.InputChanged, movedPointer)
    track(UserInputService.InputEnded, pointerEnded)
    track(workspace:GetPropertyChangedSignal("CurrentCamera"), function()
        if refreshFloats then refreshFloats() end
    end)
    local camera = workspace.CurrentCamera
    if camera then
        track(camera:GetPropertyChangedSignal("ViewportSize"), function()
            if refreshFloats then refreshFloats() end
        end)
    end
    saveButton.Activated:Connect(function()
        local ok, result = Waypoints:add(nameInput.Text)
        if ok then nameInput.Text = "" end
        report(result)
    end)
    visibility.Activated:Connect(function()
        Waypoints:setVisible(not globalVisible)
    end)
    refreshHeader()
    refreshRows()
    refreshFloats()
    return true
end

function Waypoints:disable()
    gesture = nil
    mounted = false
    for _, connection in ipairs(connections) do connection:Disconnect() end
    table.clear(connections)
    for _, b in pairs(floatButtons) do b:Destroy() end
    table.clear(floatButtons)
    for _, item in ipairs(pageRows) do if item.Parent then item:Destroy() end end
    table.clear(pageRows)
    refreshHeader, refreshRows, refreshFloats = nil, nil, nil
    page, gui, theme, notify = nil, nil, nil, nil
    enabled = false
end

return Waypoints
