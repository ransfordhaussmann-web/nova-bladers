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

local function addLabel(parent, text, offset)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = offset or Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 18
	label.Text = text
	label.Parent = billboard
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Model")
	hub.Name = HubConfig.HUB_FOLDER_NAME

	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = Vector3.new(0, -0.5, 0),
		Color = Color3.fromRGB(35, 40, 55),
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallThickness = 2

	local wallDefs = {
		{ Vector3.new(0, HubConfig.WALL_HEIGHT / 2, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, wallThickness) },
		{ Vector3.new(0, HubConfig.WALL_HEIGHT / 2, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, wallThickness) },
		{ Vector3.new(-halfX, HubConfig.WALL_HEIGHT / 2, 0), Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(halfX, HubConfig.WALL_HEIGHT / 2, 0), Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
	}

	for index, def in wallDefs do
		makePart({
			Name = "Wall" .. index,
			Size = def[2],
			Position = def[1],
			Color = Color3.fromRGB(50, 55, 75),
			Material = Enum.Material.Concrete,
			Transparency = 0.15,
			Parent = hub,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_OFFSET
	spawn.Color = Color3.fromRGB(100, 200, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.4
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local marker = makePart({
			Name = zone.id,
			Size = zone.size,
			Position = zone.position,
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.55,
			CanCollide = false,
			Parent = zonesFolder,
		})
		marker:SetAttribute("ZoneId", zone.id)
		marker:SetAttribute("Action", zone.action)
		addLabel(marker, zone.name, Vector3.new(0, zone.size.Y / 2 + 2, 0))
	end

	addLabel(floor, "Nova Bladers Hub", Vector3.new(0, 6, 0))

	hub.PrimaryPart = floor
	hub.Parent = workspace
	return hub
end

return HubWorldBuilder
