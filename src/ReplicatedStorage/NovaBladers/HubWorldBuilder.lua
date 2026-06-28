local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color or Color3.fromRGB(70, 75, 90)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Name = props.Name or "Part"
	part.Parent = props.Parent
	return part
end

local function addZoneLabel(parent, text, offsetY)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 48)
	billboard.StudsOffset = Vector3.new(0, offsetY or 6, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
	label.TextColor3 = Color3.fromRGB(240, 244, 255)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.Text = text
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
end

local function buildArenaGate(parent, zone)
	local center = HubConfig.ORIGIN + zone.center

	local platform = makePart({
		Name = "ArenaGatePlatform",
		Parent = parent,
		Size = zone.size + Vector3.new(0, 0.4, 0),
		CFrame = CFrame.new(center + Vector3.new(0, 0.2, 0)),
		Color = zone.color,
		Material = Enum.Material.Neon,
	})

	local leftPillar = makePart({
		Name = "GatePillarLeft",
		Parent = parent,
		Size = Vector3.new(2, 10, 2),
		CFrame = CFrame.new(center + Vector3.new(-5, 5, -2)),
		Color = Color3.fromRGB(45, 50, 65),
	})
	local rightPillar = makePart({
		Name = "GatePillarRight",
		Parent = parent,
		Size = Vector3.new(2, 10, 2),
		CFrame = CFrame.new(center + Vector3.new(5, 5, -2)),
		Color = Color3.fromRGB(45, 50, 65),
	})

	local arch = makePart({
		Name = "GateArch",
		Parent = parent,
		Size = Vector3.new(12, 2, 2),
		CFrame = CFrame.new(center + Vector3.new(0, 10, -2)),
		Color = zone.glowColor,
		Material = Enum.Material.Neon,
	})
	arch:SetAttribute("GlowPart", true)

	local portal = makePart({
		Name = "GatePortal",
		Parent = parent,
		Size = Vector3.new(8, 8, 1),
		CFrame = CFrame.new(center + Vector3.new(0, 5, -2)),
		Color = zone.glowColor,
		Material = Enum.Material.Neon,
	})
	portal.Transparency = 0.45
	portal.CanCollide = false
	portal:SetAttribute("GlowPart", true)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Betreten"
	prompt.ObjectText = zone.label
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.Parent = portal

	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = zone.id
	zoneFolder.Parent = parent

	local marker = makePart({
		Name = "ZoneMarker",
		Parent = zoneFolder,
		Size = zone.size + Vector3.new(0, 8, 0),
		CFrame = CFrame.new(center + Vector3.new(0, 4, 0)),
		Color = zone.color,
	})
	marker.Transparency = 0.92
	marker.CanCollide = false
	marker:SetAttribute("ZoneId", zone.id)

	addZoneLabel(platform, zone.label, 8)

	return zoneFolder, prompt
end

local function buildZone(parent, zone, withPrompt)
	local center = HubConfig.ORIGIN + zone.center

	local platform = makePart({
		Name = zone.id .. "Platform",
		Parent = parent,
		Size = zone.size + Vector3.new(0, 0.3, 0),
		CFrame = CFrame.new(center + Vector3.new(0, 0.15, 0)),
		Color = zone.color,
		Material = Enum.Material.SmoothPlastic,
	})

	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = zone.id
	zoneFolder.Parent = parent

	local marker = makePart({
		Name = "ZoneMarker",
		Parent = zoneFolder,
		Size = zone.size + Vector3.new(0, 6, 0),
		CFrame = CFrame.new(center + Vector3.new(0, 3, 0)),
		Color = zone.color,
	})
	marker.Transparency = 0.94
	marker.CanCollide = false
	marker:SetAttribute("ZoneId", zone.id)

	addZoneLabel(platform, zone.label, 5)

	local prompt
	if withPrompt and zone.prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = zone.prompt
		prompt.ObjectText = zone.label
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.Parent = platform
	end

	if zone.id == "BeyLab" then
		local pad = makePart({
			Name = "DisplayPad",
			Parent = zoneFolder,
			Size = Vector3.new(6, 1, 6),
			CFrame = CFrame.new(center + Vector3.new(0, 1, 0)),
			Color = Color3.fromRGB(120, 170, 255),
			Material = Enum.Material.Glass,
		})
		pad.Transparency = 0.3
	elseif zone.id == "HallOfFame" then
		local pedestal = makePart({
			Name = "Pedestal",
			Parent = zoneFolder,
			Size = Vector3.new(4, 3, 4),
			CFrame = CFrame.new(center + Vector3.new(0, 1.5, 0)),
			Color = Color3.fromRGB(220, 190, 80),
			Material = Enum.Material.Marble,
		})
		local trophy = makePart({
			Name = "Trophy",
			Parent = zoneFolder,
			Size = Vector3.new(2, 2, 2),
			CFrame = CFrame.new(center + Vector3.new(0, 3.5, 0)),
			Color = Color3.fromRGB(255, 215, 90),
			Material = Enum.Material.Neon,
		})
		trophy.Shape = Enum.PartType.Ball
	end

	return zoneFolder, prompt
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
	local mapSize = HubConfig.MAP_SIZE

	makePart({
		Name = "Ground",
		Parent = hub,
		Size = mapSize,
		CFrame = CFrame.new(origin + Vector3.new(0, -0.5, 0)),
		Color = Color3.fromRGB(38, 42, 55),
		Material = Enum.Material.Slate,
	})

	local wallThickness = 2
	local halfX = mapSize.X / 2
	local halfZ = mapSize.Z / 2
	local wallY = HubConfig.WALL_HEIGHT / 2

	for _, wall in {
		{ Vector3.new(0, wallY, -halfZ), Vector3.new(mapSize.X, HubConfig.WALL_HEIGHT, wallThickness) },
		{ Vector3.new(0, wallY, halfZ), Vector3.new(mapSize.X, HubConfig.WALL_HEIGHT, wallThickness) },
		{ Vector3.new(-halfX, wallY, 0), Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, mapSize.Z) },
		{ Vector3.new(halfX, wallY, 0), Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, mapSize.Z) },
	} do
		makePart({
			Name = "Wall",
			Parent = hub,
			Size = wall[2],
			CFrame = CFrame.new(origin + wall[1]),
			Color = Color3.fromRGB(30, 34, 48),
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = HubConfig.ZONES.Spawn.size
	spawn.CFrame = HubConfig.SPAWN_CFRAME
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Parent = hub

	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = hub

	local prompts = {}

	buildZone(zones, HubConfig.ZONES.Spawn, false)

	local arenaFolder, arenaPrompt = buildArenaGate(zones, HubConfig.ZONES.ArenaGate)
	prompts.ArenaGate = arenaPrompt

	local _, beyPrompt = buildZone(zones, HubConfig.ZONES.BeyLab, true)
	prompts.BeyLab = beyPrompt

	local _, hallPrompt = buildZone(zones, HubConfig.ZONES.HallOfFame, true)
	prompts.HallOfFame = hallPrompt

	local lighting = Instance.new("Folder")
	lighting.Name = "Lighting"
	lighting.Parent = hub

	for _, offset in {
		Vector3.new(-20, 10, -20),
		Vector3.new(20, 10, -20),
		Vector3.new(-20, 10, 20),
		Vector3.new(20, 10, 20),
	} do
		local lamp = makePart({
			Name = "Lamp",
			Parent = lighting,
			Size = Vector3.new(1, 1, 1),
			CFrame = CFrame.new(origin + offset),
			Color = Color3.fromRGB(255, 240, 200),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		lamp.Shape = Enum.PartType.Ball

		local light = Instance.new("PointLight")
		light.Brightness = 1.2
		light.Range = 28
		light.Parent = lamp
	end

	return hub, prompts
end

return HubWorldBuilder
