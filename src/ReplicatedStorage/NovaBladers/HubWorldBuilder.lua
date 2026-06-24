local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.Position = props.Position
	part.Color = props.Color or Color3.fromRGB(60, 60, 60)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Name = props.Name or "Part"
	part.Parent = props.Parent
	if props.Transparency then
		part.Transparency = props.Transparency
	end
	return part
end

local function addSign(parent, text, offsetY)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Size = UDim2.fromOffset(220, 56)
	billboard.StudsOffset = Vector3.new(0, offsetY or 6, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(10, 12, 20)
	label.TextColor3 = Color3.fromRGB(240, 245, 255)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.Text = text
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
end

local function buildZoneMarker(zoneFolder, zone)
	local color = HubConfig.Colors[zone.colorKey] or HubConfig.Colors.Accent

	local pad = makePart({
		Name = zone.id,
		Parent = zoneFolder,
		Size = zone.size,
		Position = zone.position,
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
	})

	local frame = makePart({
		Name = zone.id .. "Frame",
		Parent = zoneFolder,
		Size = Vector3.new(zone.size.X + 1, 0.4, zone.size.Z + 1),
		Position = zone.position - Vector3.new(0, zone.size.Y * 0.5 + 0.2, 0),
		Color = color,
		Material = Enum.Material.Metal,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = zone.promptText
	prompt.ObjectText = zone.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("HubAction", zone.action)
	prompt:SetAttribute("HubZoneId", zone.id)
	prompt.Parent = pad

	addSign(pad, zone.name, zone.size.Y * 0.5 + 2)

	return pad, frame
end

local function buildHallBoard(hub, leaderboardLabel)
	local zone = HubConfig.Zones[3]
	local board = makePart({
		Name = "LeaderboardBoard",
		Parent = hub,
		Size = Vector3.new(10, 7, 0.6),
		Position = zone.position + Vector3.new(0, 4, zone.size.Z * 0.5 + 1),
		Color = Color3.fromRGB(14, 16, 24),
		Material = Enum.Material.Metal,
	})
	board.CFrame = CFrame.new(board.Position) * CFrame.Angles(0, math.pi, 0)

	local surface = Instance.new("SurfaceGui")
	surface.Name = "BoardGui"
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(500, 360)
	surface.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 48)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 28
	title.TextColor3 = HubConfig.Colors.Hall
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = surface

	local body = Instance.new("TextLabel")
	body.Name = "Entries"
	body.Size = UDim2.new(1, -24, 1, -56)
	body.Position = UDim2.fromOffset(12, 52)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Gotham
	body.TextSize = 22
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextColor3 = Color3.fromRGB(230, 235, 245)
	body.Text = leaderboardLabel or "Lade Rangliste..."
	body.TextWrapped = true
	body.Parent = surface

	return board
end

function HubWorldBuilder.build(leaderboardLines)
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local floorY = HubConfig.FLOOR_Y - HubConfig.FLOOR_SIZE.Y * 0.5
	makePart({
		Name = "Floor",
		Parent = hub,
		Size = HubConfig.FLOOR_SIZE,
		Position = Vector3.new(0, floorY, 0),
		Color = HubConfig.Colors.Floor,
		Material = Enum.Material.Slate,
	})

	local wallH = 12
	local wallT = 1
	local halfX = HubConfig.FLOOR_SIZE.X * 0.5
	local halfZ = HubConfig.FLOOR_SIZE.Z * 0.5
	local walls = {
		{ Vector3.new(0, wallH * 0.5, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, wallT) },
		{ Vector3.new(0, wallH * 0.5, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, wallT) },
		{ Vector3.new(-halfX, wallH * 0.5, 0), Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(halfX, wallH * 0.5, 0), Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
	}
	for i, spec in walls do
		makePart({
			Name = "Wall" .. i,
			Parent = hub,
			Size = spec[2],
			Position = spec[1],
			Color = HubConfig.Colors.Wall,
			Material = Enum.Material.Concrete,
		})
	end

	makePart({
		Name = "SpawnPad",
		Parent = hub,
		Size = Vector3.new(8, 0.4, 8),
		Position = Vector3.new(HubConfig.SPAWN.X, HubConfig.FLOOR_Y + 0.2, HubConfig.SPAWN.Z),
		Color = HubConfig.Colors.Accent,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
	})
	addSign(hub:FindFirstChild("SpawnPad"), "Nova Hub", 4)

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.Zones do
		buildZoneMarker(zonesFolder, zone)
	end

	buildHallBoard(hub, leaderboardLines)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	return hub
end

function HubWorldBuilder.formatLeaderboard(entries)
	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt.", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		return "Noch keine Einträge"
	end
	return table.concat(lines, "\n")
end

function HubWorldBuilder.updateLeaderboardBoard(hub, entries)
	if not hub then return end
	local board = hub:FindFirstChild("LeaderboardBoard")
	if not board then return end
	local gui = board:FindFirstChild("BoardGui")
	local entriesLabel = gui and gui:FindFirstChild("Entries")
	if entriesLabel then
		entriesLabel.Text = HubWorldBuilder.formatLeaderboard(entries)
	end
end

return HubWorldBuilder
