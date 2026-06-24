local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color or Color3.fromRGB(45, 50, 65)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Name = props.Name
	part.Transparency = props.Transparency or 0
	part.Parent = props.Parent
	return part
end

local function addZoneLabel(parent, text, color)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(200, 48)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	label.TextColor3 = color
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local floor = makePart({
		Name = "Floor",
		Parent = hub,
		Size = HubConfig.FLOOR_SIZE,
		CFrame = CFrame.new(HubConfig.FLOOR_CENTER),
		Color = Color3.fromRGB(35, 38, 48),
		Material = Enum.Material.Slate,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallY = HubConfig.FLOOR_CENTER.Y + HubConfig.WALL_HEIGHT / 2

	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = hub

	local wallDefs = {
		{ name = "North", size = Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, 2), pos = Vector3.new(0, wallY, halfZ) },
		{ name = "South", size = Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, 2), pos = Vector3.new(0, wallY, -halfZ) },
		{ name = "East", size = Vector3.new(2, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), pos = Vector3.new(halfX, wallY, 0) },
		{ name = "West", size = Vector3.new(2, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), pos = Vector3.new(-halfX, wallY, 0) },
	}

	for _, def in wallDefs do
		makePart({
			Name = def.name,
			Parent = walls,
			Size = def.size,
			CFrame = CFrame.new(def.pos),
			Color = Color3.fromRGB(55, 58, 72),
		})
	end

	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = hub

	for _, zone in HubConfig.ZONES do
		local marker = makePart({
			Name = zone.id,
			Parent = zones,
			Size = zone.size,
			CFrame = CFrame.new(zone.position),
			Color = zone.color,
			Transparency = 0.35,
			CanCollide = false,
		})
		marker:SetAttribute("ZoneId", zone.id)
		marker:SetAttribute("Action", zone.action)
		addZoneLabel(marker, zone.name, zone.color)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Parent = hub

	local hallZone = zones:FindFirstChild("hallOfFame")
	if hallZone then
		local board = makePart({
			Name = "LeaderboardBoard",
			Parent = hallZone,
			Size = Vector3.new(0.4, 8, 12),
			CFrame = hallZone.CFrame * CFrame.new(-6, 2, 0),
			Color = Color3.fromRGB(25, 28, 38),
			Material = Enum.Material.Metal,
		})

		local surface = Instance.new("SurfaceGui")
		surface.Name = "BoardGui"
		surface.Face = Enum.NormalId.Right
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStuds
		surface.PixelsPerStuds = 40
		surface.Parent = board

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, 0, 0, 48)
		title.BackgroundTransparency = 1
		title.Text = "🏆 Ruhmeshalle"
		title.TextColor3 = Color3.fromRGB(255, 220, 100)
		title.Font = Enum.Font.GothamBold
		title.TextScaled = true
		title.Parent = surface

		local list = Instance.new("TextLabel")
		list.Name = "Entries"
		list.Position = UDim2.fromOffset(0, 52)
		list.Size = UDim2.new(1, 0, 1, -52)
		list.BackgroundTransparency = 1
		list.Text = "Lade Rangliste…"
		list.TextColor3 = Color3.new(1, 1, 1)
		list.Font = Enum.Font.Gotham
		list.TextXAlignment = Enum.TextXAlignment.Left
		list.TextYAlignment = Enum.TextYAlignment.Top
		list.TextSize = 22
		list.TextWrapped = true
		list.Parent = surface
	end

	return hub
end

function HubWorldBuilder.updateLeaderboardBoard(entries)
	local hub = workspace:FindFirstChild("NovaHub")
	if not hub then return end

	local board = hub:FindFirstChild("Zones")
		and hub.Zones:FindFirstChild("hallOfFame")
		and hub.Zones.hallOfFame:FindFirstChild("LeaderboardBoard")
	if not board then return end

	local list = board.BoardGui:FindFirstChild("Entries")
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
