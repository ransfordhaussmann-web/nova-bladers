local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Color = props.Color or Color3.fromRGB(45, 50, 65)
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Name = props.Name or "Part"
	part.Transparency = props.Transparency or 0
	part.Parent = props.Parent
	return part
end

local function addLabel(parent, text, offsetY)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, offsetY or 5, 0)
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
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER
	hub.Parent = workspace

	local floorSize = HubConfig.FLOOR_SIZE
	makePart({
		Name = "Floor",
		Size = floorSize,
		CFrame = CFrame.new(0, 0, 0),
		Color = Color3.fromRGB(35, 40, 52),
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	local wallHeight = HubConfig.WALL_HEIGHT
	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local wallThickness = 2
	local walls = {
		{ Vector3.new(0, wallHeight / 2, -halfZ), Vector3.new(floorSize.X + 4, wallHeight, wallThickness) },
		{ Vector3.new(0, wallHeight / 2, halfZ), Vector3.new(floorSize.X + 4, wallHeight, wallThickness) },
		{ Vector3.new(-halfX, wallHeight / 2, 0), Vector3.new(wallThickness, wallHeight, floorSize.Z + 4) },
		{ Vector3.new(halfX, wallHeight / 2, 0), Vector3.new(wallThickness, wallHeight, floorSize.Z + 4) },
	}
	for i, wall in walls do
		makePart({
			Name = "Wall" .. i,
			Size = wall[2],
			CFrame = CFrame.new(wall[1]),
			Color = Color3.fromRGB(28, 32, 42),
			Parent = hub,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN_OFFSET)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zonePart = makePart({
			Name = "Zone_" .. zone.id,
			Size = zone.size,
			CFrame = CFrame.new(zone.position),
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.35,
			Parent = zonesFolder,
		})
		zonePart:SetAttribute("ZoneId", zone.id)
		zonePart:SetAttribute("Action", zone.action)
		zonePart:SetAttribute("Hint", zone.hint)

		local pad = makePart({
			Name = "Pad",
			Size = Vector3.new(zone.size.X - 2, 0.4, zone.size.Z - 2),
			CFrame = CFrame.new(zone.position + Vector3.new(0, -zone.size.Y / 2 + 0.2, 0)),
			Color = zone.color,
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.15,
			Parent = zonePart,
		})
		pad.CanCollide = false

		addLabel(zonePart, zone.name, zone.size.Y / 2 + 2)
	end

	local centerPillar = makePart({
		Name = "CenterPillar",
		Size = Vector3.new(4, 10, 4),
		CFrame = CFrame.new(0, 5, 0),
		Color = Color3.fromRGB(60, 70, 95),
		Material = Enum.Material.Metal,
		Parent = hub,
	})
	addLabel(centerPillar, "Nova Bladers Hub", 7)

	return hub
end

return HubWorldBuilder
