local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local BeyCatalog = require(NovaBladers.BeyCatalog)
local HubConfig = require(NovaBladers.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	return part
end

local function addBillboard(parent, text, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 50)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.Text = text
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	return gui
end

local function addZoneMarker(folder, zoneId, zone, color)
	local marker = makePart({
		Name = zoneId,
		Size = Vector3.new(zone.radius * 2, 0.4, zone.radius * 2),
		Position = zone.position + Vector3.new(0, 0.3, 0),
		Shape = Enum.PartType.Cylinder,
		Orientation = Vector3.new(0, 0, 90),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		CanCollide = false,
	})
	marker:SetAttribute("ZoneId", zoneId)
	marker.Parent = folder

	local pillar = makePart({
		Name = zoneId .. "Sign",
		Size = Vector3.new(2, 6, 2),
		Position = zone.position + Vector3.new(0, 3.5, 0),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
	})
	pillar.Parent = folder
	addBillboard(pillar, zone.label, color)

	return marker
end

local function buildArenaGate(parent, zone, color)
	local gateFolder = Instance.new("Folder")
	gateFolder.Name = "ArenaGate"
	gateFolder.Parent = parent

	local basePos = zone.position
	local leftPillar = makePart({
		Name = "LeftPillar",
		Size = Vector3.new(3, 12, 3),
		Position = basePos + Vector3.new(-6, 6, 0),
		Color = color,
		Material = Enum.Material.Metal,
	})
	leftPillar.Parent = gateFolder

	local rightPillar = makePart({
		Name = "RightPillar",
		Size = Vector3.new(3, 12, 3),
		Position = basePos + Vector3.new(6, 6, 0),
		Color = color,
		Material = Enum.Material.Metal,
	})
	rightPillar.Parent = gateFolder

	local arch = makePart({
		Name = "Arch",
		Size = Vector3.new(15, 2, 3),
		Position = basePos + Vector3.new(0, 12.5, 0),
		Color = color,
		Material = Enum.Material.Neon,
	})
	arch.Parent = gateFolder

	local portal = makePart({
		Name = "Portal",
		Size = Vector3.new(8, 10, 1),
		Position = basePos + Vector3.new(0, 6, 0),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
	})
	portal.Parent = gateFolder

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterArenaPrompt"
	prompt.ActionText = "Betreten"
	prompt.ObjectText = zone.prompt
	prompt.MaxActivationDistance = zone.radius
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = portal

	addBillboard(arch, zone.label, color)
	addZoneMarker(parent, "ArenaGate", zone, color)

	return gateFolder
end

local function buildBeyGarage(parent, zone, color)
	local garageFolder = Instance.new("Folder")
	garageFolder.Name = "BeyGarage"
	garageFolder.Parent = parent

	local platform = makePart({
		Name = "GaragePlatform",
		Size = Vector3.new(zone.radius * 2, 1, zone.radius * 2),
		Position = zone.position + Vector3.new(0, 0.5, 0),
		Color = HubConfig.COLORS.platformAccent,
		Material = Enum.Material.Slate,
	})
	platform.Parent = garageFolder

	local count = math.min(HubConfig.BEY_PEDESTAL_COUNT, #BeyCatalog)
	for index, bey in BeyCatalog do
		if index > count then break end
		local angle = (index - 1) * (math.pi * 2 / count)
		local offset = Vector3.new(
			math.cos(angle) * HubConfig.BEY_PEDESTAL_RADIUS,
			0,
			math.sin(angle) * HubConfig.BEY_PEDESTAL_RADIUS
		)
		local pos = zone.position + offset

		local pedestal = makePart({
			Name = bey.id .. "Pedestal",
			Size = Vector3.new(4, 1.5, 4),
			Position = pos + Vector3.new(0, 1.25, 0),
			Color = bey.color,
			Material = Enum.Material.SmoothPlastic,
		})
		pedestal:SetAttribute("BeyId", bey.id)
		pedestal.Parent = garageFolder

		local ring = makePart({
			Name = bey.id .. "Ring",
			Size = Vector3.new(5, 0.3, 5),
			Position = pos + Vector3.new(0, 2.2, 0),
			Shape = Enum.PartType.Cylinder,
			Orientation = Vector3.new(0, 0, 90),
			Color = bey.color,
			Material = Enum.Material.Neon,
			Transparency = 0.4,
			CanCollide = false,
		})
		ring.Parent = garageFolder

		addBillboard(pedestal, bey.name, bey.color)
	end

	addZoneMarker(parent, "BeyGarage", zone, color)
	return garageFolder
end

local function buildHallOfFame(parent, zone, color)
	local hallFolder = Instance.new("Folder")
	hallFolder.Name = "HallOfFame"
	hallFolder.Parent = parent

	local pillar = makePart({
		Name = "LeaderboardPillar",
		Size = Vector3.new(8, HubConfig.LEADERBOARD_HEIGHT, 3),
		Position = zone.position + Vector3.new(0, HubConfig.LEADERBOARD_HEIGHT / 2, 0),
		Color = HubConfig.COLORS.platformAccent,
		Material = Enum.Material.Marble,
	})
	pillar.Parent = hallFolder

	local surface = Instance.new("SurfaceGui")
	surface.Name = "LeaderboardSurface"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.Parent = pillar

	local label = Instance.new("TextLabel")
	label.Name = "LeaderboardLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	label.BackgroundTransparency = 0.15
	label.TextColor3 = color
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 22
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = "🏆 Top Spieler\nLade..."
	label.Parent = surface

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = label

	addBillboard(pillar, zone.label, color)
	addZoneMarker(parent, "HallOfFame", zone, color)

	return hallFolder
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER
	hub.Parent = workspace

	local platform = makePart({
		Name = "MainPlatform",
		Size = Vector3.new(HubConfig.PLATFORM_RADIUS * 2, HubConfig.PLATFORM_HEIGHT, HubConfig.PLATFORM_RADIUS * 2),
		Position = Vector3.new(0, HubConfig.PLATFORM_HEIGHT / 2, 0),
		Shape = Enum.PartType.Cylinder,
		Orientation = Vector3.new(0, 0, 90),
		Color = HubConfig.COLORS.platform,
		Material = Enum.Material.Concrete,
	})
	platform.Parent = hub

	local rim = makePart({
		Name = "PlatformRim",
		Size = Vector3.new(HubConfig.PLATFORM_RADIUS * 2 + 4, HubConfig.RIM_HEIGHT, HubConfig.PLATFORM_RADIUS * 2 + 4),
		Position = Vector3.new(0, HubConfig.RIM_HEIGHT / 2, 0),
		Shape = Enum.PartType.Cylinder,
		Orientation = Vector3.new(0, 0, 90),
		Color = HubConfig.COLORS.rim,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		CanCollide = false,
	})
	rim.Parent = hub

	local spawnGlow = makePart({
		Name = "SpawnGlow",
		Size = Vector3.new(10, 0.4, 10),
		Position = HubConfig.SPAWN + Vector3.new(0, -2.5, 0),
		Shape = Enum.PartType.Cylinder,
		Orientation = Vector3.new(0, 0, 90),
		Color = HubConfig.COLORS.spawnGlow,
		Material = Enum.Material.Neon,
		Transparency = 0.4,
		CanCollide = false,
	})
	spawnGlow.Parent = hub

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = HubConfig.SPAWN
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	buildArenaGate(zonesFolder, HubConfig.ZONES.ArenaGate, HubConfig.COLORS.arenaGate)
	buildBeyGarage(zonesFolder, HubConfig.ZONES.BeyGarage, HubConfig.COLORS.beyGarage)
	buildHallOfFame(zonesFolder, HubConfig.ZONES.HallOfFame, HubConfig.COLORS.hallOfFame)

	local lighting = Instance.new("Folder")
	lighting.Name = "Lighting"
	lighting.Parent = hub

	for i = 1, 8 do
		local angle = (i - 1) * (math.pi * 2 / 8)
		local dist = HubConfig.PLATFORM_RADIUS - 6
		local lamp = makePart({
			Name = "Lamp" .. i,
			Size = Vector3.new(1.5, 8, 1.5),
			Position = Vector3.new(math.cos(angle) * dist, 4, math.sin(angle) * dist),
			Color = HubConfig.COLORS.rim,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		lamp.Parent = lighting

		local light = Instance.new("PointLight")
		light.Brightness = 1.2
		light.Range = 28
		light.Color = HubConfig.COLORS.rim
		light.Parent = lamp
	end

	return hub
end

return HubWorldBuilder
