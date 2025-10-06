local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local backpack = player:WaitForChild("Backpack")
local camera = workspace.CurrentCamera

local assetId = "rbxassetid://75968537204104"
local objects = game:GetObjects(assetId)
local Tool = objects[1]
if not Tool or not Tool:IsA("Tool") then
    warn("Asset does not contain a Tool.")
    return
end

Tool.RequiresHandle = true
local handle = Tool:FindFirstChild("Handle") or Tool:FindFirstChildWhichIsA("BasePart")
if not handle then
    handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(1,1,1)
    handle.Parent = Tool
    handle.CanCollide = false
    handle.Transparency = 0
else
    handle.Transparency = 0
    handle.CanCollide = false
end

local mu = handle:FindFirstChildWhichIsA("Attachment")
if not mu or mu.Name ~= "Muzzle" then
    mu = Instance.new("Attachment")
    mu.Name = "Muzzle"
    mu.Parent = handle
end
mu.Position = Vector3.new(0, 0, -5)

Tool.TextureId = "rbxassetid://10867606165"

Tool.Parent = backpack

local mouse = player:GetMouse()

local SUCK_RANGE = 200
local SUCK_TIME = 0.7
local SHRINK_TO = Vector3.new(0.05, 0.05, 0.05)
local SHOOT_SPEED = 60
local ENABLE_SPIN = true
local SPIN_ANGULAR_VEL = Vector3.new(0, 10, 0)

local lastCapturedTemplate = nil
local lastCapturedPrimary = nil

local animationId = "rbxassetid://10526835827"
local animationTrack = nil

local function makeViewportUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "SuckViewer"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = player:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 200, 0, 200)
    frame.Position = UDim2.new(1, -220, 1, -220)
    frame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    frame.BackgroundTransparency = 0.35
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local viewport = Instance.new("ViewportFrame")
    viewport.Size = UDim2.new(1, 0, 1, 0)
    viewport.BackgroundTransparency = 1
    viewport.Name = "Viewport"
    viewport.Parent = frame

    local cam = Instance.new("Camera")
    cam.Parent = viewport
    viewport.CurrentCamera = cam

    return gui, viewport, cam
end

local gui, viewport, vpCam = makeViewportUI()

local function clearViewport()
    viewport:ClearAllChildren()
    vpCam = Instance.new("Camera")
    vpCam.Parent = viewport
    viewport.CurrentCamera = vpCam
end

local function showModelInViewport(model)
    if not model then
        clearViewport()
        return
    end
    viewport:ClearAllChildren()
    vpCam = Instance.new("Camera")
    vpCam.Parent = viewport
    viewport.CurrentCamera = vpCam

    local clone = model:Clone()
    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored = true
            d.CanCollide = true
            d.Transparency = d.Transparency or 0
        end
    end
    clone.Parent = viewport

    local extents = clone:GetExtentsSize()
    local primary = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart")
    local center = primary and primary.Position or clone:GetModelCFrame().Position
    local size = math.max(extents.X, extents.Y, extents.Z)
    local dist = math.max(1, size * 1.6)
    vpCam.CFrame = CFrame.new(center + Vector3.new(0, 0, dist), center)
end

local function getMuzzleCFrame()
    local handle = Tool:FindFirstChild("Handle") or Tool:FindFirstChildWhichIsA("BasePart")
    if not handle then return camera.CFrame end
    local muzzle = handle:FindFirstChild("Muzzle")
    if muzzle and muzzle:IsA("Attachment") then
        return handle.CFrame * muzzle.CFrame
    end
    local muzzlePart = handle:FindFirstChild("MuzzlePart")
    if muzzlePart and muzzlePart:IsA("BasePart") then
        return muzzlePart.CFrame
    end
    local attach = handle:FindFirstChildWhichIsA("Attachment")
    if attach then
        return handle.CFrame * attach.CFrame
    end
    return handle.CFrame
end

local function findModelFromTarget(target)
    if not target then return nil end
    local char = player.Character
    if char and target:IsDescendantOf(char) then return nil end
    return target:FindFirstAncestorOfClass("Model")
end

local function ensurePrimaryPart(model)
    if model.PrimaryPart then return model.PrimaryPart end
    for _, v in ipairs(model:GetDescendants()) do
        if v:IsA("BasePart") then
            model.PrimaryPart = v
            return v
        end
    end
end

