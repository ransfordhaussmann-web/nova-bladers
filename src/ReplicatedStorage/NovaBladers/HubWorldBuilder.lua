local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(name, size, cframe, color, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.Parent = parent
	return part
end

local function makeBillboard(parent, title, subtitle, color)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ZoneLabel"
	gui.Size = UDim2.fromOffset(220, 90)
	gui.StudsOffset = Vector3.new(0, 6, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = color
	titleLabel.TextScaled = true
	titleLabel.Text = title
	titleLabel.Parent = gui

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "Subtitle"
	subLabel.Position = UDim2.fromScale(0, 0.55)
	subLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
	subLabel.TextScaled = true
	subLabel.Text = subtitle
	subLabel.Parent = gui
end

local function makeZone(zoneConfig, parent)
	local folder = Instance.new("Folder")
	folder.Name = zoneConfig.id
	folder.Parent = parent

	local platform = makePart(
		"Platform",
		Vector3.new(HubConfig.ZONE_RADIUS * 2, 0.4, HubConfig.ZONE_RADIUS * 2),
		CFrame.new(zoneConfig.position + Vector3.new(0, 0.7, 0)),
		zoneConfig.color,
		folder
	)
	platform.Transparency = 0.15
	platform.Material = Enum.Material.Neon

	local marker = makePart(
		"Marker",
		Vector3.new(2, 8, 2),
		CFrame.new(zoneConfig.position + Vector3.new(0, 4.4, 0)),
		zoneConfig.color,
		folder
	)
	marker.Material = Enum.Material.Neon
	marker.Transparency = 0.25

	local trigger = makePart(
		"Trigger",
		Vector3.new(HubConfig.ZONE_RADIUS * 2, 10, HubConfig.ZONE_RADIUS * 2),
		CFrame.new(zoneConfig.position + Vector3.new(0, 5, 0)),
		zoneConfig.color,
		folder
	)
	trigger.Transparency = 1
	trigger.CanCollide = false
	trigger:SetAttribute("ZoneId", zoneConfig.id)
	trigger:SetAttribute("ZoneAction", zoneConfig.action)

	makeBillboard(marker, zoneConfig.name, zoneConfig.subtitle, zoneConfig.color)

	local light = Instance.new("PointLight")
	light.Brightness = 1.2
	light.Range = 18
	light.Color = zoneConfig.color
	light.Parent = marker

	return folder
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Model")
	hub.Name = HubConfig.HUB_NAME
	hub.Parent = workspace

	local floor = makePart(
		"Floor",
		HubConfig.FLOOR_SIZE,
		CFrame.new(0, 0, 0),
		Color3.fromRGB(35, 38, 48),
		hub
	)
	floor.Material = Enum.Material.Slate

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallY = HubConfig.WALL_HEIGHT / 2 + 0.5
	local wallColor = Color3.fromRGB(50, 54, 68)

	local walls = {
		{ "NorthWall", Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, HubConfig.WALL_THICKNESS), Vector3.new(0, wallY, -halfZ) },
		{ "SouthWall", Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, HubConfig.WALL_THICKNESS), Vector3.new(0, wallY, halfZ) },
		{ "WestWall", Vector3.new(HubConfig.WALL_THICKNESS, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), Vector3.new(-halfX, wallY, 0) },
		{ "EastWall", Vector3.new(HubConfig.WALL_THICKNESS, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), Vector3.new(halfX, wallY, 0) },
	}
	for _, wall in walls do
		makePart(wall[1], wall[2], CFrame.new(wall[3]), wallColor, hub)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = HubConfig.SPAWN_NAME
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 1.5, 0)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zoneConfig in HubConfig.ZONES do
		makeZone(zoneConfig, zonesFolder)
	end

	local centerRing = makePart(
		"CenterRing",
		Vector3.new(16, 0.3, 16),
		CFrame.new(0, 0.65, 0),
		Color3.fromRGB(90, 100, 255),
		hub
	)
	centerRing.Material = Enum.Material.Neon
	centerRing.Transparency = 0.4

	return hub
end

return HubWorldBuilder
