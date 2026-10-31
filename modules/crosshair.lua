-- Overlay local, leve e removivel.
local module = {}
local overlay = nil

function module:enable()
    if overlay and overlay.Parent then return end
    overlay = Instance.new("ScreenGui")
    overlay.Name = "MonarcaCrosshair"
    overlay.ResetOnSpawn = false
    overlay.IgnoreGuiInset = true
    overlay.DisplayOrder = 905

    local root = Instance.new("Frame")
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Position = UDim2.fromScale(0.5, 0.5)
    root.Size = UDim2.fromOffset(28, 28)
    root.BackgroundTransparency = 1
    root.Parent = overlay

    local color = Color3.fromRGB(234, 185, 110)
    local function mark(pos, size)
        local item = Instance.new("Frame")
        item.BorderSizePixel = 0
        item.BackgroundColor3 = color
        item.Position = pos
        item.Size = size
        item.Parent = root
    end
    mark(UDim2.fromOffset(13, 0), UDim2.fromOffset(2, 9))
    mark(UDim2.fromOffset(13, 19), UDim2.fromOffset(2, 9))
    mark(UDim2.fromOffset(0, 13), UDim2.fromOffset(9, 2))
    mark(UDim2.fromOffset(19, 13), UDim2.fromOffset(9, 2))
    mark(UDim2.fromOffset(12, 12), UDim2.fromOffset(4, 4))

    local target = nil
    if type(gethui) == "function" then
        local ok, result = pcall(gethui)
        if ok then target = result end
    end
    if not target then target = game:GetService("CoreGui") end
    if not pcall(function() overlay.Parent = target end) then
        overlay.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    end
end

function module:disable()
    if overlay then overlay:Destroy(); overlay = nil end
end

return module
