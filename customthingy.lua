local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local backpack = player:WaitForChild("Backpack")
local camera = workspace.CurrentCamera
local mouse = player:GetMouse()

local SUCK_RANGE = 200
local SUCK_TIME = 0.55
local CHARGE_TIME = 1.25

local objects = game:GetObjects("rbxassetid://75968537204104")
local Tool = objects[1]

if not Tool or not Tool:IsA("Tool") then
	return
end

Tool.RequiresHandle = true
Tool.TextureId = "rbxassetid://10867606165"

local handle = Tool:FindFirstChild("Handle") or Tool:FindFirstChildWhichIsA("BasePart")

if not handle then
	handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 1)
	handle.Parent = Tool
end

handle.CanCollide = false
handle.Massless = true

local muzzle = handle:FindFirstChild("Muzzle")

if not muzzle then
	muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Parent = handle
end

muzzle.Position = Vector3.new(0, 0, -5)

Tool.Parent = backpack

local storedModel
local viewportModel
local animationTrack

local equipped = false
local sucking = false
local charging = false
local chargeStarted = 0
local chargePower = 0


local gui = Instance.new("ScreenGui")
gui.Name = "SuckViewer"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")


local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(180, 180)
frame.Position = UDim2.new(1, -200, 1, -200)
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
frame.BackgroundTransparency = 0.1
frame.BorderSizePixel = 0
frame.Parent = gui

Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(100, 105, 120)
stroke.Transparency = 0.4
stroke.Parent = frame


local viewport = Instance.new("ViewportFrame")
viewport.Size = UDim2.new(1, -12, 1, -12)
viewport.Position = UDim2.fromOffset(6, 6)
viewport.BackgroundTransparency = 1
viewport.Ambient = Color3.fromRGB(150, 150, 160)
viewport.LightColor = Color3.fromRGB(255, 255, 255)
viewport.Parent = frame

Instance.new("UICorner", viewport).CornerRadius = UDim.new(0, 9)

local world = Instance.new("WorldModel")
world.Parent = viewport

local viewportCamera = Instance.new("Camera")
viewportCamera.FieldOfView = 38
viewportCamera.Parent = viewport
viewport.CurrentCamera = viewportCamera


local emptyText = Instance.new("TextLabel")
emptyText.Size = UDim2.fromScale(1, 1)
emptyText.BackgroundTransparency = 1
emptyText.Text = "EMPTY"
emptyText.Font = Enum.Font.GothamMedium
emptyText.TextSize = 13
emptyText.TextColor3 = Color3.fromRGB(100, 100, 110)
emptyText.Parent = frame


local chargeHolder = Instance.new("Frame")
chargeHolder.AnchorPoint = Vector2.new(0.5, 1)
chargeHolder.Position = UDim2.new(0.5, 0, 1, -55)
chargeHolder.Size = UDim2.fromOffset(300, 16)
chargeHolder.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
chargeHolder.BackgroundTransparency = 0.1
chargeHolder.BorderSizePixel = 0
chargeHolder.Visible = false
chargeHolder.Parent = gui

Instance.new("UICorner", chargeHolder).CornerRadius = UDim.new(1, 0)

local chargeStroke = Instance.new("UIStroke")
chargeStroke.Color = Color3.fromRGB(80, 80, 85)
chargeStroke.Transparency = 0.4
chargeStroke.Parent = chargeHolder


local chargeBar = Instance.new("Frame")
chargeBar.Size = UDim2.fromScale(0, 1)
chargeBar.BackgroundColor3 = Color3.fromRGB(80, 255, 100)
chargeBar.BorderSizePixel = 0
chargeBar.Parent = chargeHolder

Instance.new("UICorner", chargeBar).CornerRadius = UDim.new(1, 0)


local chargeText = Instance.new("TextLabel")
chargeText.AnchorPoint = Vector2.new(0.5, 1)
chargeText.Position = UDim2.new(0.5, 0, 0, -7)
chargeText.Size = UDim2.fromOffset(100, 20)
chargeText.BackgroundTransparency = 1
chargeText.Text = ""
chargeText.Font = Enum.Font.GothamBold
chargeText.TextSize = 12
chargeText.TextColor3 = Color3.new(1, 1, 1)
chargeText.Parent = chargeHolder


