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
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(200, 50)
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

	return gui
end

local function addZoneSign(zonePart, label)
	local sign = makePart({
		name = "Sign",
		parent = zonePart,
		size = Vector3.new(8, 3, 0.4),
		position = zonePart.Position + Vector3.new(0, zonePart.Size.Y * 0.5 + 2.5, 0),
		color = zonePart.Color,
		material = Enum.Material.Neon,
	})
	addBillboard(sign, label, Vector3.new(0, 2, 0))
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
	local gui = board:FindFirstChild("BoardGui")
	if not gui then return end
	local list = gui:FindFirstChild("List")
	if not list then return end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s  (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		list.Text = "Noch keine Einträge"
	else
		list.Text = table.concat(lines, "\n")
	end
end

local function findLeaderboardBoard(hub)
	local zones = hub:FindFirstChild("Zones")
	local hall = zones and zones:FindFirstChild("HallOfFame")
	return hall and hall:FindFirstChild("LeaderboardBoard")
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing, findLeaderboardBoard(existing)
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		position = HubConfig.FLOOR_POSITION,
		color = Color3.fromRGB(45, 50, 65),
		material = Enum.Material.Slate,
	})

	local halfX = HubConfig.FLOOR_SIZE.X * 0.5
	local halfZ = HubConfig.FLOOR_SIZE.Z * 0.5
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS

	local walls = {
		{ pos = Vector3.new(0, wallH * 0.5, -halfZ - wallT * 0.5), size = Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT) },
		{ pos = Vector3.new(0, wallH * 0.5, halfZ + wallT * 0.5), size = Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT) },
		{ pos = Vector3.new(-halfX - wallT * 0.5, wallH * 0.5, 0), size = Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ pos = Vector3.new(halfX + wallT * 0.5, wallH * 0.5, 0), size = Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
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
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.CFrame = HubConfig.SPAWN
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	local leaderboardBoard

	for _, zone in HubConfig.ZONES do
		local zonePart = makePart({
			name = zone.id,
			parent = zonesFolder,
			size = zone.size,
			position = zone.position,
			color = zone.color,
			material = Enum.Material.Neon,
			canCollide = false,
		})
		zonePart.Transparency = 0.35

		makePart({
			name = "Trigger",
			parent = zonePart,
			size = zone.size + Vector3.new(4, 4, 4),
			position = zone.position,
			color = zone.color,
			canCollide = false,
		}).Transparency = 1

		addZoneSign(zonePart, zone.label)

		if zone.id == "HallOfFame" then
			leaderboardBoard = HubWorldBuilder.createLeaderboardBoard(zonePart, zone.position)
		end
	end

	local center = makePart({
		name = "WelcomeMarker",
		parent = hub,
		size = Vector3.new(4, 0.3, 4),
		position = Vector3.new(0, 0.65, 10),
		color = Color3.fromRGB(120, 180, 255),
		material = Enum.Material.Neon,
		canCollide = false,
	})
	center.Transparency = 0.5
	addBillboard(center, "Nova Bladers Hub", Vector3.new(0, 3, 0))

	return hub, leaderboardBoard
end

return HubWorldBuilder
