-- Monarca X? / stable viewpoint and root-aligned proxy (EXPERIMENTAL) v0.7.5
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
local savedRootCFrame
local cameraEpoch = 0
local CAMERA_BIND = "MonarcaInvisibleCameraSwitch_" .. tostring(player.UserId)
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


-- Align the root of a cloned model exactly with the original root.
-- Model:GetPivot() may differ from HumanoidRootPart.CFrame, notably on R15.
local function alignRoot(model, modelRoot, destination)
    if not model or not modelRoot or not destination then return end
    model:PivotTo(destination * modelRoot.CFrame:Inverse() * model:GetPivot())
end

-- Roblox's default camera reads CameraSubject every frame. Temporarily put
-- it in Scriptable mode during the swap, then preserve world-space CFrame
-- and Focus at Camera+1 for a short transition. No forced avatar-facing angle.
local function changeCharacterWithCamera(targetCharacter, targetSubject, operation)
    local camera = workspace.CurrentCamera
    local view = camera and camera.CFrame
    local focus = camera and camera.Focus
    local previousType = camera and camera.CameraType
    cameraEpoch = cameraEpoch + 1
    local epoch = cameraEpoch
    pcall(function() RunService:UnbindFromRenderStep(CAMERA_BIND) end)
    if camera then camera.CameraType = Enum.CameraType.Scriptable end
    local ok, err = pcall(function()
        operation()
        if camera and targetSubject and targetSubject.Parent then
            camera.CameraSubject = targetSubject
        end
    end)
    if camera and view then
        camera.CFrame = view
        camera.Focus = focus
        -- Original mode may be Custom, Follow, etc. Never force a new angle.
        local frames = 0
        local function complete()
            if epoch ~= cameraEpoch then return end
            pcall(function() RunService:UnbindFromRenderStep(CAMERA_BIND) end)
            if workspace.CurrentCamera == camera then
                camera.CameraType = previousType
                camera.CFrame = view
                camera.Focus = focus
            end
        end
        if ok then
            -- The camera module may update its own transform immediately after
            -- Character is replaced. Reapply the pre-toggle view post-camera.
            camera.CameraType = previousType
            RunService:BindToRenderStep(
                CAMERA_BIND, Enum.RenderPriority.Camera.Value + 1,
                function()
                    if epoch ~= cameraEpoch then return end
                    if workspace.CurrentCamera ~= camera then
                        complete()
                        return
                    end
                    camera.CFrame = view
                    camera.Focus = focus
                    frames = frames + 1
                    if frames >= 2 then
                        pcall(function() RunService:UnbindFromRenderStep(CAMERA_BIND) end)
                    end
                end
            )
            -- Safety fallback if the render loop stops before 2 frames.
            task.delay(0.20, function()
                if epoch == cameraEpoch and frames < 2 then complete() end
            end)
        else
            complete()
        end
    end
    return ok, err
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
    local fakeRootPart = proxy and proxy:FindFirstChild("HumanoidRootPart")
    local destination = savedRootCFrame
    if fakeRootPart and fakeRootPart.Parent then
        destination = fakeRootPart.CFrame
    end
    local cameraSubject = real and real:FindFirstChildOfClass("Humanoid")
    if not cameraSubject and savedCameraSubject and savedCameraSubject.Parent then
        cameraSubject = savedCameraSubject
    end

    -- Prevent the still-present proxy from physically pushing the restored
    -- character up/down for one simulation frame before the proxy is destroyed.
    if proxy and proxy.Parent then
        for _, item in ipairs(proxy:GetDescendants()) do
            if item:IsA("BasePart") then
                item.CanCollide = false
                item.CanTouch = false
            end
        end
    end

    local ok = changeCharacterWithCamera(real, cameraSubject, function()
        if real and real.Parent then
            if realRootPart and realRootPart.Parent and destination then
                -- Prevent vertical fling caused by the real body falling while
                -- kept far away. The proxy's ROOT position is the destination.
                realRootPart.AssemblyLinearVelocity = Vector3.zero
                realRootPart.AssemblyAngularVelocity = Vector3.zero
                alignRoot(real, realRootPart, destination)
                realRootPart.AssemblyLinearVelocity = Vector3.zero
                realRootPart.AssemblyAngularVelocity = Vector3.zero
            end
            if player.Character == proxy then player.Character = real end
        end
    end)
    -- Do not destroy the proxy if the character rebind failed: avoid leaving
    -- the player with no locally controlled character.
    if ok and proxy then pcall(function() proxy:Destroy() end) end
    if real and real.Parent and savedArchivable ~= nil then
        pcall(function() real.Archivable = savedArchivable end)
    end
    realCharacter, fakeCharacter, realRoot, realHumanoid = nil, nil, nil, nil
    fakeHumanoid, savedCameraSubject, savedArchivable = nil, nil, nil
    savedPivot, remotePivot, savedRootCFrame = nil, nil, nil
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
    savedRootCFrame = root.CFrame
    savedCameraSubject = camera.CameraSubject
    -- Preserve root orientation, independent of Model pivot offset.
    remotePivot = savedRootCFrame + Vector3.new(2500, 1000, 2500)

    local ok, err = pcall(function()
        hum:UnequipTools()
        proxy.Parent = workspace
        alignRoot(proxy, cloneRoot, savedRootCFrame)
        local changed, reason = changeCharacterWithCamera(
            proxy, cloneHum, function() player.Character = proxy end
        )
        if not changed then error(reason) end
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
        alignRoot(real, root, remotePivot)
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero

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
            alignRoot(real, root, remotePivot)
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
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
