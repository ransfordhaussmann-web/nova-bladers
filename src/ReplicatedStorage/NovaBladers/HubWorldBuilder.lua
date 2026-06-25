local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color or Color3.fromRGB(30, 32, 40)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Name = props.Name or "Part"
	part.Parent = props.Parent
	return part
end

local function addZoneLabel(parent, zone)
	local anchor = makePart({
		Name = zone.id .. "_Marker",
		Size = Vector3.new(6, 0.4, 6),
		CFrame = CFrame.new(zone.position + Vector3.new(0, 0.2, 0)),
		Color = zone.color,
		Material = Enum.Material.Neon,
		Parent = parent,
	})

	local pillar = makePart({
		Name = zone.id .. "_Pillar",
		Size = Vector3.new(1.2, 8, 1.2),
		CFrame = CFrame.new(zone.position + Vector3.new(0, 4, 0)),
		Color = zone.color,
		Material = Enum.Material.Neon,
		Parent = parent,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, 5.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = pillar

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 18
	label.Text = zone.name
	label.Parent = billboard

	local ring = makePart({
		Name = zone.id .. "_Ring",
		Size = Vector3.new(zone.radius * 2, 0.15, zone.radius * 2),
		CFrame = CFrame.new(zone.position + Vector3.new(0, 0.08, 0)),
		Color = zone.color,
		Material = Enum.Material.Neon,
		Parent = parent,
	})
	ring.Transparency = 0.55

	return anchor
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local origin = HubConfig.ORIGIN
	local floorW, floorD = HubConfig.FLOOR_SIZE.X, HubConfig.FLOOR_SIZE.Y

	makePart({
		Name = "Floor",
		Size = Vector3.new(floorW, 1, floorD),
		CFrame = CFrame.new(origin + Vector3.new(0, -0.5, 0)),
		Color = Color3.fromRGB(22, 24, 32),
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	local wallH = HubConfig.WALL_HEIGHT
	local wallThickness = 2
	local halfW, halfD = floorW / 2, floorD / 2

	local walls = {
		{ Vector3.new(floorW + wallThickness, wallH, wallThickness), Vector3.new(0, wallH / 2, halfD) },
		{ Vector3.new(floorW + wallThickness, wallH, wallThickness), Vector3.new(0, wallH / 2, -halfD) },
		{ Vector3.new(wallThickness, wallH, floorD + wallThickness), Vector3.new(halfW, wallH / 2, 0) },
		{ Vector3.new(wallThickness, wallH, floorD + wallThickness), Vector3.new(-halfW, wallH / 2, 0) },
	}

	for index, wall in walls do
		makePart({
			Name = "Wall" .. index,
			Size = wall[1],
			CFrame = CFrame.new(origin + wall[2]),
			Color = Color3.fromRGB(40, 44, 58),
			Material = Enum.Material.Concrete,
			Parent = hub,
		})
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		addZoneLabel(zonesFolder, zone)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = HubConfig.SPAWN
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hub

	return hub
end

return HubWorldBuilder
