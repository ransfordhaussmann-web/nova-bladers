local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.new(1, 1, 1)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Transparency = props.transparency or 0
	part.Name = props.name or "Part"
	if props.shape then
		part.Shape = props.shape
	end
	part.Parent = props.parent
	return part
end

local function makeSign(parent, cframe, title, subtitle)
	local post = makePart({
		parent = parent,
		name = "SignPost",
		size = Vector3.new(0.6, 5, 0.6),
		cframe = cframe * CFrame.new(0, 2.5, 0),
		color = HubConfig.COLORS.Sign,
		material = Enum.Material.Metal,
	})

	local board = makePart({
		parent = parent,
		name = "SignBoard",
		size = Vector3.new(6, 3, 0.3),
		cframe = cframe * CFrame.new(0, 5.2, 0),
		color = HubConfig.COLORS.FloorAccent,
	})

	local titleGui = Instance.new("SurfaceGui")
	titleGui.Face = Enum.NormalId.Front
	titleGui.Parent = board

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.fromScale(1, 0.55)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextScaled = true
	titleLabel.Text = title
	titleLabel.Parent = titleGui

	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subLabel.Position = UDim2.fromScale(0, 0.55)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextColor3 = Color3.fromRGB(180, 185, 200)
	subLabel.TextScaled = true
	subLabel.Text = subtitle or ""
	subLabel.Parent = titleGui

	return post, board
end

local function makeZonePlatform(parent, zoneKey, zone, color)
	local folder = Instance.new("Folder")
	folder.Name = zoneKey
	folder.Parent = parent

	local platform = makePart({
		parent = folder,
		name = "Platform",
		size = Vector3.new(zone.size.X, 0.4, zone.size.Z),
		cframe = CFrame.new(zone.center + Vector3.new(0, 0.2, 0)),
		color = color,
		material = Enum.Material.Neon,
		transparency = 0.55,
		canCollide = false,
	})

	local marker = Instance.new("Part")
	marker.Name = "ZoneMarker"
	marker.Anchored = true
	marker.CanCollide = false
	marker.Transparency = 1
	marker.Size = zone.size
	marker.CFrame = CFrame.new(zone.center + Vector3.new(0, zone.size.Y * 0.5, 0))
	marker.Parent = folder

	return folder, marker
end

function HubWorldBuilder.build(parent)
	local existing = parent:FindFirstChild("NovaHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Model")
	hub.Name = "NovaHub"
	hub.Parent = parent

	local origin = HubConfig.ORIGIN
	local floorSize = HubConfig.FLOOR_SIZE

	makePart({
		parent = hub,
		name = "Floor",
		size = floorSize,
		cframe = CFrame.new(origin + Vector3.new(0, -0.5, 0)),
		color = HubConfig.COLORS.Floor,
		material = Enum.Material.Slate,
	})

	makePart({
		parent = hub,
		name = "FloorAccent",
		size = Vector3.new(floorSize.X * 0.6, 0.2, floorSize.Z * 0.4),
		cframe = CFrame.new(origin + Vector3.new(0, 0.05, 0)),
		color = HubConfig.COLORS.FloorAccent,
		material = Enum.Material.SmoothPlastic,
	})

	local halfX = floorSize.X * 0.5
	local halfZ = floorSize.Z * 0.5
	local wallH = HubConfig.WALL_HEIGHT
	local wallY = wallH * 0.5

	local walls = {
		{ Vector3.new(0, wallY, -halfZ), Vector3.new(floorSize.X, wallH, 1) },
		{ Vector3.new(0, wallY, halfZ), Vector3.new(floorSize.X, wallH, 1) },
		{ Vector3.new(-halfX, wallY, 0), Vector3.new(1, wallH, floorSize.Z) },
		{ Vector3.new(halfX, wallY, 0), Vector3.new(1, wallH, floorSize.Z) },
	}

	for i, wall in walls do
		makePart({
			parent = hub,
			name = "Wall" .. i,
			size = wall[2],
			cframe = CFrame.new(origin + wall[1]),
			color = HubConfig.COLORS.Wall,
			material = Enum.Material.Concrete,
		})
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	local zoneColors = {
		Spawn = HubConfig.COLORS.FloorAccent,
		ArenaGate = HubConfig.COLORS.ArenaPad,
		BeyLab = HubConfig.COLORS.BeyLab,
		HallOfFame = HubConfig.COLORS.HallOfFame,
	}

	for zoneKey, zone in HubConfig.ZONES do
		makeZonePlatform(zonesFolder, zoneKey, zone, zoneColors[zoneKey] or HubConfig.COLORS.FloorAccent)
	end

	local arenaZone = HubConfig.ZONES.ArenaGate
	local arenaPad = makePart({
		parent = hub,
		name = "ArenaPad",
		size = Vector3.new(10, 0.5, 8),
		cframe = CFrame.new(arenaZone.center + Vector3.new(0, 0.35, 0)),
		color = HubConfig.COLORS.ArenaPad,
		material = Enum.Material.Neon,
		transparency = 0.25,
	})

	local padLight = Instance.new("PointLight")
	padLight.Color = HubConfig.COLORS.ArenaPad
	padLight.Brightness = 2
	padLight.Range = 14
	padLight.Parent = arenaPad

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Arena betreten"
	prompt.ObjectText = "Nova Arena"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.Parent = arenaPad

	makeSign(
		hub,
		CFrame.new(arenaZone.center + Vector3.new(0, 0, -arenaZone.size.Z * 0.5 - 3)),
		"Arena-Tor",
		"Kämpfe in der Bowl"
	)

	local beyZone = HubConfig.ZONES.BeyLab
	makeSign(
		hub,
		CFrame.new(beyZone.center + Vector3.new(0, 0, beyZone.size.Z * 0.5 + 2)),
		"Bey-Labor",
		"Wähle deinen Kämpfer"
	)

	local hallZone = HubConfig.ZONES.HallOfFame
	makeSign(
		hub,
		CFrame.new(hallZone.center + Vector3.new(0, 0, hallZone.size.Z * 0.5 + 2)),
		"Ruhmeshalle",
		"Globale Bestenliste"
	)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = HubConfig.SPAWN_CFRAME
	spawn.Neutral = true
	spawn.Parent = hub

	return hub, arenaPad, prompt
end

return HubWorldBuilder
