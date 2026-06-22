local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.fromRGB(45, 48, 58)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Transparency = props.transparency or 0
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function addBillboard(parent, title, subtitle, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 70)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -12, 0.55, 0)
	titleLabel.Position = UDim2.fromOffset(6, 4)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 18
	titleLabel.TextColor3 = color
	titleLabel.Text = title
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = frame

	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, -12, 0.4, 0)
	subLabel.Position = UDim2.new(0, 6, 0.55, 0)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextSize = 13
	subLabel.TextColor3 = Color3.fromRGB(200, 205, 220)
	subLabel.Text = subtitle
	subLabel.TextXAlignment = Enum.TextXAlignment.Left
	subLabel.TextWrapped = true
	subLabel.Parent = frame
end

local function buildFloor(parent)
	local size = HubConfig.FLOOR_SIZE
	makePart({
		name = "Floor",
		parent = parent,
		size = Vector3.new(size.X, 1, size.Y),
		cframe = CFrame.new(0, HubConfig.FLOOR_Y - 0.5, 0),
		color = Color3.fromRGB(32, 36, 48),
		material = Enum.Material.Slate,
	})
end

local function buildWalls(parent)
	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Y / 2
	local h = HubConfig.WALL_HEIGHT
	local thickness = 2

	local walls = {
		{ Vector3.new(halfX * 2 + thickness, h, thickness), CFrame.new(0, h / 2, halfZ + thickness / 2) },
		{ Vector3.new(halfX * 2 + thickness, h, thickness), CFrame.new(0, h / 2, -halfZ - thickness / 2) },
		{ Vector3.new(thickness, h, halfZ * 2 + thickness), CFrame.new(halfX + thickness / 2, h / 2, 0) },
		{ Vector3.new(thickness, h, halfZ * 2 + thickness), CFrame.new(-halfX - thickness / 2, h / 2, 0) },
	}

	for i, wall in walls do
		makePart({
			name = "Wall" .. i,
			parent = parent,
			size = wall[1],
			cframe = wall[2],
			color = Color3.fromRGB(55, 60, 75),
			material = Enum.Material.Concrete,
		})
	end
end

local function buildSpawn(parent)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = parent
end

local function buildZone(parent, zone)
	local folder = Instance.new("Folder")
	folder.Name = zone.id
	folder.Parent = parent

	local pad = makePart({
		name = "Pad",
		parent = folder,
		size = Vector3.new(zone.size.X, 0.4, zone.size.Z),
		cframe = CFrame.new(zone.center.X, HubConfig.FLOOR_Y + 0.2, zone.center.Z),
		color = zone.color,
		material = Enum.Material.Neon,
		transparency = 0.35,
	})

	local trigger = makePart({
		name = "Trigger",
		parent = folder,
		size = zone.size,
		cframe = CFrame.new(zone.center),
		color = zone.color,
		transparency = 1,
		canCollide = false,
	})
	trigger:SetAttribute("ZoneId", zone.id)

	local pillar = makePart({
		name = "Marker",
		parent = folder,
		size = Vector3.new(2, 8, 2),
		cframe = CFrame.new(zone.center.X, HubConfig.FLOOR_Y + 4, zone.center.Z),
		color = zone.color,
		material = Enum.Material.Neon,
		transparency = 0.15,
	})

	addBillboard(pillar, zone.name, zone.hint, zone.color)

	local light = Instance.new("PointLight")
	light.Color = zone.color
	light.Brightness = 1.2
	light.Range = 18
	light.Parent = pad

	return folder
end

local function buildLeaderboardBoard(parent, zone)
	local board = makePart({
		name = "LeaderboardBoard",
		parent = parent,
		size = Vector3.new(12, 8, 0.5),
		cframe = CFrame.new(zone.center.X - 6, HubConfig.FLOOR_Y + 5, zone.center.Z),
		color = Color3.fromRGB(25, 28, 38),
		material = Enum.Material.Metal,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 50)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 28
	title.TextColor3 = zone.color
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "Entries"
	list.Size = UDim2.new(1, -20, 1, -60)
	list.Position = UDim2.fromOffset(10, 55)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextSize = 22
	list.TextColor3 = Color3.fromRGB(220, 225, 235)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Text = "Lade Rangliste..."
	list.Parent = frame

	return board
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	buildFloor(hub)
	buildWalls(hub)
	buildSpawn(hub)

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zoneFolder = buildZone(zonesFolder, zone)
		if zone.id == "HallOfFame" then
			buildLeaderboardBoard(zoneFolder, zone)
		end
	end

	return hub
end

function HubWorldBuilder.updateLeaderboard(entries)
	local hub = workspace:FindFirstChild("NovaHub")
	if not hub then return end

	local board = hub:FindFirstChild("Zones")
		and hub.Zones:FindFirstChild("HallOfFame")
		and hub.Zones.HallOfFame:FindFirstChild("LeaderboardBoard")
	if not board then return end

	local gui = board:FindFirstChild("BoardGui")
	local list = gui and gui:FindFirstChild("Frame") and gui.Frame:FindFirstChild("Entries")
	if not list then return end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt.", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		list.Text = "Noch keine Einträge"
	else
		list.Text = table.concat(lines, "\n")
	end
end

function HubWorldBuilder.getArenaSpawnCFrame()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local bowl = arena:FindFirstChild("Bowl")
		if bowl and bowl:IsA("BasePart") then
			return bowl.CFrame + Vector3.new(0, 4, 0)
		end
		local spawn = arena:FindFirstChildWhichIsA("SpawnLocation", true)
		if spawn then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(0, 6, 0)
end

return HubWorldBuilder
