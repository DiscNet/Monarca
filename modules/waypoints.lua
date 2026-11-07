-- Monarca / Waypoints v0.9.3
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
local BUTTON_W, BUTTON_H = 40, 40
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
local captureId, captureButton = nil, nil
local lastHotkeyAt = 0

-- Single-key PC shortcuts. Navigation/chat/modifier keys are deliberately
-- excluded to prevent accidental shortcuts while using the Roblox client.
local RESERVED_KEYS = {
    Unknown = true, Escape = true, Tab = true, Return = true,
    KeypadEnter = true, Backspace = true, Delete = true, Slash = true,
    LeftControl = true, RightControl = true, LeftAlt = true, RightAlt = true,
    LeftShift = true, RightShift = true, LeftMeta = true, RightMeta = true,
    LeftSuper = true, RightSuper = true, CapsLock = true, None = true,
}
local NUMBER_KEYS = {
    Zero = "0", One = "1", Two = "2", Three = "3", Four = "4",
    Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9",
}
local function validKeyName(name)
    if type(name) ~= "string" or #name == 0 or #name > 30 or RESERVED_KEYS[name] then
        return nil
    end
    local code = Enum.KeyCode[name]
    if not code or code == Enum.KeyCode.Unknown or code.Value >= 1000 then
        return nil -- keyboard shortcuts only, never gamepad codes from saved JSON
    end
    return name
end
local function displayKey(name)
    if not name then return "DEFINIR TECLA" end
    return "TECLA: " .. (NUMBER_KEYS[name] or name:upper())
end
local function ctrlAltMetaHeld()
    return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
        or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
        or UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
        or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
        or UserInputService:IsKeyDown(Enum.KeyCode.LeftMeta)
        or UserInputService:IsKeyDown(Enum.KeyCode.RightMeta)
        or UserInputService:IsKeyDown(Enum.KeyCode.LeftSuper)
        or UserInputService:IsKeyDown(Enum.KeyCode.RightSuper)
end
local function cancelCapture()
    if captureButton and captureButton.Parent then
        local point
        for _, saved in ipairs(points) do
            if saved.id == captureId then point = saved; break end
        end
        captureButton.Text = point and displayKey(point.keybind) or "DEFINIR TECLA"
    end
    captureId, captureButton = nil, nil
end

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

-- Display a single uppercase letter, never the entire saved name or an emoji.
-- UTF-8 codepoints matter for names such as Árvore, Éden and Órbita.
local ACCENT_INITIALS = {
    ["á"] = "Á", ["à"] = "À", ["â"] = "Â", ["ã"] = "Ã", ["ä"] = "Ä",
    ["é"] = "É", ["ê"] = "Ê", ["è"] = "È", ["ë"] = "Ë",
    ["í"] = "Í", ["ì"] = "Ì", ["î"] = "Î",
    ["ó"] = "Ó", ["ô"] = "Ô", ["õ"] = "Õ", ["ò"] = "Ò", ["ö"] = "Ö",
    ["ú"] = "Ú", ["ù"] = "Ù", ["û"] = "Û", ["ü"] = "Ü",
    ["ç"] = "Ç",
}
local function firstLetter(name)
    local success, initial = pcall(function()
        for _, codepoint in utf8.codes(name) do
            if (codepoint >= 65 and codepoint <= 90)
                or (codepoint >= 97 and codepoint <= 122) then
                return string.upper(utf8.char(codepoint))
            end
            if codepoint >= 48 and codepoint <= 57 then
                return utf8.char(codepoint)
            end
            local char = utf8.char(codepoint)
            if ACCENT_INITIALS[char] then return ACCENT_INITIALS[char] end
            if codepoint >= 192 and codepoint <= 255 then return char end
        end
        return "W"
    end)
    return success and initial or "W"
end

local function freshId()
    local id = tostring(nextId)
    nextId = nextId + 1
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
    local used, usedKeys = {}, {}
    for _, point in ipairs(data.points) do
        if #points >= MAX_POINTS then break end
        if type(point) == "table" and validComponents(point.cf) then
            local name = cleanName(point.name)
            local id = tostring(point.id or "")
            if name ~= "" and id:match("^%d+$") and not used[id] then
                used[id] = true
                nextId = math.max(nextId, math.min(tonumber(id) + 1, 100000000))
                local shortcut = validKeyName(point.keybind)
                if shortcut and usedKeys[shortcut] then shortcut = nil end
                if shortcut then usedKeys[shortcut] = true end
                table.insert(points, {
                    id = id,
                    name = name,
                    cf = point.cf,
                    floating = point.floating == true,
                    keybind = shortcut,
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
            floating = item.floating, keybind = item.keybind})
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

