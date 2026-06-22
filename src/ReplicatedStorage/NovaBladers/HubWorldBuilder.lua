local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	for key, value in props do
		if key ~= "CanCollide" then
			part[key] = value
		end
	end
	return part
end

local function makeZoneLabel(parent: Instance, text: string, color: Color3)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.5
	label.TextSize = 18
	label.Text = text
	label.Parent = billboard
end

function HubWorldBuilder.buildLeaderboardBoard(hub: Folder, entries: { { rank: number, name: string, points: number } })
	local boardCfg = HubConfig.LEADERBOARD_BOARD
	local board = hub:FindFirstChild("LeaderboardBoard")
	if not board then
		board = makePart({
			Name = "LeaderboardBoard",
			Size = boardCfg.size,
			CFrame = CFrame.new(boardCfg.position),
			Color = Color3.fromRGB(30, 30, 40),
			Material = Enum.Material.SmoothPlastic,
		})
		board.Parent = hub
	end

	local surface = board:FindFirstChildOfClass("SurfaceGui")
	if not surface then
		surface = Instance.new("SurfaceGui")
		surface.Face = boardCfg.face
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 50
		surface.Parent = board
	end

	local frame = surface:FindFirstChild("Frame")
	if not frame then
		frame = Instance.new("Frame")
		frame.Name = "Frame"
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
		frame.BorderSizePixel = 0
		frame.Parent = surface

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, 0, 0, 60)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextColor3 = Color3.fromRGB(255, 210, 80)
		title.TextSize = 28
		title.Text = "🏆 Ruhmeshalle"
		title.Parent = frame

		local list = Instance.new("TextLabel")
		list.Name = "List"
		list.Position = UDim2.fromOffset(0, 60)
		list.Size = UDim2.new(1, 0, 1, -60)
		list.BackgroundTransparency = 1
		list.Font = Enum.Font.Gotham
		list.TextColor3 = Color3.fromRGB(230, 230, 240)
		list.TextSize = 22
		list.TextXAlignment = Enum.TextXAlignment.Left
		list.TextYAlignment = Enum.TextYAlignment.Top
		list.Parent = frame
	end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	frame.List.Text = table.concat(lines, "\n")
end

function HubWorldBuilder.build(): Folder
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = Vector3.new(0, 0, 200),
		Color = Color3.fromRGB(45, 48, 58),
		Material = Enum.Material.Slate,
	})
	floor.Parent = hub

	local wallThickness = 2
	local floorSize = HubConfig.FLOOR_SIZE
	local wallH = HubConfig.WALL_HEIGHT
	local center = floor.Position

	local walls = {
		{ Size = Vector3.new(floorSize.X, wallH, wallThickness), Position = center + Vector3.new(0, wallH / 2, floorSize.Z / 2) },
		{ Size = Vector3.new(floorSize.X, wallH, wallThickness), Position = center + Vector3.new(0, wallH / 2, -floorSize.Z / 2) },
		{ Size = Vector3.new(wallThickness, wallH, floorSize.Z), Position = center + Vector3.new(floorSize.X / 2, wallH / 2, 0) },
		{ Size = Vector3.new(wallThickness, wallH, floorSize.Z), Position = center + Vector3.new(-floorSize.X / 2, wallH / 2, 0) },
	}

	local wallsFolder = Instance.new("Folder")
	wallsFolder.Name = "Walls"
	wallsFolder.Parent = hub

	for i, spec in walls do
		local wall = makePart({
			Name = "Wall" .. i,
			Size = spec.Size,
			Position = spec.Position,
			Color = Color3.fromRGB(35, 38, 48),
			Material = Enum.Material.Concrete,
		})
		wall.Parent = wallsFolder
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zoneCfg in HubConfig.ZONES do
		local zone = makePart({
			Name = zoneCfg.id,
			Size = zoneCfg.size,
			Position = zoneCfg.position,
			Color = zoneCfg.color,
			Material = Enum.Material.Neon,
			Transparency = 0.55,
			CanCollide = false,
		})
		zone:SetAttribute("ZoneId", zoneCfg.id)
		zone:SetAttribute("Action", zoneCfg.action)
		zone.Parent = zonesFolder
		makeZoneLabel(zone, zoneCfg.name, zoneCfg.color)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hub

	HubWorldBuilder.buildLeaderboardBoard(hub, {})

	return hub
end

return HubWorldBuilder
