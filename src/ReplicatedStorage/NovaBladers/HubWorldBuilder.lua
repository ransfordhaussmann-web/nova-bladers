local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Color = props.Color or Color3.fromRGB(45, 48, 58)
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Name = props.Name or "Part"
	part.Transparency = props.Transparency or 0
	part.Parent = props.Parent
	return part
end

local function makeSign(parent, text, position, color)
	local sign = makePart({
		Name = "Sign",
		Parent = parent,
		Size = Vector3.new(10, 3, 0.4),
		CFrame = CFrame.new(position + Vector3.new(0, 8, 0)),
		Color = color,
		Material = Enum.Material.Neon,
	})
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
	return sign
end

local function buildLeaderboardBoard(parent, position)
	local board = makePart({
		Name = "LeaderboardBoard",
		Parent = parent,
		Size = Vector3.new(12, 8, 0.5),
		CFrame = CFrame.new(position + Vector3.new(0, 5, -6.5)),
		Color = Color3.fromRGB(30, 32, 40),
		Material = Enum.Material.Slate,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Name = "LeaderboardSurface"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 50)
	title.BackgroundTransparency = 1
	title.Text = "🏆 Ruhmeshalle"
	title.TextColor3 = Color3.fromRGB(255, 220, 80)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = gui

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.fromOffset(0, 55)
	list.Size = UDim2.new(1, 0, 1, -60)
	list.BackgroundTransparency = 1
	list.Text = "Lade Rangliste..."
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextSize = 22
	list.Font = Enum.Font.Gotham
	list.Parent = gui

	return board
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	local floorY = HubConfig.SPAWN_POSITION.Y - 3
	local center = Vector3.new(HubConfig.SPAWN_POSITION.X, floorY, HubConfig.SPAWN_POSITION.Z)

	makePart({
		Name = "Floor",
		Parent = hub,
		Size = HubConfig.FLOOR_SIZE,
		CFrame = CFrame.new(center),
		Color = Color3.fromRGB(38, 42, 52),
		Material = Enum.Material.Concrete,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallThickness = 2

	local walls = {
		{ name = "WallNorth", size = Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, wallThickness), pos = center + Vector3.new(0, wallH / 2, halfZ) },
		{ name = "WallSouth", size = Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, wallThickness), pos = center + Vector3.new(0, wallH / 2, -halfZ) },
		{ name = "WallEast", size = Vector3.new(wallThickness, wallH, HubConfig.FLOOR_SIZE.Z), pos = center + Vector3.new(halfX, wallH / 2, 0) },
		{ name = "WallWest", size = Vector3.new(wallThickness, wallH, HubConfig.FLOOR_SIZE.Z), pos = center + Vector3.new(-halfX, wallH / 2, 0) },
	}
	for _, wall in walls do
		makePart({
			Name = wall.name,
			Parent = hub,
			Size = wall.size,
			CFrame = CFrame.new(wall.pos),
			Color = Color3.fromRGB(28, 30, 38),
			Material = Enum.Material.Brick,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zonePart = makePart({
			Name = zone.id,
			Parent = zonesFolder,
			Size = zone.size,
			CFrame = CFrame.new(center + zone.position + Vector3.new(0, zone.size.Y / 2, 0)),
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.35,
			CanCollide = false,
		})
		zonePart:SetAttribute("ZoneId", zone.id)
		zonePart:SetAttribute("ZoneAction", zone.action)
		zonePart:SetAttribute("ZoneHint", zone.hint)

		makeSign(zonesFolder, zone.name, center + zone.position, zone.color)

		if zone.id == "hall" then
			buildLeaderboardBoard(zonesFolder, center + zone.position)
		end
	end

	return hub
end

function HubWorldBuilder.updateLeaderboardBoard(hub, entries)
	local zones = hub:FindFirstChild("Zones")
	if not zones then return end
	local board = zones:FindFirstChild("LeaderboardBoard", true)
	if not board then return end
	local gui = board:FindFirstChild("LeaderboardSurface")
	if not gui then return end
	local list = gui:FindFirstChild("List")
	if not list then return end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		list.Text = "Noch keine Einträge"
	else
		list.Text = table.concat(lines, "\n")
	end
end

return HubWorldBuilder
