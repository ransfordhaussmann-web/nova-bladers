local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Color = props.color or Color3.fromRGB(45, 48, 58)
	part.Size = props.size
	part.CFrame = props.cframe
	part.Name = props.name or "Part"
	part.Transparency = props.transparency or 0
	part.Parent = props.parent
	return part
end

local function addBillboard(parent, title, subtitle)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 80)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = false
	gui.Parent = parent

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextScaled = true
	titleLabel.Text = title
	titleLabel.Parent = gui

	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subLabel.Position = UDim2.fromScale(0, 0.55)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
	subLabel.TextScaled = true
	subLabel.Text = subtitle or ""
	subLabel.Parent = gui
end

function HubWorldBuilder.buildLeaderboardBoard(parent, entries)
	local existing = parent:FindFirstChild("LeaderboardBoard")
	if existing then
		existing:Destroy()
	end

	local board = makePart({
		name = "LeaderboardBoard",
		parent = parent,
		size = HubConfig.LEADERBOARD_BOARD_SIZE,
		cframe = CFrame.new(0, 5, -5.8),
		color = Color3.fromRGB(30, 32, 40),
		material = Enum.Material.Neon,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 215, 80)
	title.TextSize = 22
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Size = UDim2.new(1, -16, 1, -44)
	list.Position = UDim2.fromOffset(8, 40)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextSize = 18
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextWrapped = true

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	list.Text = table.concat(lines, "\n")
	list.Parent = frame

	return board
end

function HubWorldBuilder.build(entries)
	local workspace = game:GetService("Workspace")
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER
	hub.Parent = workspace

	local floorY = HubConfig.FLOOR_SIZE.Y / 2
	makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		cframe = CFrame.new(0, floorY, 0),
		color = Color3.fromRGB(55, 58, 68),
		material = Enum.Material.Slate,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local t = HubConfig.WALL_THICKNESS

	local walls = {
		{ Vector3.new(0, wallH / 2 + floorY, -halfZ - t / 2), Vector3.new(HubConfig.FLOOR_SIZE.X + t * 2, wallH, t) },
		{ Vector3.new(0, wallH / 2 + floorY, halfZ + t / 2), Vector3.new(HubConfig.FLOOR_SIZE.X + t * 2, wallH, t) },
		{ Vector3.new(-halfX - t / 2, wallH / 2 + floorY, 0), Vector3.new(t, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(halfX + t / 2, wallH / 2 + floorY, 0), Vector3.new(t, wallH, HubConfig.FLOOR_SIZE.Z) },
	}
	for i, wall in walls do
		makePart({
			name = "Wall" .. i,
			parent = hub,
			size = wall[2],
			cframe = CFrame.new(wall[1]),
			color = Color3.fromRGB(38, 40, 50),
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.CFrame = CFrame.new(HubConfig.SPAWN_OFFSET + Vector3.new(0, floorY, 0))
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zonePart = makePart({
			name = zone.id,
			parent = zonesFolder,
			size = zone.size,
			cframe = CFrame.new(zone.position + Vector3.new(0, zone.size.Y / 2 + floorY, 0)),
			color = zone.color,
			material = Enum.Material.Neon,
			transparency = 0.35,
		})
		zonePart:SetAttribute("ZoneId", zone.id)
		zonePart:SetAttribute("ZoneAction", zone.action)

		local pad = makePart({
			name = "Pad",
			parent = zonePart,
			size = Vector3.new(zone.size.X - 2, 0.4, zone.size.Z - 2),
			cframe = zonePart.CFrame * CFrame.new(0, -zone.size.Y / 2 + 0.2, 0),
			color = zone.color,
			material = Enum.Material.SmoothPlastic,
			transparency = 0.15,
		})
		pad.CanCollide = false

		addBillboard(zonePart, zone.name, zone.hint)

		if zone.id == "hall_of_fame" then
			local hall = Instance.new("Folder")
			hall.Name = "HallOfFame"
			hall.Parent = zonePart
			HubWorldBuilder.buildLeaderboardBoard(hall, entries or {})
		end
	end

	return hub
end

return HubWorldBuilder
