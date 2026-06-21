local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Color = props.color or Color3.fromRGB(40, 44, 56)
	part.Size = props.size
	part.CFrame = props.cframe
	part.Name = props.name or "Part"
	part.Transparency = props.transparency or 0
	part.Parent = props.parent
	return part
end

local function makeSign(parent, text, position, color)
	local sign = makePart({
		parent = parent,
		name = "Sign",
		size = Vector3.new(10, 3, 0.4),
		cframe = CFrame.new(position),
		color = Color3.fromRGB(30, 32, 40),
		material = Enum.Material.Metal,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	return sign
end

local function makeZonePad(parent, zone)
	local pad = makePart({
		parent = parent,
		name = zone.id,
		size = zone.size,
		cframe = CFrame.new(zone.position),
		color = zone.color,
		material = Enum.Material.Neon,
		transparency = 0.35,
		canCollide = false,
	})

	local light = Instance.new("PointLight")
	light.Color = zone.color
	light.Brightness = 0.6
	light.Range = 14
	light.Parent = pad

	return pad
end

function HubWorldBuilder.buildLeaderboardBoard(parent, entries)
	local boardConfig = HubConfig.LEADERBOARD_BOARD
	local existing = parent:FindFirstChild("LeaderboardBoard")
	if existing then
		existing:Destroy()
	end

	local board = makePart({
		parent = parent,
		name = "LeaderboardBoard",
		size = boardConfig.size,
		cframe = CFrame.new(boardConfig.position),
		color = Color3.fromRGB(20, 22, 30),
		material = Enum.Material.Slate,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = boardConfig.face
	gui.Parent = board

	local label = Instance.new("TextLabel")
	label.Name = "BoardLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 230, 120)
	label.TextScaled = false
	label.TextSize = 22
	label.TextWrapped = true
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Font = Enum.Font.GothamMedium
	label.Parent = gui

	local lines = { "🏆 Ruhmeshalle" }
	if entries and #entries > 0 then
		for _, entry in entries do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
	else
		table.insert(lines, "Noch keine Einträge")
	end
	label.Text = table.concat(lines, "\n")

	return board
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Model")
	hub.Name = HubConfig.HUB_NAME
	hub.Parent = workspace

	local floorSize = HubConfig.FLOOR_SIZE
	makePart({
		parent = hub,
		name = "Floor",
		size = floorSize,
		cframe = CFrame.new(0, 0, 0),
		color = Color3.fromRGB(32, 36, 48),
		material = Enum.Material.Concrete,
	})

	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS

	local walls = {
		{ name = "WallNorth", size = Vector3.new(floorSize.X + wallT * 2, wallH, wallT), pos = Vector3.new(0, wallH / 2, -halfZ - wallT / 2) },
		{ name = "WallSouth", size = Vector3.new(floorSize.X + wallT * 2, wallH, wallT), pos = Vector3.new(0, wallH / 2, halfZ + wallT / 2) },
		{ name = "WallWest", size = Vector3.new(wallT, wallH, floorSize.Z), pos = Vector3.new(-halfX - wallT / 2, wallH / 2, 0) },
		{ name = "WallEast", size = Vector3.new(wallT, wallH, floorSize.Z), pos = Vector3.new(halfX + wallT / 2, wallH / 2, 0) },
	}

	for _, wall in walls do
		makePart({
			parent = hub,
			name = wall.name,
			size = wall.size,
			cframe = CFrame.new(wall.pos),
			color = Color3.fromRGB(50, 54, 68),
			material = Enum.Material.Brick,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		makeZonePad(zonesFolder, zone)
		local signOffset = zone.position + Vector3.new(0, 5, 0)
		makeSign(zonesFolder, zone.label, signOffset, zone.color)
	end

	makeSign(hub, "Nova Bladers Hub", Vector3.new(0, 8, -20), Color3.fromRGB(120, 180, 255))

	return hub
end

return HubWorldBuilder
