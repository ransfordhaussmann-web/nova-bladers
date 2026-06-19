local HubWorldBuilder = {}

local function createPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	for key, value in props do
		if key ~= "Parent" and key ~= "CanCollide" then
			part[key] = value
		end
	end
	part.Parent = props.Parent
	return part
end

local function addBillboard(parent, text, offsetY)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(220, 56)
	billboard.StudsOffset = Vector3.new(0, offsetY or 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard
end

function HubWorldBuilder.build(config)
	local existing = workspace:FindFirstChild(config.HUB_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	local origin = config.ORIGIN
	local hub = Instance.new("Folder")
	hub.Name = config.HUB_FOLDER_NAME
	hub.Parent = workspace

	local floorY = origin.Y + config.SPAWN_OFFSET.Y - 2
	createPart({
		Name = "Floor",
		Size = config.FLOOR_SIZE,
		Position = origin + Vector3.new(0, floorY - config.FLOOR_SIZE.Y / 2, 0),
		Color = Color3.fromRGB(32, 36, 48),
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = origin + config.SPAWN_OFFSET
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hub

	createPart({
		Name = "CenterPillar",
		Size = Vector3.new(4, 10, 4),
		Position = origin + Vector3.new(0, floorY + 5, 0),
		Color = Color3.fromRGB(90, 110, 200),
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		CanCollide = false,
		Parent = hub,
	})
	addBillboard(hub.CenterPillar, "Nova Bladers", 6)

	local halfX = config.FLOOR_SIZE.X / 2
	local halfZ = config.FLOOR_SIZE.Z / 2
	local wallY = floorY + config.WALL_HEIGHT / 2
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = hub

	local wallDefs = {
		{ Vector3.new(0, wallY, origin.Z - halfZ), Vector3.new(config.FLOOR_SIZE.X, config.WALL_HEIGHT, 2) },
		{ Vector3.new(0, wallY, origin.Z + halfZ), Vector3.new(config.FLOOR_SIZE.X, config.WALL_HEIGHT, 2) },
		{ Vector3.new(origin.X - halfX, wallY, 0), Vector3.new(2, config.WALL_HEIGHT, config.FLOOR_SIZE.Z) },
		{ Vector3.new(origin.X + halfX, wallY, 0), Vector3.new(2, config.WALL_HEIGHT, config.FLOOR_SIZE.Z) },
	}
	for index, def in wallDefs do
		createPart({
			Name = "Wall" .. index,
			Size = def[2],
			Position = def[1],
			Color = Color3.fromRGB(22, 24, 32),
			Material = Enum.Material.Concrete,
			Parent = walls,
		})
	end

	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = hub

	for _, zone in config.ZONES do
		local zoneFolder = Instance.new("Folder")
		zoneFolder.Name = zone.id
		zoneFolder.Parent = zones

		local padY = floorY + zone.size.Y / 2
		local pad = createPart({
			Name = "Pad",
			Size = zone.size,
			Position = origin + zone.position + Vector3.new(0, padY, 0),
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.45,
			CanCollide = false,
			Parent = zoneFolder,
		})

		local arch = createPart({
			Name = "Arch",
			Size = Vector3.new(zone.size.X * 0.6, 8, 1),
			Position = pad.Position + Vector3.new(0, 5, 0),
			Color = zone.color,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			Parent = zoneFolder,
		})
		addBillboard(arch, zone.name, 2)

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = zone.actionText
		prompt.ObjectText = zone.name
		prompt.MaxActivationDistance = 14
		prompt.HoldDuration = 0
		prompt.Parent = pad
		prompt:SetAttribute("ZoneId", zone.id)
		prompt:SetAttribute("RemoteName", zone.remote)
	end

	return hub
end

return HubWorldBuilder
