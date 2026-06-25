local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local BeyCatalog = require(ReplicatedStorage.NovaBladers.BeyCatalog)

local HubWorldBuilder = {}

local function createPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Color = props.Color or Color3.fromRGB(60, 60, 60)
	part.Size = props.Size or Vector3.new(4, 1, 4)
	part.CFrame = props.CFrame or CFrame.new(HubConfig.ORIGIN)
	part.Name = props.Name or "Part"
	part.Transparency = props.Transparency or 0
	part.Parent = props.Parent
	return part
end

local function createSurfaceGui(part, name)
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = part

	local frame = Instance.new("Frame")
	frame.Name = "Background"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(18, 20, 32)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Content"
	label.Size = UDim2.new(1, -16, 1, -16)
	label.Position = UDim2.fromOffset(8, 8)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(230, 235, 255)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 22
	label.Text = ""
	label.Parent = frame

	return label
end

local function buildPlatform(parent)
	local origin = HubConfig.ORIGIN
	local radius = HubConfig.PLATFORM_RADIUS
	local height = HubConfig.PLATFORM_HEIGHT

	createPart({
		Name = "MainPlatform",
		Size = Vector3.new(radius * 2, height, radius * 2),
		CFrame = CFrame.new(origin + Vector3.new(0, height / 2, 0)),
		Color = HubConfig.COLORS.Platform,
		Material = Enum.Material.Slate,
		Parent = parent,
	})

	createPart({
		Name = "PlatformRim",
		Size = Vector3.new(radius * 2 + 4, 0.4, radius * 2 + 4),
		CFrame = CFrame.new(origin + Vector3.new(0, height + 0.2, 0)),
		Color = HubConfig.COLORS.Rim,
		Material = Enum.Material.Neon,
		Parent = parent,
	})

	for i = 0, 7 do
		local angle = math.rad(i * 45)
		local dist = radius - 6
		local pos = origin + Vector3.new(math.sin(angle) * dist, height + 0.5, math.cos(angle) * dist)
		createPart({
			Name = "PathMarker_" .. i,
			Size = Vector3.new(3, 0.2, 3),
			CFrame = CFrame.new(pos),
			Color = HubConfig.COLORS.PlatformAccent,
			Material = Enum.Material.Metal,
			Parent = parent,
		})
	end
end

