local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.Position = props.position
	part.Color = props.color or Color3.fromRGB(40, 44, 52)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Transparency = props.transparency or 0
	part.Parent = props.parent
	return part
end

local function addBillboard(parent, title, subtitle, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 80)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = false
	gui.Parent = parent

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -8, 0.55, 0)
	titleLabel.Position = UDim2.fromOffset(4, 2)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 18
	titleLabel.TextColor3 = color or Color3.new(1, 1, 1)
	titleLabel.Text = title
	titleLabel.Parent = frame

	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, -8, 0.4, 0)
	subLabel.Position = UDim2.new(0, 4, 0.55, 0)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextSize = 13
	subLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
	subLabel.Text = subtitle or ""
	subLabel.TextWrapped = true
	subLabel.Parent = frame

	return gui
end

local function addProximityPrompt(part, actionText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText or "Interagieren"
	prompt.ObjectText = part.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

function HubWorldBuilder.buildLeaderboardBoard(parent, entries)
	local board = makePart({
		name = "LeaderboardBoard",
		parent = parent,
		size = Vector3.new(10, 7, 0.5),
		position = HubConfig.ZONES.HallOfFame.position + Vector3.new(0, 2, -7),
		color = Color3.fromRGB(30, 32, 40),
		material = Enum.Material.Metal,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 50)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 28
	title.TextColor3 = Color3.fromRGB(255, 210, 80)
	title.Text = "🏆 Nova Liga — Top 5"
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "Entries"
	list.Size = UDim2.new(1, -16, 1, -58)
	list.Position = UDim2.fromOffset(8, 52)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextSize = 22
	list.TextColor3 = Color3.fromRGB(230, 230, 240)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextWrapped = true
	list.Parent = frame

	HubWorldBuilder.updateLeaderboardBoard(board, entries)
	return board
end

function HubWorldBuilder.updateLeaderboardBoard(board, entries)
	local surface = board:FindFirstChildOfClass("SurfaceGui")
	if not surface then return end
	local entriesLabel = surface:FindFirstChild("Frame") and surface.Frame:FindFirstChild("Entries")
	if not entriesLabel then return end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		entriesLabel.Text = "Noch keine Einträge"
	else
		entriesLabel.Text = table.concat(lines, "\n")
	end
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_NAME
	hub.Parent = workspace

	local floor = makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		position = HubConfig.FLOOR_POSITION,
		color = Color3.fromRGB(35, 38, 48),
		material = Enum.Material.Slate,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallY = HubConfig.WALL_HEIGHT / 2

	local walls = {
		{ Vector3.new(0, wallY, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, 1) },
		{ Vector3.new(0, wallY, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, 1) },
		{ Vector3.new(-halfX, wallY, 0), Vector3.new(1, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(halfX, wallY, 0), Vector3.new(1, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
	}
	for i, wall in walls do
		makePart({
			name = "Wall" .. i,
			parent = hub,
			size = wall[2],
			position = wall[1],
			color = Color3.fromRGB(50, 54, 64),
			material = Enum.Material.Concrete,
		})
	end

	makePart({
		name = "SpawnMarker",
		parent = hub,
		size = Vector3.new(6, 0.2, 6),
		position = HubConfig.SPAWN - Vector3.new(0, 3, 0),
		color = Color3.fromRGB(100, 180, 255),
		material = Enum.Material.Neon,
		transparency = 0.4,
		canCollide = false,
	})

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	local zoneParts = {}
	for _, zone in HubConfig.ZONES do
		local pad = makePart({
			name = zone.id,
			parent = zonesFolder,
			size = zone.size,
			position = zone.position,
			color = zone.color,
			material = Enum.Material.Neon,
			transparency = 0.65,
			canCollide = false,
		})
		pad:SetAttribute("ZoneId", zone.id)
		pad:SetAttribute("ZoneAction", zone.action)
		addBillboard(pad, zone.name, zone.hint, zone.color)
		addProximityPrompt(pad, zone.name)
		zoneParts[zone.id] = pad
	end

	local leaderboardBoard = HubWorldBuilder.buildLeaderboardBoard(hub, {})

	return hub, zoneParts, leaderboardBoard
end

return HubWorldBuilder
