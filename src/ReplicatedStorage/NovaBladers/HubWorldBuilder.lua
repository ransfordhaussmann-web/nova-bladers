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

local function addSign(parent, text, position, color)
	local sign = makePart({
		Name = "Sign",
		Size = Vector3.new(8, 3, 0.4),
		Position = position,
		Color = color,
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
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
end

local function buildLeaderboardBoard(parent, entries)
	local board = makePart({
		Name = "LeaderboardBoard",
		Size = Vector3.new(10, 8, 0.5),
		Position = HubConfig.ZONES.HallOfFame.center + Vector3.new(0, 4, -6),
		Color = Color3.fromRGB(30, 30, 40),
		Material = Enum.Material.Metal,
		Parent = parent,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.Text = "🏆 Ruhmeshalle"
	title.TextColor3 = Color3.fromRGB(255, 220, 100)
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

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	list.Text = table.concat(lines, "\n")

	return board
end

function HubWorldBuilder.build(leaderboardEntries)
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Model")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local floorY = HubConfig.SPAWN.Y - 2.5
	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = Vector3.new(0, floorY, 0),
		Color = Color3.fromRGB(45, 48, 58),
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS
	local wallY = floorY + wallH / 2

	local walls = {
		{ Vector3.new(0, wallY, halfZ + wallT / 2), Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT) },
		{ Vector3.new(0, wallY, -halfZ - wallT / 2), Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT) },
		{ Vector3.new(halfX + wallT / 2, wallY, 0), Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(-halfX - wallT / 2, wallY, 0), Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
	}

	for index, spec in walls do
		makePart({
			Name = "Wall" .. index,
			Size = spec[2],
			Position = spec[1],
			Color = Color3.fromRGB(60, 64, 78),
			Material = Enum.Material.Concrete,
			Parent = hub,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for zoneId, zone in HubConfig.ZONES do
		local zonePart = makePart({
			Name = zoneId,
			Size = zone.size,
			Position = zone.center,
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.65,
			CanCollide = false,
			Parent = zonesFolder,
		})
		zonePart:SetAttribute("ZoneId", zone.id)

		local pad = makePart({
			Name = zoneId .. "Pad",
			Size = Vector3.new(zone.size.X, 0.3, zone.size.Z),
			Position = zone.center - Vector3.new(0, zone.size.Y / 2 - 0.15, 0),
			Color = zone.color,
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.2,
			Parent = zonesFolder,
		})
		pad:SetAttribute("ZoneId", zone.id)

		addSign(zonesFolder, zone.name, zone.center + Vector3.new(0, zone.size.Y / 2 + 2, 0), zone.color)
	end

	buildLeaderboardBoard(hub, leaderboardEntries or {})

	hub.PrimaryPart = floor
	return hub
end

return HubWorldBuilder