local function storeCapturedModelForShooting(model)
    if lastCapturedTemplate and lastCapturedTemplate.Parent then
        lastCapturedTemplate:Destroy()
    end

    local clone = model:Clone()

    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") or d:IsA("Constraint") then
            d:Destroy()
        end
    end

    local root = Instance.new("Part")
    root.Name = "SuckRoot"
    root.Size = Vector3.new(1,1,1)
    root.Transparency = 1
    root.CanCollide = false
    root.Anchored = true
    root.Massless = true
    root.Parent = clone

    local anyPos = nil
    for _, part in ipairs(clone:GetDescendants()) do
        if part:IsA("BasePart") and part ~= root then
            part.Anchored = true
            part.CanCollide = true
            anyPos = anyPos or part.Position
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = part
            weld.Part1 = root
            weld.Parent = part
        end
    end

    if anyPos then
        root.CFrame = CFrame.new(anyPos)
    end
    clone.PrimaryPart = root

    clone.Parent = workspace
    lastCapturedTemplate = clone
    lastCapturedPrimary = root

    showModelInViewport(clone)
end

local function suckModel(model)
    if not model or not model:IsDescendantOf(workspace) then return end
    local char = player.Character
    if char and model:IsDescendantOf(char) then return end

    local primary = ensurePrimaryPart(model)
    if not primary then return end

    local dist = (camera.CFrame.Position - primary.Position).Magnitude
    if dist > SUCK_RANGE then return end

    local muzzleCFrame = getMuzzleCFrame()
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.Anchored = true
            local tween = TweenService:Create(part, TweenInfo.new(SUCK_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                CFrame = muzzleCFrame,
                Size = SHRINK_TO,
                Transparency = 1
            })
            tween:Play()
        end
    end

    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://183763515"
    s.Volume = 1.2
    s.Parent = workspace
    s:Play()
    Debris:AddItem(s, 2)

    storeCapturedModelForShooting(model)

    task.delay(SUCK_TIME + 0.03, function()
        if model and model.Parent then
            model:Destroy()
        end
    end)
end

local function createProjectileFromStored()
    if not lastCapturedTemplate or not lastCapturedTemplate.Parent then return nil end
    local projectile = lastCapturedTemplate:Clone()

    local pRoot = projectile:FindFirstChild("SuckRoot") or projectile.PrimaryPart
    if not pRoot then
        pRoot = ensurePrimaryPart(projectile)
    end
    if not pRoot then projectile:Destroy(); return nil end

    local parts = {}
    for _, part in ipairs(projectile:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = false
            part.CanCollide = true
            part.Massless = true
            table.insert(parts, part)
        end
    end

    local muzzle = getMuzzleCFrame()
    projectile:SetPrimaryPartCFrame(muzzle)
    projectile.Parent = workspace

    local dir = camera.CFrame.LookVector.Unit
    local velocity = dir * SHOOT_SPEED
    pRoot.AssemblyLinearVelocity = velocity

    if ENABLE_SPIN then
        local conn
        conn = RunService.Heartbeat:Connect(function(dt)
            if not projectile or not projectile.Parent then
                if conn and conn.Connected then conn:Disconnect() end
                return
            end
            if projectile.PrimaryPart then
                projectile:SetPrimaryPartCFrame(projectile.PrimaryPart.CFrame * CFrame.Angles(
                    SPIN_ANGULAR_VEL.X * dt, SPIN_ANGULAR_VEL.Y * dt, SPIN_ANGULAR_VEL.Z * dt
                ))
            end
        end)
    end

    task.delay(1, function()
        for _, part in ipairs(parts) do
            if part and part.Parent then
                part.CanCollide = true
            end
        end
    end)

    return projectile
end

local function shootStoredModel()
    if not lastCapturedTemplate then return end
    local projectile = createProjectileFromStored()
    if not projectile then return end

    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://12222030"
    s.Volume = 1.2
    s.Parent = workspace
    s:Play()
    Debris:AddItem(s, 2)
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        local target = mouse.Target
        if target then
            local model = findModelFromTarget(target)
            if model then
                suckModel(model)
            end
        end
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
        shootStoredModel()
    end
end)

local function cleanupLocalStore()
    if lastCapturedTemplate and lastCapturedTemplate.Parent then
        lastCapturedTemplate:Destroy()
    end
    lastCapturedTemplate = nil
    lastCapturedPrimary = nil
    clearViewport()
end

Tool.Unequipped:Connect(cleanupLocalStore)
player.CharacterAdded:Connect(cleanupLocalStore)

local function playIdleAnimation()
    if not animationTrack then
        local anim = Instance.new("Animation")
        anim.AnimationId = animationId
        local humanoid = (Tool.Parent and Tool.Parent:FindFirstChildOfClass("Humanoid")) or (player.Character and player.Character:FindFirstChildOfClass("Humanoid"))
        if humanoid then
            animationTrack = humanoid:LoadAnimation(anim)
        end
    end
    if animationTrack and not animationTrack.IsPlaying then
        animationTrack:Play()
        animationTrack.Looped = true
    end
end

Tool.Equipped:Connect(playIdleAnimation)
clearViewport()