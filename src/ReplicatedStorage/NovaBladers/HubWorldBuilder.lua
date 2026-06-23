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

local function addZoneLabel(part, text)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, part.Size.Y * 0.5 + 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

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

function HubWorldBuilder.buildLeaderboardBoard(parent, entries)
	local board = parent:FindFirstChild("LeaderboardBoard")
	if not board then
		board = makePart({
			name = "LeaderboardBoard",
			parent = parent,
			size = Vector3.new(14, 10, 0.5),
			cframe = CFrame.new(HubConfig.ZONES.HallOfFame.center + Vector3.new(0, 2, -6))
				* CFrame.Angles(0, math.rad(-90), 0),
			color = Color3.fromRGB(30, 32, 40),
			material = Enum.Material.Neon,
		})
	end

	local surface = board:FindFirstChildOfClass("SurfaceGui")
	if not surface then
		surface = Instance.new("SurfaceGui")
		surface.Face = Enum.NormalId.Front
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 50
		surface.Parent = board
	end

	local frame = surface:FindFirstChild("Frame")
	if not frame then
		frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
		frame.BackgroundTransparency = 0.15
		frame.BorderSizePixel = 0
		frame.Parent = surface

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, 0, 0, 60)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextColor3 = Color3.fromRGB(255, 210, 80)
		title.TextSize = 28
		title.Text = "🏆 Ruhmeshalle"
		title.Parent = frame

		local list = Instance.new("TextLabel")
		list.Name = "List"
		list.Position = UDim2.fromOffset(0, 60)
		list.Size = UDim2.new(1, 0, 1, -60)
		list.BackgroundTransparency = 1
		list.Font = Enum.Font.Gotham
		list.TextColor3 = Color3.new(1, 1, 1)
		list.TextSize = 22
		list.TextXAlignment = Enum.TextXAlignment.Left
		list.TextYAlignment = Enum.TextYAlignment.Top
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
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local floorY = HubConfig.SPAWN.Y - 3
	local floorSize = HubConfig.FLOOR_SIZE

	makePart({
		name = "Floor",
		parent = hub,
		size = floorSize,
		cframe = CFrame.new(0, floorY, 0),
		color = Color3.fromRGB(55, 58, 68),
		material = Enum.Material.Slate,
	})

	local halfX = floorSize.X * 0.5
	local halfZ = floorSize.Z * 0.5
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS
	local wallY = floorY + wallH * 0.5

	local walls = {
		{ Vector3.new(0, wallY, halfZ + wallT * 0.5), Vector3.new(floorSize.X + wallT * 2, wallH, wallT) },
		{ Vector3.new(0, wallY, -halfZ - wallT * 0.5), Vector3.new(floorSize.X + wallT * 2, wallH, wallT) },
		{ Vector3.new(halfX + wallT * 0.5, wallY, 0), Vector3.new(wallT, wallH, floorSize.Z) },
		{ Vector3.new(-halfX - wallT * 0.5, wallY, 0), Vector3.new(wallT, wallH, floorSize.Z) },
	}
	for i, wall in walls do
		makePart({
			name = "Wall" .. i,
			parent = hub,
			size = wall[2],
			cframe = CFrame.new(wall[1]),
			color = Color3.fromRGB(38, 40, 50),
		})
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zonePart = makePart({
			name = zone.id,
			parent = zonesFolder,
			size = zone.size,
			cframe = CFrame.new(zone.center),
			color = zone.color,
			transparency = 0.55,
			canCollide = false,
		})
		zonePart.Material = Enum.Material.Neon
		addZoneLabel(zonePart, zone.label)
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
