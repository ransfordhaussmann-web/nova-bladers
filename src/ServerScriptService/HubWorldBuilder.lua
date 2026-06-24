local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldBuilder = {}
local built = false

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.CastShadow = props.CastShadow ~= false
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Color = props.Color or Color3.fromRGB(45, 50, 65)
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Name = props.Name or "Part"
	part.Transparency = props.Transparency or 0
	part.Parent = props.Parent
	return part
end

local function addSign(parent, text, position, color)
	local sign = makePart({
		Name = "Sign",
		Size = Vector3.new(10, 4, 0.4),
		CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(180), 0),
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

function HubWorldBuilder.buildLeaderboardBoard(parent, entries)
	local board = parent:FindFirstChild("LeaderboardBoard")
	if board then board:Destroy() end

	board = makePart({
		Name = "LeaderboardBoard",
		Size = Vector3.new(12, 8, 0.5),
		CFrame = CFrame.new(HubConfig.ZONES[3].position + Vector3.new(0, 4, -6)),
		Color = Color3.fromRGB(30, 32, 42),
		Material = Enum.Material.Slate,
		Parent = parent,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 60)
	title.BackgroundTransparency = 1
	title.Text = "🏆 Ruhmeshalle"
	title.TextColor3 = Color3.fromRGB(255, 220, 100)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Size = UDim2.new(1, -20, 1, -70)
	list.Position = UDim2.new(0, 10, 0, 65)
	list.BackgroundTransparency = 1
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextColor3 = Color3.fromRGB(230, 230, 240)
	list.TextSize = 28
	list.Font = Enum.Font.Gotham
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
end

function HubWorldBuilder.build(entries)
	if built then
		local hub = workspace:FindFirstChild("NovaHub")
		if hub then
			HubWorldBuilder.buildLeaderboardBoard(hub, entries or {})
		end
		return workspace:FindFirstChild("NovaHub")
	end
	built = true

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local floorY = HubConfig.FLOOR_Y
	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		CFrame = CFrame.new(0, floorY - HubConfig.FLOOR_SIZE.Y / 2, 0),
		Color = Color3.fromRGB(55, 60, 75),
		Material = Enum.Material.Concrete,
		Parent = hub,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallY = floorY + wallH / 2

	local walls = {
		{ Vector3.new(0, wallY, halfZ + 1), Vector3.new(HubConfig.FLOOR_SIZE.X + 2, wallH, 2) },
		{ Vector3.new(0, wallY, -halfZ - 1), Vector3.new(HubConfig.FLOOR_SIZE.X + 2, wallH, 2) },
		{ Vector3.new(halfX + 1, wallY, 0), Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(-halfX - 1, wallY, 0), Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z) },
	}
	for i, wall in walls do
		makePart({
			Name = "Wall" .. i,
			Size = wall[2],
			CFrame = CFrame.new(wall[1]),
			Color = Color3.fromRGB(40, 44, 58),
			Material = Enum.Material.Brick,
			Parent = hub,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.CFrame = CFrame.new(HubConfig.SPAWN)
	spawn.Neutral = true
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local marker = makePart({
			Name = zone.id,
			Size = zone.size,
			CFrame = CFrame.new(zone.position),
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.55,
			CanCollide = false,
			Parent = zonesFolder,
		})
		marker:SetAttribute("ZoneId", zone.id)
		marker:SetAttribute("ZoneAction", zone.action)

		local ring = makePart({
			Name = "Ring",
			Size = Vector3.new(zone.size.X + 2, 0.3, zone.size.Z + 2),
			CFrame = CFrame.new(zone.position.X, floorY + 0.2, zone.position.Z),
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.3,
			CanCollide = false,
			Parent = marker,
		})
		ring.Name = "FloorRing"

		addSign(zonesFolder, zone.name, zone.position + Vector3.new(0, zone.size.Y / 2 + 3, 0), zone.color)
	end

	HubWorldBuilder.buildLeaderboardBoard(hub, entries or {})
	return hub
end

return HubWorldBuilder
