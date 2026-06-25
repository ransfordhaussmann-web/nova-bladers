local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	return part
end

local function addZoneMarker(parent, zone)
	local pad = makePart({
		Name = zone.id .. "_Pad",
		Size = Vector3.new(zone.radius * 2, 0.4, zone.radius * 2),
		Position = zone.position - Vector3.new(0, 1.2, 0),
		Color = zone.color,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		CanCollide = false,
	})
	pad.Parent = parent

	local sign = makePart({
		Name = zone.id .. "_Sign",
		Size = Vector3.new(6, 8, 1),
		Position = zone.position + Vector3.new(0, 5, 0),
		Color = zone.color,
		Material = Enum.Material.SmoothPlastic,
	})
	sign.Parent = parent

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, 5.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.TextSize = 22
	label.Text = zone.name
	label.Parent = billboard
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_NAME
	hub.Parent = workspace

	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = HubConfig.FLOOR_CENTER,
		Color = Color3.fromRGB(35, 38, 48),
		Material = Enum.Material.Slate,
	})
	floor.Parent = hub

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallY = HubConfig.FLOOR_CENTER.Y + HubConfig.WALL_HEIGHT / 2
	local wallDefs = {
		{ name = "WallNorth", size = Vector3.new(HubConfig.FLOOR_SIZE.X + 4, HubConfig.WALL_HEIGHT, HubConfig.WALL_THICKNESS), pos = Vector3.new(0, wallY, -halfZ) },
		{ name = "WallSouth", size = Vector3.new(HubConfig.FLOOR_SIZE.X + 4, HubConfig.WALL_HEIGHT, HubConfig.WALL_THICKNESS), pos = Vector3.new(0, wallY, halfZ) },
		{ name = "WallWest", size = Vector3.new(HubConfig.WALL_THICKNESS, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z + 4), pos = Vector3.new(-halfX, wallY, 0) },
		{ name = "WallEast", size = Vector3.new(HubConfig.WALL_THICKNESS, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z + 4), pos = Vector3.new(halfX, wallY, 0) },
	}

	for _, def in wallDefs do
		local wall = makePart({
			Name = def.name,
			Size = def.size,
			Position = HubConfig.FLOOR_CENTER + def.pos,
			Color = Color3.fromRGB(55, 60, 75),
			Material = Enum.Material.Concrete,
		})
		wall.Parent = hub
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		addZoneMarker(zonesFolder, zone)
	end

	return hub
end

return HubWorldBuilder
