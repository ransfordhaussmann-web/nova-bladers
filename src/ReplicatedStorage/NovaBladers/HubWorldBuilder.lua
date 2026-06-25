local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Color = props.color or Color3.fromRGB(200, 200, 200)
	part.Size = props.size
	part.CFrame = props.cframe or CFrame.new(props.position or Vector3.zero)
	part.Transparency = props.transparency or 0
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function addBillboard(parent, text, offset)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ZoneLabel"
	gui.Size = UDim2.fromOffset(160, 40)
	gui.StudsOffset = offset or Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 18
	label.Text = text
	label.Parent = gui
end

function HubWorldBuilder.createLeaderboardBoard(parent, position)
	local board = makePart({
		name = "LeaderboardBoard",
		parent = parent,
		size = Vector3.new(10, 7, 0.5),
		position = position + Vector3.new(0, 4, -5.5),
		color = Color3.fromRGB(30, 30, 40),
		material = Enum.Material.Metal,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "BoardGui"
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(400, 280)
	surface.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 210, 80)
	title.TextSize = 22
	title.Text = "🏆 Nova Liga — Top 5"
	title.Parent = surface

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Size = UDim2.new(1, -16, 1, -48)
	list.Position = UDim2.fromOffset(8, 44)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextSize = 18
	list.Text = "Lade Rangliste…"
	list.TextWrapped = true
	list.Parent = surface

	return board
end

function HubWorldBuilder.updateLeaderboardBoard(board, entries)
	local gui = board and board:FindFirstChild("BoardGui")
	if not gui then return end
	local list = gui:FindFirstChild("List")
	if not list then return end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s  (%d)", entry.rank, entry.name, entry.points))
	end
	list.Text = if #lines == 0 then "Noch keine Einträge" else table.concat(lines, "\n")
end

function HubWorldBuilder.build(onZoneTriggered)
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		local board = existing:FindFirstChild("LeaderboardBoard", true)
		return existing, board
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	makePart({
		name = "HubFloor",
		parent = hub,
		size = HubConfig.HUB_FLOOR_SIZE,
		position = Vector3.new(0, 0.5, 0),
		color = HubConfig.HUB_FLOOR_COLOR,
		material = Enum.Material.Slate,
	})

	local halfX = HubConfig.HUB_FLOOR_SIZE.X * 0.5
	local halfZ = HubConfig.HUB_FLOOR_SIZE.Z * 0.5
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS

	local walls = {
		{ pos = Vector3.new(0, wallH * 0.5, -halfZ - wallT * 0.5), size = Vector3.new(HubConfig.HUB_FLOOR_SIZE.X + wallT * 2, wallH, wallT) },
		{ pos = Vector3.new(0, wallH * 0.5, halfZ + wallT * 0.5), size = Vector3.new(HubConfig.HUB_FLOOR_SIZE.X + wallT * 2, wallH, wallT) },
		{ pos = Vector3.new(-halfX - wallT * 0.5, wallH * 0.5, 0), size = Vector3.new(wallT, wallH, HubConfig.HUB_FLOOR_SIZE.Z) },
		{ pos = Vector3.new(halfX + wallT * 0.5, wallH * 0.5, 0), size = Vector3.new(wallT, wallH, HubConfig.HUB_FLOOR_SIZE.Z) },
	}

	for i, wall in walls do
		makePart({
			name = "Wall" .. i,
			parent = hub,
			size = wall.size,
			position = wall.pos,
			color = Color3.fromRGB(60, 65, 80),
			material = Enum.Material.Concrete,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = HubConfig.HUB_SPAWN
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	local centerSign = makePart({
		name = "HubSign",
		parent = hub,
		size = Vector3.new(8, 1, 4),
		position = Vector3.new(0, 1.5, 8),
		color = Color3.fromRGB(50, 55, 75),
		canCollide = false,
	})
	addBillboard(centerSign, "Nova Bladers Hub", Vector3.new(0, 3, 0))

	local leaderboardBoard

	for zoneId, zoneConfig in HubConfig.ZONES do
		local platform = makePart({
			name = zoneId .. "Zone",
			parent = hub,
			size = zoneConfig.size,
			position = zoneConfig.position,
			color = zoneConfig.color,
			material = Enum.Material.Neon,
		})
		platform.Transparency = 0.25

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ZonePrompt"
		prompt.ActionText = zoneConfig.promptText
		prompt.ObjectText = zoneConfig.label
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = platform

		addBillboard(platform, zoneConfig.label)

		if onZoneTriggered then
			prompt.Triggered:Connect(function(player)
				onZoneTriggered(player, zoneConfig.promptAction)
			end)
		end

		if zoneId == "Leaderboard" then
			leaderboardBoard = HubWorldBuilder.createLeaderboardBoard(hub, zoneConfig.position)
		end
	end

	return hub, leaderboardBoard
end

return HubWorldBuilder
