local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.fromRGB(60, 65, 80)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function addSign(parent, text, offset, color)
	local sign = makePart({
		name = "Sign",
		parent = parent,
		size = Vector3.new(8, 3, 0.4),
		cframe = parent.CFrame * CFrame.new(0, parent.Size.Y / 2 + 2.5, -parent.Size.Z / 2 - 0.5) * CFrame.new(offset or Vector3.zero),
		color = Color3.fromRGB(40, 42, 52),
		material = Enum.Material.Metal,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Text = text
	label.Parent = gui
end

local function buildZone(parent, zone)
	local zonePart = makePart({
		name = zone.id,
		parent = parent,
		size = zone.size,
		cframe = CFrame.new(zone.position),
		color = zone.color,
		material = Enum.Material.Neon,
		canCollide = false,
	})
	zonePart.Transparency = 0.55

	local light = Instance.new("PointLight")
	light.Color = zone.color
	light.Brightness = 1.2
	light.Range = 14
	light.Parent = zonePart

	addSign(zonePart, zone.name, Vector3.zero, zone.color)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zone.name
	prompt.ObjectText = "Nova Hub"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = HubConfig.PROXIMITY_RANGE
	prompt.RequiresLineOfSight = false
	prompt.Parent = zonePart

	return zonePart
end

local function buildLeaderboardBoard(parent, position)
	local board = makePart({
		name = "LeaderboardBoard",
		parent = parent,
		size = Vector3.new(10, 7, 0.5),
		cframe = CFrame.new(position + Vector3.new(0, 5, -5)),
		color = Color3.fromRGB(30, 32, 42),
		material = Enum.Material.Metal,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 210, 80)
	title.TextSize = 22
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = gui

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.fromOffset(0, 40)
	list.Size = UDim2.new(1, 0, 1, -40)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextColor3 = Color3.fromRGB(230, 230, 240)
	list.TextSize = 18
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Text = "Lade Rangliste…"
	list.Parent = gui

	return board
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_NAME
	hub.Parent = workspace

	local floorSize = HubConfig.FLOOR_SIZE
	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2

	makePart({
		name = "Floor",
		parent = hub,
		size = floorSize,
		cframe = CFrame.new(0, 0, 0),
		color = Color3.fromRGB(45, 50, 62),
		material = Enum.Material.Slate,
	})

	local wallThickness = 2
	local wallY = HubConfig.WALL_HEIGHT / 2
	local walls = {
		{ Vector3.new(0, wallY, halfZ + wallThickness / 2), Vector3.new(floorSize.X + 4, HubConfig.WALL_HEIGHT, wallThickness) },
		{ Vector3.new(0, wallY, -halfZ - wallThickness / 2), Vector3.new(floorSize.X + 4, HubConfig.WALL_HEIGHT, wallThickness) },
		{ Vector3.new(halfX + wallThickness / 2, wallY, 0), Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, floorSize.Z + 4) },
		{ Vector3.new(-halfX - wallThickness / 2, wallY, 0), Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, floorSize.Z + 4) },
	}
	for index, wall in walls do
		makePart({
			name = "Wall" .. index,
			parent = hub,
			size = wall[2],
			cframe = CFrame.new(wall[1]),
			color = Color3.fromRGB(55, 58, 72),
			material = Enum.Material.Concrete,
		})
	end

	local spawn = makePart({
		name = "Spawn",
		parent = hub,
		size = Vector3.new(6, 0.5, 6),
		cframe = CFrame.new(HubConfig.SPAWN_POSITION),
		color = Color3.fromRGB(100, 180, 255),
		material = Enum.Material.Neon,
		canCollide = false,
	})
	spawn.Transparency = 0.6

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	local hallZone
	for _, zone in HubConfig.ZONES do
		local zonePart = buildZone(zonesFolder, zone)
		if zone.id == "hall_of_fame" then
			hallZone = zone
		end
	end

	if hallZone then
		buildLeaderboardBoard(hub, hallZone.position)
	end

	local welcome = makePart({
		name = "WelcomeSign",
		parent = hub,
		size = Vector3.new(16, 4, 0.5),
		cframe = CFrame.new(0, 6, -25),
		color = Color3.fromRGB(35, 38, 50),
		material = Enum.Material.Metal,
		canCollide = false,
	})
	local welcomeGui = Instance.new("SurfaceGui")
	welcomeGui.Face = Enum.NormalId.Front
	welcomeGui.Parent = welcome
	local welcomeLabel = Instance.new("TextLabel")
	welcomeLabel.Size = UDim2.fromScale(1, 1)
	welcomeLabel.BackgroundTransparency = 1
	welcomeLabel.Font = Enum.Font.GothamBold
	welcomeLabel.TextColor3 = Color3.fromRGB(180, 220, 255)
	welcomeLabel.TextScaled = true
	welcomeLabel.Text = "Nova Bladers — Hub"
	welcomeLabel.Parent = welcomeGui

	return hub
end

function HubWorldBuilder.getSpawnCFrame()
	local hub = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if hub then
		local spawn = hub:FindFirstChild("Spawn")
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(HubConfig.SPAWN_POSITION)
end

return HubWorldBuilder
