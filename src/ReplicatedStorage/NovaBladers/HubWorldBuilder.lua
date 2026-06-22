local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	return part
end

local function makeSign(parent, text, position, size)
	local sign = makePart({
		Name = "Sign",
		Size = size or Vector3.new(10, 4, 0.4),
		Position = position,
		Color = Color3.fromRGB(30, 35, 50),
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(240, 245, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	return sign
end

local function makeZoneMarker(parent, zone)
	local marker = makePart({
		Name = zone.id,
		Size = zone.size,
		Position = zone.position + Vector3.new(0, zone.size.Y / 2, 0),
		Color = zone.color,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		CanCollide = false,
		Parent = parent,
	})

	local prompt = makePart({
		Name = "Pad",
		Size = Vector3.new(zone.size.X * 0.7, 0.3, zone.size.Z * 0.7),
		Position = zone.position + Vector3.new(0, 0.2, 0),
		Color = zone.color,
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.2,
		Parent = parent,
	})

	makeSign(parent, zone.name, zone.position + Vector3.new(0, zone.size.Y + 2, 0), Vector3.new(12, 3, 0.4))

	return marker, prompt
end

function HubWorldBuilder.build(leaderboardEntries)
	local existing = workspace:FindFirstChild(HubConfig.WORLD_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.WORLD_NAME
	hub.Parent = workspace

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = Vector3.new(0, -0.5, 0),
		Color = Color3.fromRGB(45, 52, 68),
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	local spawn = makePart({
		Name = "HubSpawn",
		Size = Vector3.new(6, 0.2, 6),
		Position = HubConfig.SPAWN_POSITION - Vector3.new(0, 3.5, 0),
		Color = Color3.fromRGB(100, 180, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.4,
		CanCollide = false,
		Parent = hub,
	})
	spawn.Transparency = 0.4

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS

	local walls = {
		{ Vector3.new(0, wallH / 2, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X + wallT, wallH, wallT) },
		{ Vector3.new(0, wallH / 2, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X + wallT, wallH, wallT) },
		{ Vector3.new(-halfX, wallH / 2, 0), Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(halfX, wallH / 2, 0), Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
	}

	for index, wallData in walls do
		makePart({
			Name = "Wall" .. index,
			Size = wallData[2],
			Position = wallData[1],
			Color = Color3.fromRGB(55, 62, 82),
			Material = Enum.Material.Concrete,
			Parent = hub,
		})
	end

	for _, zone in HubConfig.ZONES do
		makeZoneMarker(zonesFolder, zone)
	end

	HubWorldBuilder.buildLeaderboardBoard(hub, leaderboardEntries or {})

	return hub
end

function HubWorldBuilder.buildLeaderboardBoard(hub, entries)
	local zone = HubConfig.ZONES.HallOfFame
	local board = makePart({
		Name = "LeaderboardBoard",
		Size = Vector3.new(14, 10, 0.6),
		Position = zone.position + Vector3.new(0, 6, -zone.size.Z / 2 - 1),
		Color = Color3.fromRGB(25, 28, 40),
		Material = Enum.Material.SmoothPlastic,
		Parent = hub,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.Text = "🏆 Nova Liga — Top 5"
	title.TextColor3 = Color3.fromRGB(255, 220, 80)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = gui

	local list = Instance.new("TextLabel")
	list.Size = UDim2.new(1, -12, 1, -44)
	list.Position = UDim2.fromOffset(6, 40)
	list.BackgroundTransparency = 1
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextColor3 = Color3.fromRGB(230, 235, 250)
	list.TextSize = 22
	list.Font = Enum.Font.GothamMedium
	list.TextWrapped = true

	local lines = {}
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	else
		for _, entry in entries do
			table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
		end
	end
	list.Text = table.concat(lines, "\n")
	list.Parent = gui

	return board
end

function HubWorldBuilder.findArenaSpawn()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local named = arena:FindFirstChild("Spawn") or arena:FindFirstChild("ArenaSpawn")
		if named and named:IsA("BasePart") then
			return named.CFrame + Vector3.new(0, 3, 0)
		end
	end

	local bowl = workspace:FindFirstChild("Bowl")
	if bowl and bowl:IsA("BasePart") then
		return bowl.CFrame + Vector3.new(0, 5, 0)
	end

	return CFrame.new(0, 8, 0)
end

return HubWorldBuilder
