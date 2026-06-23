local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function createPart(parent, props)
	local part = Instance.new("Part")
	part.Name = props.Name
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color or HubConfig.FLOOR_COLOR
	part.Material = props.Material or Enum.Material.Concrete
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Transparency = props.Transparency or 0
	part.Parent = parent
	return part
end

local function createLabel(parent, text, size, position)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, size.Y / 2 + 3, 0)
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

function HubWorldBuilder.createLeaderboardBoard(parent, zonePart)
	local board = createPart(parent, {
		Name = "LeaderboardBoard",
		Size = Vector3.new(10, 8, 0.5),
		CFrame = zonePart.CFrame * CFrame.new(0, 2, -zonePart.Size.Z / 2 - 1),
		Color = Color3.fromRGB(20, 22, 30),
		Material = Enum.Material.SmoothPlastic,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "LeaderboardGui"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.Parent = board

	local frame = Instance.new("Frame")
	frame.Name = "Root"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 60)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 200, 60)
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
	list.Text = "Lade Rangliste..."
	list.Parent = frame

	return board
end

function HubWorldBuilder.updateLeaderboard(board, entries)
	local gui = board:FindFirstChild("LeaderboardGui")
	if not gui then return end
	local list = gui.Root.List
	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		list.Text = "Noch keine Einträge"
	else
		list.Text = table.concat(lines, "\n")
	end
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		return existing
	end

	local hub = Instance.new("Model")
	hub.Name = "NovaHub"

	local floorY = HubConfig.SPAWN.Position.Y - 3
	createPart(hub, {
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		CFrame = CFrame.new(0, floorY, 0),
		Color = HubConfig.FLOOR_COLOR,
		Material = Enum.Material.Slate,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallY = floorY + wallH / 2

	local walls = {
		{ "WallNorth", Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 2), CFrame.new(0, wallY, -halfZ) },
		{ "WallSouth", Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 2), CFrame.new(0, wallY, halfZ) },
		{ "WallWest", Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z), CFrame.new(-halfX, wallY, 0) },
		{ "WallEast", Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z), CFrame.new(halfX, wallY, 0) },
	}
	for _, wall in walls do
		createPart(hub, {
			Name = wall[1],
			Size = wall[2],
			CFrame = wall[3],
			Color = HubConfig.WALL_COLOR,
			Material = Enum.Material.Brick,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = HubConfig.SPAWN
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	local leaderboardBoard

	for zoneId, zone in HubConfig.ZONES do
		local zonePart = createPart(zonesFolder, {
			Name = zoneId,
			Size = zone.size,
			CFrame = CFrame.new(zone.position.X, zone.position.Y + floorY + zone.size.Y / 2, zone.position.Z),
			Color = zone.color,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Transparency = 0.55,
		})
		zonePart:SetAttribute("ZoneId", zone.id)
		createLabel(zonePart, zone.name, zone.size)

		if zoneId == "HallOfFame" then
			leaderboardBoard = HubWorldBuilder.createLeaderboardBoard(hub, zonePart)
		end
	end

	hub.Parent = workspace
	return hub, leaderboardBoard
end

return HubWorldBuilder
