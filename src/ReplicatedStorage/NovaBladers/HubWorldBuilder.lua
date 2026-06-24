local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Color = props.Color or Color3.fromRGB(35, 40, 55)
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Name = props.Name or "Part"
	part.Transparency = props.Transparency or 0
	part.Parent = props.Parent
	return part
end

local function addBillboard(parent, title, subtitle, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 70)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Parent = frame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -12, 0.55, 0)
	titleLabel.Position = UDim2.fromOffset(6, 4)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 18
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.Text = title
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = frame

	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, -12, 0.4, 0)
	subLabel.Position = UDim2.new(0, 6, 0.55, 0)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextSize = 14
	subLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
	subLabel.Text = subtitle
	subLabel.TextXAlignment = Enum.TextXAlignment.Left
	subLabel.Parent = frame
end

local function buildLeaderboardBoard(parent, position)
	local board = makePart({
		Name = "LeaderboardBoard",
		Size = Vector3.new(14, 10, 0.5),
		CFrame = CFrame.new(position + Vector3.new(0, 6, -6)) * CFrame.Angles(0, math.rad(180), 0),
		Color = Color3.fromRGB(25, 28, 40),
		Material = Enum.Material.Neon,
		Parent = parent,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(18, 20, 32)
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 48)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 28
	title.TextColor3 = Color3.fromRGB(255, 210, 90)
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Size = UDim2.new(1, -16, 1, -56)
	list.Position = UDim2.fromOffset(8, 52)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextSize = 22
	list.TextColor3 = Color3.fromRGB(230, 235, 245)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextWrapped = true
	list.Text = "Lade Rangliste..."
	list.Parent = frame

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

	local floorY = HubConfig.SPAWN_POSITION.Y - 3.5
	local center = Vector3.new(HubConfig.SPAWN_POSITION.X, floorY, HubConfig.SPAWN_POSITION.Z + 7)

	makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		CFrame = CFrame.new(center),
		Color = Color3.fromRGB(30, 34, 48),
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallY = floorY + wallH / 2

	local walls = {
		{ Vector3.new(halfX + 1, wallY, 0), Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z + 4) },
		{ Vector3.new(-halfX - 1, wallY, 0), Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z + 4) },
		{ Vector3.new(0, wallY, halfZ + 1), Vector3.new(HubConfig.FLOOR_SIZE.X + 4, wallH, 2) },
		{ Vector3.new(0, wallY, -halfZ - 1), Vector3.new(HubConfig.FLOOR_SIZE.X + 4, wallH, 2) },
	}

	for i, wall in walls do
		makePart({
			Name = "Wall" .. i,
			Size = wall[2],
			CFrame = CFrame.new(center + wall[1]),
			Color = Color3.fromRGB(22, 26, 38),
			Material = Enum.Material.Concrete,
			Parent = hub,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zonePart = makePart({
			Name = zone.id,
			Size = zone.size,
			CFrame = CFrame.new(center + zone.position + Vector3.new(0, zone.size.Y / 2, 0)),
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.55,
			CanCollide = false,
			Parent = zonesFolder,
		})
		zonePart:SetAttribute("ZoneId", zone.id)
		addBillboard(zonePart, zone.name, zone.hint, zone.color)

		if zone.id == "HallOfFame" then
			buildLeaderboardBoard(hub, center + zone.position)
		end
	end

	local sign = makePart({
		Name = "WelcomeSign",
		Size = Vector3.new(18, 4, 1),
		CFrame = CFrame.new(center + Vector3.new(0, floorY + 8, -halfZ + 6)),
		Color = Color3.fromRGB(50, 60, 90),
		Material = Enum.Material.Metal,
		Parent = hub,
	})
	addBillboard(sign, "Nova Bladers", "Hub — Arena, Bey-Labor, Ruhmeshalle", Color3.fromRGB(120, 180, 255))

	return hub
end

function HubWorldBuilder.updateLeaderboardBoard(entries)
	local hub = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if not hub then return end

	local board = hub:FindFirstChild("LeaderboardBoard")
	if not board then return end

	local surface = board:FindFirstChildOfClass("SurfaceGui")
	if not surface then return end

	local list = surface:FindFirstChild("Frame") and surface.Frame:FindFirstChild("List")
	if not list then return end

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

return HubWorldBuilder
