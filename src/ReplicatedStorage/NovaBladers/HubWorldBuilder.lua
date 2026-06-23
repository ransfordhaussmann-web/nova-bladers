local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Transparency = props.transparency or 0
	part.Color = props.color or Color3.fromRGB(40, 45, 60)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Size = props.size
	part.CFrame = props.cframe or CFrame.new(props.position or Vector3.zero)
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function makeSign(parent, text, position, color)
	local sign = makePart({
		parent = parent,
		name = "Sign",
		size = Vector3.new(8, 3, 0.4),
		position = position + Vector3.new(0, 6, 0),
		color = color,
		material = Enum.Material.Neon,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.Parent = gui
	return sign
end

local function buildLeaderboardBoard(parent, zonePart)
	local board = makePart({
		parent = parent,
		name = "LeaderboardBoard",
		size = Vector3.new(10, 6, 0.5),
		position = zonePart.Position + Vector3.new(0, 4, -zonePart.Size.Z / 2 - 1),
		color = Color3.fromRGB(25, 25, 35),
		material = Enum.Material.Metal,
	})
	board.CFrame = CFrame.new(board.Position, board.Position + Vector3.new(0, 0, -1))

	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(400, 240)
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.Text = "🏆 Nova Liga — Top 5"
	title.TextColor3 = Color3.fromRGB(255, 220, 80)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = gui

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Size = UDim2.new(1, -16, 1, -44)
	list.Position = UDim2.new(0, 8, 0, 40)
	list.BackgroundTransparency = 1
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextSize = 22
	list.Font = Enum.Font.Gotham
	list.Text = "Lade Rangliste…"
	list.TextWrapped = true
	list.Parent = gui

	return board
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	makePart({
		parent = hub,
		name = "Floor",
		size = HubConfig.FLOOR_SIZE,
		position = HubConfig.FLOOR_POSITION,
		color = Color3.fromRGB(30, 34, 48),
		material = Enum.Material.Slate,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION - Vector3.new(0, 2.5, 0)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = hub

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallY = wallH / 2

	for _, wall in {
		{ name = "WallNorth", size = Vector3.new(HubConfig.FLOOR_SIZE.X + 2, wallH, 2), pos = Vector3.new(0, wallY, -halfZ) },
		{ name = "WallSouth", size = Vector3.new(HubConfig.FLOOR_SIZE.X + 2, wallH, 2), pos = Vector3.new(0, wallY, halfZ) },
		{ name = "WallWest", size = Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z + 2), pos = Vector3.new(-halfX, wallY, 0) },
		{ name = "WallEast", size = Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z + 2), pos = Vector3.new(halfX, wallY, 0) },
	} do
		makePart({
			parent = hub,
			name = wall.name,
			size = wall.size,
			position = wall.pos,
			color = Color3.fromRGB(50, 55, 75),
			material = Enum.Material.Concrete,
		})
	end

	local leaderboardBoard = nil

	for zoneKey, zone in HubConfig.ZONES do
		local zonePart = makePart({
			parent = zonesFolder,
			name = zone.id,
			size = zone.size,
			position = zone.position,
			color = zone.color,
			material = Enum.Material.Neon,
			transparency = 0.65,
			canCollide = false,
		})
		zonePart:SetAttribute("ZoneId", zone.id)

		local trigger = makePart({
			parent = zonePart,
			name = "Trigger",
			size = zone.size + Vector3.new(2, 4, 2),
			position = zone.position + Vector3.new(0, 2, 0),
			transparency = 1,
			canCollide = false,
		})
		trigger:SetAttribute("ZoneId", zone.id)

		makeSign(hub, zone.name, zone.position, zone.color)

		if zoneKey == "HallOfFame" then
			leaderboardBoard = buildLeaderboardBoard(hub, zonePart)
		end
	end

	hub:SetAttribute("Built", true)
	return hub, leaderboardBoard
end

function HubWorldBuilder.updateLeaderboardBoard(board, entries)
	if not board then return end
	local gui = board:FindFirstChild("BoardGui")
	if not gui then return end
	local list = gui:FindFirstChild("List")
	if not list then return end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		list.Text = "Noch keine Einträge"
	else
		list.Text = table.concat(lines, "\n")
	end
end

return HubWorldBuilder
