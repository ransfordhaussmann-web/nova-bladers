local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function createPart(name, size, position, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function addZoneLabel(parent, title, subtitle)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(220, 70)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = parent

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 0.35
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.BorderSizePixel = 0
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -12, 0.55, 0)
	titleLabel.Position = UDim2.fromOffset(6, 4)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 18
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.Text = title
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center
	titleLabel.Parent = frame

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "Subtitle"
	subLabel.Size = UDim2.new(1, -12, 0.4, 0)
	subLabel.Position = UDim2.new(0, 6, 0.55, 0)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextSize = 13
	subLabel.TextColor3 = Color3.fromRGB(190, 195, 210)
	subLabel.Text = subtitle
	subLabel.TextXAlignment = Enum.TextXAlignment.Center
	subLabel.Parent = frame
end

function HubWorldBuilder.build(parent)
	parent = parent or workspace
	local existing = parent:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = parent

	local floorY = HubConfig.FLOOR_SIZE.Y / 2
	local floor = createPart(
		"Floor",
		HubConfig.FLOOR_SIZE,
		Vector3.new(0, floorY, 0),
		Color3.fromRGB(45, 48, 58),
		Enum.Material.Slate
	)
	floor.Parent = hub

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local t = HubConfig.WALL_THICKNESS
	local wallColor = Color3.fromRGB(35, 38, 48)

	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = hub

	local wallDefs = {
		{ "NorthWall", Vector3.new(halfX * 2 + t * 2, wallH, t), Vector3.new(0, wallH / 2 + floorY, halfZ + t / 2) },
		{ "SouthWall", Vector3.new(halfX * 2 + t * 2, wallH, t), Vector3.new(0, wallH / 2 + floorY, -halfZ - t / 2) },
		{ "EastWall", Vector3.new(t, wallH, halfZ * 2 + t * 2), Vector3.new(halfX + t / 2, wallH / 2 + floorY, 0) },
		{ "WestWall", Vector3.new(t, wallH, halfZ * 2 + t * 2), Vector3.new(-halfX - t / 2, wallH / 2 + floorY, 0) },
	}

	for _, def in wallDefs do
		local wall = createPart(def[1], def[2], def[3], wallColor, Enum.Material.Concrete)
		wall.Parent = walls
	end

	local spawn = Instance.new("Part")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = hub

	local spawnLight = Instance.new("PointLight")
	spawnLight.Brightness = 1.2
	spawnLight.Range = 16
	spawnLight.Color = Color3.fromRGB(120, 180, 255)
	spawnLight.Parent = spawn

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zonePart = createPart(
			zone.id,
			zone.size,
			Vector3.new(zone.position.X, floorY + zone.size.Y / 2, zone.position.Z),
			zone.color,
			Enum.Material.Neon
		)
		zonePart.Transparency = 0.25
		zonePart:SetAttribute("ZoneAction", zone.action)
		zonePart:SetAttribute("ZoneId", zone.id)
		addZoneLabel(zonePart, zone.name, zone.subtitle)
		zonePart.Parent = zonesFolder

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ZonePrompt"
		prompt.ActionText = zone.promptText
		prompt.ObjectText = zone.name
		prompt.MaxActivationDistance = HubConfig.PROXIMITY_DISTANCE
		prompt.HoldDuration = HubConfig.PROXIMITY_HOLD
		prompt.RequiresLineOfSight = false
		prompt.Parent = zonePart
	end

	local centerPad = createPart(
		"CenterPad",
		Vector3.new(14, 0.4, 14),
		Vector3.new(0, floorY + 0.2, 0),
		Color3.fromRGB(60, 65, 80),
		Enum.Material.Marble
	)
	centerPad.Parent = hub

	return hub
end

return HubWorldBuilder
