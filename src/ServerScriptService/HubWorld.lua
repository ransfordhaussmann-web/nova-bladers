local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local BeyCatalog = require(ReplicatedStorage.NovaBladers.BeyCatalog)

local HubWorld = {}

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

local function addNeonRing(parent, center, radius, color)
	local ring = makePart({
		Name = "NeonRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.35, radius * 2, radius * 2),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = 0.15,
		CanCollide = false,
	})
	ring.Parent = parent
end

local function addBillboard(parent, text, offsetY)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(220, 56)
	gui.StudsOffset = Vector3.new(0, offsetY or 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.TextSize = 22
	label.Text = text
	label.Parent = gui
end

local function addModeZone(parent, zoneInfo)
	local color = HubConfig.COLORS[zoneInfo.colorKey]
	local pad = makePart({
		Name = zoneInfo.id .. "Pad",
		Size = Vector3.new(HubConfig.ZONE_RADIUS * 2, 0.6, HubConfig.ZONE_RADIUS * 2),
		Position = zoneInfo.position,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.2,
	})
	pad.Parent = parent

	local marker = makePart({
		Name = zoneInfo.id .. "Marker",
		Size = Vector3.new(1.2, 6, 1.2),
		Position = zoneInfo.position + Vector3.new(0, 3.2, 0),
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	marker.Parent = parent

	addBillboard(marker, zoneInfo.label, 4)
	addNeonRing(parent, zoneInfo.position + Vector3.new(0, 0.4, 0), HubConfig.ZONE_RADIUS - 0.5, color)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ModePrompt"
	prompt.ActionText = "Wählen"
	prompt.ObjectText = zoneInfo.label
	prompt.MaxActivationDistance = HubConfig.ZONE_RADIUS + 2
	prompt.HoldDuration = 0
	prompt:SetAttribute("ModeId", zoneInfo.id)
	prompt.Parent = pad

	return pad
end

local function addBeyShowcase(parent)
	local showcaseFolder = Instance.new("Folder")
	showcaseFolder.Name = "BeyShowcase"
	showcaseFolder.Parent = parent

	local base = makePart({
		Name = "ShowcaseBase",
		Size = Vector3.new(20, 1, 12),
		Position = HubConfig.BEY_SHOWCASE,
		Color = HubConfig.COLORS.FloorAccent,
		Material = Enum.Material.Slate,
	})
	base.Parent = showcaseFolder

	local title = makePart({
		Name = "ShowcaseTitle",
		Size = Vector3.new(8, 2, 1),
		Position = HubConfig.BEY_SHOWCASE + Vector3.new(0, 3, -5),
		Color = HubConfig.COLORS.Neon,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	title.Parent = showcaseFolder
	addBillboard(title, "Nova Beys", 2)

	local spacing = 4.5
	local startX = HubConfig.BEY_SHOWCASE.X - ((#BeyCatalog - 1) * spacing) / 2
	for index, bey in BeyCatalog do
		local pedestal = makePart({
			Name = bey.id .. "Pedestal",
			Size = Vector3.new(3, 2.5, 3),
			Position = Vector3.new(startX + (index - 1) * spacing, HubConfig.BEY_SHOWCASE.Y + 1.75, HubConfig.BEY_SHOWCASE.Z),
			Color = bey.color,
			Material = Enum.Material.SmoothPlastic,
		})
		pedestal.Parent = showcaseFolder

		local orb = makePart({
			Name = bey.id .. "Orb",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.4, 2.4, 2.4),
			Position = pedestal.Position + Vector3.new(0, 2.2, 0),
			Color = bey.color,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		orb.Parent = showcaseFolder
		addBillboard(orb, bey.name, 2.5)
	end
end

local function addLeaderboardBoard(parent)
	local board = makePart({
		Name = "LeaderboardBoard",
		Size = Vector3.new(10, 8, 1),
		Position = HubConfig.LEADERBOARD,
		Color = HubConfig.COLORS.FloorAccent,
		Material = Enum.Material.Metal,
	})
	board.Parent = parent

	local surface = Instance.new("SurfaceGui")
	surface.Name = "BoardGui"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStuds
	surface.PixelsPerStud = 40
	surface.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(16, 18, 28)
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 48)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 24
	title.TextColor3 = HubConfig.COLORS.Neon
	title.Text = "Top Spieler"
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Size = UDim2.new(1, -16, 1, -56)
	list.Position = UDim2.fromOffset(8, 48)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextSize = 18
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Text = "Lade..."
	list.Parent = frame

	board.CFrame = CFrame.lookAt(board.Position, Vector3.new(0, board.Position.Y, 0))
end

local function addArenaGate(parent)
	local gateFolder = Instance.new("Folder")
	gateFolder.Name = "ArenaGate"
	gateFolder.Parent = parent

	local frame = makePart({
		Name = "GateFrame",
		Size = HubConfig.GATE_SIZE,
		Position = HubConfig.ARENA_GATE,
		Color = HubConfig.COLORS.Gate,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
	})
	frame.Parent = gateFolder

	local portal = makePart({
		Name = "GateTrigger",
		Size = Vector3.new(HubConfig.GATE_SIZE.X - 2, HubConfig.GATE_SIZE.Y - 2, 4),
		Position = HubConfig.ARENA_GATE,
		Transparency = 1,
		CanCollide = false,
	})
	portal.Parent = gateFolder

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterArenaPrompt"
	prompt.ActionText = "Betreten"
	prompt.ObjectText = "Arena"
	prompt.MaxActivationDistance = 12
	prompt.HoldDuration = 0.4
	prompt.Parent = portal

	addBillboard(frame, "Arena", 6)

	return portal
end

local function applyLighting()
	Lighting.ClockTime = 17.5
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(70, 75, 95)
	Lighting.OutdoorAmbient = Color3.fromRGB(90, 95, 120)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.5
end

function HubWorld.getRoot()
	return workspace:FindFirstChild(HubConfig.ROOT_NAME)
end

function HubWorld.ensure()
	local existing = HubWorld.getRoot()
	if existing then
		return existing
	end

	local root = Instance.new("Folder")
	root.Name = HubConfig.ROOT_NAME
	root.Parent = workspace

	local floor = makePart({
		Name = "Floor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(HubConfig.FLOOR_THICKNESS, HubConfig.FLOOR_RADIUS * 2, HubConfig.FLOOR_RADIUS * 2),
		CFrame = CFrame.new(0, HubConfig.FLOOR_THICKNESS / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = HubConfig.COLORS.Floor,
		Material = Enum.Material.Slate,
	})
	floor.Parent = root

	addNeonRing(root, Vector3.new(0, 0.8, 0), HubConfig.FLOOR_RADIUS - 2, HubConfig.COLORS.Neon)

	local spawn = makePart({
		Name = "Spawn",
		Size = Vector3.new(6, 0.4, 6),
		Position = HubConfig.SPAWN - Vector3.new(0, 2, 0),
		Color = HubConfig.COLORS.Neon,
		Material = Enum.Material.Neon,
		Transparency = 0.5,
		CanCollide = false,
	})
	spawn.Parent = root
	addBillboard(spawn, "Spawn", 3)

	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = root

	for _, zoneInfo in HubConfig.MODE_ZONES do
		addModeZone(zones, zoneInfo)
	end

	addArenaGate(root)
	addLeaderboardBoard(root)
	addBeyShowcase(root)
	applyLighting()

	return root
end

function HubWorld.getSpawnCFrame()
	return CFrame.new(HubConfig.SPAWN)
end

function HubWorld.updateLeaderboard(entries)
	local root = HubWorld.getRoot()
	if not root then return end

	local board = root:FindFirstChild("LeaderboardBoard")
	if not board then return end

	local list = board.BoardGui.Frame.List
	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		list.Text = "Noch keine Einträge"
	else
		list.Text = table.concat(lines, "\n")
	end
end

return HubWorld
