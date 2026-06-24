local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}
local built = false

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.fromRGB(45, 50, 65)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name
	part.Transparency = props.transparency or 0
	part.Parent = props.parent
	return part
end

local function makeSign(parent, text, position, color)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = color
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.Text = text
	label.Parent = billboard

	return billboard
end

local function buildGeometry(hub)
	local geometry = Instance.new("Folder")
	geometry.Name = "Geometry"
	geometry.Parent = hub

	local floorSize = HubConfig.FLOOR_SIZE
	makePart({
		name = "Floor",
		parent = geometry,
		size = floorSize,
		cframe = CFrame.new(0, floorSize.Y * 0.5, 0),
		color = Color3.fromRGB(35, 40, 52),
		material = Enum.Material.Slate,
	})

	makePart({
		name = "SpawnPad",
		parent = geometry,
		size = Vector3.new(10, 0.4, 10),
		cframe = CFrame.new(HubConfig.SPAWN_POSITION.X, 0.7, HubConfig.SPAWN_POSITION.Z),
		color = Color3.fromRGB(90, 120, 200),
		material = Enum.Material.Neon,
		transparency = 0.2,
	})

	local halfX = floorSize.X * 0.5
	local halfZ = floorSize.Z * 0.5
	local wallH = HubConfig.WALL_HEIGHT
	local wallThickness = 2
	local wallY = wallH * 0.5 + floorSize.Y

	local walls = {
		{ name = "WallNorth", size = Vector3.new(floorSize.X + 4, wallH, wallThickness), pos = Vector3.new(0, wallY, -halfZ) },
		{ name = "WallSouth", size = Vector3.new(floorSize.X + 4, wallH, wallThickness), pos = Vector3.new(0, wallY, halfZ) },
		{ name = "WallWest", size = Vector3.new(wallThickness, wallH, floorSize.Z + 4), pos = Vector3.new(-halfX, wallY, 0) },
		{ name = "WallEast", size = Vector3.new(wallThickness, wallH, floorSize.Z + 4), pos = Vector3.new(halfX, wallY, 0) },
	}

	for _, wall in walls do
		makePart({
			name = wall.name,
			parent = geometry,
			size = wall.size,
			cframe = CFrame.new(wall.pos),
			color = Color3.fromRGB(28, 32, 42),
			material = Enum.Material.Concrete,
		})
	end

	return geometry
end

local function buildZones(hub)
	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local part = makePart({
			name = zone.id,
			parent = zonesFolder,
			size = zone.size,
			cframe = CFrame.new(zone.position),
			color = zone.color,
			material = Enum.Material.Neon,
			transparency = 0.55,
			canCollide = false,
		})
		part:SetAttribute("ZoneId", zone.id)
		part:SetAttribute("Action", zone.action)
		makeSign(part, zone.name, zone.position, zone.color)
	end

	return zonesFolder
end

local function buildLeaderboardBoard(hub)
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = hub

	local hallZone = HubConfig.ZONES.HallOfFame
	local board = makePart({
		name = "LeaderboardBoard",
		parent = decor,
		size = Vector3.new(10, 7, 0.4),
		cframe = CFrame.new(hallZone.position.X - 9, 6, hallZone.position.Z),
		color = Color3.fromRGB(20, 22, 30),
		material = Enum.Material.SmoothPlastic,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "BoardGui"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStuds
	surface.PixelsPerStud = 50
	surface.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextColor3 = Color3.fromRGB(255, 210, 80)
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = surface

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.fromOffset(0, 44)
	list.Size = UDim2.new(1, 0, 1, -44)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextSize = 16
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Text = "Lade Bestenliste…"
	list.Parent = surface

	return board
end

function HubWorldBuilder.build()
	if built then
		return workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	end

	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	if existing then
		built = true
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER
	hub.Parent = workspace

	buildGeometry(hub)
	buildZones(hub)
	buildLeaderboardBoard(hub)

	built = true
	return hub
end

function HubWorldBuilder.updateLeaderboard(entries)
	local hub = workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	if not hub then return end

	local board = hub:FindFirstChild("Decor")
		and hub.Decor:FindFirstChild("LeaderboardBoard")
	if not board then return end

	local gui = board:FindFirstChild("BoardGui")
	local list = gui and gui:FindFirstChild("List")
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
