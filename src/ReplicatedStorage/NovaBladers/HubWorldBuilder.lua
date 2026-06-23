local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Color = props.color or Color3.fromRGB(45, 50, 65)
	part.Size = props.size
	part.CFrame = props.cframe
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function createZoneMarker(parent, zone)
	local folder = Instance.new("Folder")
	folder.Name = zone.id
	folder.Parent = parent

	local platform = makePart({
		parent = folder,
		name = "Platform",
		size = zone.size,
		cframe = CFrame.new(zone.position),
		color = zone.color,
		material = Enum.Material.Neon,
	})
	platform.Transparency = 0.35

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zone.name
	prompt.ObjectText = zone.hint
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.Parent = platform

	local labelPart = makePart({
		parent = folder,
		name = "Sign",
		size = Vector3.new(6, 2, 0.4),
		cframe = CFrame.new(zone.position + Vector3.new(0, zone.size.Y / 2 + 2, 0)),
		color = Color3.fromRGB(30, 32, 40),
		material = Enum.Material.Slate,
	})
	labelPart.CanCollide = false

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = labelPart

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = zone.name
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.Parent = gui

	return folder
end

function HubWorldBuilder.createLeaderboardBoard(parent, entries)
	local cfg = HubConfig.LEADERBOARD_BOARD
	local board = parent:FindFirstChild("LeaderboardBoard")
	if not board then
		board = makePart({
			parent = parent,
			name = "LeaderboardBoard",
			size = cfg.size,
			cframe = CFrame.new(cfg.position),
			color = Color3.fromRGB(25, 28, 38),
			material = Enum.Material.Metal,
		})
		board.CanCollide = false

		local gui = Instance.new("SurfaceGui")
		gui.Name = "BoardGui"
		gui.Face = cfg.face
		gui.Parent = board

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, 0, 0.15, 0)
		title.BackgroundTransparency = 1
		title.Text = "🏆 Ruhmeshalle"
		title.TextColor3 = Color3.fromRGB(255, 220, 80)
		title.TextScaled = true
		title.Font = Enum.Font.GothamBold
		title.Parent = gui

		local list = Instance.new("TextLabel")
		list.Name = "List"
		list.Position = UDim2.new(0, 0, 0.15, 0)
		list.Size = UDim2.new(1, 0, 0.85, 0)
		list.BackgroundTransparency = 1
		list.TextColor3 = Color3.new(1, 1, 1)
		list.TextScaled = false
		list.TextSize = 28
		list.TextXAlignment = Enum.TextXAlignment.Left
		list.TextYAlignment = Enum.TextYAlignment.Top
		list.Font = Enum.Font.Gotham
		list.Parent = gui
	end

	local listLabel = board.BoardGui.List
	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	listLabel.Text = table.concat(lines, "\n")

	return board
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local floorY = HubConfig.SPAWN.Y - 2.5
	makePart({
		parent = hub,
		name = "Floor",
		size = HubConfig.FLOOR_SIZE,
		cframe = CFrame.new(0, floorY, 0),
		color = Color3.fromRGB(55, 60, 75),
		material = Enum.Material.Concrete,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallY = floorY + wallH / 2

	for _, wall in {
		{ Vector3.new(0, wallY, halfZ + 1), Vector3.new(HubConfig.FLOOR_SIZE.X + 2, wallH, 2) },
		{ Vector3.new(0, wallY, -halfZ - 1), Vector3.new(HubConfig.FLOOR_SIZE.X + 2, wallH, 2) },
		{ Vector3.new(halfX + 1, wallY, 0), Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z + 2) },
		{ Vector3.new(-halfX - 1, wallY, 0), Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z + 2) },
	} do
		makePart({
			parent = hub,
			name = "Wall",
			size = wall[2],
			cframe = CFrame.new(wall[1]),
			color = Color3.fromRGB(35, 38, 50),
			material = Enum.Material.Brick,
		})
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		createZoneMarker(zonesFolder, zone)
	end

	HubWorldBuilder.createLeaderboardBoard(hub, {})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Parent = hub

	return hub
end

return HubWorldBuilder
