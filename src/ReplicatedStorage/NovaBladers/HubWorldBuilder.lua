local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local BeyCatalog = require(NovaBladers.BeyCatalog)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Color = props.color or Color3.fromRGB(40, 44, 60)
	part.Size = props.size or Vector3.new(4, 4, 4)
	part.CFrame = props.cframe or CFrame.new(HubConfig.CENTER)
	part.Name = props.name or "Part"
	part.Parent = props.parent
	if props.transparency then
		part.Transparency = props.transparency
	end
	return part
end

local function addNeonStrip(parent, cframe, size, color)
	local strip = makePart({
		name = "NeonStrip",
		parent = parent,
		size = size,
		cframe = cframe,
		color = color,
		material = Enum.Material.Neon,
		canCollide = false,
	})
	strip.CastShadow = false
	return strip
end

local function addBillboard(part, title, subtitle)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ZoneLabel"
	gui.Size = UDim2.fromOffset(220, 72)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = part

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = Color3.fromRGB(235, 240, 255)
	titleLabel.TextScaled = true
	titleLabel.Text = title
	titleLabel.Parent = gui

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "Subtitle"
	subLabel.BackgroundTransparency = 1
	subLabel.Position = UDim2.fromScale(0, 0.55)
	subLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextColor3 = Color3.fromRGB(160, 175, 210)
	subLabel.TextScaled = true
	subLabel.Text = subtitle
	subLabel.Parent = gui
end

local function addSurfaceDisplay(part, face, displayName)
	local gui = Instance.new("SurfaceGui")
	gui.Name = displayName
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = part

	local frame = Instance.new("Frame")
	frame.Name = "Frame"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(12, 16, 28)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = HubConfig.COLORS.neon
	stroke.Thickness = 2
	stroke.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Body"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -16, 1, -16)
	label.Position = UDim2.fromOffset(8, 8)
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(220, 230, 255)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	label.TextSize = 22
	label.Text = displayName
	label.Parent = frame

	return label
end

