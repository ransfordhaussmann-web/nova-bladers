local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function createPart(parent, name, size, position, color, anchored)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = anchored ~= false
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if color then
		part.Color = color
	end
	part.Parent = parent
	return part
end

local function createZoneLabel(part, text)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 20
	label.Text = text
	label.Parent = billboard
end

local function createZonePrompt(part, promptText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = promptText
	prompt.ObjectText = ""
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	local floorY = HubConfig.FLOOR_SIZE.Y / 2
	createPart(
		hub,
		"Floor",
		HubConfig.FLOOR_SIZE,
		Vector3.new(0, floorY, 0),
		Color3.fromRGB(35, 40, 55)
	)

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallThickness = 2
	local wallY = HubConfig.WALL_HEIGHT / 2 + floorY

	for _, wall in {
		{ "WallNorth", Vector3.new(halfX * 2, HubConfig.WALL_HEIGHT, wallThickness), Vector3.new(0, wallY, -halfZ) },
		{ "WallSouth", Vector3.new(halfX * 2, HubConfig.WALL_HEIGHT, wallThickness), Vector3.new(0, wallY, halfZ) },
		{ "WallWest", Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, halfZ * 2), Vector3.new(-halfX, wallY, 0) },
		{ "WallEast", Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, halfZ * 2), Vector3.new(halfX, wallY, 0) },
	} do
		local part = createPart(hub, wall[1], wall[2], wall[3], Color3.fromRGB(50, 55, 70))
		part.Transparency = 0.15
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	local zones = {}
	for zoneId, zone in HubConfig.ZONES do
		local zonePart = createPart(
			zonesFolder,
			zoneId,
			zone.size,
			zone.position + Vector3.new(0, zone.size.Y / 2 + floorY, 0),
			zone.color
		)
		zonePart.Material = Enum.Material.Neon
		zonePart.Transparency = 0.35
		createZoneLabel(zonePart, zone.name)
		local prompt = createZonePrompt(zonePart, zone.promptText)
		zones[zoneId] = {
			part = zonePart,
			prompt = prompt,
			action = zone.action,
		}
	end

	return hub, zones
end

return HubWorldBuilder
