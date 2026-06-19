local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.Position = props.position
	part.Color = props.color or Color3.fromRGB(200, 200, 200)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Transparency = props.transparency or 0
	part.Name = props.name
	part.Parent = props.parent
	return part
end

local function addLabel(parent, text, offset)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
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

local function addPrompt(zonePart, zoneConfig)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zoneConfig.actionText
	prompt.ObjectText = zoneConfig.name
	prompt.HoldDuration = zoneConfig.promptHold or 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = zonePart
	return prompt
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		return existing
	end

	local hub = Instance.new("Model")
	hub.Name = "NovaHub"

	local floorY = HubConfig.FLOOR_SIZE.Y / 2
	makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		position = Vector3.new(0, floorY, 0),
		color = Color3.fromRGB(35, 38, 48),
		material = Enum.Material.Slate,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallThickness = 2
	local wallY = HubConfig.WALL_HEIGHT / 2 + floorY

	local walls = {
		{ name = "WallNorth", size = Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, wallThickness), position = Vector3.new(0, wallY, -halfZ) },
		{ name = "WallSouth", size = Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, wallThickness), position = Vector3.new(0, wallY, halfZ) },
		{ name = "WallWest", size = Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), position = Vector3.new(-halfX, wallY, 0) },
		{ name = "WallEast", size = Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), position = Vector3.new(halfX, wallY, 0) },
	}

	for _, wall in walls do
		makePart({
			name = wall.name,
			parent = hub,
			size = wall.size,
			position = wall.position,
			color = Color3.fromRGB(50, 55, 70),
			material = Enum.Material.Concrete,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Parent = hub

	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = hub

	for zoneId, zoneConfig in HubConfig.ZONES do
		local zoneY = floorY + zoneConfig.size.Y / 2
		local zonePart = makePart({
			name = zoneId,
			parent = zones,
			size = zoneConfig.size,
			position = zoneConfig.position + Vector3.new(0, zoneY, 0),
			color = zoneConfig.color,
			material = Enum.Material.Neon,
			transparency = 0.35,
			canCollide = false,
		})
		addLabel(zonePart, zoneConfig.name)
		addPrompt(zonePart, zoneConfig)
	end

	hub.Parent = workspace
	return hub
end

return HubWorldBuilder
