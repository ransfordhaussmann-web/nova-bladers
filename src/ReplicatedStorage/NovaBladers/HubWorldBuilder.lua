local HubConfig = require(script.Parent.HubConfig)

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

local function addBillboard(parent, title, subtitle, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 80)
	gui.StudsOffset = Vector3.new(0, 6, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(12, 14, 24)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Parent = frame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -8, 0.55, 0)
	titleLabel.Position = UDim2.fromOffset(4, 2)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 18
	titleLabel.TextColor3 = color
	titleLabel.Text = title
	titleLabel.Parent = frame

	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, -8, 0.4, 0)
	subLabel.Position = UDim2.new(0, 4, 0.55, 0)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextSize = 13
	subLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
	subLabel.Text = subtitle
	subLabel.Parent = frame
end

function HubWorldBuilder.createLeaderboardBoard(parent, leaderboardEntries)
	local board = makePart({
		Name = "LeaderboardBoard",
		Size = Vector3.new(14, 10, 0.5),
		Position = HubConfig.ZONES.HallOfFame.position + Vector3.new(0, 6, -10),
		Color = Color3.fromRGB(20, 24, 40),
		CFrame = CFrame.new(HubConfig.ZONES.HallOfFame.position + Vector3.new(0, 6, -10))
			* CFrame.Angles(0, math.rad(180), 0),
	})
	board.Parent = parent

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(14, 18, 32)
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 60)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 28
	title.TextColor3 = HubConfig.THEME.trim
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "Entries"
	list.Size = UDim2.new(1, -20, 1, -70)
	list.Position = UDim2.fromOffset(10, 65)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextSize = 22
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextColor3 = Color3.fromRGB(220, 225, 240)
	list.TextWrapped = true
	list.Parent = frame

	HubWorldBuilder.updateLeaderboardBoard(board, leaderboardEntries)
	return board
end

function HubWorldBuilder.updateLeaderboardBoard(board, leaderboardEntries)
	if not board then
		return
	end
	local surface = board:FindFirstChildOfClass("SurfaceGui")
	local entries = surface and surface:FindFirstChild("Frame") and surface.Frame:FindFirstChild("Entries")
	if not entries then
		return
	end

	local lines = {}
	for _, entry in leaderboardEntries do
		table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	entries.Text = table.concat(lines, "\n")
end

function HubWorldBuilder.build(leaderboardEntries)
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local geometry = Instance.new("Folder")
	geometry.Name = "Geometry"
	geometry.Parent = hub

	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = Vector3.new(0, HubConfig.FLOOR_Y, 0),
		Color = HubConfig.THEME.floor,
		Material = Enum.Material.Slate,
	})
	floor.Parent = geometry

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallY = HubConfig.FLOOR_Y + HubConfig.WALL_HEIGHT / 2
	local wallDefs = {
		{ name = "WallNorth", size = Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, 2), pos = Vector3.new(0, wallY, -halfZ) },
		{ name = "WallSouth", size = Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, 2), pos = Vector3.new(0, wallY, halfZ) },
		{ name = "WallWest", size = Vector3.new(2, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), pos = Vector3.new(-halfX, wallY, 0) },
		{ name = "WallEast", size = Vector3.new(2, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), pos = Vector3.new(halfX, wallY, 0) },
	}
	for _, def in wallDefs do
		local wall = makePart({
			Name = def.name,
			Size = def.size,
			Position = def.pos,
			Color = HubConfig.THEME.wall,
			Material = Enum.Material.Metal,
			Transparency = 0.2,
		})
		wall.Parent = geometry
	end

	local centerRing = makePart({
		Name = "CenterRing",
		Size = Vector3.new(16, 0.3, 16),
		Position = Vector3.new(0, HubConfig.FLOOR_Y + 0.65, -8),
		Color = HubConfig.THEME.accent,
		Material = Enum.Material.Neon,
		Shape = Enum.PartType.Cylinder,
		CFrame = CFrame.new(0, HubConfig.FLOOR_Y + 0.65, -8) * CFrame.Angles(0, 0, math.rad(90)),
	})
	centerRing.Parent = geometry

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION - Vector3.new(0, 2, 0)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	local zoneTriggers = {}

	for zoneId, zone in HubConfig.ZONES do
		local zoneFolder = Instance.new("Folder")
		zoneFolder.Name = zoneId
		zoneFolder.Parent = zonesFolder

		local platform = makePart({
			Name = "Platform",
			Size = zone.size,
			Position = zone.position,
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.35,
		})
		platform.Parent = zoneFolder

		local trigger = makePart({
			Name = "Trigger",
			Size = zone.size + Vector3.new(0, 8, 0),
			Position = zone.position + Vector3.new(0, 4, 0),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		trigger:SetAttribute("ZoneId", zoneId)
		trigger.Parent = zoneFolder
		zoneTriggers[zoneId] = trigger

		local signAnchor = makePart({
			Name = "SignAnchor",
			Size = Vector3.new(1, 1, 1),
			Position = zone.position + Vector3.new(0, 1, 0),
			Transparency = 1,
			CanCollide = false,
		})
		signAnchor.Parent = zoneFolder
		addBillboard(signAnchor, zone.name, zone.hint, zone.color)
	end

	local board = HubWorldBuilder.createLeaderboardBoard(hub, leaderboardEntries or {})
	hub:SetAttribute("LeaderboardBoardName", board.Name)

	return hub, zoneTriggers
end

return HubWorldBuilder
