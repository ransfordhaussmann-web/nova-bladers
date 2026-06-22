local HubConfig = require(script.Parent.HubConfig)

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
	part.Parent = props.parent
	return part
end

local function makeLabel(parent, text, size, position)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, size.Y / 2 + 2, 0)
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

	return billboard
end

function HubWorldBuilder.buildLeaderboardBoard(hub, entries)
	local cfg = HubConfig.LEADERBOARD_BOARD
	local board = hub:FindFirstChild("LeaderboardBoard")
	if not board then
		board = makePart({
			name = "LeaderboardBoard",
			parent = hub,
			size = Vector3.new(cfg.size.X, cfg.size.Y, 0.4),
			cframe = CFrame.new(cfg.position),
			color = Color3.fromRGB(30, 32, 45),
			material = Enum.Material.Metal,
		})
	end

	local surface = board:FindFirstChild("BoardGui")
	if not surface then
		surface = Instance.new("SurfaceGui")
		surface.Name = "BoardGui"
		surface.Face = cfg.face
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStuds
		surface.PixelsPerStud = 50
		surface.Parent = board
	end

	local frame = surface:FindFirstChild("Frame")
	if not frame then
		frame = Instance.new("Frame")
		frame.Name = "Frame"
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
		frame.BorderSizePixel = 0
		frame.Parent = surface

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, 0, 0, 40)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextSize = 22
		title.TextColor3 = Color3.fromRGB(255, 200, 60)
		title.Text = "🏆 Ruhmeshalle"
		title.Parent = frame

		local list = Instance.new("TextLabel")
		list.Name = "List"
		list.Size = UDim2.new(1, -16, 1, -48)
		list.Position = UDim2.fromOffset(8, 44)
		list.BackgroundTransparency = 1
		list.Font = Enum.Font.Gotham
		list.TextSize = 16
		list.TextXAlignment = Enum.TextXAlignment.Left
		list.TextYAlignment = Enum.TextYAlignment.Top
		list.TextColor3 = Color3.fromRGB(230, 230, 240)
		list.TextWrapped = true
		list.Parent = frame
	end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	frame.List.Text = table.concat(lines, "\n")
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Model")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local floorSize = HubConfig.FLOOR_SIZE
	makePart({
		name = "Floor",
		parent = hub,
		size = floorSize,
		cframe = CFrame.new(0, floorSize.Y / 2, 0),
		color = Color3.fromRGB(42, 46, 58),
		material = Enum.Material.Slate,
	})

	local wallH = HubConfig.WALL_HEIGHT
	local wallThickness = 2
	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local wallY = wallH / 2 + floorSize.Y

	local walls = {
		{ Vector3.new(0, wallY, halfZ + wallThickness / 2), Vector3.new(floorSize.X + wallThickness * 2, wallH, wallThickness) },
		{ Vector3.new(0, wallY, -halfZ - wallThickness / 2), Vector3.new(floorSize.X + wallThickness * 2, wallH, wallThickness) },
		{ Vector3.new(halfX + wallThickness / 2, wallY, 0), Vector3.new(wallThickness, wallH, floorSize.Z) },
		{ Vector3.new(-halfX - wallThickness / 2, wallY, 0), Vector3.new(wallThickness, wallH, floorSize.Z) },
	}
	for i, wall in walls do
		makePart({
			name = "Wall" .. i,
			parent = hub,
			size = wall[2],
			cframe = CFrame.new(wall[1]),
			color = Color3.fromRGB(55, 60, 75),
			material = Enum.Material.Concrete,
		})
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local trigger = makePart({
			name = zone.id,
			parent = zonesFolder,
			size = zone.size,
			cframe = CFrame.new(zone.position),
			color = zone.color,
			material = Enum.Material.Neon,
			canCollide = false,
		})
		trigger.Transparency = 0.55

		local zoneValue = Instance.new("StringValue")
		zoneValue.Name = "ZoneId"
		zoneValue.Value = zone.id
		zoneValue.Parent = trigger

		makeLabel(trigger, zone.name, zone.size, zone.position)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Parent = hub

	HubWorldBuilder.buildLeaderboardBoard(hub, {})
	return hub
end

return HubWorldBuilder
