local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function createLabel(parent: BasePart, title: string, subtitle: string?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "ZoneLabel"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = parent

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, subtitle and 0.55 or 1, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextScaled = true
	titleLabel.Text = title
	titleLabel.Parent = frame

	if subtitle then
		local subLabel = Instance.new("TextLabel")
		subLabel.Name = "Subtitle"
		subLabel.Size = UDim2.new(1, 0, 0.45, 0)
		subLabel.Position = UDim2.fromScale(0, 0.55)
		subLabel.BackgroundTransparency = 1
		subLabel.Font = Enum.Font.Gotham
		subLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
		subLabel.TextScaled = true
		subLabel.Text = subtitle
		subLabel.Parent = frame
	end
end

local function createZoneMarker(folder: Folder, zone)
	local marker = Instance.new("Part")
	marker.Name = "Zone_" .. zone.id
	marker.Anchored = true
	marker.CanCollide = true
	marker.Size = zone.size
	marker.CFrame = CFrame.new(zone.position)
	marker.Color = zone.color
	marker.Material = Enum.Material.Neon
	marker.Transparency = 0.35
	marker:SetAttribute("ZoneId", zone.id)
	marker.Parent = folder

	createLabel(marker, zone.name, zone.hint)

	local trigger = Instance.new("Part")
	trigger.Name = "Trigger"
	trigger.Anchored = true
	trigger.CanCollide = false
	trigger.Transparency = 1
	trigger.Size = zone.size + Vector3.new(4, 4, 4)
	trigger.CFrame = marker.CFrame
	trigger:SetAttribute("ZoneId", zone.id)
	trigger.Parent = marker

	return marker
end

function HubWorldBuilder.createLeaderboardBoard(parent: Instance, entries)
	local board = parent:FindFirstChild("LeaderboardBoard")
	if not board then
		board = Instance.new("Part")
		board.Name = "LeaderboardBoard"
		board.Anchored = true
		board.CanCollide = false
		board.Size = HubConfig.LEADERBOARD_BOARD_SIZE
		board.Color = Color3.fromRGB(30, 32, 42)
		board.Material = Enum.Material.SmoothPlastic
		board.Parent = parent

		local hallZone = HubConfig.ZONES.hall_of_fame
		board.CFrame = CFrame.new(hallZone.position + Vector3.new(0, 4, -7))
			* CFrame.Angles(0, math.rad(180), 0)

		local gui = Instance.new("SurfaceGui")
		gui.Name = "BoardGui"
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Parent = board

		local label = Instance.new("TextLabel")
		label.Name = "BoardText"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.fromRGB(255, 230, 140)
		label.TextScaled = false
		label.TextSize = 28
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.Parent = gui
	end

	local textLabel = board.BoardGui.BoardText
	local lines = { "🏆 Nova Liga — Top 5", "" }
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	textLabel.Text = table.concat(lines, "\n")
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER
	hub.Parent = workspace

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = HubConfig.HUB_SIZE
	floor.Position = Vector3.new(0, 0, 0)
	floor.Color = Color3.fromRGB(45, 48, 58)
	floor.Material = Enum.Material.Slate
	floor.Parent = hub

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_OFFSET
	spawn.Color = Color3.fromRGB(100, 200, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.5
	spawn.Neutral = true
	spawn.Parent = hub

	local halfX = HubConfig.HUB_SIZE.X / 2
	local halfZ = HubConfig.HUB_SIZE.Z / 2
	local wallThickness = 2
	local wallY = HubConfig.WALL_HEIGHT / 2

	local wallDefs = {
		{ pos = Vector3.new(0, wallY, halfZ), size = Vector3.new(HubConfig.HUB_SIZE.X, HubConfig.WALL_HEIGHT, wallThickness) },
		{ pos = Vector3.new(0, wallY, -halfZ), size = Vector3.new(HubConfig.HUB_SIZE.X, HubConfig.WALL_HEIGHT, wallThickness) },
		{ pos = Vector3.new(halfX, wallY, 0), size = Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, HubConfig.HUB_SIZE.Z) },
		{ pos = Vector3.new(-halfX, wallY, 0), size = Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, HubConfig.HUB_SIZE.Z) },
	}

	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = hub

	for i, def in wallDefs do
		local wall = Instance.new("Part")
		wall.Name = "Wall" .. i
		wall.Anchored = true
		wall.Size = def.size
		wall.Position = def.pos
		wall.Color = Color3.fromRGB(60, 64, 78)
		wall.Material = Enum.Material.Concrete
		wall.Parent = walls
	end

	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = hub

	for _, zone in HubConfig.ZONES do
		createZoneMarker(zones, zone)
	end

	local lighting = Instance.new("PointLight")
	lighting.Brightness = 2
	lighting.Range = 40
	lighting.Parent = floor

	return hub
end

function HubWorldBuilder.getSpawnCFrame()
	local hub = workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	if hub then
		local spawn = hub:FindFirstChild("HubSpawn")
		if spawn then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(HubConfig.SPAWN_OFFSET + Vector3.new(0, 3, 0))
end

return HubWorldBuilder
