local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Color = props.Color or Color3.fromRGB(35, 38, 48)
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Name = props.Name or "Part"
	part.Transparency = props.Transparency or 0
	if props.Parent then
		part.Parent = props.Parent
	end
	return part
end

local function createSign(parent, zone)
	local sign = makePart({
		Name = zone.id .. "_Sign",
		Size = Vector3.new(10, 3, 0.4),
		CFrame = CFrame.new(zone.position + zone.signOffset),
		Color = zone.color,
		Material = Enum.Material.Neon,
		Parent = parent,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = zone.name
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	return sign
end

local function createZone(parent, zone)
	local pad = makePart({
		Name = zone.id,
		Size = zone.size,
		CFrame = CFrame.new(zone.position),
		Color = zone.color,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		Parent = parent,
	})
	pad:SetAttribute("ZoneId", zone.id)
	pad:SetAttribute("ZoneName", zone.name)
	pad:SetAttribute("ZoneHint", zone.hint)
	pad:SetAttribute("ZoneAction", zone.action)
	pad:SetAttribute("ZoneActionLabel", zone.actionLabel)

	local border = makePart({
		Name = zone.id .. "_Border",
		Size = zone.size + Vector3.new(0.6, 0.2, 0.6),
		CFrame = CFrame.new(zone.position - Vector3.new(0, 0.15, 0)),
		Color = zone.color,
		Material = Enum.Material.Metal,
		Transparency = 0.2,
		Parent = parent,
	})

	createSign(parent, zone)
	return pad
end

function HubWorldBuilder.createLeaderboardBoard(parent, entries)
	local boardCfg = HubConfig.LEADERBOARD_BOARD
	local existing = parent:FindFirstChild("LeaderboardBoard")
	if existing then
		existing:Destroy()
	end

	local board = makePart({
		Name = "LeaderboardBoard",
		Size = Vector3.new(boardCfg.size.X, boardCfg.size.Y, 0.4),
		CFrame = CFrame.new(boardCfg.position),
		Color = Color3.fromRGB(20, 22, 30),
		Material = Enum.Material.Slate,
		Parent = parent,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = boardCfg.face
	gui.CanvasSize = Vector2.new(400, 280)
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 48)
	title.BackgroundTransparency = 1
	title.Text = "🏆 Ruhmeshalle"
	title.TextColor3 = Color3.fromRGB(255, 220, 80)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = gui

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.fromOffset(0, 52)
	list.Size = UDim2.new(1, 0, 1, -56)
	list.BackgroundTransparency = 1
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextColor3 = Color3.fromRGB(230, 230, 240)
	list.TextSize = 22
	list.Font = Enum.Font.GothamMedium
	list.TextWrapped = true
	list.Parent = gui

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt.", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	list.Text = table.concat(lines, "\n")

	return board
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Model")
	hub.Name = HubConfig.HUB_FOLDER_NAME

	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		CFrame = CFrame.new(0, 0, 0),
		Color = Color3.fromRGB(28, 30, 38),
		Material = Enum.Material.Concrete,
		Parent = hub,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallY = HubConfig.WALL_HEIGHT / 2

	local walls = {
		{ Vector3.new(0, wallY, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, 1) },
		{ Vector3.new(0, wallY, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, 1) },
		{ Vector3.new(halfX, wallY, 0), Vector3.new(1, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(-halfX, wallY, 0), Vector3.new(1, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
	}
	for i, wall in walls do
		makePart({
			Name = "Wall" .. i,
			Size = wall[2],
			CFrame = CFrame.new(wall[1]),
			Color = Color3.fromRGB(45, 48, 58),
			Parent = hub,
		})
	end

	makePart({
		Name = "SpawnPlatform",
		Size = Vector3.new(14, 0.6, 10),
		CFrame = CFrame.new(HubConfig.SPAWN_POSITION - Vector3.new(0, 2.8, 0)),
		Color = Color3.fromRGB(90, 100, 130),
		Material = Enum.Material.Metal,
		Parent = hub,
	})

	for _, zone in HubConfig.ZONES do
		createZone(hub, zone)
	end

	HubWorldBuilder.createLeaderboardBoard(hub, {})
	hub.Parent = workspace
	return hub
end

return HubWorldBuilder
