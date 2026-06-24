local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Color = props.color or Color3.new(1, 1, 1)
	part.Size = props.size
	part.CFrame = props.cframe
	part.Name = props.name or "Part"
	part.Parent = props.parent
	if props.transparency then
		part.Transparency = props.transparency
	end
	return part
end

local function createZoneLabel(zonePart, zone)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(180, 48)
	billboard.StudsOffset = Vector3.new(0, zone.size.Y * 0.5 + 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = zonePart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.Text = zone.name
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
end

local function createZonePrompt(zonePart, zone)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zone.actionText
	prompt.ObjectText = zone.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = zonePart
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
		name = "Floor",
		parent = hub,
		size = HubConfig.HUB_SIZE,
		cframe = CFrame.new(0, 0, 0),
		color = HubConfig.FLOOR_COLOR,
		material = Enum.Material.Slate,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = HubConfig.SPAWN
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	local halfX = HubConfig.HUB_SIZE.X * 0.5
	local halfZ = HubConfig.HUB_SIZE.Z * 0.5
	local wallH = HubConfig.WALL_HEIGHT
	local wallY = wallH * 0.5

	local walls = {
		{ name = "WallNorth", size = Vector3.new(HubConfig.HUB_SIZE.X + 4, wallH, 2), pos = Vector3.new(0, wallY, -halfZ - 1) },
		{ name = "WallSouth", size = Vector3.new(HubConfig.HUB_SIZE.X + 4, wallH, 2), pos = Vector3.new(0, wallY, halfZ + 1) },
		{ name = "WallWest", size = Vector3.new(2, wallH, HubConfig.HUB_SIZE.Z + 4), pos = Vector3.new(-halfX - 1, wallY, 0) },
		{ name = "WallEast", size = Vector3.new(2, wallH, HubConfig.HUB_SIZE.Z + 4), pos = Vector3.new(halfX + 1, wallY, 0) },
	}

	for _, wall in walls do
		makePart({
			name = wall.name,
			parent = hub,
			size = wall.size,
			cframe = CFrame.new(wall.pos),
			color = HubConfig.WALL_COLOR,
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
			cframe = CFrame.new(zone.position),
			color = zone.color,
			material = Enum.Material.Neon,
			canCollide = false,
		})
		zonePart.Transparency = 0.55
		zonePart:SetAttribute("ZoneId", zone.id)
		zonePart:SetAttribute("ZoneName", zone.name)
		zonePart:SetAttribute("ZoneAction", zone.action)
		zonePart:SetAttribute("ZoneHint", zone.hint)
		createZoneLabel(zonePart, zone)
		createZonePrompt(zonePart, zone)
	end

	local boardCfg = HubConfig.LEADERBOARD_BOARD
	local board = makePart({
		name = "LeaderboardBoard",
		parent = hub,
		size = boardCfg.size,
		cframe = CFrame.new(boardCfg.position),
		color = Color3.fromRGB(25, 28, 38),
		material = Enum.Material.Metal,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "LeaderboardSurface"
	surface.Face = boardCfg.face
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 60)
	title.BackgroundTransparency = 1
	title.Text = "🏆 Nova Liga — Top 5"
	title.TextColor3 = Color3.fromRGB(255, 220, 100)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 28
	title.Parent = surface

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Size = UDim2.new(1, -20, 1, -70)
	list.Position = UDim2.fromOffset(10, 65)
	list.BackgroundTransparency = 1
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextColor3 = Color3.new(1, 1, 1)
	list.Font = Enum.Font.Gotham
	list.TextSize = 22
	list.Text = "Lade Rangliste…"
	list.TextWrapped = true
	list.Parent = surface

	-- Decorative center marker so players orient in the hub
	makePart({
		name = "CenterMark",
		parent = hub,
		size = Vector3.new(8, 0.2, 8),
		cframe = CFrame.new(0, 0.15, 0),
		color = Color3.fromRGB(90, 100, 130),
		material = Enum.Material.Neon,
		canCollide = false,
	}).Transparency = 0.4

	return hub
end

function HubWorldBuilder.getLeaderboardList()
	local hub = workspace:FindFirstChild("NovaHub")
	if not hub then return nil end
	local board = hub:FindFirstChild("LeaderboardBoard")
	if not board then return nil end
	local surface = board:FindFirstChild("LeaderboardSurface")
	if not surface then return nil end
	return surface:FindFirstChild("List")
end

return HubWorldBuilder
