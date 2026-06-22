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

local function createZoneSign(parent, text, position, color)
	local sign = makePart({
		Name = "Sign",
		Size = Vector3.new(8, 3, 0.5),
		Position = position + Vector3.new(0, 6, 0),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
		Parent = parent,
	})

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = surfaceGui

	return sign
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Model")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = Vector3.new(0, 0, 0),
		Color = Color3.fromRGB(35, 40, 55),
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = hub

	local wallHeight = 12
	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local walls = {
		{ Vector3.new(0, wallHeight / 2, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, wallHeight, 2) },
		{ Vector3.new(0, wallHeight / 2, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, wallHeight, 2) },
		{ Vector3.new(-halfX, wallHeight / 2, 0), Vector3.new(2, wallHeight, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(halfX, wallHeight / 2, 0), Vector3.new(2, wallHeight, HubConfig.FLOOR_SIZE.Z) },
	}

	for index, wall in walls do
		makePart({
			Name = "Wall" .. index,
			Position = wall[1],
			Size = wall[2],
			Color = Color3.fromRGB(50, 55, 75),
			Material = Enum.Material.Concrete,
			Parent = hub,
		})
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for zoneId, zone in HubConfig.ZONES do
		local zonePart = makePart({
			Name = zoneId,
			Size = zone.size,
			Position = zone.position,
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.65,
			CanCollide = false,
			Parent = zonesFolder,
		})

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = zone.name
		prompt.ObjectText = zone.hint
		prompt.MaxActivationDistance = HubConfig.INTERACT_DISTANCE
		prompt.HoldDuration = 0
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt:SetAttribute("ZoneId", zoneId)
		prompt:SetAttribute("Action", zone.action)
		prompt.Parent = zonePart

		createZoneSign(zonesFolder, zone.name, zone.position, zone.color)
	end

	local hallZone = HubConfig.ZONES.HallOfFame
	local board = makePart({
		Name = "LeaderboardBoard",
		Size = Vector3.new(10, 8, 0.5),
		Position = hallZone.position + Vector3.new(0, 5, 4),
		Color = Color3.fromRGB(25, 25, 35),
		Material = Enum.Material.SmoothPlastic,
		Parent = hub,
	})

	local boardGui = Instance.new("SurfaceGui")
	boardGui.Face = Enum.NormalId.Back
	boardGui.CanvasSize = Vector2.new(400, 500)
	boardGui.Parent = board

	local boardLabel = Instance.new("TextLabel")
	boardLabel.Name = "BoardLabel"
	boardLabel.Size = UDim2.fromScale(1, 1)
	boardLabel.BackgroundTransparency = 1
	boardLabel.Text = "🏆 Ruhmeshalle\nLädt..."
	boardLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
	boardLabel.Font = Enum.Font.GothamBold
	boardLabel.TextSize = 28
	boardLabel.TextWrapped = true
	boardLabel.Parent = boardGui

	hub.PrimaryPart = floor
	return hub
end

function HubWorldBuilder.updateLeaderboardBoard(entries)
	local hub = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if not hub then
		return
	end

	local board = hub:FindFirstChild("LeaderboardBoard")
	if not board then
		return
	end

	local surfaceGui = board:FindFirstChildOfClass("SurfaceGui")
	if not surfaceGui then
		return
	end

	local label = surfaceGui:FindFirstChild("BoardLabel")
	if not label then
		return
	end

	local lines = { "🏆 Top Spieler" }
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	label.Text = table.concat(lines, "\n")
end

return HubWorldBuilder
