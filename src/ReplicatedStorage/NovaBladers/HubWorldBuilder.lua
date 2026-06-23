local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.CanTouch = props.CanTouch ~= false
	part.CastShadow = props.CastShadow ~= false
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color or Color3.fromRGB(40, 44, 58)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Transparency = props.Transparency or 0
	part.Name = props.Name or "Part"
	if props.Shape then
		part.Shape = props.Shape
	end
	part.Parent = props.Parent
	return part
end

local function addSign(parent, text, position, color)
	local sign = makePart({
		Name = "Sign",
		Parent = parent,
		Size = Vector3.new(8, 3, 0.4),
		CFrame = CFrame.new(position + Vector3.new(0, 5, 0)),
		Color = color,
		Material = Enum.Material.Neon,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Text = text
	label.Parent = gui
end

local function addZonePad(parent, zone)
	local pad = makePart({
		Name = zone.id,
		Parent = parent,
		Size = Vector3.new(18, 0.4, 18),
		CFrame = CFrame.new(zone.position - Vector3.new(0, 0.5, 0)),
		Color = zone.color,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanTouch = true,
	})
	pad:SetAttribute("ZoneId", zone.id)
	pad:SetAttribute("Action", zone.action)

	makePart({
		Name = "Ring",
		Parent = pad,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 20, 20),
		CFrame = CFrame.new(zone.position - Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = zone.color,
		Material = Enum.Material.Neon,
		Transparency = 0.5,
		CanCollide = false,
		CanTouch = false,
	})

	addSign(parent, zone.name, zone.position, zone.color)
	return pad
end

function HubWorldBuilder.buildLeaderboardBoard(parent, entries)
	local boardPart = makePart({
		Name = "LeaderboardBoard",
		Parent = parent,
		Size = Vector3.new(14, 10, 0.6),
		CFrame = CFrame.new(Vector3.new(32, 8.5, -8)),
		Color = Color3.fromRGB(25, 28, 38),
		Material = Enum.Material.Metal,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = boardPart

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(18, 20, 30)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 48)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 215, 80)
	title.TextSize = 28
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "Entries"
	list.Position = UDim2.new(0, 12, 0, 52)
	list.Size = UDim2.new(1, -24, 1, -60)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextColor3 = Color3.fromRGB(220, 225, 240)
	list.TextSize = 22
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextWrapped = true
	list.Parent = frame

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	list.Text = table.concat(lines, "\n")

	return boardPart
end

function HubWorldBuilder.build(entries)
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	makePart({
		Name = "Floor",
		Parent = hub,
		Size = HubConfig.FLOOR_SIZE,
		CFrame = CFrame.new(HubConfig.FLOOR_CENTER),
		Color = Color3.fromRGB(32, 36, 48),
		Material = Enum.Material.Slate,
	})

	local floorY = HubConfig.FLOOR_CENTER.Y + HubConfig.FLOOR_SIZE.Y * 0.5
	local halfX = HubConfig.FLOOR_SIZE.X * 0.5
	local halfZ = HubConfig.FLOOR_SIZE.Z * 0.5
	local center = HubConfig.FLOOR_CENTER
	local wallH = HubConfig.WALL_HEIGHT
	local t = HubConfig.WALL_THICKNESS

	local walls = {
		{ Vector3.new(halfX * 2 + t, wallH, t), Vector3.new(center.X, floorY + wallH * 0.5, center.Z + halfZ + t * 0.5) },
		{ Vector3.new(halfX * 2 + t, wallH, t), Vector3.new(center.X, floorY + wallH * 0.5, center.Z - halfZ - t * 0.5) },
		{ Vector3.new(t, wallH, halfZ * 2 + t), Vector3.new(center.X + halfX + t * 0.5, floorY + wallH * 0.5, center.Z) },
		{ Vector3.new(t, wallH, halfZ * 2 + t), Vector3.new(center.X - halfX - t * 0.5, floorY + wallH * 0.5, center.Z) },
	}
	for i, wall in walls do
		makePart({
			Name = "Wall" .. i,
			Parent = hub,
			Size = wall[1],
			CFrame = CFrame.new(wall[2]),
			Color = Color3.fromRGB(50, 54, 70),
			Material = Enum.Material.Concrete,
		})
	end

	local spawn = makePart({
		Name = "HubSpawn",
		Parent = hub,
		Size = Vector3.new(6, 0.2, 6),
		CFrame = CFrame.new(HubConfig.SPAWN_POSITION - Vector3.new(0, 0.5, 0)),
		Color = Color3.fromRGB(100, 180, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.4,
		CanCollide = false,
		CanTouch = false,
	})

	for _, zone in HubConfig.ZONES do
		addZonePad(zonesFolder, zone)
	end

	HubWorldBuilder.buildLeaderboardBoard(hub, entries)

	local light = Instance.new("PointLight")
	light.Brightness = 1.2
	light.Range = 40
	light.Color = Color3.fromRGB(180, 200, 255)
	light.Parent = spawn

	return hub
end

return HubWorldBuilder
