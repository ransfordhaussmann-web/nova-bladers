local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Color = props.color or Color3.new(1, 1, 1)
	part.Size = props.size
	part.CFrame = props.cframe
	part.Name = props.name or "Part"
	part.Transparency = props.transparency or 0
	part.Parent = props.parent
	return part
end

local function makeSign(parent, text, position, color)
	local sign = makePart({
		name = "Sign",
		parent = parent,
		size = Vector3.new(10, 3, 0.4),
		cframe = CFrame.new(position),
		color = color,
		material = Enum.Material.Neon,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	return sign
end

function HubWorldBuilder.buildLeaderboardBoard(parent, entries)
	local cfg = HubConfig.LEADERBOARD_BOARD
	local board = makePart({
		name = "LeaderboardBoard",
		parent = parent,
		size = cfg.size,
		cframe = CFrame.new(cfg.position),
		color = Color3.fromRGB(20, 24, 36),
		material = Enum.Material.Slate,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.Text = "🏆 Ruhmeshalle"
	title.TextColor3 = HubConfig.COLORS.HallOfFame
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = gui

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.fromOffset(0, 40)
	list.Size = UDim2.new(1, 0, 1, -44)
	list.BackgroundTransparency = 1
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextSize = 18
	list.Font = Enum.Font.Gotham
	list.Text = ""
	list.Parent = gui

	HubWorldBuilder.updateLeaderboardBoard(board, entries)
	return board
end

function HubWorldBuilder.updateLeaderboardBoard(board, entries)
	local list = board:FindFirstChild("SurfaceGui") and board.SurfaceGui:FindFirstChild("List")
	if not list then return end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	list.Text = table.concat(lines, "\n")
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER
	hub.Parent = workspace

	makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		cframe = CFrame.new(0, -0.5, 0),
		color = HubConfig.COLORS.Floor,
		material = Enum.Material.Concrete,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT

	local walls = {
		{ size = Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 2), pos = Vector3.new(0, wallH / 2, -halfZ) },
		{ size = Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 2), pos = Vector3.new(0, wallH / 2, halfZ) },
		{ size = Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z), pos = Vector3.new(-halfX, wallH / 2, 0) },
		{ size = Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z), pos = Vector3.new(halfX, wallH / 2, 0) },
	}
	for i, wall in walls do
		makePart({
			name = "Wall" .. i,
			parent = hub,
			size = wall.size,
			cframe = CFrame.new(wall.pos),
			color = HubConfig.COLORS.Wall,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN)
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
		local color = HubConfig.COLORS[zone.colorKey] or HubConfig.COLORS.Accent
		local pad = makePart({
			name = zone.id,
			parent = zonesFolder,
			size = zone.size,
			cframe = CFrame.new(zone.position),
			color = color,
			material = Enum.Material.Neon,
			transparency = 0.35,
			canCollide = false,
		})
		pad:SetAttribute("ZoneId", zone.id)
		pad:SetAttribute("Action", zone.action)

		makeSign(hub, zone.name, zone.position + Vector3.new(0, zone.size.Y / 2 + 2.5, 0), color)
	end

	HubWorldBuilder.buildLeaderboardBoard(hub, {})

	return hub
end

return HubWorldBuilder
