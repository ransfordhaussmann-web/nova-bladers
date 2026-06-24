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
		Size = Vector3.new(10, 4, 0.5),
		Position = position,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
	})
	sign.Parent = parent

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

local function buildLeaderboardBoard(parent, position)
	local board = makePart({
		Name = "LeaderboardBoard",
		Size = Vector3.new(12, 8, 0.5),
		Position = position + Vector3.new(0, 5, -6),
		Color = Color3.fromRGB(30, 30, 40),
		Material = Enum.Material.Metal,
	})
	board.Parent = parent

	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 60)
	title.BackgroundTransparency = 1
	title.Text = "🏆 Ruhmeshalle"
	title.TextColor3 = Color3.fromRGB(255, 220, 80)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = gui

	local list = Instance.new("TextLabel")
	list.Name = "Entries"
	list.Position = UDim2.fromOffset(0, 60)
	list.Size = UDim2.new(1, 0, 1, -60)
	list.BackgroundTransparency = 1
	list.Text = "Lade Rangliste..."
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextScaled = false
	list.TextSize = 28
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Font = Enum.Font.Gotham
	list.Parent = gui
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	local floorY = HubConfig.SPAWN_CFRAME.Position.Y - 3
	local center = Vector3.new(0, floorY, 0)

	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = center,
		Color = Color3.fromRGB(45, 48, 58),
		Material = Enum.Material.Slate,
	})
	floor.Parent = hub

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS

	local walls = {
		{ Vector3.new(0, floorY + wallH / 2, halfZ + wallT / 2), Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT) },
		{ Vector3.new(0, floorY + wallH / 2, -halfZ - wallT / 2), Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT) },
		{ Vector3.new(halfX + wallT / 2, floorY + wallH / 2, 0), Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(-halfX - wallT / 2, floorY + wallH / 2, 0), Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
	}

	for index, wallData in walls do
		local wall = makePart({
			Name = "Wall" .. index,
			Size = wallData[2],
			Position = wallData[1],
			Color = Color3.fromRGB(35, 38, 48),
			Material = Enum.Material.Concrete,
		})
		wall.Parent = hub
	end

	local spawn = makePart({
		Name = "HubSpawn",
		Size = Vector3.new(6, 1, 6),
		Position = Vector3.new(HubConfig.SPAWN_CFRAME.Position.X, floorY + 0.5, HubConfig.SPAWN_CFRAME.Position.Z),
		Color = Color3.fromRGB(90, 200, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.35,
	})
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local pad = makePart({
			Name = zone.id,
			Size = zone.size,
			Position = Vector3.new(zone.position.X, floorY + zone.position.Y, zone.position.Z),
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.55,
		})
		pad:SetAttribute("ZoneId", zone.id)
		pad:SetAttribute("ZoneAction", zone.action)
		pad.Parent = zonesFolder

		addSign(
			zonesFolder,
			zone.name,
			pad.Position + Vector3.new(0, 4, 0),
			zone.color
		)

		if zone.id == "HallOfFame" then
			buildLeaderboardBoard(zonesFolder, pad.Position)
		end
	end

	local lighting = Instance.new("PointLight")
	lighting.Brightness = 1.2
	lighting.Range = 40
	lighting.Parent = spawn

	return hub
end

return HubWorldBuilder
