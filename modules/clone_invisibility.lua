-- Monarca X? / Invisible by local character proxy (EXPERIMENTAL) v0.7.2
-- Inspired by the publicly documented RealCharacter/FakeCharacter pattern.
-- No exploit APIs, no remote code, no forced respawn, no permanent modification.
-- IMPORTANT: The server may reject position updates or correct the character.
-- Other-player visibility is NOT guaranteed without a two-client test.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local CloneInvisible = {}

local active = false
local restoring = false
local realCharacter, fakeCharacter, realRoot, realHumanoid
local fakeHumanoid, savedCameraSubject, savedArchivable
local savedPivot, remotePivot
local heartbeatConnection, characterConnection, diedConnection
local accumulator = 0
local CHECK_INTERVAL = 1 / 25
local OWNER = "samulucas7419"

local function disconnect(connection)
    if connection then pcall(function() connection:Disconnect() end) end
end

local function validRig(character)
    if not character or not character.Parent then return nil end
    local hum = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not hum or not root or not root:IsA("BasePart") or hum.Health <= 0 then
        return nil
    end
    return hum, root
end

local function makeProxy(real)
    local previous = real.Archivable
    real.Archivable = true
    local ok, result = pcall(function() return real:Clone() end)
    real.Archivable = previous
    if not ok or not result then
        return nil, "Não foi possível clonar o avatar local."
    end
    local proxy = result
    proxy.Name = "MonarcaLocalProxy_" .. tostring(player.UserId)

    -- Prevent duplicated gameplay scripts from running. Enable only Animate
    -- after the proxy becomes the local player's current Character.
    for _, child in ipairs(proxy:GetDescendants()) do
        if child:IsA("LocalScript") then child.Disabled = true end
        if child:IsA("Script") then child.Disabled = true end
        if child:IsA("BasePart") then
            child.LocalTransparencyModifier = 0
            if child.Name ~= "HumanoidRootPart" then
                child.Transparency = math.max(child.Transparency, 0.52)
            end
        end
        if child:IsA("Decal") or child:IsA("Texture") then
            child.Transparency = math.max(child.Transparency, 0.52)
        end
    end
    return proxy
end

local function restoreWorldCharacter()
    if restoring then return end
    restoring = true
    active = false
    disconnect(heartbeatConnection)
    disconnect(characterConnection)
    disconnect(diedConnection)
    heartbeatConnection, characterConnection, diedConnection = nil, nil, nil

    local real = realCharacter
    local proxy = fakeCharacter
    local realRootPart = realRoot
    local camera = workspace.CurrentCamera
    local returnPivot = savedPivot
    if proxy and proxy.Parent then
        pcall(function() returnPivot = proxy:GetPivot() end)
    end

    -- Unbind the proxy before it is removed; restore at the proxy's last
    -- position so users do not remain stuck in the remote holding area.
    if real and real.Parent then
        pcall(function()
            if player.Character == proxy then player.Character = real end
        end)
        if realRootPart and realRootPart.Parent and returnPivot then
            pcall(function() real:PivotTo(returnPivot) end)
        end
    end
    if camera then
        pcall(function()
            if real and real.Parent then
                local hum = real:FindFirstChildOfClass("Humanoid")
                camera.CameraSubject = hum or savedCameraSubject
            elseif savedCameraSubject and savedCameraSubject.Parent then
                camera.CameraSubject = savedCameraSubject
            end
        end)
    end
    if proxy then pcall(function() proxy:Destroy() end) end
    if real and real.Parent and savedArchivable ~= nil then
        pcall(function() real.Archivable = savedArchivable end)
    end

    realCharacter, fakeCharacter, realRoot, realHumanoid = nil, nil, nil, nil
    fakeHumanoid, savedCameraSubject, savedArchivable = nil, nil, nil
    savedPivot, remotePivot = nil, nil
    restoring = false
end

function CloneInvisible:enable()
    if player.Name:lower() ~= OWNER then
        return false, "Disponível somente para @" .. OWNER .. "."
    end
    if active then return true, "Modo experimental já ativo." end
    if restoring then return false, "Restauração em andamento." end
    local real = player.Character
    local hum, root = validRig(real)
    if not hum then return false, "Personagem não está pronto." end
    if hum.Sit or hum.SeatPart then
        return false, "Saia do assento antes de ativar."
    end
    local camera = workspace.CurrentCamera
    if not camera then return false, "Câmera indisponível." end
    local proxy, why = makeProxy(real)
    if not proxy then return false, why end
    -- The proxy has not been parented yet, so inspect its parts directly.
    local cloneHum = proxy:FindFirstChildOfClass("Humanoid")
    local cloneRoot = proxy:FindFirstChild("HumanoidRootPart")
    if not cloneHum or not cloneRoot then
        proxy:Destroy()
        return false, "O clone não possui Humanoid e HumanoidRootPart."
    end

    realCharacter, fakeCharacter = real, proxy
    realRoot, realHumanoid, fakeHumanoid = root, hum, cloneHum
    savedArchivable = real.Archivable
    savedPivot = real:GetPivot()
    savedCameraSubject = camera.CameraSubject
    -- Chosen relative to current position, far from the playable area.
    remotePivot = CFrame.new(savedPivot.Position + Vector3.new(2500, 1000, 2500))
        * savedPivot.Rotation

    local ok, err = pcall(function()
        hum:UnequipTools()
        proxy.Parent = workspace
        proxy:PivotTo(savedPivot)
        player.Character = proxy
        camera.CameraSubject = cloneHum
        -- Roblox player scripts generally rebind movement on Character swap.
        -- Only Animate runs from the cloned character, not arbitrary scripts.
        local animate = proxy:FindFirstChild("Animate")
        if animate and animate:IsA("LocalScript") then
            animate.Disabled = false
        end
        local actual = player.Character
        if actual ~= proxy then
            error("O ambiente bloqueou a troca local de Player.Character.")
        end

        active = true
        accumulator = 0
        characterConnection = player.CharacterAdded:Connect(function(character)
            if character ~= proxy and character ~= real then
                task.defer(restoreWorldCharacter)
            end
        end)
        diedConnection = hum.Died:Connect(function()
            task.defer(restoreWorldCharacter)
        end)
        real:PivotTo(remotePivot)

        heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
            if not active then return end
            if not proxy.Parent or not real.Parent then
                task.defer(restoreWorldCharacter)
                return
            end
            if player.Character ~= proxy or not root.Parent
                or hum.Health <= 0 or cloneHum.Health <= 0 then
                task.defer(restoreWorldCharacter)
                return
            end
            accumulator = accumulator + math.min(dt, 0.1)
            if accumulator < CHECK_INTERVAL then return end
            accumulator = accumulator % CHECK_INTERVAL
            -- Client-side repositioning may replicate or be corrected by the
            -- server, depending on network ownership and game protections.
            real:PivotTo(remotePivot)
            -- Mirror basic state, without promising other clients will see it.
            if cloneHum.Jump then
                pcall(function() hum.Jump = true end)
            end
            pcall(function() hum:Move(cloneHum.MoveDirection, false) end)
        end)
    end)
    if not ok then
        restoreWorldCharacter()
        return false, "Falha no proxy: " .. tostring(err)
    end
    return true, "Proxy local ativo. Confirme a visão de outro jogador."
end

function CloneInvisible:disable()
    restoreWorldCharacter()
    return true, "Personagem original restaurado."
end
function CloneInvisible:isActive() return active end
return CloneInvisible
