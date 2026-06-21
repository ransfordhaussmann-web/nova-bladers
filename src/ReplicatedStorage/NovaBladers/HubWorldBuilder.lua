local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Color = props.color or Color3.fromRGB(60, 65, 80)
	part.Size = props.size
	part.CFrame = props.cframe
	part.Name = props.name or "Part"
	part.Transparency = props.transparency or 0
	part.Parent = props.parent
	return part
end

local function makeSign(parent, text, position, color)
	local sign = makePart({
		parent = parent,
		name = "Sign",
		size = Vector3.new(8, 3, 0.4),
		cframe = CFrame.new(position) * CFrame.Angles(0, math.rad(180), 0),
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

local function buildZone(parent, zoneDef)
	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = zoneDef.id
	zoneFolder.Parent = parent

	makePart({
		parent = zoneFolder,
		name = "Platform",
		size = Vector3.new(zoneDef.size.X, 1, zoneDef.size.Z),
		cframe = CFrame.new(zoneDef.position + Vector3.new(0, 0.5, 0)),
		color = zoneDef.color,
		material = Enum.Material.Concrete,
	})

	local trigger = makePart({
		parent = zoneFolder,
		name = "Trigger",
		size = zoneDef.size,
		cframe = CFrame.new(zoneDef.position + Vector3.new(0, zoneDef.size.Y / 2, 0)),
		color = zoneDef.accent,
		transparency = 0.85,
		canCollide = false,
	})
	trigger:SetAttribute("ZoneId", zoneDef.id)

	local archHeight = zoneDef.size.Y
	makePart({
		parent = zoneFolder,
		name = "ArchLeft",
		size = Vector3.new(1.5, archHeight, 1.5),
		cframe = CFrame.new(zoneDef.position + Vector3.new(-zoneDef.size.X / 2 + 1, archHeight / 2, 0)),
		color = zoneDef.accent,
		material = Enum.Material.Metal,
	})
	makePart({
		parent = zoneFolder,
		name = "ArchRight",
		size = Vector3.new(1.5, archHeight, 1.5),
		cframe = CFrame.new(zoneDef.position + Vector3.new(zoneDef.size.X / 2 - 1, archHeight / 2, 0)),
		color = zoneDef.accent,
		material = Enum.Material.Metal,
	})

	makeSign(zoneFolder, zoneDef.name, zoneDef.position + Vector3.new(0, archHeight + 1.5, zoneDef.size.Z / 2 + 1), zoneDef.color)

	return zoneFolder, trigger
end

local function buildLeaderboardBoard(parent, zoneDef, boardConfig)
	local boardFolder = Instance.new("Folder")
	boardFolder.Name = "LeaderboardBoard"
	boardFolder.Parent = parent

	local boardPos = zoneDef.position + boardConfig.offset
	local board = makePart({
		parent = boardFolder,
		name = "Board",
		size = Vector3.new(boardConfig.size.X, boardConfig.size.Y, 0.5),
		cframe = CFrame.new(boardPos),
		color = Color3.fromRGB(30, 32, 45),
		material = Enum.Material.Slate,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.Text = "🏆 Nova Liga — Top 5"
	title.TextColor3 = Color3.fromRGB(255, 220, 100)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = gui

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.fromOffset(0, 40)
	list.Size = UDim2.new(1, 0, 1, -44)
	list.BackgroundTransparency = 1
	list.Text = "Lade Rangliste…"
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextScaled = false
	list.TextSize = 22
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Font = Enum.Font.GothamMedium
	list.Parent = gui

	return boardFolder
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_NAME
	hub.Parent = workspace

	local floorSize = HubConfig.FLOOR_SIZE
	makePart({
		parent = hub,
		name = "Floor",
		size = floorSize,
		cframe = CFrame.new(0, 0, 0),
		color = Color3.fromRGB(45, 48, 58),
		material = Enum.Material.Slate,
	})

	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS

	local walls = {
		{ Vector3.new(0, wallH / 2, -halfZ), Vector3.new(floorSize.X, wallH, wallT) },
		{ Vector3.new(0, wallH / 2, halfZ), Vector3.new(floorSize.X, wallH, wallT) },
		{ Vector3.new(-halfX, wallH / 2, 0), Vector3.new(wallT, wallH, floorSize.Z) },
		{ Vector3.new(halfX, wallH / 2, 0), Vector3.new(wallT, wallH, floorSize.Z) },
	}
	for i, wall in walls do
		makePart({
			parent = hub,
			name = "Wall" .. i,
			size = wall[2],
			cframe = CFrame.new(wall[1]),
			color = Color3.fromRGB(55, 58, 72),
			material = Enum.Material.Brick,
		})
	end

	local spawn = makePart({
		parent = hub,
		name = "HubSpawn",
		size = Vector3.new(6, 0.2, 6),
		cframe = CFrame.new(HubConfig.SPAWN_OFFSET),
		color = Color3.fromRGB(100, 180, 255),
		material = Enum.Material.Neon,
		canCollide = false,
	})
	spawn.Transparency = 0.4

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	local triggers = {}
	for _, zoneDef in HubConfig.ZONES do
		local zoneFolder, trigger = buildZone(zonesFolder, zoneDef)
		triggers[zoneDef.id] = trigger

		if zoneDef.id == "HallOfFame" then
			buildLeaderboardBoard(zoneFolder, zoneDef, HubConfig.LEADERBOARD_BOARD)
		end
	end

	makePart({
		parent = hub,
		name = "CenterLogo",
		size = Vector3.new(14, 0.3, 14),
		cframe = CFrame.new(0, 0.2, 0),
		color = Color3.fromRGB(90, 100, 200),
		material = Enum.Material.Neon,
		canCollide = false,
	}).Transparency = 0.5

	return hub, triggers
end

function HubWorldBuilder.updateLeaderboardBoard(hub, entries)
	local hallZone = hub:FindFirstChild("Zones")
		and hub.Zones:FindFirstChild("HallOfFame")
	if not hallZone then return end

	local board = hallZone:FindFirstChild("LeaderboardBoard")
		and hallZone.LeaderboardBoard:FindFirstChild("Board")
	if not board then return end

	local list = board:FindFirstChild("SurfaceGui")
		and board.SurfaceGui:FindFirstChild("List")
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

return HubWorldBuilder