function HubWorldBuilder.getSpawnCFrame()
	return CFrame.new(HubConfig.CENTER + HubConfig.SPAWN_OFFSET)
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.ROOT_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.ROOT_NAME
	hub.Parent = workspace

	local geometry = Instance.new("Folder")
	geometry.Name = "Geometry"
	geometry.Parent = hub

	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = hub

	local center = HubConfig.CENTER

	local floor = makePart({
		name = "Floor",
		parent = geometry,
		size = Vector3.new(HubConfig.FLOOR_RADIUS * 2, HubConfig.FLOOR_THICKNESS, HubConfig.FLOOR_RADIUS * 2),
		cframe = CFrame.new(center + Vector3.new(0, -HubConfig.FLOOR_THICKNESS / 2, 0)),
		color = HubConfig.COLORS.floor,
		material = Enum.Material.Slate,
	})

	local floorAccent = makePart({
		name = "FloorRing",
		parent = geometry,
		size = Vector3.new(HubConfig.FLOOR_RADIUS * 1.4, 0.3, HubConfig.FLOOR_RADIUS * 1.4),
		cframe = CFrame.new(center + Vector3.new(0, 0.15, 0)),
		color = HubConfig.COLORS.floorAccent,
		material = Enum.Material.Neon,
		canCollide = false,
	})
	floorAccent.Transparency = 0.35

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = HubWorldBuilder.getSpawnCFrame() * CFrame.new(0, -3.5, 0)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	for angle = 0, 315, 45 do
		local rad = math.rad(angle)
		local edge = Vector3.new(math.sin(rad), 0, math.cos(rad)) * (HubConfig.FLOOR_RADIUS - 2)
		local wallPos = center + edge + Vector3.new(0, 5, 0)
		local wall = makePart({
			name = "BoundaryWall",
			parent = geometry,
			size = Vector3.new(14, 10, 2),
			cframe = CFrame.new(wallPos) * CFrame.Angles(0, -rad, 0),
			color = HubConfig.COLORS.wall,
			material = Enum.Material.Concrete,
		})
		addNeonStrip(
			geometry,
			wall.CFrame * CFrame.new(0, 4.8, -1.1),
			Vector3.new(12, 0.25, 0.25),
			HubConfig.COLORS.neon
		)
	end

	local gateZone = HubConfig.ZONES.ArenaGate
	local gatePos = center + gateZone.offset + Vector3.new(0, 6, 0)
	local gateFolder = Instance.new("Folder")
	gateFolder.Name = "ArenaGate"
	gateFolder.Parent = zones

	local gateFrame = makePart({
		name = "Frame",
		parent = gateFolder,
		size = HubConfig.ARENA_GATE.size,
		cframe = CFrame.new(gatePos),
		color = HubConfig.COLORS.gate,
		material = Enum.Material.Metal,
	})
	gateFrame.Transparency = 0.15

	local gatePortal = makePart({
		name = "Portal",
		parent = gateFolder,
		size = Vector3.new(8, 9, 0.5),
		cframe = gateFrame.CFrame,
		color = HubConfig.COLORS.neon,
		material = Enum.Material.Neon,
		canCollide = false,
	})
	gatePortal.Transparency = 0.55

	local gatePrompt = Instance.new("ProximityPrompt")
	gatePrompt.Name = "ArenaPrompt"
	gatePrompt.ActionText = "Arena"
	gatePrompt.ObjectText = "Match starten"
	gatePrompt.KeyboardKeyCode = Enum.KeyCode.E
	gatePrompt.MaxActivationDistance = HubConfig.ARENA_GATE.promptDistance
	gatePrompt.HoldDuration = 0
	gatePrompt.Parent = gatePortal

	addBillboard(gateFrame, gateZone.label, gateZone.hint)

	local boardZone = HubConfig.ZONES.Leaderboard
	local boardPos = center + boardZone.offset + Vector3.new(0, 5, 0)
	local boardFolder = Instance.new("Folder")
	boardFolder.Name = "Leaderboard"
	boardFolder.Parent = zones

	local boardPart = makePart({
		name = "Board",
		parent = boardFolder,
		size = HubConfig.BOARD.size,
		cframe = CFrame.new(boardPos) * CFrame.Angles(0, math.rad(-90), 0),
		color = HubConfig.COLORS.wall,
	})
	addSurfaceDisplay(boardPart, Enum.NormalId.Front, "🏆 Top Spieler\n\nLade…")
	addBillboard(boardPart, boardZone.label, boardZone.hint)

	local statsZone = HubConfig.ZONES.StatsTerminal
	local statsPos = center + statsZone.offset + Vector3.new(0, 4, 0)
	local statsFolder = Instance.new("Folder")
	statsFolder.Name = "StatsTerminal"
	statsFolder.Parent = zones

	local statsPedestal = makePart({
		name = "Pedestal",
		parent = statsFolder,
		size = Vector3.new(6, 3, 6),
		cframe = CFrame.new(statsPos + Vector3.new(0, -1.5, 0)),
		color = HubConfig.COLORS.wall,
	})
	local statsScreen = makePart({
		name = "Screen",
		parent = statsFolder,
		size = Vector3.new(7, 5, 0.6),
		cframe = CFrame.new(statsPos + Vector3.new(0, 2, -2.8)) * CFrame.Angles(0, math.rad(90), 0),
		color = HubConfig.COLORS.wall,
	})
	addSurfaceDisplay(statsScreen, Enum.NormalId.Front, "Deine Stats\n\nWins: —\nLosses: —\nRank: —")
	addBillboard(statsPedestal, statsZone.label, statsZone.hint)

	local showcaseZone = HubConfig.ZONES.BeyShowcase
	local showcaseCenter = center + showcaseZone.offset
	local showcaseFolder = Instance.new("Folder")
	showcaseFolder.Name = "BeyShowcase"
	showcaseFolder.Parent = zones

	local count = #BeyCatalog
	local startX = -(count - 1) * HubConfig.PEDESTAL.spacing / 2
	for index, bey in BeyCatalog do
		local offset = Vector3.new(startX + (index - 1) * HubConfig.PEDESTAL.spacing, 0, 0)
		local pedestalPos = showcaseCenter + offset

		local pedestal = makePart({
			name = bey.id,
			parent = showcaseFolder,
			size = Vector3.new(5, 2, 5),
			cframe = CFrame.new(pedestalPos + Vector3.new(0, 1, 0)),
			color = HubConfig.COLORS.wall,
		})

		local disc = makePart({
			name = "Disc",
			parent = pedestal,
			size = Vector3.new(3.6, 0.8, 3.6),
			cframe = pedestal.CFrame * CFrame.new(0, 2, 0),
			color = bey.color,
			material = Enum.Material.Neon,
			canCollide = false,
		})
		disc.Shape = Enum.PartType.Cylinder
		disc.CFrame = pedestal.CFrame * CFrame.new(0, 2.4, 0) * CFrame.Angles(0, 0, math.rad(90))

		addBillboard(disc, bey.name, bey.special)
	end

	local sign = makePart({
		name = "HubSign",
		parent = geometry,
		size = Vector3.new(18, 4, 1),
		cframe = CFrame.new(center + Vector3.new(0, 14, 0)),
		color = HubConfig.COLORS.wall,
		material = Enum.Material.Metal,
		canCollide = false,
	})
	addSurfaceDisplay(sign, Enum.NormalId.Front, "NOVA BLADERS\nSpin-Arena Hub")

	local hubLight = Instance.new("PointLight")
	hubLight.Brightness = 2
	hubLight.Range = 80
	hubLight.Color = HubConfig.COLORS.neon
	hubLight.Parent = floor

	return hub
end

return HubWorldBuilder
