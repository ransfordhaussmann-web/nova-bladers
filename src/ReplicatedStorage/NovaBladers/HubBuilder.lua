local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local BeyCatalog = require(ReplicatedStorage.NovaBladers.BeyCatalog)

local HubBuilder = {}

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

local function addLight(parent, color)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 1.2
	light.Range = 14
	light.Parent = parent
end

local function addBillboard(parent, text, offsetY)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(220, 48)
	gui.StudsOffset = Vector3.new(0, offsetY or 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.TextSize = 18
	label.Text = text
	label.Parent = gui
end

local function addProximityPrompt(parent, actionText, objectText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = actionText
	prompt.ObjectText = objectText or ""
	prompt.MaxActivationDistance = HubConfig.INTERACT_RANGE
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.Parent = parent
	return prompt
end

function HubBuilder.build()
	local existing = workspace:FindFirstChild("NovaBladersHub")
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaBladersHub"
	hub.Parent = workspace

	local origin = HubConfig.ORIGIN
	local theme = HubConfig.THEME

	local floor = makePart(
		"Floor",
		HubConfig.FLOOR.size,
		CFrame.new(origin + Vector3.new(0, -HubConfig.FLOOR.size.Y / 2, 0)),
		HubConfig.FLOOR.color,
		HubConfig.FLOOR.material
	)
	floor.Parent = hub

	local trim = makePart(
		"FloorTrim",
		Vector3.new(HubConfig.FLOOR.size.X + 4, 0.6, HubConfig.FLOOR.size.Z + 4),
		CFrame.new(origin + Vector3.new(0, -HubConfig.FLOOR.size.Y / 2 - 0.3, 0)),
		theme.trim,
		Enum.Material.Metal
	)
	trim.CanCollide = false
	trim.Parent = hub

	local function addPath(name, size, position)
		local path = makePart(name, size, CFrame.new(origin + position), theme.path, Enum.Material.Concrete)
		path.CanCollide = true
		path.Parent = hub
	end

	addPath("PathNorth", Vector3.new(10, 0.4, 34), Vector3.new(0, 0.2, -23))
	addPath("PathWest", Vector3.new(28, 0.4, 10), Vector3.new(-23, 0.2, 0))
	addPath("PathEast", Vector3.new(28, 0.4, 10), Vector3.new(23, 0.2, 0))

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(origin + HubConfig.SPAWN_OFFSET)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = theme.accent
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.35
	spawn.Parent = hub
	addBillboard(spawn, "Nova Bladers Hub", 5)

	local gatePos = origin + HubConfig.ARENA_GATE.position
	local gatePlatform = makePart(
		"ArenaGatePlatform",
		Vector3.new(16, 1, 8),
		CFrame.new(gatePos + Vector3.new(0, 0.5, 0)),
		theme.trim,
		Enum.Material.Metal
	)
	gatePlatform.Parent = hub

	local gatePortal = makePart(
		"ArenaGate",
		Vector3.new(10, 12, 1.2),
		CFrame.new(gatePos + Vector3.new(0, 6.5, -2)),
		theme.glow,
		Enum.Material.Neon
	)
	gatePortal.Transparency = 0.25
	gatePortal.CanCollide = false
	gatePortal.Parent = hub
	addLight(gatePortal, theme.glow)
	addBillboard(gatePortal, "Arena", 7)
	addProximityPrompt(gatePortal, HubConfig.ARENA_GATE.promptText, "Arena-Tor")

	local gateTrigger = makePart(
		"ArenaGateTrigger",
		Vector3.new(HubConfig.ARENA_GATE.radius * 2, 8, HubConfig.ARENA_GATE.radius * 2),
		CFrame.new(gatePos + Vector3.new(0, 4, 0)),
		theme.accent
	)
	gateTrigger.Transparency = 1
	gateTrigger.CanCollide = false
	gateTrigger.Parent = hub

	local statsPos = origin + HubConfig.STATS_BOARD.position
	local statsStand = makePart(
		"StatsBoard",
		Vector3.new(2, 8, 6),
		CFrame.new(statsPos + Vector3.new(0, 4, 0)),
		theme.trim,
		Enum.Material.Metal
	)
	statsStand.Parent = hub

	local statsFace = makePart(
		"StatsFace",
		Vector3.new(5.8, 5.8, 0.2),
		CFrame.new(statsPos + Vector3.new(-1.1, 4.5, 0)),
		Color3.fromRGB(18, 22, 32)
	)
	statsFace.CanCollide = false
	statsFace.Parent = hub

	local statsGui = Instance.new("SurfaceGui")
	statsGui.Name = "StatsGui"
	statsGui.Face = Enum.NormalId.Right
	statsGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	statsGui.PixelsPerStud = 40
	statsGui.Parent = statsFace

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Name = "StatsLabel"
	statsLabel.Size = UDim2.fromScale(1, 1)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Font = Enum.Font.GothamMedium
	statsLabel.TextColor3 = Color3.new(1, 1, 1)
	statsLabel.TextSize = 22
	statsLabel.TextWrapped = true
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.TextYAlignment = Enum.TextYAlignment.Top
	statsLabel.Text = "Deine Stats\nWins: -\nLosses: -\nRank: -"
	statsLabel.Parent = statsGui
	addBillboard(statsStand, "Stats", 5)

	local boardPos = origin + HubConfig.LEADERBOARD.position
	local boardStand = makePart(
		"LeaderboardBoard",
		Vector3.new(2, 10, 8),
		CFrame.new(boardPos + Vector3.new(0, 5, 0)),
		theme.trim,
		Enum.Material.Metal
	)
	boardStand.Parent = hub

	local boardFace = makePart(
		"LeaderboardFace",
		Vector3.new(7.8, 7.8, 0.2),
		CFrame.new(boardPos + Vector3.new(1.1, 5.5, 0)),
		Color3.fromRGB(18, 22, 32)
	)
	boardFace.CanCollide = false
	boardFace.Parent = hub

	local boardGui = Instance.new("SurfaceGui")
	boardGui.Name = "LeaderboardGui"
	boardGui.Face = Enum.NormalId.Left
	boardGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	boardGui.PixelsPerStud = 40
	boardGui.Parent = boardFace

	local boardLabel = Instance.new("TextLabel")
	boardLabel.Name = "LeaderboardLabel"
	boardLabel.Size = UDim2.fromScale(1, 1)
	boardLabel.BackgroundTransparency = 1
	boardLabel.Font = Enum.Font.GothamMedium
	boardLabel.TextColor3 = Color3.new(1, 1, 1)
	boardLabel.TextSize = 20
	boardLabel.TextWrapped = true
	boardLabel.TextXAlignment = Enum.TextXAlignment.Left
	boardLabel.TextYAlignment = Enum.TextYAlignment.Top
	boardLabel.Text = "Top Spieler\nNoch keine Einträge"
	boardLabel.Parent = boardGui
	addBillboard(boardStand, "Leaderboard", 6)

	local showcaseFolder = Instance.new("Folder")
	showcaseFolder.Name = "BeyShowcase"
	showcaseFolder.Parent = hub

	for index, offset in HubConfig.BEY_SHOWCASE_OFFSETS do
		local bey = BeyCatalog[index]
		if not bey then
			continue
		end

		local pos = origin + offset
		local pedestal = makePart(
			bey.id .. "Pedestal",
			Vector3.new(4, 1.2, 4),
			CFrame.new(pos + Vector3.new(0, 0.6, 0)),
			theme.trim,
			Enum.Material.Marble
		)
		pedestal.Parent = showcaseFolder

		local orb = makePart(
			bey.id .. "Orb",
			Vector3.new(2.8, 2.8, 2.8),
			CFrame.new(pos + Vector3.new(0, 2.8, 0)),
			bey.color,
			Enum.Material.Neon
		)
		orb.Shape = Enum.PartType.Ball
		orb.CanCollide = false
		orb.Transparency = 0.15
		orb.Parent = showcaseFolder
		addLight(orb, bey.color)
		addBillboard(orb, bey.name, 2.5)
	end

	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = hub

	local arenaZone = Instance.new("Part")
	arenaZone.Name = "ArenaGateZone"
	arenaZone.Size = Vector3.new(HubConfig.ARENA_GATE.radius * 2, 6, HubConfig.ARENA_GATE.radius * 2)
	arenaZone.CFrame = CFrame.new(gatePos + Vector3.new(0, 3, 0))
	arenaZone.Anchored = true
	arenaZone.CanCollide = false
	arenaZone.Transparency = 1
	arenaZone.Parent = zones

	return hub
end

return HubBuilder