local highlight = Instance.new("Highlight")
highlight.FillColor = Color3.fromRGB(80, 165, 255)
highlight.FillTransparency = 0.88
highlight.OutlineColor = Color3.fromRGB(200, 230, 255)
highlight.OutlineTransparency = 0.05
highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
highlight.Enabled = false
highlight.Parent = workspace


local function getMuzzleCFrame()
	if muzzle and muzzle.Parent then
		return muzzle.WorldCFrame
	end

	return handle.CFrame
end


local function getModel(target)
	if not target then
		return
	end

	if player.Character and target:IsDescendantOf(player.Character) then
		return
	end

	local model = target:FindFirstAncestorOfClass("Model")

	if model == Tool then
		return
	end

	return model
end


local function getPart(model)
	if model.PrimaryPart then
		return model.PrimaryPart
	end

	local part = model:FindFirstChildWhichIsA("BasePart", true)

	if part then
		model.PrimaryPart = part
	end

	return part
end


local function clearViewport()
	for _, obj in ipairs(world:GetChildren()) do
		obj:Destroy()
	end

	viewportModel = nil
	emptyText.Visible = true
end


local function showViewport(model)
	clearViewport()

	if not model then
		return
	end

	local clone = model:Clone()

	for _, obj in ipairs(clone:GetDescendants()) do
		if obj:IsA("Script")
			or obj:IsA("LocalScript")
			or obj:IsA("ModuleScript") then

			obj:Destroy()

		elseif obj:IsA("BasePart") then
			obj.Anchored = true
			obj.CanCollide = false
		end
	end

	clone.Parent = world
	clone:PivotTo(CFrame.new())

	local box, size = clone:GetBoundingBox()
	local largest = math.max(size.X, size.Y, size.Z)

	viewportCamera.CFrame = CFrame.new(
		box.Position + Vector3.new(
			largest * 0.5,
			largest * 0.25,
			largest * 1.8
		),
		box.Position
	)

	viewportModel = clone
	emptyText.Visible = false
end


local function saveModel(model)
	if storedModel then
		storedModel:Destroy()
	end

	storedModel = model:Clone()

	for _, obj in ipairs(storedModel:GetDescendants()) do
		if obj:IsA("Script")
			or obj:IsA("LocalScript")
			or obj:IsA("ModuleScript") then

			obj:Destroy()

		elseif obj:IsA("BasePart") then
			obj.Anchored = true
			obj.CanCollide = false
		end
	end

	storedModel.Parent = nil

	showViewport(storedModel)

	stroke.Color = Color3.fromRGB(100, 190, 255)
	stroke.Thickness = 2

	TweenService:Create(
		stroke,
		TweenInfo.new(0.5),
		{
			Color = Color3.fromRGB(100, 105, 120),
			Thickness = 1
		}
	):Play()
end


local function suck(model)
	if sucking or not model or not model:IsDescendantOf(workspace) then
		return
	end

	local primary = getPart(model)

	if not primary then
		return
	end

	if (camera.CFrame.Position - primary.Position).Magnitude > SUCK_RANGE then
		return
	end

	sucking = true
	highlight.Enabled = false

	saveModel(model)

	local oldFov = camera.FieldOfView

	TweenService:Create(
		camera,
		TweenInfo.new(0.1),
		{FieldOfView = oldFov + 7}
	):Play()

	task.delay(0.1, function()
		TweenService:Create(
			camera,
			TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{FieldOfView = oldFov}
		):Play()
	end)

	local targetAttachment = Instance.new("Attachment")
	targetAttachment.Parent = primary

	local beam = Instance.new("Beam")
	beam.Attachment0 = muzzle
	beam.Attachment1 = targetAttachment
	beam.Width0 = 0.15
	beam.Width1 = 1.4
	beam.CurveSize0 = 2
	beam.CurveSize1 = -2
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Color = ColorSequence.new(
		Color3.fromRGB(220, 245, 255),
		Color3.fromRGB(70, 145, 255)
	)

	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 0.5)
	})

	beam.Parent = handle


	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(100, 180, 255)
	light.Brightness = 4
	light.Range = 12
	light.Parent = handle

	TweenService:Create(
		light,
		TweenInfo.new(SUCK_TIME),
		{Brightness = 0}
	):Play()


	local particles = Instance.new("ParticleEmitter")
	particles.Rate = 80
	particles.Lifetime = NumberRange.new(0.2, 0.4)
	particles.Speed = NumberRange.new(1, 3)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.LightEmission = 1
	particles.Color = ColorSequence.new(
		Color3.fromRGB(100, 190, 255),
		Color3.new(1, 1, 1)
	)
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.22),
		NumberSequenceKeypoint.new(1, 0)
	})
	particles.Parent = muzzle


	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://183763515"
	sound.Volume = 1.25
	sound.PlaybackSpeed = 0.9
	sound.Parent = handle
	sound:Play()


	local muzzleCFrame = getMuzzleCFrame()

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false

			task.delay(math.random() * 0.08, function()
				if not part.Parent then
					return
				end

				local spin = CFrame.Angles(
					math.rad(math.random(-120, 120)),
					math.rad(math.random(-120, 120)),
					math.rad(math.random(-120, 120))
				)

				TweenService:Create(
					part,
					TweenInfo.new(
						SUCK_TIME,
						Enum.EasingStyle.Quint,
						Enum.EasingDirection.In
					),
					{
						CFrame = muzzleCFrame * spin,
						Size = Vector3.new(0.03, 0.03, 0.03),
						Transparency = 1
					}
				):Play()
			end)
		end
	end


	task.delay(SUCK_TIME + 0.08, function()
		if model and model.Parent then
			model:Destroy()
		end

		if beam then
			beam:Destroy()
		end

		if targetAttachment then
			targetAttachment:Destroy()
		end

		if particles then
			particles.Enabled = false
			Debris:AddItem(particles, 1)
		end

		Debris:AddItem(light, 0.2)
		Debris:AddItem(sound, 1)

		sucking = false
	end)
