local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = true
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function addZonePrompt(zonePart, zoneId, zoneDef)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zoneDef.action
	prompt.ObjectText = zoneDef.name
	prompt.MaxActivationDistance = 14
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ZoneId", zoneId)
	prompt.Parent = zonePart

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, zoneDef.size.Y * 0.5 + 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = zonePart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextScaled = true
	label.Text = zoneDef.name
	label.Parent = billboard
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		return existing
	end

	local origin = HubConfig.ORIGIN
	local hub = Instance.new("Model")
	hub.Name = "NovaHub"

	local floor = makePart(
		"Floor",
		HubConfig.FLOOR_SIZE,
		CFrame.new(origin + Vector3.new(0, HubConfig.FLOOR_SIZE.Y * 0.5, 0)),
		Color3.fromRGB(35, 40, 55),
		Enum.Material.Slate
	)
	floor.Parent = hub

	local halfX = HubConfig.FLOOR_SIZE.X * 0.5
	local halfZ = HubConfig.FLOOR_SIZE.Z * 0.5
	local wallY = HubConfig.FLOOR_SIZE.Y + HubConfig.WALL_HEIGHT * 0.5
	local wallThickness = 2

	local walls = {
		{ name = "WallNorth", size = Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, wallThickness), pos = Vector3.new(0, wallY, -halfZ) },
		{ name = "WallSouth", size = Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, wallThickness), pos = Vector3.new(0, wallY, halfZ) },
		{ name = "WallWest", size = Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), pos = Vector3.new(-halfX, wallY, 0) },
		{ name = "WallEast", size = Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), pos = Vector3.new(halfX, wallY, 0) },
	}

	for _, wall in walls do
		local part = makePart(
			wall.name,
			wall.size,
			CFrame.new(origin + wall.pos),
			Color3.fromRGB(50, 55, 75),
			Enum.Material.Concrete
		)
		part.Parent = hub
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(origin + HubConfig.SPAWN_OFFSET)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for zoneId, zoneDef in HubConfig.ZONES do
		local zonePart = makePart(
			zoneId,
			zoneDef.size,
			CFrame.new(origin + zoneDef.offset + Vector3.new(0, zoneDef.size.Y * 0.5 + HubConfig.FLOOR_SIZE.Y * 0.5, 0)),
			zoneDef.color,
			Enum.Material.Neon
		)
		zonePart.Transparency = 0.25
		zonePart.CanCollide = false
		addZonePrompt(zonePart, zoneId, zoneDef)
		zonePart.Parent = zonesFolder
	end

	hub.PrimaryPart = floor
	hub.Parent = workspace
	return hub
end

return HubWorldBuilder
