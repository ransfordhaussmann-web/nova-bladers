local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Color = props.Color or Color3.fromRGB(200, 200, 200)
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Name = props.Name
	part.Transparency = props.Transparency or 0
	part.Parent = props.Parent
	return part
end

local function addZoneLabel(parent, text, color)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.5
	label.TextSize = 20
	label.Text = text
	label.Parent = billboard
end

local function addProximityPrompt(part, actionText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = actionText
	prompt.ObjectText = part.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.MODEL_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Model")
	hub.Name = HubConfig.MODEL_NAME

	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		CFrame = CFrame.new(0, 0, 0),
		Color = HubConfig.COLORS.Floor,
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS

	local walls = {
		{ name = "WallNorth", pos = Vector3.new(0, wallH / 2, -halfZ), size = Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, wallT) },
		{ name = "WallSouth", pos = Vector3.new(0, wallH / 2, halfZ), size = Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, wallT) },
		{ name = "WallWest", pos = Vector3.new(-halfX, wallH / 2, 0), size = Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ name = "WallEast", pos = Vector3.new(halfX, wallH / 2, 0), size = Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
	}

	local wallsFolder = Instance.new("Folder")
	wallsFolder.Name = "Walls"
	wallsFolder.Parent = hub

	for _, wall in walls do
		makePart({
			Name = wall.name,
			Size = wall.size,
			CFrame = CFrame.new(wall.pos),
			Color = HubConfig.COLORS.Wall,
			Material = Enum.Material.Concrete,
			Parent = wallsFolder,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local colorKey = zone.id
		local zoneColor = HubConfig.COLORS[colorKey] or HubConfig.COLORS.Accent

		local marker = makePart({
			Name = zone.id,
			Size = zone.size,
			CFrame = CFrame.new(zone.position + Vector3.new(0, zone.size.Y / 2, 0)),
			Color = zoneColor,
			Material = Enum.Material.Neon,
			Transparency = 0.35,
			Parent = zonesFolder,
		})
		marker:SetAttribute("ZoneId", zone.id)
		marker:SetAttribute("ZoneName", zone.name)
		marker:SetAttribute("ZoneHint", zone.hint)
		marker:SetAttribute("ZoneAction", zone.action or "")

		addZoneLabel(marker, zone.name, zoneColor)

		if zone.action then
			addProximityPrompt(marker, zone.hint)
		end
	end

	local boardCfg = HubConfig.LEADERBOARD_BOARD
	local board = makePart({
		Name = "LeaderboardBoard",
		Size = boardCfg.size,
		CFrame = CFrame.new(boardCfg.position),
		Color = HubConfig.COLORS.HallOfFame,
		Material = Enum.Material.Metal,
		Parent = hub,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "LeaderboardSurface"
	surface.Face = boardCfg.face
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 48)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "🏆 Nova Liga"
	title.TextColor3 = Color3.fromRGB(255, 230, 120)
	title.TextSize = 28
	title.Parent = surface

	local list = Instance.new("TextLabel")
	list.Name = "Entries"
	list.Position = UDim2.fromOffset(0, 52)
	list.Size = UDim2.new(1, 0, 1, -52)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.Text = "Lade Rangliste..."
	list.TextColor3 = Color3.fromRGB(240, 240, 240)
	list.TextSize = 22
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Parent = surface

	hub.PrimaryPart = floor
	hub.Parent = workspace

	return hub
end

function HubWorldBuilder.formatLeaderboardText(entries)
	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		return "Noch keine Einträge"
	end
	return table.concat(lines, "\n")
end

function HubWorldBuilder.updateLeaderboardBoard(entries)
	local hub = workspace:FindFirstChild(HubConfig.MODEL_NAME)
	if not hub then return end
	local board = hub:FindFirstChild("LeaderboardBoard")
	if not board then return end
	local surface = board:FindFirstChild("LeaderboardSurface")
	if not surface then return end
	local list = surface:FindFirstChild("Entries")
	if list then
		list.Text = HubWorldBuilder.formatLeaderboardText(entries)
	end
end

return HubWorldBuilder
