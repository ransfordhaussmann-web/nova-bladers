local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color or Color3.fromRGB(30, 32, 45)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Name = props.Name or "Part"
	part.Parent = props.Parent
	return part
end

local function makeSign(parent, text, offset)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Size = UDim2.fromOffset(200, 60)
	billboard.StudsOffset = offset or Vector3.new(0, 8, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.3
	label.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
	label.TextColor3 = Color3.fromRGB(240, 240, 255)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	return billboard
end

local function makeZone(parent, zoneConfig)
	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = zoneConfig.id
	zoneFolder.Parent = parent

	local platform = makePart({
		Name = "Platform",
		Parent = zoneFolder,
		Size = zoneConfig.size,
		CFrame = CFrame.new(zoneConfig.position + Vector3.new(0, zoneConfig.size.Y / 2, 0)),
		Color = zoneConfig.color,
		Material = Enum.Material.Neon,
	})

	local glow = makePart({
		Name = "GlowRing",
		Parent = zoneFolder,
		Size = Vector3.new(zoneConfig.size.X + 2, 0.4, zoneConfig.size.Z + 2),
		CFrame = CFrame.new(zoneConfig.position + Vector3.new(0, 0.3, 0)),
		Color = zoneConfig.glowColor,
		Material = Enum.Material.Neon,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zoneConfig.name
	prompt.ObjectText = zoneConfig.description
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ZoneAction", zoneConfig.action)
	prompt.Parent = platform

	makeSign(platform, zoneConfig.name, Vector3.new(0, zoneConfig.size.Y / 2 + 4, 0))

	local light = Instance.new("PointLight")
	light.Color = zoneConfig.glowColor
	light.Brightness = 1.2
	light.Range = 20
	light.Parent = platform

	platform.Transparency = 0.35
	glow.Transparency = 0.2

	return zoneFolder
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_NAME
	hub.Parent = workspace

	local floorY = 0
	local floor = makePart({
		Name = "Floor",
		Parent = hub,
		Size = HubConfig.FLOOR_SIZE,
		CFrame = CFrame.new(0, floorY - HubConfig.FLOOR_SIZE.Y / 2, 0),
		Color = Color3.fromRGB(22, 24, 35),
		Material = Enum.Material.Slate,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallThickness = 2
	local wallY = floorY + HubConfig.WALL_HEIGHT / 2

	local walls = {
		{ Vector3.new(0, wallY, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, wallThickness) },
		{ Vector3.new(0, wallY, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, wallThickness) },
		{ Vector3.new(-halfX, wallY, 0), Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(halfX, wallY, 0), Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
	}

	for i, wallData in walls do
		makePart({
			Name = "Wall" .. i,
			Parent = hub,
			Size = wallData[2],
			CFrame = CFrame.new(wallData[1]),
			Color = Color3.fromRGB(35, 38, 55),
			Material = Enum.Material.Concrete,
		})
	end

	local spawn = makePart({
		Name = "Spawn",
		Parent = hub,
		Size = Vector3.new(6, 0.5, 6),
		CFrame = CFrame.new(HubConfig.SPAWN_POSITION),
		Color = Color3.fromRGB(80, 200, 255),
		Material = Enum.Material.Neon,
	})
	spawn.Transparency = 0.5
	spawn.CanCollide = false

	makeSign(spawn, "Nova Hub", Vector3.new(0, 4, 0))

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zoneConfig in HubConfig.ZONES do
		makeZone(zonesFolder, zoneConfig)
	end

	local ceiling = makePart({
		Name = "Ceiling",
		Parent = hub,
		Size = Vector3.new(HubConfig.FLOOR_SIZE.X, 1, HubConfig.FLOOR_SIZE.Z),
		CFrame = CFrame.new(0, floorY + HubConfig.WALL_HEIGHT, 0),
		Color = Color3.fromRGB(18, 20, 30),
		Material = Enum.Material.SmoothPlastic,
	})

	local ambient = Instance.new("Part")
	ambient.Name = "AmbientLight"
	ambient.Anchored = true
	ambient.CanCollide = false
	ambient.Transparency = 1
	ambient.Size = Vector3.new(1, 1, 1)
	ambient.CFrame = CFrame.new(0, HubConfig.WALL_HEIGHT - 2, 0)
	ambient.Parent = hub

	local light = Instance.new("PointLight")
	light.Brightness = 0.6
	light.Range = 80
	light.Color = Color3.fromRGB(180, 200, 255)
	light.Parent = ambient

	return hub
end

return HubWorldBuilder
