local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Name = props.Name or "Part"
	part.Size = props.Size or Vector3.new(4, 1, 4)
	part.CFrame = props.CFrame or CFrame.new(0, 0, 0)
	part.Color = props.Color or Color3.fromRGB(45, 50, 65)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Transparency = props.Transparency or 0
	part.Parent = props.Parent
	return part
end

local function addSign(parent, text, position, color)
	local sign = makePart({
		Name = "Sign",
		Size = Vector3.new(8, 3, 0.4),
		CFrame = CFrame.new(position + Vector3.new(0, 5, 0)),
		Color = color,
		Material = Enum.Material.Neon,
		Parent = parent,
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
end

local function buildZone(parent, zone)
	local folder = Instance.new("Folder")
	folder.Name = zone.id
	folder.Parent = parent

	local pad = makePart({
		Name = "ZonePad",
		Size = Vector3.new(zone.size.X, 0.3, zone.size.Z),
		CFrame = CFrame.new(zone.position),
		Color = zone.color,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		CanCollide = false,
		Parent = folder,
	})
	pad:SetAttribute("ZoneId", zone.id)
	pad:SetAttribute("ZoneAction", zone.action)

	makePart({
		Name = "Pillar",
		Size = Vector3.new(1.2, 6, 1.2),
		CFrame = CFrame.new(zone.position + Vector3.new(0, 3, 0)),
		Color = zone.color,
		Material = Enum.Material.Metal,
		Parent = folder,
	})

	addSign(folder, zone.name, zone.position, zone.color)

	return folder, pad
end

local function buildHallBoard(parent, position)
	local board = makePart({
		Name = "LeaderboardBoard",
		Size = Vector3.new(10, 7, 0.5),
		CFrame = CFrame.new(position + Vector3.new(0, 5, -5)) * CFrame.Angles(0, math.rad(-90), 0),
		Color = Color3.fromRGB(25, 28, 38),
		Material = Enum.Material.Slate,
		Parent = parent,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.Text = "🏆 Ruhmeshalle"
	title.TextColor3 = Color3.fromRGB(255, 210, 80)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = gui

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Size = UDim2.new(1, -12, 1, -44)
	list.Position = UDim2.fromOffset(6, 40)
	list.BackgroundTransparency = 1
	list.Text = "Lade Rangliste…"
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextSize = 18
	list.Font = Enum.Font.Gotham
	list.TextWrapped = true
	list.Parent = gui

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

	makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		CFrame = CFrame.new(HubConfig.FLOOR_CENTER),
		Color = Color3.fromRGB(35, 40, 52),
		Material = Enum.Material.Concrete,
		Parent = hub,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local center = HubConfig.FLOOR_CENTER
	local wallY = center.Y + HubConfig.WALL_HEIGHT / 2

	local walls = {
		{ Vector3.new(halfX, wallY, 0), Vector3.new(1, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(-halfX, wallY, 0), Vector3.new(1, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(0, wallY, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, 1) },
		{ Vector3.new(0, wallY, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, 1) },
	}
	for i, wall in walls do
		makePart({
			Name = "Wall" .. i,
			Size = wall[2],
			CFrame = CFrame.new(center + wall[1]),
			Color = Color3.fromRGB(28, 32, 42),
			Material = Enum.Material.Brick,
			Parent = hub,
		})
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local folder = buildZone(zonesFolder, zone)
		if zone.id == "halloffame" then
			buildHallBoard(folder, zone.position)
		end
	end

	makePart({
		Name = "HubSpawn",
		Size = Vector3.new(6, 0.2, 6),
		CFrame = CFrame.new(HubConfig.SPAWN - Vector3.new(0, 3, 0)),
		Color = Color3.fromRGB(100, 200, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.7,
		CanCollide = false,
		Parent = hub,
	})

	addSign(hub, "Nova Bladers Hub", HubConfig.SPAWN - Vector3.new(0, 1, 6), Color3.fromRGB(120, 180, 255))

	return hub
end

function HubWorldBuilder.getLeaderboardBoard()
	local hub = workspace:FindFirstChild("NovaHub")
	if not hub then return nil end
	local hall = hub:FindFirstChild("Zones") and hub.Zones:FindFirstChild("halloffame")
	if not hall then return nil end
	return hall:FindFirstChild("LeaderboardBoard")
end

return HubWorldBuilder