function Waypoints:setKeybind(id, keyName)
    self:enable()
    local point = findPoint(id)
    if not point then return false, "Localização não encontrada." end
    if keyName ~= nil then
        keyName = validKeyName(keyName)
        if not keyName then
            return false, "Tecla inválida ou reservada. Escolha outra tecla."
        end
        for _, other in ipairs(points) do
            if other.id ~= point.id and other.keybind == keyName then
                return false, "Essa tecla já pertence ao waypoint " .. other.name .. "."
            end
        end
    end
    point.keybind = keyName
    local saved, note = persist()
    if refreshRows then refreshRows() end
    if keyName then
        return true, displayKey(keyName) .. " atribuída a " .. point.name ..
            (saved and "." or (" (temporário: " .. note .. ")"))
    end
    return true, "Keybind removido de " .. point.name .. "."
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
    if captureId == point.id then cancelCapture() end
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
    corner(b, 6)
    if not highlighted then
        make("UIStroke", {
            Color = theme.whiteLine, Thickness = 1, Transparency = 0.88,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, b)
        b.BackgroundTransparency = 0.28
    end
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
    counter = counter + 1
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

local function beginKeyCapture(point, keyButton)
    if captureId == point.id then
        cancelCapture()
        report("Captura de tecla cancelada.")
        return
    end
    cancelCapture()
    captureId, captureButton = point.id, keyButton
    keyButton.Text = "PRESSIONE..."
    report("Pressione uma tecla. ESC cancela; Backspace ou Delete remove.")
end

local function handleKeyInput(input, gameProcessed)
    if not enabled or not mounted or input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end
    -- Chat, search, renaming and other TextBoxes never trigger a waypoint.
    if UserInputService:GetFocusedTextBox() then return end
    local key = input.KeyCode.Name
    if captureId then
        local target = captureId
        if key == "Escape" then
            cancelCapture()
            report("Captura cancelada.")
        elseif key == "Backspace" or key == "Delete" then
            cancelCapture()
            local _, messageText = Waypoints:setKeybind(target, nil)
            report(messageText)
        elseif ctrlAltMetaHeld() then
            report("Use uma única tecla sem Ctrl ou Alt.")
        elseif not validKeyName(key) then
            report("Tecla reservada. Pressione outra tecla ou ESC para cancelar.")
        else
            cancelCapture()
            local _, messageText = Waypoints:setKeybind(target, key)
            report(messageText)
        end
        return -- The capture key must never teleport on its own.
    end
    if gameProcessed or ctrlAltMetaHeld() or RESERVED_KEYS[key] then return end
    if os.clock() - lastHotkeyAt < 0.25 then return end
    for _, point in ipairs(points) do
        if point.keybind == key then
            lastHotkeyAt = os.clock()
            local _, detail = Waypoints:teleport(point.id)
            report(detail)
            break
        end
    end
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
    local availableRows = math.max(1, math.floor((vp.Y - 100) / 48))
    local col = math.floor((index - 1) / availableRows)
    local row = (index - 1) % availableRows
    return clampXY(vp.X - BUTTON_W - 12 - col * (BUTTON_W + 8),
        68 + row * 48)
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
        Text = firstLetter(point.name),
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        TextTruncate = Enum.TextTruncate.AtEnd,
        AutoButtonColor = false,
        Active = true,
        ZIndex = 45,
    }, gui)
    corner(b, 8)
    make("UIStroke", {
        Color = theme.whiteLine, Thickness = 1, Transparency = 0.73,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, b)
    -- Small indicator: a UI Frame, not an emoji or appended character.
    local dot = make("Frame", {
        Name = "WaypointDot",
        Position = UDim2.new(1, -10, 0, 5),
        Size = UDim2.fromOffset(5, 5),
        BackgroundColor3 = theme.accent,
        BorderSizePixel = 0,
        ZIndex = 46,
    }, b)
    corner(dot, 5)
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
        PlaceholderText = "Nome do local",
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
    local visibility = action(globalBar, "OCULTAR", "WaypointVisibility",
        UDim2.new(1, -131, 0, 2), UDim2.fromOffset(131, 30))
    visibility.TextSize = 10
    persistInfo = pageMessage(
        persistent and "Os pontos são salvos por jogo neste dispositivo."
            or "Sem readfile/writefile: pontos disponíveis só durante esta execução.",
        36, "WaypointStorage")
    pageMessage("Edite o nome diretamente na lista. Um toque no atalho teleporta; arrastar só reposiciona.", 38)
    pageMessage("PC: defina uma tecla diferente para cada ponto. ESC cancela a captura; Delete limpa.", 37, "WaypointKeybindHelp")
    local listTitle = pageMessage("LOCAIS", 24, "WaypointListHeading")
    listTitle.TextColor3 = theme.text
    listTitle.Font = Enum.Font.GothamBold

    refreshHeader = function()
        if not mounted then return end
        countLabel.Text = tostring(#points) .. " / " .. tostring(MAX_POINTS) .. " pontos"
        visibility.Text = globalVisible and "OCULTAR" or "MOSTRAR"
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
                index = index + 1
                drawFloat(point, index)
            end
        end
    end
    refreshRows = function()
        if not mounted then return end
        cancelCapture()
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
                Size = UDim2.new(1, -2, 0, 121),
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
                Text = string.format("X: %.1f    Y: %.1f    Z: %.1f",
                    point.cf[1], point.cf[2], point.cf[3]),
                TextColor3 = theme.muted,
                TextSize = 10,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, row)
            -- Three typography-only actions: no emoji, icon glyph or verbose labels.
            local goButton = action(row, "IR", "WaypointTeleport_" .. point.id,
                UDim2.new(0, 7, 0, 49), UDim2.new(0.20, -5, 0, 30),
                function()
                    local _, result = Waypoints:teleport(point.id)
                    report(result)
                end, true)
            goButton.TextSize = 11
            local floatToggle = action(row, point.floating and "OCULTAR" or "MOSTRAR",
                "WaypointFloating_" .. point.id,
                UDim2.new(0.20, 6, 0, 49), UDim2.new(0.47, -11, 0, 30),
                function()
                    local _, result = Waypoints:setFloating(point.id, not point.floating)
                    report(result)
                end)
            floatToggle.TextSize = 10
            local removeButton = action(row, "APAGAR", "WaypointDelete_" .. point.id,
                UDim2.new(0.67, 2, 0, 49), UDim2.new(0.33, -9, 0, 30),
                function()
                    local _, result = Waypoints:remove(point.id)
                    report(result)
                end)
            removeButton.TextSize = 10
            removeButton.TextColor3 = theme.danger

            local bindLabel = make("TextLabel", {
                Name = "WaypointBindLabel_" .. point.id,
                Position = UDim2.fromOffset(7, 89),
                Size = UDim2.new(0.30, -6, 0, 26),
                BackgroundTransparency = 1,
                Text = "KEYBIND",
                Font = Enum.Font.GothamMedium,
                TextSize = 10,
                TextColor3 = theme.muted,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, row)
            local keyButton = action(row, displayKey(point.keybind),
                "WaypointBind_" .. point.id,
                UDim2.new(0.30, 1, 0, 86), UDim2.new(0.47, -8, 0, 29),
                nil)
            keyButton.TextSize = 10
            keyButton.Activated:Connect(function()
                beginKeyCapture(point, keyButton)
            end)
            local clearButton = action(row, "LIMPAR",
                "WaypointClearBind_" .. point.id,
                UDim2.new(0.77, 2, 0, 86), UDim2.new(0.23, -9, 0, 29),
                function()
                    cancelCapture()
                    local _, messageText = Waypoints:setKeybind(point.id, nil)
                    report(messageText)
                end)
            clearButton.TextSize = 10
        end
    end

    track(UserInputService.InputChanged, movedPointer)
    track(UserInputService.InputEnded, pointerEnded)
    track(UserInputService.InputBegan, handleKeyInput)
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
    cancelCapture()
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
