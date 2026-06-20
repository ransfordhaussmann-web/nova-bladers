local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	return part
end

local function addZoneLabel(parent, zone)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextSize = 18
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.5
	text.Text = zone.label
	text.Parent = billboard
end

local function addProximityPrompt(parent, zone)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = zone.label
	prompt.ObjectText = "Nova Hub"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt:SetAttribute("HubAction", zone.action)
	prompt.Parent = parent
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Model")
	hub.Name = HubConfig.HUB_NAME
	hub.Parent = workspace

	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = Vector3.new(0, 0, 0),
		Color = Color3.fromRGB(35, 38, 48),
		Material = Enum.Material.Slate,
	})
	floor.Parent = hub

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT

	local walls = {
		{ Size = Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 2), Position = Vector3.new(0, wallH / 2, halfZ) },
		{ Size = Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 2), Position = Vector3.new(0, wallH / 2, -halfZ) },
		{ Size = Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z), Position = Vector3.new(halfX, wallH / 2, 0) },
		{ Size = Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z), Position = Vector3.new(-halfX, wallH / 2, 0) },
	}

	for i, wall in walls do
		local part = makePart({
			Name = "Wall" .. i,
			Size = wall.Size,
			Position = wall.Position,
			Color = Color3.fromRGB(50, 55, 70),
			Material = Enum.Material.Concrete,
		})
		part.Parent = hub
	end

	local spawn = makePart({
		Name = "HubSpawn",
		Size = Vector3.new(6, 1, 6),
		Position = HubConfig.SPAWN_OFFSET + Vector3.new(0, 0.5, 0),
		Transparency = 1,
		CanCollide = false,
	})
	spawn.Parent = hub
	hub.PrimaryPart = spawn

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local pad = makePart({
			Name = zone.id,
			Size = zone.size + Vector3.new(0, 0.2, 0),
			Position = zone.position + Vector3.new(0, 0.6, 0),
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.35,
			CanCollide = false,
		})
		pad:SetAttribute("ZoneId", zone.id)
		pad:SetAttribute("HubAction", zone.action)
		addZoneLabel(pad, zone)
		addProximityPrompt(pad, zone)
		pad.Parent = zonesFolder
	end

	local board = makePart({
		Name = "LeaderboardBoard",
		Size = Vector3.new(10, 8, 0.5),
		Position = HubConfig.ZONES.HallOfFame.position + Vector3.new(0, 5, -8),
		Color = Color3.fromRGB(25, 25, 35),
		Material = Enum.Material.SmoothPlastic,
	})
	board.Parent = hub

	local surface = Instance.new("SurfaceGui")
	surface.Name = "BoardGui"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 50)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 28
	title.TextColor3 = Color3.fromRGB(255, 200, 60)
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = surface

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.fromOffset(0, 50)
	list.Size = UDim2.new(1, 0, 1, -50)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextSize = 22
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Text = "Lade Rangliste…"
	list.Parent = surface

	return hub
end

function HubWorldBuilder.updateLeaderboardBoard(entries)
	local hub = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if not hub then return end

	local board = hub:FindFirstChild("LeaderboardBoard")
	if not board then return end

	local list = board.BoardGui:FindFirstChild("List")
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
