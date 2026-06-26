local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local BeyCatalog = require(ReplicatedStorage.NovaBladers.BeyCatalog)

local HubBuilder = {}

local HUB_FOLDER_NAME = "NovaHub"
local ZONE_TAG = "HubZone"

local function setPartDefaults(part)
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function makePart(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	setPartDefaults(part)
	part.Parent = parent
	return part
end

local function makeNeonRing(parent, name, center, radius, color)
	local ring = makePart(
		parent,
		name,
		Vector3.new(radius * 2, 0.25, radius * 2),
		CFrame.new(center + Vector3.new(0, 0.15, 0)),
		color,
		Enum.Material.Neon
	)
	ring.Shape = Enum.PartType.Cylinder
	ring.CFrame = CFrame.new(center + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.CanCollide = false
	return ring
end

local function tagZone(part, zoneId)
	part:SetAttribute("ZoneId", zoneId)
	CollectionService:AddTag(part, ZONE_TAG)
end

local function buildFloor(parent, origin)
	local colors = HubConfig.COLORS
	local tileSize = 12
	local tiles = math.ceil((HubConfig.FLOOR_RADIUS * 2) / tileSize)
	local half = tiles / 2

	for x = 0, tiles - 1 do
		for z = 0, tiles - 1 do
			local localX = (x - half + 0.5) * tileSize
			local localZ = (z - half + 0.5) * tileSize
			if Vector2.new(localX, localZ).Magnitude <= HubConfig.FLOOR_RADIUS then
				local isAccent = (x + z) % 3 == 0
				makePart(
					parent,
					"FloorTile",
					Vector3.new(tileSize, 2, tileSize),
					CFrame.new(origin + Vector3.new(localX, HubConfig.FLOOR_Y - 1, localZ)),
					isAccent and colors.floorAccent or colors.floor,
					Enum.Material.Slate
				)
			end
		end
	end
end

local function buildEdgeRailings(parent, origin)
	local colors = HubConfig.COLORS
	local segments = 24
	local angleStep = (math.pi * 2) / segments

	for i = 0, segments - 1 do
		local angle = i * angleStep
		local x = math.cos(angle) * HubConfig.FLOOR_RADIUS
		local z = math.sin(angle) * HubConfig.FLOOR_RADIUS
		local pos = origin + Vector3.new(x, 6, z)
		local facing = CFrame.lookAt(pos, origin + Vector3.new(0, 6, 0))

		local rail = makePart(
			parent,
			"Railing",
			Vector3.new(8, 12, 0.6),
			facing,
			colors.railing,
			Enum.Material.Metal
		)
		rail.Transparency = 0.35
	end
end

local function buildArenaGate(parent, origin, zone)
	local colors = HubConfig.COLORS
	local base = origin + zone.position

	local platform = makePart(
		parent,
		"ArenaGatePlatform",
		Vector3.new(14, 1, 10),
		CFrame.new(base + Vector3.new(0, 0.5, 0)),
		colors.floorAccent,
		Enum.Material.Concrete
	)
	tagZone(platform, "ArenaGate")

	local leftPillar = makePart(
		parent,
		"GatePillarLeft",
		Vector3.new(1.5, 12, 1.5),
		CFrame.new(base + Vector3.new(-5, 6, 0)),
		colors.railing,
		Enum.Material.Metal
	)
	local rightPillar = makePart(
		parent,
		"GatePillarRight",
		Vector3.new(1.5, 12, 1.5),
		CFrame.new(base + Vector3.new(5, 6, 0)),
		colors.railing,
		Enum.Material.Metal
	)

	local arch = makePart(
		parent,
		"GateArch",
		Vector3.new(12, 1.5, 1.5),
		CFrame.new(base + Vector3.new(0, 11, 0)),
		colors.neon,
		Enum.Material.Neon
	)
	arch.CanCollide = false

	makeNeonRing(parent, "GateRing", base, 5, colors.neonDim)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ArenaPrompt"
	prompt.ActionText = "Start"
	prompt.ObjectText = zone.prompt
	prompt.MaxActivationDistance = zone.radius
	prompt.HoldDuration = 0
	prompt.Parent = platform

	local sign = makePart(
		parent,
		"GateSign",
		Vector3.new(8, 3, 0.4),
		CFrame.new(base + Vector3.new(0, 8, -3)),
		colors.floorAccent,
		Enum.Material.SmoothPlastic
	)
	sign.CanCollide = false

	local gui = Instance.new("SurfaceGui")
	gui.Name = "GateLabel"
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = colors.neon
	label.TextScaled = true
	label.Text = "ARENA"
	label.Parent = gui

	return platform
end

local function buildStatsKiosk(parent, origin, zone)
	local colors = HubConfig.COLORS
	local base = origin + zone.position

	local kiosk = makePart(
		parent,
		"StatsKiosk",
		Vector3.new(6, 8, 2),
		CFrame.new(base + Vector3.new(0, 4, 0)),
		colors.floorAccent,
		Enum.Material.SmoothPlastic
	)
	tagZone(kiosk, "StatsKiosk")

	local screen = makePart(
		parent,
		"StatsScreen",
		Vector3.new(5, 4, 0.2),
		CFrame.new(base + Vector3.new(0, 5.5, -1.1)),
		Color3.fromRGB(10, 12, 20),
		Enum.Material.Glass
	)
	screen.CanCollide = false

	local gui = Instance.new("SurfaceGui")
	gui.Name = "StatsDisplay"
	gui.Face = Enum.NormalId.Front
	gui.Parent = screen

	local label = Instance.new("TextLabel")
	label.Name = "StatsLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Text = "Wins: 0\nLosses: 0\nRank: -"
	label.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StatsPrompt"
	prompt.ActionText = "Ansehen"
	prompt.ObjectText = zone.prompt
	prompt.MaxActivationDistance = zone.radius
	prompt.Parent = kiosk

	return kiosk
end

local function buildLeaderboardMonument(parent, origin, zone)
	local colors = HubConfig.COLORS
	local base = origin + zone.position

	local pillar = makePart(
		parent,
		"LeaderboardPillar",
		Vector3.new(4, 14, 4),
		CFrame.new(base + Vector3.new(0, 7, 0)),
		colors.railing,
		Enum.Material.Metal
	)
	tagZone(pillar, "Leaderboard")

	local board = makePart(
		parent,
		"LeaderboardBoard",
		Vector3.new(10, 8, 0.5),
		CFrame.new(base + Vector3.new(-6, 8, 0)) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(12, 14, 22),
		Enum.Material.SmoothPlastic
	)
	board.CanCollide = false

	local gui = Instance.new("SurfaceGui")
	gui.Name = "LeaderboardDisplay"
	gui.Face = Enum.NormalId.Front
	gui.Parent = board

	local label = Instance.new("TextLabel")
	label.Name = "LeaderboardLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = colors.neon
	label.TextScaled = true
	label.Text = "Top Spieler\n(laden...)"
	label.Parent = gui

	makeNeonRing(parent, "LeaderboardRing", base, 4, colors.neon)

	return board
end

local function buildBeyShowcase(parent, origin, zone)
	local colors = HubConfig.COLORS
	local center = origin + zone.position
	local count = #BeyCatalog
	local arcSpan = math.pi * 0.85
	local startAngle = math.pi / 2 + arcSpan / 2

	for i, bey in BeyCatalog do
		local t = (i - 1) / math.max(count - 1, 1)
		local angle = startAngle - t * arcSpan
		local offset = Vector3.new(math.cos(angle) * 8, 0, math.sin(angle) * 8)
		local pedestalPos = center + offset

		local pedestal = makePart(
			parent,
			bey.id .. "Pedestal",
			Vector3.new(4, 3, 4),
			CFrame.new(pedestalPos + Vector3.new(0, 1.5, 0)),
			colors.floorAccent,
			Enum.Material.Marble
		)

		makeNeonRing(parent, bey.id .. "Ring", pedestalPos, 2.2, bey.color)

		local namePlate = makePart(
			parent,
			bey.id .. "NamePlate",
			Vector3.new(3.5, 1.2, 0.3),
			CFrame.new(pedestalPos + Vector3.new(0, 3.5, 2)),
			colors.floorAccent,
			Enum.Material.SmoothPlastic
		)
		namePlate.CanCollide = false

		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.Parent = namePlate

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = bey.color
		label.TextScaled = true
		label.Text = bey.name
		label.Parent = gui
	end

	local showcaseMarker = makePart(
		parent,
		"BeyShowcaseZone",
		Vector3.new(zone.radius * 2, 1, zone.radius * 2),
		CFrame.new(center + Vector3.new(0, 0.5, 0)),
		colors.neonDim,
		Enum.Material.Neon
	)
	showcaseMarker.Transparency = 0.85
	showcaseMarker.CanCollide = false
	tagZone(showcaseMarker, "BeyShowcase")
end

local function buildSpawn(parent, origin)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(origin + HubConfig.SPAWN_OFFSET - Vector3.new(0, 2, 0))
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = parent
	return spawn
end

local function buildLighting(parent, origin)
	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 80
	light.Color = HubConfig.COLORS.neon

	local beacon = makePart(
		parent,
		"HubBeacon",
		Vector3.new(2, 2, 2),
		CFrame.new(origin + Vector3.new(0, 18, 0)),
		HubConfig.COLORS.neon,
		Enum.Material.Neon
	)
	beacon.CanCollide = false
	beacon.Shape = Enum.PartType.Ball
	light.Parent = beacon
end

function HubBuilder.getHubFolder()
	return workspace:FindFirstChild(HUB_FOLDER_NAME)
end

function HubBuilder.getZonePart(zoneId)
	local hub = HubBuilder.getHubFolder()
	if not hub then
		return nil
	end
	for _, inst in CollectionService:GetTagged(ZONE_TAG) do
		if inst:IsDescendantOf(hub) and inst:GetAttribute("ZoneId") == zoneId then
			return inst
		end
	end
	return nil
end

function HubBuilder.getLeaderboardLabel()
	local hub = HubBuilder.getHubFolder()
	if not hub then
		return nil
	end
	local board = hub:FindFirstChild("LeaderboardBoard", true)
	if board then
		local gui = board:FindFirstChild("LeaderboardDisplay")
		if gui then
			return gui:FindFirstChild("LeaderboardLabel")
		end
	end
	return nil
end

function HubBuilder.getStatsLabel()
	local hub = HubBuilder.getHubFolder()
	if not hub then
		return nil
	end
	local screen = hub:FindFirstChild("StatsScreen", true)
	if screen then
		local gui = screen:FindFirstChild("StatsDisplay")
		if gui then
			return gui:FindFirstChild("StatsLabel")
		end
	end
	return nil
end

function HubBuilder.ensureBuilt()
	local existing = workspace:FindFirstChild(HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local origin = HubConfig.ORIGIN
	local hub = Instance.new("Folder")
	hub.Name = HUB_FOLDER_NAME
	hub.Parent = workspace

	buildFloor(hub, origin)
	buildEdgeRailings(hub, origin)
	buildArenaGate(hub, origin, HubConfig.ZONES.ArenaGate)
	buildStatsKiosk(hub, origin, HubConfig.ZONES.StatsKiosk)
	buildLeaderboardMonument(hub, origin, HubConfig.ZONES.Leaderboard)
	buildBeyShowcase(hub, origin, HubConfig.ZONES.BeyShowcase)
	buildSpawn(hub, origin)
	buildLighting(hub, origin)

	return hub
end

return HubBuilder
