local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.Position = props.Position
	part.Color = props.Color or Color3.fromRGB(55, 58, 68)
	part.Material = props.Material or Enum.Material.Concrete
	part.Name = props.Name or "Part"
	part.Parent = props.Parent
	return part
end

local function makeSign(parent, text, position, face)
	local sign = makePart({
		Name = "Sign",
		Parent = parent,
		Size = Vector3.new(10, 4, 0.4),
		Position = position,
		Color = Color3.fromRGB(30, 32, 40),
		Material = Enum.Material.SmoothPlastic,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	return sign
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local center = HubConfig.SPAWN_POSITION
	local width = HubConfig.HUB_SIZE.X
	local depth = HubConfig.HUB_SIZE.Y
	local wallH = HubConfig.WALL_HEIGHT
	local floorY = center.Y - HubConfig.FLOOR_THICKNESS

	local floor = makePart({
		Name = "Floor",
		Parent = hub,
		Size = Vector3.new(width, HubConfig.FLOOR_THICKNESS, depth),
		Position = Vector3.new(center.X, floorY, center.Z),
		Color = Color3.fromRGB(48, 50, 58),
		Material = Enum.Material.Slate,
	})

	local wallThickness = 2
	local walls = {
		{ name = "WallNorth", size = Vector3.new(width + wallThickness * 2, wallH, wallThickness), pos = Vector3.new(center.X, floorY + wallH / 2, center.Z - depth / 2) },
		{ name = "WallSouth", size = Vector3.new(width + wallThickness * 2, wallH, wallThickness), pos = Vector3.new(center.X, floorY + wallH / 2, center.Z + depth / 2) },
		{ name = "WallWest", size = Vector3.new(wallThickness, wallH, depth), pos = Vector3.new(center.X - width / 2, floorY + wallH / 2, center.Z) },
		{ name = "WallEast", size = Vector3.new(wallThickness, wallH, depth), pos = Vector3.new(center.X + width / 2, floorY + wallH / 2, center.Z) },
	}

	for _, wall in walls do
		makePart({
			Name = wall.name,
			Parent = hub,
			Size = wall.size,
			Position = wall.pos,
			Color = Color3.fromRGB(62, 66, 78),
			Material = Enum.Material.Brick,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for zoneId, zone in HubConfig.ZONES do
		local zonePart = makePart({
			Name = zoneId,
			Parent = zonesFolder,
			Size = zone.size,
			Position = Vector3.new(zone.position.X, floorY + zone.size.Y / 2, zone.position.Z),
			Color = zone.color,
			Material = Enum.Material.Neon,
		})
		zonePart.Transparency = 0.35
		zonePart.CanCollide = false
		zonePart:SetAttribute("ZoneId", zone.id)
		zonePart:SetAttribute("ZoneAction", zone.action)

		makeSign(
			zonesFolder,
			zone.name,
			zonePart.Position + Vector3.new(0, zone.size.Y / 2 + 2.5, 0),
			Enum.NormalId.Front
		)
	end

	local fameZone = HubConfig.ZONES.FameHall
	local board = makePart({
		Name = "LeaderboardBoard",
		Parent = hub,
		Size = Vector3.new(12, 8, 0.5),
		Position = Vector3.new(
			fameZone.position.X,
			floorY + fameZone.size.Y + 4,
			fameZone.position.Z + fameZone.size.Z / 2 + 1
		),
		Color = Color3.fromRGB(20, 22, 30),
		Material = Enum.Material.SmoothPlastic,
	})

	local boardGui = Instance.new("SurfaceGui")
	boardGui.Name = "LeaderboardGui"
	boardGui.Face = Enum.NormalId.Front
	boardGui.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.Text = "🏆 Ruhmeshalle"
	title.TextColor3 = Color3.fromRGB(255, 220, 100)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = boardGui

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.fromOffset(0, 40)
	list.Size = UDim2.new(1, -8, 1, -44)
	list.BackgroundTransparency = 1
	list.Text = "Lade Rangliste..."
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextSize = 18
	list.Font = Enum.Font.Gotham
	list.TextWrapped = true
	list.Parent = boardGui

	return hub
end

function HubWorldBuilder.getLeaderboardLabel()
	local hub = workspace:FindFirstChild("NovaHub")
	if not hub then return nil end
	local board = hub:FindFirstChild("LeaderboardBoard")
	if not board then return nil end
	local gui = board:FindFirstChild("LeaderboardGui")
	if not gui then return nil end
	return gui:FindFirstChild("List")
end

return HubWorldBuilder
