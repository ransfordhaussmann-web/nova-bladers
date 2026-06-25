local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function createPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	return part
end

local function createSign(parent, text, position, color)
	local sign = createPart({
		Name = "Sign",
		Size = Vector3.new(10, 3, 0.4),
		Position = position,
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Transparency = 0.15,
	})
	sign.Parent = parent

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(220, 56)
	billboard.StudsOffset = Vector3.new(0, 3.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard

	return sign
end

local function createZone(parent, zoneConfig)
	local zone = createPart({
		Name = zoneConfig.id,
		Size = zoneConfig.size,
		Position = zoneConfig.position + Vector3.new(0, zoneConfig.size.Y * 0.5, 0),
		Color = zoneConfig.color,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.35,
		CanCollide = true,
	})
	zone:SetAttribute("ZoneId", zoneConfig.id)
	zone:SetAttribute("ZoneAction", zoneConfig.action)
	zone.Parent = parent

	local ring = createPart({
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, math.max(zoneConfig.size.X, zoneConfig.size.Z) + 2, math.max(zoneConfig.size.X, zoneConfig.size.Z) + 2),
		Position = zoneConfig.position + Vector3.new(0, 0.2, 0),
		Orientation = Vector3.new(0, 0, 90),
		Color = zoneConfig.color,
		Material = Enum.Material.Neon,
		Transparency = 0.5,
		CanCollide = false,
	})
	ring.Parent = zone

	createSign(zone, zoneConfig.name, zoneConfig.position + Vector3.new(0, zoneConfig.size.Y * 0.5 + 2, 0), zoneConfig.color)

	return zone
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Model")
	hub.Name = HubConfig.HUB_NAME
	hub.Parent = workspace

	local floor = createPart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = Vector3.new(0, -HubConfig.FLOOR_SIZE.Y * 0.5, 0),
		Color = Color3.fromRGB(35, 38, 48),
		Material = Enum.Material.Slate,
	})
	floor.Parent = hub

	local halfX = HubConfig.FLOOR_SIZE.X * 0.5
	local halfZ = HubConfig.FLOOR_SIZE.Z * 0.5
	local wallY = HubConfig.WALL_HEIGHT * 0.5
	local wallColor = Color3.fromRGB(50, 55, 70)

	local walls = {
		{ Vector3.new(0, wallY, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, HubConfig.WALL_THICKNESS) },
		{ Vector3.new(0, wallY, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, HubConfig.WALL_THICKNESS) },
		{ Vector3.new(-halfX, wallY, 0), Vector3.new(HubConfig.WALL_THICKNESS, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(halfX, wallY, 0), Vector3.new(HubConfig.WALL_THICKNESS, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
	}
	for index, wallData in walls do
		local wall = createPart({
			Name = "Wall" .. index,
			Size = wallData[2],
			Position = wallData[1],
			Color = wallColor,
			Material = Enum.Material.Concrete,
		})
		wall.Parent = hub
	end

	local spawn = createPart({
		Name = "Spawn",
		Size = Vector3.new(6, 0.4, 6),
		Position = HubConfig.SPAWN_POSITION - Vector3.new(0, 2, 0),
		Color = Color3.fromRGB(120, 200, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.4,
		CanCollide = false,
	})
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zoneConfig in HubConfig.ZONES do
		createZone(zonesFolder, zoneConfig)
	end

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 80
	light.Parent = floor

	return hub
end

return HubWorldBuilder
