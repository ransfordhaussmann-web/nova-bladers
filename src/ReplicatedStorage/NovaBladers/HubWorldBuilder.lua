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

local function addLabel(parent, text, offset)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 48)
	billboard.StudsOffset = offset or Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.TextSize = 18
	label.Text = text
	label.Parent = billboard
end

function HubWorldBuilder.buildHallBoard(parent, entries)
	local board = parent:FindFirstChild("HallBoard")
	if board then
		board:Destroy()
	end

	board = makePart({
		Name = "HallBoard",
		Size = Vector3.new(12, 8, 0.5),
		Position = Vector3.new(38, 5, 18),
		Color = HubConfig.COLORS.Wall,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = HubConfig.COLORS.HallOfFame
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = frame

	local body = Instance.new("TextLabel")
	body.Name = "Entries"
	body.Position = UDim2.fromOffset(0, 36)
	body.Size = UDim2.new(1, 0, 1, -36)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Gotham
	body.TextSize = 16
	body.TextColor3 = Color3.new(1, 1, 1)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.Parent = frame

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	body.Text = "  " .. table.concat(lines, "\n  ")
end

function HubWorldBuilder.build(leaderboardEntries)
	local existing = workspace:FindFirstChild(HubConfig.ROOT_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.ROOT_NAME
	hub.Parent = workspace

	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = Vector3.new(0, -0.5, 0),
		Color = HubConfig.COLORS.Floor,
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallY = HubConfig.WALL_HEIGHT / 2

	local walls = {
		{ Name = "WallNorth", Size = Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, HubConfig.WALL_THICKNESS), Position = Vector3.new(0, wallY, -halfZ) },
		{ Name = "WallSouth", Size = Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, HubConfig.WALL_THICKNESS), Position = Vector3.new(0, wallY, halfZ) },
		{ Name = "WallWest", Size = Vector3.new(HubConfig.WALL_THICKNESS, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), Position = Vector3.new(-halfX, wallY, 0) },
		{ Name = "WallEast", Size = Vector3.new(HubConfig.WALL_THICKNESS, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), Position = Vector3.new(halfX, wallY, 0) },
	}
	for _, wall in walls do
		makePart({
			Name = wall.Name,
			Size = wall.Size,
			Position = wall.Position,
			Color = HubConfig.COLORS.Wall,
			Material = Enum.Material.Concrete,
			Parent = hub,
		})
	end

	local spawn = makePart({
		Name = "HubSpawn",
		Size = Vector3.new(6, 0.2, 6),
		Position = Vector3.new(0, 0.1, 20),
		Color = HubConfig.COLORS.Accent,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
		Parent = hub,
	})
	addLabel(spawn, "Nova Hub", Vector3.new(0, 4, 0))

	for _, zone in HubConfig.ZONES do
		local color = HubConfig.COLORS[zone.colorKey] or HubConfig.COLORS.Accent
		local pad = makePart({
			Name = zone.id,
			Size = zone.size + Vector3.new(0, 0.2, 0),
			Position = zone.position + Vector3.new(0, 0.15, 0),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.45,
			CanCollide = true,
			Parent = hub,
		})
		pad:SetAttribute("ZoneId", zone.id)
		pad:SetAttribute("ZoneAction", zone.action or "")
		addLabel(pad, zone.name, Vector3.new(0, 5, 0))
	end

	HubWorldBuilder.buildHallBoard(hub, leaderboardEntries or {})

	local light = Instance.new("PointLight")
	light.Brightness = 1.2
	light.Range = 40
	light.Parent = floor

	return hub, spawn
end

function HubWorldBuilder.getSpawnCFrame()
	local hub = workspace:FindFirstChild(HubConfig.ROOT_NAME)
	local spawn = hub and hub:FindFirstChild("HubSpawn")
	if spawn then
		return spawn.CFrame + HubConfig.SPAWN_OFFSET
	end
	return CFrame.new(HubConfig.SPAWN_OFFSET)
end

return HubWorldBuilder
