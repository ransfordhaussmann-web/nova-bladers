local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Color = props.color or Color3.fromRGB(45, 48, 58)
	part.Size = props.size
	part.CFrame = props.cframe
	part.Name = props.name or "Part"
	part.Transparency = props.transparency or 0
	part.Parent = props.parent
	return part
end

local function addZoneLabel(zonePart, zoneData)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 48)
	billboard.StudsOffset = Vector3.new(0, zoneData.size.Y * 0.55, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = zonePart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 18
	label.Text = zoneData.name
	label.Parent = billboard
end

local function buildWalls(hub, floorY, halfX, halfZ)
	local wallH = HubConfig.WALL_HEIGHT
	local thick = HubConfig.WALL_THICKNESS
	local wallY = floorY + wallH / 2

	local specs = {
		{ Vector3.new(halfX * 2 + thick, wallH, thick), Vector3.new(0, wallY, -halfZ) },
		{ Vector3.new(halfX * 2 + thick, wallH, thick), Vector3.new(0, wallY, halfZ) },
		{ Vector3.new(thick, wallH, halfZ * 2 + thick), Vector3.new(-halfX, wallY, 0) },
		{ Vector3.new(thick, wallH, halfZ * 2 + thick), Vector3.new(halfX, wallY, 0) },
	}

	for index, spec in specs do
		makePart({
			name = "Wall" .. index,
			parent = hub,
			size = spec[1],
			cframe = CFrame.new(spec[2]),
			color = Color3.fromRGB(32, 35, 44),
			material = Enum.Material.Concrete,
		})
	end
end

local function buildLeaderboardBoard(zonePart, zoneCFrame)
	local boardCfg = HubConfig.LEADERBOARD_BOARD
	local board = makePart({
		name = "LeaderboardBoard",
		parent = zonePart,
		size = boardCfg.size,
		cframe = zoneCFrame * CFrame.new(boardCfg.offset),
		color = Color3.fromRGB(20, 22, 30),
		material = Enum.Material.Neon,
	})
	board.CanCollide = false

	local surface = Instance.new("SurfaceGui")
	surface.Name = "BoardGui"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 48)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 210, 80)
	title.TextSize = 28
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = surface

	local list = Instance.new("TextLabel")
	list.Name = "Entries"
	list.Position = UDim2.fromOffset(0, 52)
	list.Size = UDim2.new(1, 0, 1, -52)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextSize = 22
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Text = "Lade Rangliste..."
	list.Parent = surface

	return board
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Model")
	hub.Name = HubConfig.HUB_FOLDER_NAME

	local floorSize = HubConfig.FLOOR_SIZE
	local floorY = floorSize.Y / 2
	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2

	makePart({
		name = "Floor",
		parent = hub,
		size = floorSize,
		cframe = CFrame.new(0, floorY, 0),
		color = Color3.fromRGB(38, 42, 52),
		material = Enum.Material.Slate,
	})

	buildWalls(hub, floorY, halfX, halfZ)

	makePart({
		name = "HubSpawn",
		parent = hub,
		size = Vector3.new(6, 0.4, 6),
		cframe = CFrame.new(HubConfig.SPAWN_OFFSET),
		color = Color3.fromRGB(90, 200, 255),
		material = Enum.Material.Neon,
		canCollide = false,
		transparency = 0.35,
	})

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zoneData in HubConfig.ZONES do
		local zoneY = floorY + zoneData.size.Y / 2
		local zoneCFrame = CFrame.new(zoneData.position + Vector3.new(0, zoneY, 0))
		local zonePart = makePart({
			name = zoneData.id,
			parent = zonesFolder,
			size = zoneData.size,
			cframe = zoneCFrame,
			color = zoneData.color,
			material = Enum.Material.ForceField,
			canCollide = false,
			transparency = 0.55,
		})
		zonePart:SetAttribute("ZoneId", zoneData.id)
		zonePart:SetAttribute("Action", zoneData.action)
		addZoneLabel(zonePart, zoneData)

		if zoneData.id == "HallOfFame" then
			buildLeaderboardBoard(zonePart, zoneCFrame)
		end
	end

	hub.Parent = workspace
	return hub
end

function HubWorldBuilder.getSpawnCFrame(hub)
	local spawn = hub:FindFirstChild("HubSpawn", true)
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubConfig.SPAWN_OFFSET + Vector3.new(0, 3, 0))
end

function HubWorldBuilder.getLeaderboardBoard(hub)
	local zone = hub:FindFirstChild("HallOfFame", true)
	if not zone then return nil end
	local board = zone:FindFirstChild("LeaderboardBoard")
	if not board then return nil end
	local gui = board:FindFirstChild("BoardGui")
	if not gui then return nil end
	return gui:FindFirstChild("Entries")
end

return HubWorldBuilder
