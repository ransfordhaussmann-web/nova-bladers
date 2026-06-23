local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("HubConfig"))

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Color = props.Color or Color3.fromRGB(45, 48, 58)
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Name = props.Name or "Part"
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.Transparency then
		part.Transparency = props.Transparency
	end
	part.Parent = props.Parent
	return part
end

local function makeZoneMarker(parent, zone)
	local model = Instance.new("Model")
	model.Name = zone.id
	model.Parent = parent

	local platform = makePart({
		Name = "Platform",
		Parent = model,
		Size = zone.size,
		CFrame = CFrame.new(zone.position),
		Color = zone.color,
		Material = Enum.Material.Neon,
	})
	platform.Transparency = 0.35

	local frame = makePart({
		Name = "Frame",
		Parent = model,
		Size = Vector3.new(zone.size.X + 1, 1, zone.size.Z + 1),
		CFrame = CFrame.new(zone.position - Vector3.new(0, zone.size.Y / 2 + 0.5, 0)),
		Color = Color3.fromRGB(30, 32, 40),
		Material = Enum.Material.Metal,
	})

	local sign = makePart({
		Name = "Sign",
		Parent = model,
		Size = Vector3.new(zone.size.X * 0.8, 4, 0.4),
		CFrame = CFrame.new(zone.position + Vector3.new(0, zone.size.Y / 2 + 2.5, -zone.size.Z / 2 - 0.5)),
		Color = Color3.fromRGB(25, 27, 35),
		Material = Enum.Material.SmoothPlastic,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, 0, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = zone.color
	label.TextScaled = true
	label.Text = zone.label
	label.Parent = billboard

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zone.label
	prompt.ObjectText = "Nova Hub"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = math.max(zone.size.X, zone.size.Z) * 0.6 + 4
	prompt.Parent = platform

	local hint = Instance.new("StringValue")
	hint.Name = "HintText"
	hint.Value = zone.hint
	hint.Parent = model

	model.PrimaryPart = platform
	return model
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		return existing
	end

	local hub = Instance.new("Model")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local floorCenter = HubConfig.FLOOR_CENTER
	local floorSize = HubConfig.FLOOR_SIZE

	makePart({
		Name = "Floor",
		Parent = hub,
		Size = floorSize,
		CFrame = CFrame.new(floorCenter - Vector3.new(0, floorSize.Y / 2, 0)),
		Color = Color3.fromRGB(38, 42, 52),
		Material = Enum.Material.Slate,
	})

	makePart({
		Name = "CenterPad",
		Parent = hub,
		Size = Vector3.new(24, 0.6, 24),
		CFrame = CFrame.new(floorCenter + Vector3.new(0, 0.3, 0)),
		Color = Color3.fromRGB(55, 60, 75),
		Material = Enum.Material.Marble,
	})

	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS
	local wallY = wallH / 2

	local walls = {
		{ Vector3.new(0, wallY, halfZ + wallT / 2), Vector3.new(floorSize.X + wallT * 2, wallH, wallT) },
		{ Vector3.new(0, wallY, -halfZ - wallT / 2), Vector3.new(floorSize.X + wallT * 2, wallH, wallT) },
		{ Vector3.new(halfX + wallT / 2, wallY, 0), Vector3.new(wallT, wallH, floorSize.Z) },
		{ Vector3.new(-halfX - wallT / 2, wallY, 0), Vector3.new(wallT, wallH, floorSize.Z) },
	}

	for i, wall in walls do
		makePart({
			Name = "Wall" .. i,
			Parent = hub,
			Size = wall[2],
			CFrame = CFrame.new(wall[1]),
			Color = Color3.fromRGB(28, 30, 38),
			Material = Enum.Material.Concrete,
		})
	end

	local spawn = makePart({
		Name = "HubSpawn",
		Parent = hub,
		Size = HubConfig.SPAWN_SIZE,
		CFrame = CFrame.new(HubConfig.SPAWN_POSITION),
		Color = Color3.fromRGB(70, 130, 220),
		Material = Enum.Material.Neon,
		Transparency = 0.5,
		CanCollide = false,
	})

	local spawnLight = Instance.new("PointLight")
	spawnLight.Color = Color3.fromRGB(100, 160, 255)
	spawnLight.Brightness = 2
	spawnLight.Range = 16
	spawnLight.Parent = spawn

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		makeZoneMarker(zonesFolder, zone)
	end

	local leaderboardPart = makePart({
		Name = "LeaderboardBoard",
		Parent = hub.Zones.HallOfFame,
		Size = Vector3.new(8, 6, 0.4),
		CFrame = CFrame.new(HubConfig.ZONES.HallOfFame.position + Vector3.new(0, 2, -HubConfig.ZONES.HallOfFame.size.Z / 2 - 1)),
		Color = Color3.fromRGB(20, 22, 30),
		Material = Enum.Material.SmoothPlastic,
	})

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "LeaderboardGui"
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 40
	surfaceGui.Parent = leaderboardPart

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 48)
	title.BackgroundColor3 = Color3.fromRGB(140, 80, 220)
	title.BackgroundTransparency = 0.2
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.Text = "🏆 Top Spieler"
	title.Parent = surfaceGui

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Size = UDim2.new(1, -16, 1, -56)
	list.Position = UDim2.fromOffset(8, 52)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextColor3 = Color3.fromRGB(230, 230, 240)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextSize = 22
	list.TextWrapped = true
	list.Text = "Lade..."
	list.Parent = surfaceGui

	hub.PrimaryPart = spawn
	return hub
end

return HubWorldBuilder
