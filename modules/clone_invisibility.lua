-- Monarca X? / stable physics, camera and clone restoration (EXPERIMENTAL) v0.7.9
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
local CHECK_INTERVAL = 1 / 15
local MAX_PARK_DRIFT = 4
local OWNER = "samulucas7419"
local parkedParts, parkAttachment, parkGravityForce, originallyEquipped

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
            local bound, bindError = pcall(function()
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
                    if frames >= 5 then
                        pcall(function() RunService:UnbindFromRenderStep(CAMERA_BIND) end)
                    end
                    end
                )
            end)
            if not bound then
                warn("[Monarca] Camera bind unavailable: " .. tostring(bindError))
            end
            -- Safety fallback if the render loop stops before five frames.
            task.delay(0.45, function()
                if epoch == cameraEpoch and frames < 5 then complete() end
            end)
        else
            complete()
        end
    end
    return ok, err
end

-- Keep the distant real body free of collisions and gravity disturbances.
-- This avoids pushing the proxy and jumping when switching Character back.
local function parkBody(realModel, root)
    parkedParts = {}
    for _, item in ipairs(realModel:GetDescendants()) do
        if item:IsA("BasePart") then
            parkedParts[item] = {item.CanCollide, item.CanTouch}
            pcall(function()
                item.CanCollide = false
                item.CanTouch = false
            end)
        end
    end
    pcall(function()
        parkAttachment = Instance.new("Attachment")
        parkAttachment.Name = "MonarcaParkPoint"
        parkAttachment.Parent = root
        parkGravityForce = Instance.new("VectorForce")
        parkGravityForce.Name = "MonarcaParkGravity"
        parkGravityForce.Attachment0 = parkAttachment
        parkGravityForce.RelativeTo = Enum.ActuatorRelativeTo.World
        parkGravityForce.ApplyAtCenterOfMass = true
        parkGravityForce.Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity, 0)
        parkGravityForce.Parent = root
    end)
end

local function restoreBody()
    if parkGravityForce then pcall(function() parkGravityForce:Destroy() end) end
    if parkAttachment then pcall(function() parkAttachment:Destroy() end) end
    parkGravityForce, parkAttachment = nil, nil
    if parkedParts then
        for item, values in pairs(parkedParts) do
            if item and item.Parent then
                pcall(function()
                    item.CanCollide = values[1]
                    item.CanTouch = values[2]
                end)
            end
        end
    end
    parkedParts = nil
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
    if restoring then return false, "Restauração já em andamento." end
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
    local currentChar = player.Character
    local currentHum = currentChar and currentChar:FindFirstChildOfClass("Humanoid")
    local realIsAlive = real and real.Parent and realHumanoid and realHumanoid.Health > 0
    local cameraSubject = realIsAlive and realHumanoid or
        (currentChar ~= proxy and currentHum) or nil
    if not cameraSubject and savedCameraSubject and savedCameraSubject.Parent then
        cameraSubject = savedCameraSubject
    end

    -- Prevent the still-present proxy from physically pushing the restored
    -- character up/down for one simulation frame before the proxy is destroyed.
    if proxy and proxy.Parent then
        for _, item in ipairs(proxy:GetDescendants()) do
            if item:IsA("BasePart") then
                pcall(function()
                    item.CanCollide = false
                    item.CanTouch = false
                end)
            end
        end
    end

    local ok = changeCharacterWithCamera(real, cameraSubject, function()
        if realIsAlive and player.Character == proxy then
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
    -- If the callback failed after the world-space reposition, make one
    -- direct attempt to restore Character. Keep the proxy if still controlled.
    if not ok and realIsAlive and player.Character == proxy then
        pcall(function() player.Character = real end)
    end
    local isProxyControlled = player.Character == proxy
    if not isProxyControlled and proxy then
        pcall(function() proxy:Destroy() end)
    end
    -- Restore original collisions only after the proxy is removed, to prevent
    -- the two models from physically pushing each other in the same location.
    if isProxyControlled then
        -- Avoid abandoning the player in a disabled model after a failed swap.
        restoring = false
        return false, "Não foi possível restaurar o avatar; tente desativar novamente."
    end
    restoreBody()
    if realHumanoid and realHumanoid.Parent and player.Character == real
        and originallyEquipped and originallyEquipped.Parent
        and originallyEquipped.Parent:IsA("Backpack") then
        pcall(function() realHumanoid:EquipTool(originallyEquipped) end)
    end
    if real and real.Parent and savedArchivable ~= nil then
        pcall(function() real.Archivable = savedArchivable end)
    end
    realCharacter, fakeCharacter, realRoot, realHumanoid = nil, nil, nil, nil
    fakeHumanoid, savedCameraSubject, savedArchivable = nil, nil, nil
    savedPivot, remotePivot, savedRootCFrame = nil, nil, nil
    originallyEquipped = nil
    restoring = false
    return true, "Personagem restaurado."
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
    originallyEquipped = real:FindFirstChildOfClass("Tool")
    local initialVelocity = root.AssemblyLinearVelocity
    -- Preserve root orientation, independent of Model pivot offset.
    remotePivot = savedRootCFrame + Vector3.new(2500, 1000, 2500)

    local ok, err = pcall(function()
        hum:UnequipTools()
        proxy.Parent = workspace
        alignRoot(proxy, cloneRoot, savedRootCFrame)
        -- The avatar clone inherits current motion instead of dropping from a
        -- standing pose with zero momentum at the instant of the swap.
        cloneRoot.AssemblyLinearVelocity = initialVelocity
        cloneRoot.AssemblyAngularVelocity = Vector3.zero
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
        parkBody(real, root)
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
            -- Do not drive Jump/Move on the remote body: those movement
            -- impulses made the avatar twitch and turn at every transition.
            -- Reposition only if server/physics correction causes large drift.
            if (root.Position - remotePivot.Position).Magnitude > MAX_PARK_DRIFT then
                pcall(function() alignRoot(real, root, remotePivot) end)
            end
            if parkGravityForce and parkGravityForce.Parent then
                pcall(function()
                    parkGravityForce.Force = Vector3.new(
                        0, root.AssemblyMass * workspace.Gravity, 0)
                end)
            end
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
    end)
    if not ok then
        restoreWorldCharacter()
        return false, "Falha no proxy: " .. tostring(err)
    end
    return true, "Proxy local ativo. Confirme a visão de outro jogador."
end

function CloneInvisible:disable()
    return restoreWorldCharacter()
end
function CloneInvisible:isActive() return active end
return CloneInvisible
