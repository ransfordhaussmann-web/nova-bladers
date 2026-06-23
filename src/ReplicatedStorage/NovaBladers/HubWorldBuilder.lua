local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color or Color3.fromRGB(55, 58, 72)
	part.Material = props.Material or Enum.Material.Concrete
	part.Name = props.Name or "Part"
	part.Transparency = props.Transparency or 0
	part.Parent = props.Parent
	return part
end

local function makeSign(parent, zone)
	local sign = makePart({
		Name = zone.id .. "Sign",
		Parent = parent,
		Size = Vector3.new(zone.size.X, 2, 1),
		CFrame = CFrame.new(zone.position + Vector3.new(0, zone.size.Y * 0.5 + 2, -zone.size.Z * 0.5 - 1)),
		Color = zone.color,
		Material = Enum.Material.Neon,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = zone.name
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	return sign
end

local function makeZoneTrigger(parent, zone)
	local trigger = makePart({
		Name = zone.id .. "Trigger",
		Parent = parent,
		Size = zone.size,
		CFrame = CFrame.new(zone.position),
		Color = zone.color,
		Material = Enum.Material.ForceField,
		Transparency = 0.75,
		CanCollide = false,
	})
	trigger:SetAttribute("ZoneId", zone.id)
	trigger:SetAttribute("ZoneName", zone.name)
	trigger:SetAttribute("ZoneHint", zone.hint)
	trigger:SetAttribute("ZoneAction", zone.action or "")
	return trigger
end

local function buildLeaderboardBoard(parent, zone)
	local board = makePart({
		Name = "LeaderboardBoard",
		Parent = parent,
		Size = Vector3.new(12, 8, 0.5),
		CFrame = CFrame.new(zone.position + Vector3.new(0, 2, -zone.size.Z * 0.5 - 1)),
		Color = Color3.fromRGB(30, 32, 40),
		Material = Enum.Material.SmoothPlastic,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Name = "LeaderboardSurface"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = HubConfig.LEADERBOARD_BOARD_SIZE
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 60)
	title.BackgroundTransparency = 1
	title.Text = "🏆 Ruhmeshalle"
	title.TextColor3 = Color3.fromRGB(255, 220, 80)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = gui

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.new(0, 0, 0, 70)
	list.Size = UDim2.new(1, 0, 1, -80)
	list.BackgroundTransparency = 1
	list.Text = "Lade Rangliste..."
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextScaled = false
	list.TextSize = 28
	list.TextWrapped = true
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Font = Enum.Font.Gotham
	list.Parent = gui

	return board
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		return existing
	end

	local hub = Instance.new("Model")
	hub.Name = "NovaHub"

	local floorY = HubConfig.FLOOR_Y
	local floor = makePart({
		Name = "Floor",
		Parent = hub,
		Size = HubConfig.FLOOR_SIZE,
		CFrame = CFrame.new(0, floorY - HubConfig.FLOOR_SIZE.Y * 0.5, 0),
		Color = Color3.fromRGB(42, 44, 54),
		Material = Enum.Material.Slate,
	})

	local halfX = HubConfig.FLOOR_SIZE.X * 0.5
	local halfZ = HubConfig.FLOOR_SIZE.Z * 0.5
	local wallH = HubConfig.WALL_HEIGHT
	local wallY = floorY + wallH * 0.5

	local walls = {
		{ Vector3.new(0, wallY, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 2) },
		{ Vector3.new(0, wallY, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 2) },
		{ Vector3.new(halfX, wallY, 0), Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(-halfX, wallY, 0), Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z) },
	}
	for i, wall in walls do
		makePart({
			Name = "Wall" .. i,
			Parent = hub,
			Size = wall[2],
			CFrame = CFrame.new(wall[1]),
			Color = Color3.fromRGB(35, 37, 48),
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN)
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
		makeSign(hub, zone)
		makeZoneTrigger(zonesFolder, zone)
		if zone.id == "HallOfFame" then
			buildLeaderboardBoard(hub, zone)
		end
	end

	local light = Instance.new("PointLight")
	light.Brightness = 0.6
	light.Range = 80
	light.Parent = floor

	hub.PrimaryPart = floor
	hub.Parent = workspace
	return hub
end

function HubWorldBuilder.updateLeaderboard(hub, entries)
	local board = hub:FindFirstChild("LeaderboardBoard")
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

function HubWorldBuilder.getZoneTriggers(hub)
	local zones = hub:FindFirstChild("Zones")
	if not zones then return {} end
	return zones:GetChildren()
end

return HubWorldBuilder
