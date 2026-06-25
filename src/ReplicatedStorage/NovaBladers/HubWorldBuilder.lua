local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(name, size, position, color, anchored, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = anchored ~= false
	part.CanCollide = true
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color or Color3.fromRGB(45, 48, 58)
	if transparency then
		part.Transparency = transparency
	end
	return part
end

local function addZoneLabel(parent, zone)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 18
	label.Text = zone.name
	label.Parent = billboard
end

function HubWorldBuilder.build(parent)
	local existing = parent:FindFirstChild(HubConfig.HUB_FOLDER)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER
	hub.Parent = parent

	local floorY = HubConfig.SPAWN_POSITION.Y - 2.5
	local floor = makePart(
		"Floor",
		HubConfig.FLOOR_SIZE,
		Vector3.new(HubConfig.SPAWN_POSITION.X, floorY, HubConfig.SPAWN_POSITION.Z),
		Color3.fromRGB(35, 38, 48)
	)
	floor.Material = Enum.Material.Slate
	floor.Parent = hub

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallY = floorY + HubConfig.WALL_HEIGHT / 2
	local t = HubConfig.WALL_THICKNESS

	local walls = {
		{ "NorthWall", Vector3.new(HubConfig.FLOOR_SIZE.X + t * 2, HubConfig.WALL_HEIGHT, t), Vector3.new(0, wallY, -halfZ - t / 2) },
		{ "SouthWall", Vector3.new(HubConfig.FLOOR_SIZE.X + t * 2, HubConfig.WALL_HEIGHT, t), Vector3.new(0, wallY, halfZ + t / 2) },
		{ "WestWall", Vector3.new(t, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), Vector3.new(-halfX - t / 2, wallY, 0) },
		{ "EastWall", Vector3.new(t, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), Vector3.new(halfX + t / 2, wallY, 0) },
	}
	for _, spec in walls do
		local wall = makePart(spec[1], spec[2], spec[3], Color3.fromRGB(55, 58, 72))
		wall.Parent = hub
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

	for _, zone in HubConfig.ZONES do
		local marker = makePart(
			zone.id,
			Vector3.new(zone.size.X, 0.4, zone.size.Z),
			Vector3.new(zone.position.X, floorY + 0.7, zone.position.Z),
			zone.color,
			true,
			0.25
		)
		marker.CanCollide = false
		marker.Material = Enum.Material.Neon
		marker:SetAttribute("ZoneId", zone.id)
		marker:SetAttribute("Action", zone.action)
		marker.Parent = zonesFolder
		addZoneLabel(marker, zone)
	end

	local centerSign = makePart(
		"CenterSign",
		Vector3.new(8, 0.3, 8),
		Vector3.new(0, floorY + 0.5, 0),
		Color3.fromRGB(100, 110, 255),
		true,
		0.4
	)
	centerSign.CanCollide = false
	centerSign.Material = Enum.Material.Neon
	centerSign.Parent = hub
	addZoneLabel(centerSign, { name = "Nova Bladers Hub" })

	return hub
end

return HubWorldBuilder
