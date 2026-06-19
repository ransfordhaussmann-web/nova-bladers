local HubWorldBuilder = {}

local function addBillboard(part, title, hint)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ZoneLabel"
	gui.Size = UDim2.fromOffset(200, 60)
	gui.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = part

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextScaled = true
	titleLabel.Text = title
	titleLabel.Parent = gui

	local hintLabel = Instance.new("TextLabel")
	hintLabel.Size = UDim2.new(1, 0, 0.45, 0)
	hintLabel.Position = UDim2.fromScale(0, 0.55)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Font = Enum.Font.Gotham
	hintLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
	hintLabel.TextScaled = true
	hintLabel.Text = hint
	hintLabel.Parent = gui
end

function HubWorldBuilder.build(config)
	local workspace = game:GetService("Workspace")

	local existing = workspace:FindFirstChild(config.HUB_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = config.HUB_FOLDER_NAME
	hub.Parent = workspace

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = config.FLOOR_SIZE
	floor.Position = Vector3.new(0, config.FLOOR_SIZE.Y / 2, 0)
	floor.Anchored = true
	floor.Material = Enum.Material.Slate
	floor.Color = Color3.fromRGB(45, 50, 65)
	floor.Parent = hub

	local halfX = config.FLOOR_SIZE.X / 2
	local halfZ = config.FLOOR_SIZE.Z / 2
	local wallThickness = 2
	local wallY = config.FLOOR_SIZE.Y + config.WALL_HEIGHT / 2

	local wallDefs = {
		{ name = "WallNorth", size = Vector3.new(config.FLOOR_SIZE.X, config.WALL_HEIGHT, wallThickness), pos = Vector3.new(0, wallY, -halfZ) },
		{ name = "WallSouth", size = Vector3.new(config.FLOOR_SIZE.X, config.WALL_HEIGHT, wallThickness), pos = Vector3.new(0, wallY, halfZ) },
		{ name = "WallWest", size = Vector3.new(wallThickness, config.WALL_HEIGHT, config.FLOOR_SIZE.Z), pos = Vector3.new(-halfX, wallY, 0) },
		{ name = "WallEast", size = Vector3.new(wallThickness, config.WALL_HEIGHT, config.FLOOR_SIZE.Z), pos = Vector3.new(halfX, wallY, 0) },
	}

	for _, def in wallDefs do
		local wall = Instance.new("Part")
		wall.Name = def.name
		wall.Size = def.size
		wall.Position = def.pos
		wall.Anchored = true
		wall.Material = Enum.Material.Concrete
		wall.Color = Color3.fromRGB(60, 65, 80)
		wall.Parent = hub
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = config.SPAWN_POSITION
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for zoneId, zone in config.ZONES do
		local zonePart = Instance.new("Part")
		zonePart.Name = zoneId
		zonePart.Size = zone.size
		zonePart.Position = zone.position + Vector3.new(0, zone.size.Y / 2, 0)
		zonePart.Anchored = true
		zonePart.CanCollide = true
		zonePart.Material = Enum.Material.Neon
		zonePart.Color = zone.color
		zonePart.Transparency = 0.35
		zonePart:SetAttribute("ZoneId", zoneId)
		zonePart:SetAttribute("ZoneName", zone.name)
		zonePart:SetAttribute("ZoneHint", zone.hint)
		zonePart.Parent = zonesFolder

		addBillboard(zonePart, zone.name, zone.hint)
	end

	return hub
end

return HubWorldBuilder