local function buildArenaGate(parent)
	local zone = HubConfig.ZONES.ArenaGate
	local pos = HubConfig.worldPosition(zone.position + Vector3.new(0, zone.size.Y / 2, 0))

	local gateFolder = Instance.new("Folder")
	gateFolder.Name = "ArenaGate"
	gateFolder.Parent = parent

	local leftPillar = createPart({
		Name = "LeftPillar",
		Size = Vector3.new(2, zone.size.Y, 2),
		CFrame = CFrame.new(pos + Vector3.new(-zone.size.X / 2 + 1, 0, 0)),
		Color = HubConfig.COLORS.Gate,
		Material = Enum.Material.Metal,
		Parent = gateFolder,
	})

	local rightPillar = createPart({
		Name = "RightPillar",
		Size = Vector3.new(2, zone.size.Y, 2),
		CFrame = CFrame.new(pos + Vector3.new(zone.size.X / 2 - 1, 0, 0)),
		Color = HubConfig.COLORS.Gate,
		Material = Enum.Material.Metal,
		Parent = gateFolder,
	})

	createPart({
		Name = "Arch",
		Size = Vector3.new(zone.size.X, 2, 3),
		CFrame = CFrame.new(pos + Vector3.new(0, zone.size.Y / 2 - 1, 0)),
		Color = HubConfig.COLORS.GateGlow,
		Material = Enum.Material.Neon,
		Parent = gateFolder,
	})

	local portal = createPart({
		Name = "PortalTrigger",
		Size = Vector3.new(zone.size.X - 4, zone.size.Y - 2, zone.size.Z),
		CFrame = CFrame.new(pos),
		Color = HubConfig.COLORS.GateGlow,
		Material = Enum.Material.Neon,
		Transparency = 0.65,
		CanCollide = false,
		Parent = gateFolder,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterArenaPrompt"
	prompt.ActionText = HubConfig.LABELS.ArenaPrompt
	prompt.ObjectText = "Spin Arena"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = portal

	local sign = createPart({
		Name = "GateSign",
		Size = Vector3.new(8, 3, 0.5),
		CFrame = CFrame.new(pos + Vector3.new(0, zone.size.Y / 2 + 2, 2)),
		Color = HubConfig.COLORS.PlatformAccent,
		Material = Enum.Material.SmoothPlastic,
		Parent = gateFolder,
	})

	local signLabel = createSurfaceGui(sign, "GateSignGui")
	signLabel.Text = "➜ ARENA"
	signLabel.TextXAlignment = Enum.TextXAlignment.Center
	signLabel.TextYAlignment = Enum.TextYAlignment.Center
	signLabel.TextSize = 28

	return portal
end

local function buildInfoBoard(parent, zoneKey, title)
	local zone = HubConfig.ZONES[zoneKey]
	local rot = zone.rotation or 0
	local pos = HubConfig.worldPosition(zone.position + Vector3.new(0, zone.size.Y / 2, 0))
	local board = createPart({
		Name = zoneKey .. "Board",
		Size = zone.size,
		CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(rot), 0),
		Color = HubConfig.COLORS.PlatformAccent,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})

	local label = createSurfaceGui(board, zoneKey .. "Gui")
	label.Text = title .. "\n\nLade…"
	return board
end

local function buildBeyShowcase(parent)
	local zone = HubConfig.ZONES.BeyShowcase
	local center = HubConfig.worldPosition(zone.position)
	local showcase = Instance.new("Folder")
	showcase.Name = "BeyShowcase"
	showcase.Parent = parent

	createPart({
		Name = "ShowcasePlatform",
		Size = Vector3.new(zone.radius * 2, 0.6, zone.radius * 2),
		CFrame = CFrame.new(center + Vector3.new(0, 0.3, 0)),
		Color = HubConfig.COLORS.Pedestal,
		Material = Enum.Material.Marble,
		Parent = showcase,
	})

	local count = #BeyCatalog
	for i, bey in BeyCatalog do
		local angle = math.rad((i - 1) * (360 / count))
		local dist = zone.radius * 0.55
		local pos = center + Vector3.new(math.sin(angle) * dist, 1.2, math.cos(angle) * dist)

		local pedestal = createPart({
			Name = bey.id .. "Pedestal",
			Size = Vector3.new(3, 1.2, 3),
			CFrame = CFrame.new(pos - Vector3.new(0, 0.6, 0)),
			Color = HubConfig.COLORS.Pedestal,
			Material = Enum.Material.Metal,
			Parent = showcase,
		})

		local orb = createPart({
			Name = bey.id .. "Orb",
			Size = Vector3.new(2.2, 2.2, 2.2),
			CFrame = CFrame.new(pos + Vector3.new(0, 1.4, 0)),
			Color = bey.color,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = showcase,
		})
		orb.Shape = Enum.PartType.Ball

		local nameSign = createPart({
			Name = bey.id .. "Label",
			Size = Vector3.new(4, 1.5, 0.3),
			CFrame = CFrame.new(pos + Vector3.new(0, 2.8, 0)),
			Color = HubConfig.COLORS.PlatformAccent,
			Material = Enum.Material.SmoothPlastic,
			Parent = showcase,
		})

		local nameLabel = createSurfaceGui(nameSign, "NameGui")
		nameLabel.Text = bey.name
		nameLabel.TextXAlignment = Enum.TextXAlignment.Center
		nameLabel.TextYAlignment = Enum.TextYAlignment.Center
		nameLabel.TextSize = 18
	end
end

local function buildSpawn(parent)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = parent
	return spawn
end

local function buildTitleSign(parent)
	local pos = HubConfig.worldPosition(Vector3.new(0, 8, -132))
	local sign = createPart({
		Name = "HubTitleSign",
		Size = Vector3.new(20, 4, 1),
		CFrame = CFrame.new(pos),
		Color = HubConfig.COLORS.Rim,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = parent,
	})

	local label = createSurfaceGui(sign, "TitleGui")
	label.Text = HubConfig.LABELS.HubTitle
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextSize = 32
end

function HubWorldBuilder.getHubFolder()
	return Workspace:FindFirstChild("HubWorld")
end

function HubWorldBuilder.getBoard(zoneKey)
	local hub = HubWorldBuilder.getHubFolder()
	if not hub then return nil end
	local board = hub:FindFirstChild(zoneKey .. "Board")
	if not board then return nil end
	local gui = board:FindFirstChild(zoneKey .. "Gui")
	if not gui then return nil end
	local frame = gui:FindFirstChild("Background")
	if not frame then return nil end
	return frame:FindFirstChild("Content")
end

function HubWorldBuilder.build()
	local existing = Workspace:FindFirstChild("HubWorld")
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = "HubWorld"
	hub.Parent = Workspace

	buildPlatform(hub)
	buildTitleSign(hub)
	buildArenaGate(hub)
	buildInfoBoard(hub, "Leaderboard", "🏆 Top Spieler")
	buildInfoBoard(hub, "StatsBoard", "📊 Deine Stats")
	buildBeyShowcase(hub)
	buildSpawn(hub)

	return hub
end

return HubWorldBuilder
