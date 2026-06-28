local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function anchor(part)
	part.Anchored = true
	part.CanCollide = true
	return part
end

local function makePart(name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return anchor(part)
end

local function addBillboard(parent, title, subtitle, color)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ZoneLabel"
	gui.Size = UDim2.fromOffset(200, 60)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 18
	titleLabel.TextColor3 = color
	titleLabel.Text = title
	titleLabel.Parent = gui

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "Subtitle"
	subLabel.Position = UDim2.fromScale(0, 0.55)
	subLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextSize = 13
	subLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	subLabel.Text = subtitle
	subLabel.Parent = gui
end

local function addProximityPrompt(parent, actionText, objectText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

function HubWorldBuilder.build(origin)
	origin = origin or HubConfig.ORIGIN

	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local floor = makePart(
		"HubFloor",
		HubConfig.FLOOR_SIZE,
		CFrame.new(origin + Vector3.new(0, -0.5, 0)),
		Color3.fromRGB(45, 55, 70),
		Enum.Material.Slate
	)
	floor.Parent = hub

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(origin + HubConfig.SPAWN_OFFSET)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	local zoneParts = {}

	for zoneId, zone in HubConfig.ZONES do
		local zoneFolder = Instance.new("Folder")
		zoneFolder.Name = zoneId
		zoneFolder.Parent = hub

		local worldPos = origin + zone.position
		local building = makePart(
			"Building",
			zone.size,
			CFrame.new(worldPos + Vector3.new(0, zone.size.Y / 2, 0)),
			zone.color,
			Enum.Material.Neon
		)
		building.Transparency = 0.25
		building.Parent = zoneFolder

		local pad = makePart(
			"Pad",
			Vector3.new(zone.size.X - 2, 0.4, zone.size.Z - 2),
			CFrame.new(worldPos + Vector3.new(0, 0.2, 0)),
			zone.color:Lerp(Color3.new(1, 1, 1), 0.35),
			Enum.Material.Concrete
		)
		pad.Parent = zoneFolder

		local trigger = makePart(
			"ZoneTrigger",
			Vector3.new(zone.size.X + 4, zone.size.Y, zone.size.Z + 4),
			CFrame.new(worldPos + Vector3.new(0, zone.size.Y / 2, 0)),
			zone.color
		)
		trigger.Transparency = 1
		trigger.CanCollide = false
		trigger.Parent = zoneFolder

		addBillboard(building, zone.name, zone.subtitle, zone.color)
		addProximityPrompt(pad, "Interagieren", zone.name)

		zoneParts[zoneId] = trigger
	end

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = 3
	local wallThickness = 2
	local wallColor = Color3.fromRGB(30, 35, 45)

	local walls = {
		{ Vector3.new(0, wallH / 2, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, wallThickness) },
		{ Vector3.new(0, wallH / 2, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, wallThickness) },
		{ Vector3.new(-halfX, wallH / 2, 0), Vector3.new(wallThickness, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(halfX, wallH / 2, 0), Vector3.new(wallThickness, wallH, HubConfig.FLOOR_SIZE.Z) },
	}

	local borders = Instance.new("Folder")
	borders.Name = "Borders"
	borders.Parent = hub

	for i, spec in walls do
		local wall = makePart("Wall" .. i, spec[2], CFrame.new(origin + spec[1]), wallColor, Enum.Material.Brick)
		wall.Parent = borders
	end

	local path = makePart(
		"MainPath",
		Vector3.new(8, 0.15, 40),
		CFrame.new(origin + Vector3.new(0, 0.08, -22)),
		Color3.fromRGB(70, 75, 90),
		Enum.Material.Cobblestone
	)
	path.CanCollide = false
	path.Parent = hub

	return hub, zoneParts
end

return HubWorldBuilder
