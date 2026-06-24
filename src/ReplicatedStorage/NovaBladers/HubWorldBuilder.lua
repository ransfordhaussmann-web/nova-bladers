local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.Position = props.position
	part.Color = props.color or Color3.new(1, 1, 1)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Transparency = props.transparency or 0
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function makeZoneLabel(parent, zone)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, zone.size.Y / 2 + 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 18
	label.Text = zone.name
	label.Parent = billboard
end

local function makeProximityPrompt(parent, zone)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zone.promptText
	prompt.ObjectText = zone.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ZoneId", zone.id)
	prompt:SetAttribute("ZoneAction", zone.action)
	prompt.Parent = parent
end

function HubWorldBuilder.buildLeaderboardBoard(parent, entries)
	local existing = parent:FindFirstChild("LeaderboardBoard")
	if existing then
		existing:Destroy()
	end

	local board = makePart({
		name = "LeaderboardBoard",
		parent = parent,
		size = Vector3.new(8, 6, 0.4),
		position = Vector3.new(28, 5, 14),
		color = Color3.fromRGB(25, 28, 40),
		material = Enum.Material.Neon,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "BoardGui"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 50)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextColor3 = Color3.fromRGB(255, 210, 80)
	title.Text = "🏆 Top Nova Bladers"
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "Entries"
	list.Size = UDim2.new(1, -16, 1, -58)
	list.Position = UDim2.fromOffset(8, 54)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextSize = 16
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextWrapped = true
	list.Parent = frame

	local lines = {}
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	else
		for _, entry in entries do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
	end
	list.Text = table.concat(lines, "\n")

	return board
end

function HubWorldBuilder.build(leaderboardEntries)
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER
	hub.Parent = workspace

	local theme = HubConfig.THEME
	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2

	makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		position = Vector3.new(0, 0, 0),
		color = theme.floor,
		material = Enum.Material.Slate,
	})

	local wallDefs = {
		{ name = "WallNorth", size = Vector3.new(HubConfig.FLOOR_SIZE.X + 4, HubConfig.WALL_HEIGHT, HubConfig.WALL_THICKNESS), pos = Vector3.new(0, HubConfig.WALL_HEIGHT / 2, -halfZ - 1) },
		{ name = "WallSouth", size = Vector3.new(HubConfig.FLOOR_SIZE.X + 4, HubConfig.WALL_HEIGHT, HubConfig.WALL_THICKNESS), pos = Vector3.new(0, HubConfig.WALL_HEIGHT / 2, halfZ + 1) },
		{ name = "WallWest", size = Vector3.new(HubConfig.WALL_THICKNESS, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z + 4), pos = Vector3.new(-halfX - 1, HubConfig.WALL_HEIGHT / 2, 0) },
		{ name = "WallEast", size = Vector3.new(HubConfig.WALL_THICKNESS, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z + 4), pos = Vector3.new(halfX + 1, HubConfig.WALL_HEIGHT / 2, 0) },
	}

	for _, wall in wallDefs do
		makePart({
			name = wall.name,
			parent = hub,
			size = wall.size,
			position = wall.pos,
			color = theme.wall,
		})
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zonePart = makePart({
			name = zone.id,
			parent = zonesFolder,
			size = zone.size,
			position = zone.position,
			color = zone.color,
			transparency = 0.35,
			canCollide = false,
		})
		zonePart:SetAttribute("ZoneId", zone.id)
		zonePart:SetAttribute("ZoneAction", zone.action)
		zonePart:SetAttribute("ZoneHint", zone.hint)
		makeZoneLabel(zonePart, zone)
		makeProximityPrompt(zonePart, zone)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION - Vector3.new(0, 2.5, 0)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	HubWorldBuilder.buildLeaderboardBoard(hub, leaderboardEntries or {})

	return hub
end

return HubWorldBuilder
