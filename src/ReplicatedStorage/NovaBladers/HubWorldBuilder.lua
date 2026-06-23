local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.fromRGB(45, 48, 58)
	part.Material = props.material or Enum.Material.Concrete
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function buildZoneMarker(parent, zone)
	local marker = makePart({
		name = zone.id,
		parent = parent,
		size = zone.size,
		cframe = CFrame.new(zone.position),
		color = zone.color,
		material = Enum.Material.Neon,
		canCollide = false,
	})
	marker.Transparency = 0.65

	local sign = makePart({
		name = zone.id .. "Sign",
		parent = parent,
		size = Vector3.new(zone.size.X, 2, 0.4),
		cframe = CFrame.new(zone.position + Vector3.new(0, zone.size.Y * 0.5 + 2, 0)),
		color = Color3.fromRGB(30, 32, 40),
		material = Enum.Material.SmoothPlastic,
		canCollide = false,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Text = zone.name
	label.Parent = billboard

	return marker
end

function HubWorldBuilder.buildLeaderboardBoard(parent, entries)
	local existing = parent:FindFirstChild("LeaderboardBoard")
	if existing then
		existing:Destroy()
	end

	local board = makePart({
		name = "LeaderboardBoard",
		parent = parent,
		size = Vector3.new(14, 10, 0.5),
		cframe = CFrame.new(32, 7, -6) * CFrame.Angles(0, math.rad(-90), 0),
		color = Color3.fromRGB(25, 28, 36),
		material = Enum.Material.SmoothPlastic,
		canCollide = false,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "BoardGui"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 60)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 200, 80)
	title.TextSize = 28
	title.Text = "🏆 Ruhmeshalle — Top 5"
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Size = UDim2.new(1, -20, 1, -70)
	list.Position = UDim2.fromOffset(10, 65)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextSize = 22
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextWrapped = true
	list.Parent = frame

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	list.Text = table.concat(lines, "\n")

	return board
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local floorY = 0
	makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		cframe = CFrame.new(0, floorY - HubConfig.FLOOR_SIZE.Y * 0.5, 0),
		color = Color3.fromRGB(55, 58, 68),
		material = Enum.Material.Slate,
	})

	local halfX = HubConfig.FLOOR_SIZE.X * 0.5
	local halfZ = HubConfig.FLOOR_SIZE.Z * 0.5
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS

	local walls = {
		{ size = Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT), pos = Vector3.new(0, wallH * 0.5, halfZ + wallT * 0.5) },
		{ size = Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT), pos = Vector3.new(0, wallH * 0.5, -halfZ - wallT * 0.5) },
		{ size = Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z), pos = Vector3.new(halfX + wallT * 0.5, wallH * 0.5, 0) },
		{ size = Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z), pos = Vector3.new(-halfX - wallT * 0.5, wallH * 0.5, 0) },
	}
	for i, wall in walls do
		makePart({
			name = "Wall" .. i,
			parent = hub,
			size = wall.size,
			cframe = CFrame.new(wall.pos),
			color = Color3.fromRGB(38, 40, 50),
			material = Enum.Material.Brick,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
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
		buildZoneMarker(zonesFolder, zone)
	end

	HubWorldBuilder.buildLeaderboardBoard(hub, {})

	return hub
end

return HubWorldBuilder
