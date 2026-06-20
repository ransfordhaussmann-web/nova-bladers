local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.fromRGB(50, 55, 70)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Transparency = props.transparency or 0
	part.Parent = props.parent
	return part
end

local function addLabel(parent, text, offsetY)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, offsetY or 8, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 18
	label.Text = text
	label.Parent = billboard
end

local function addZoneTrigger(zonePart, zoneId)
	local trigger = Instance.new("Part")
	trigger.Name = "Trigger"
	trigger.Anchored = true
	trigger.CanCollide = false
	trigger.Transparency = 1
	trigger.Size = zonePart.Size + Vector3.new(4, 4, 4)
	trigger.CFrame = zonePart.CFrame
	trigger.Parent = zonePart

	local tag = Instance.new("StringValue")
	tag.Name = "ZoneId"
	tag.Value = zoneId
	tag.Parent = trigger
end

function HubWorldBuilder.build(config)
	local existing = workspace:FindFirstChild(config.HUB_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = config.HUB_NAME
	hub.Parent = workspace

	local floorY = config.FLOOR_SIZE.Y / 2
	local floor = makePart({
		name = "Floor",
		size = config.FLOOR_SIZE,
		cframe = CFrame.new(0, floorY, 0),
		color = Color3.fromRGB(35, 40, 55),
		material = Enum.Material.Slate,
		parent = hub,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.CFrame = CFrame.new(config.SPAWN_OFFSET + Vector3.new(0, floorY + 1, 0))
	spawn.Parent = hub

	local halfX = config.FLOOR_SIZE.X / 2
	local halfZ = config.FLOOR_SIZE.Z / 2
	local wallH = config.WALL_HEIGHT
	local wallY = floorY + wallH / 2

	local walls = {
		{ size = Vector3.new(config.FLOOR_SIZE.X, wallH, 2), pos = Vector3.new(0, wallY, halfZ) },
		{ size = Vector3.new(config.FLOOR_SIZE.X, wallH, 2), pos = Vector3.new(0, wallY, -halfZ) },
		{ size = Vector3.new(2, wallH, config.FLOOR_SIZE.Z), pos = Vector3.new(halfX, wallY, 0) },
		{ size = Vector3.new(2, wallH, config.FLOOR_SIZE.Z), pos = Vector3.new(-halfX, wallY, 0) },
	}
	for i, wall in walls do
		makePart({
			name = "Wall" .. i,
			size = wall.size,
			cframe = CFrame.new(wall.pos),
			color = Color3.fromRGB(25, 28, 38),
			material = Enum.Material.Concrete,
			parent = hub,
		})
	end

	for _, zone in config.ZONES do
		local zoneFolder = Instance.new("Folder")
		zoneFolder.Name = zone.id
		zoneFolder.Parent = hub

		local zoneY = floorY + zone.size.Y / 2
		local zonePart = makePart({
			name = "Zone",
			size = zone.size,
			cframe = CFrame.new(zone.position + Vector3.new(0, zoneY, 0)),
			color = zone.color,
			material = Enum.Material.Neon,
			transparency = 0.35,
			canCollide = true,
			parent = zoneFolder,
		})
		addLabel(zonePart, zone.name, zone.size.Y / 2 + 2)
		addZoneTrigger(zonePart, zone.id)
	end

	local hallZone = hub:FindFirstChild("HallOfFame")
	if hallZone then
		local board = makePart({
			name = "LeaderboardBoard",
			size = Vector3.new(10, 8, 0.5),
			cframe = CFrame.new(config.ZONES[3].position + Vector3.new(0, floorY + 5, -5)),
			color = Color3.fromRGB(20, 22, 30),
			material = Enum.Material.Metal,
			parent = hallZone,
		})

		local surface = Instance.new("SurfaceGui")
		surface.Name = "BoardGui"
		surface.Face = Enum.NormalId.Front
		surface.CanvasSize = Vector2.new(400, 320)
		surface.Parent = board

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, 0, 0, 40)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextColor3 = Color3.fromRGB(255, 200, 60)
		title.TextSize = 22
		title.Text = "🏆 Ruhmeshalle"
		title.Parent = surface

		local list = Instance.new("TextLabel")
		list.Name = "Entries"
		list.Position = UDim2.fromOffset(0, 44)
		list.Size = UDim2.new(1, 0, 1, -44)
		list.BackgroundTransparency = 1
		list.Font = Enum.Font.Gotham
		list.TextColor3 = Color3.new(1, 1, 1)
		list.TextSize = 16
		list.TextXAlignment = Enum.TextXAlignment.Left
		list.TextYAlignment = Enum.TextYAlignment.Top
		list.Text = "Lade Rangliste..."
		list.Parent = surface
	end

	return hub
end

function HubWorldBuilder.updateLeaderboard(hub, entries)
	local hall = hub and hub:FindFirstChild("HallOfFame")
	local board = hall and hall:FindFirstChild("LeaderboardBoard")
	local gui = board and board:FindFirstChild("BoardGui")
	local label = gui and gui:FindFirstChild("Entries")
	if not label then return end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		label.Text = "Noch keine Einträge"
	else
		label.Text = table.concat(lines, "\n")
	end
end

return HubWorldBuilder