end


local function throw(power)
	if not storedModel then
		return
	end

	local projectile = storedModel:Clone()

	for _, obj in ipairs(projectile:GetDescendants()) do
		if obj:IsA("Script")
			or obj:IsA("LocalScript")
			or obj:IsA("ModuleScript") then

			obj:Destroy()
		end
	end

	local box = projectile:GetBoundingBox()

	local root = Instance.new("Part")
	root.Name = "ThrowRoot"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.CanCollide = false
	root.Anchored = true
	root.CFrame = box
	root.Parent = projectile

	for _, part in ipairs(projectile:GetDescendants()) do
		if part:IsA("BasePart") and part ~= root then
			part.Anchored = false
			part.CanCollide = true
			part.Massless = true
			part.Transparency = math.min(part.Transparency, 0.95)

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = root
		end
	end

	projectile.PrimaryPart = root
	projectile.Parent = workspace

	local muzzleCFrame = getMuzzleCFrame()

	projectile:PivotTo(
		CFrame.new(
			muzzleCFrame.Position + camera.CFrame.LookVector * 3
		)
	)

	root.Anchored = false
	root.Massless = false

	local aimPosition = mouse.Hit.Position
	local direction = aimPosition - root.Position

	if direction.Magnitude < 1 then
		direction = camera.CFrame.LookVector
	else
		direction = direction.Unit
	end

	local speed = 55 + power * 185

	root.AssemblyLinearVelocity = direction * speed
	root.AssemblyAngularVelocity = Vector3.new(
		4 + power * 8,
		7 + power * 15,
		3 + power * 7
	)


	local outline = Instance.new("Highlight")
	outline.FillTransparency = 1
	outline.OutlineColor = Color3.new(1, 1, 1)
	outline.OutlineTransparency = 0.2
	outline.Parent = projectile

	task.delay(0.15, function()
		if outline then
			TweenService:Create(
				outline,
				TweenInfo.new(0.2),
				{OutlineTransparency = 1}
			):Play()

			Debris:AddItem(outline, 0.2)
		end
	end)


	local flash = Instance.new("PointLight")
	flash.Color =
		Color3.fromRGB(80, 255, 100):Lerp(
			Color3.fromRGB(255, 70, 60),
			power
		)

	flash.Brightness = 5 + power * 5
	flash.Range = 14
	flash.Parent = handle

	TweenService:Create(
		flash,
		TweenInfo.new(0.12),
		{Brightness = 0}
	):Play()

	Debris:AddItem(flash, 0.15)


	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://12222030"
	sound.Volume = 0.8 + power * 0.8
	sound.PlaybackSpeed = 1.15 - power * 0.25
	sound.Parent = handle
	sound:Play()

	Debris:AddItem(sound, 2)


	local oldFov = camera.FieldOfView

	TweenService:Create(
		camera,
		TweenInfo.new(0.06),
		{FieldOfView = oldFov - (2 + power * 6)}
	):Play()

	task.delay(0.06, function()
		TweenService:Create(
			camera,
			TweenInfo.new(
				0.3,
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.Out
			),
			{FieldOfView = oldFov}
		):Play()
	end)

	Debris:AddItem(projectile, 25)
