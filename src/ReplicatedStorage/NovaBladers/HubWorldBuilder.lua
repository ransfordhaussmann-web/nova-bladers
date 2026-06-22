local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.Position = props.position
	part.Color = props.color or Color3.fromRGB(60, 65, 80)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	if props.transparency then
		part.Transparency = props.transparency
	end
	return part
end

local function buildWalls(parent, floorSize, floorY)
	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local height = HubConfig.WALL_HEIGHT
	local thick = HubConfig.WALL_THICKNESS
	local wallY = floorY + height / 2
	local wallColor = Color3.fromRGB(50, 55, 70)

	local walls = {
		{ Vector3.new(0, wallY, -halfZ - thick / 2), Vector3.new(floorSize.X + thick * 2, height, thick) },
		{ Vector3.new(0, wallY, halfZ + thick / 2), Vector3.new(floorSize.X + thick * 2, height, thick) },
		{ Vector3.new(-halfX - thick / 2, wallY, 0), Vector3.new(thick, height, floorSize.Z) },
		{ Vector3.new(halfX + thick / 2, wallY, 0), Vector3.new(thick, height, floorSize.Z) },
	}

	for i, wall in walls do
		makePart({
			name = "Wall" .. i,
			parent = parent,
			position = wall[1],
			size = wall[2],
			color = wallColor,
			material = Enum.Material.Concrete,
		})
	end
end

local function buildZoneMarker(parent, zone)
	local marker = makePart({
		name = zone.id,
		parent = parent,
		position = zone.position,
		size = zone.size,
		color = zone.color,
		material = Enum.Material.Neon,
		canCollide = false,
	})
	marker.Transparency = 0.35
	marker:SetAttribute("ZoneId", zone.id)
	marker:SetAttribute("Hint", zone.hint)
	marker:SetAttribute("Action", zone.action)

	local label = Instance.new("BillboardGui")
	label.Name = "Label"
	label.Size = UDim2.fromOffset(200, 50)
	label.StudsOffset = Vector3.new(0, 4, 0)
	label.AlwaysOnTop = true
	label.Parent = marker

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.5
	text.TextSize = 16
	text.Text = zone.id:gsub("(%u)", " %1"):gsub("^%s", "")
	text.Parent = label

	return marker
end

local function buildLeaderboardBoard(parent)
	local boardCfg = HubConfig.LEADERBOARD_BOARD
	local board = makePart({
		name = "LeaderboardBoard",
		parent = parent,
		position = boardCfg.position,
		size = boardCfg.size,
		color = Color3.fromRGB(25, 28, 38),
		material = Enum.Material.Slate,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "BoardGui"
	surface.Face = boardCfg.face
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.Parent = board

	local frame = Instance.new("Frame")
	frame.Name = "Content"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 48)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 210, 80)
	title.TextSize = 22
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.new(0, 12, 0, 52)
	list.Size = UDim2.new(1, -24, 1, -60)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextColor3 = Color3.fromRGB(220, 220, 230)
	list.TextSize = 18
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextWrapped = true
	list.Text = "Lade Rangliste…"
	list.Parent = frame

	return board
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER
	hub.Parent = workspace

	local floorY = HubConfig.SPAWN.Y - 3
	local floor = makePart({
		name = "Floor",
		parent = hub,
		position = Vector3.new(0, floorY, HubConfig.SPAWN.Z),
		size = HubConfig.FLOOR_SIZE,
		color = HubConfig.FLOOR_COLOR,
		material = Enum.Material.Grass,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	buildWalls(hub, HubConfig.FLOOR_SIZE, floorY)

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		buildZoneMarker(zonesFolder, zone)
	end

	buildLeaderboardBoard(hub)

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 40
	light.Color = Color3.fromRGB(255, 240, 200)
	light.Parent = floor

	return hub
end

function HubWorldBuilder.updateLeaderboardBoard(hub, entries)
	local board = hub:FindFirstChild("LeaderboardBoard")
	if not board then return end
	local list = board.BoardGui.Content.List
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
