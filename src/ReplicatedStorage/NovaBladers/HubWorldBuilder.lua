local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function createPart(name, size, position, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.CanCollide = true
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function addZoneLabel(part, title, subtitle)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 80)
	billboard.StudsOffset = Vector3.new(0, part.Size.Y * 0.5 + 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextStrokeTransparency = 0.4
	titleLabel.TextSize = 22
	titleLabel.Text = title
	titleLabel.Parent = billboard

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.Position = UDim2.fromScale(0, 0.55)
	subtitleLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Font = Enum.Font.Gotham
	subtitleLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	subtitleLabel.TextStrokeTransparency = 0.5
	subtitleLabel.TextSize = 16
	subtitleLabel.Text = subtitle
	subtitleLabel.Parent = billboard
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	local floorSize = HubConfig.FLOOR_SIZE
	local floor = createPart(
		"Floor",
		floorSize,
		Vector3.new(0, floorSize.Y * 0.5, 0),
		Color3.fromRGB(35, 38, 48),
		Enum.Material.Slate
	)
	floor.Parent = hub

	local halfX = floorSize.X * 0.5
	local halfZ = floorSize.Z * 0.5
	local wallY = HubConfig.WALL_HEIGHT * 0.5 + floorSize.Y
	local wallDefs = {
		{ "WallNorth", Vector3.new(floorSize.X + HubConfig.WALL_THICKNESS, HubConfig.WALL_HEIGHT, HubConfig.WALL_THICKNESS), Vector3.new(0, wallY, -halfZ) },
		{ "WallSouth", Vector3.new(floorSize.X + HubConfig.WALL_THICKNESS, HubConfig.WALL_HEIGHT, HubConfig.WALL_THICKNESS), Vector3.new(0, wallY, halfZ) },
		{ "WallWest", Vector3.new(HubConfig.WALL_THICKNESS, HubConfig.WALL_HEIGHT, floorSize.Z), Vector3.new(-halfX, wallY, 0) },
		{ "WallEast", Vector3.new(HubConfig.WALL_THICKNESS, HubConfig.WALL_HEIGHT, floorSize.Z), Vector3.new(halfX, wallY, 0) },
	}

	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = hub

	for _, def in wallDefs do
		local wall = createPart(def[1], def[2], def[3], Color3.fromRGB(55, 58, 72), Enum.Material.Concrete)
		wall.Parent = walls
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_OFFSET
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local marker = createPart(zone.id, zone.size, zone.position, zone.color, Enum.Material.Neon)
		marker.Transparency = 0.35
		marker.CanCollide = false
		marker:SetAttribute("ZoneId", zone.id)
		addZoneLabel(marker, zone.name, zone.hint)
		marker.Parent = zonesFolder
	end

	local lighting = Instance.new("PointLight")
	lighting.Brightness = 1.2
	lighting.Range = 40
	lighting.Parent = floor

	return hub
end

function HubWorldBuilder.getSpawnCFrame()
	local hub = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	local spawn = hub and hub:FindFirstChild("HubSpawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubConfig.SPAWN_OFFSET)
end

return HubWorldBuilder