end


local function startCharge()
	if charging or not storedModel then
		return
	end

	charging = true
	chargeStarted = os.clock()
	chargePower = 0

	chargeHolder.Visible = true
	chargeHolder.Size = UDim2.fromOffset(260, 10)

	TweenService:Create(
		chargeHolder,
		TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Size = UDim2.fromOffset(300, 16)}
	):Play()
end


local function releaseCharge()
	if not charging then
		return
	end

	charging = false

	throw(chargePower)

	chargeBar.Size = UDim2.fromScale(chargePower, 1)

	TweenService:Create(
		chargeHolder,
		TweenInfo.new(0.12),
		{Size = UDim2.fromOffset(315, 18)}
	):Play()

	task.delay(0.06, function()
		TweenService:Create(
			chargeHolder,
			TweenInfo.new(0.15),
			{Size = UDim2.fromOffset(270, 8)}
		):Play()
	end)

	task.delay(0.16, function()
		if not charging then
			chargeHolder.Visible = false
		end
	end)
end


UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not equipped then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		local model = getModel(mouse.Target)

		if model then
			suck(model)
		end

	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		startCharge()
	end
end)


UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		releaseCharge()
	end
end)


Tool.Equipped:Connect(function()
	equipped = true
	gui.Enabled = true

	frame.Position = UDim2.new(1, 20, 1, -200)

	TweenService:Create(
		frame,
		TweenInfo.new(
			0.3,
			Enum.EasingStyle.Quint,
			Enum.EasingDirection.Out
		),
		{Position = UDim2.new(1, -200, 1, -200)}
	):Play()

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator")

		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end

		if not animationTrack then
			local animation = Instance.new("Animation")
			animation.AnimationId = "rbxassetid://10526835827"

			animationTrack = animator:LoadAnimation(animation)
			animationTrack.Looped = true
		end

		animationTrack:Play()
	end
end)


Tool.Unequipped:Connect(function()
	equipped = false
	charging = false

	highlight.Enabled = false
	chargeHolder.Visible = false

	if animationTrack then
		animationTrack:Stop()
	end

	gui.Enabled = false
end)


RunService.RenderStepped:Connect(function(dt)
	if not equipped then
		return
	end

	if viewportModel then
		viewportModel:PivotTo(
			viewportModel:GetPivot()
				* CFrame.Angles(0, dt * 0.65, 0)
		)
	end


	if charging then
		local elapsed = (os.clock() - chargeStarted) / CHARGE_TIME
		local cycle = elapsed % 2

		if cycle <= 1 then
			chargePower = cycle
		else
			chargePower = 2 - cycle
		end

		chargeBar.Size = UDim2.fromScale(chargePower, 1)

		local green = Color3.fromRGB(70, 255, 90)
		local yellow = Color3.fromRGB(255, 220, 60)
		local red = Color3.fromRGB(255, 65, 55)

		if chargePower < 0.5 then
			chargeBar.BackgroundColor3 =
				green:Lerp(yellow, chargePower * 2)
		else
			chargeBar.BackgroundColor3 =
				yellow:Lerp(red, (chargePower - 0.5) * 2)
		end

		chargeText.Text = math.floor(chargePower * 100) .. "%"

		if chargePower > 0.9 then
			chargeStroke.Color = red
		elseif chargePower > 0.5 then
			chargeStroke.Color = yellow
		else
			chargeStroke.Color = green
		end
	end


	local model = getModel(mouse.Target)

	if model then
		local part = getPart(model)

		if part
			and (camera.CFrame.Position - part.Position).Magnitude <= SUCK_RANGE then

			highlight.Adornee = model
			highlight.Enabled = true
		else
			highlight.Enabled = false
		end
	else
		highlight.Enabled = false
	end
end)


player.CharacterAdded:Connect(function()
	animationTrack = nil
	charging = false
	equipped = false

	highlight.Enabled = false
	chargeHolder.Visible = false
	gui.Enabled = false
end)


clearViewport()
