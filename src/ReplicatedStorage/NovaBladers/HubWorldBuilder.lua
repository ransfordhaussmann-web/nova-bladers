local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.fromRGB(60, 60, 70)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function addBillboard(parent, text, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 56)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
	label.TextColor3 = color
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = text
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
end

function HubWorldBuilder.build(leaderboardEntries)
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	local origin = HubConfig.ORIGIN

	makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		cframe = CFrame.new(origin + Vector3.new(0, -HubConfig.FLOOR_SIZE.Y / 2, 0)),
		color = HubConfig.COLORS.Floor,
		material = Enum.Material.Slate,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS

	local walls = {
		{ Vector3.new(0, wallH / 2, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, wallT) },
		{ Vector3.new(0, wallH / 2, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, wallT) },
		{ Vector3.new(-halfX, wallH / 2, 0), Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(halfX, wallH / 2, 0), Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
	}
	for i, spec in walls do
		makePart({
			name = "Wall" .. i,
			parent = hub,
			size = spec[2],
			cframe = CFrame.new(origin + spec[1]),
			color = HubConfig.COLORS.Wall,
			material = Enum.Material.Concrete,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Transparency = 0.4
	spawn.Color = HubConfig.COLORS.Trim
	spawn.CFrame = CFrame.new(origin + HubConfig.SPAWN_OFFSET)
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zoneFolder = Instance.new("Folder")
		zoneFolder.Name = zone.id
		zoneFolder.Parent = zonesFolder

		local color = HubConfig.COLORS[zone.colorKey] or HubConfig.COLORS.Trim
		local gate = makePart({
			name = "Gate",
			parent = zoneFolder,
			size = zone.size,
			cframe = CFrame.new(origin + zone.position + Vector3.new(0, zone.size.Y / 2, 0)),
			color = color,
			material = Enum.Material.Neon,
		})
		gate.Transparency = 0.25

		local trigger = makePart({
			name = "Trigger",
			parent = zoneFolder,
			size = zone.size + Vector3.new(4, 0, 4),
			cframe = gate.CFrame,
			color = color,
			canCollide = false,
		})
		trigger.Transparency = 1

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ZonePrompt"
		prompt.ActionText = zone.label
		prompt.ObjectText = "Nova Hub"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 14
		prompt.Parent = gate

		local attr = Instance.new("StringValue")
		attr.Name = "ZoneAction"
		attr.Value = zone.action
		attr.Parent = zoneFolder

		local idAttr = Instance.new("StringValue")
		idAttr.Name = "ZoneId"
		idAttr.Value = zone.id
		idAttr.Parent = zoneFolder

		addBillboard(gate, zone.label, color)
	end

	local boardCfg = HubConfig.LEADERBOARD_BOARD
	local board = makePart({
		name = "LeaderboardBoard",
		parent = hub,
		size = boardCfg.size,
		cframe = CFrame.new(origin + boardCfg.position),
		color = Color3.fromRGB(18, 22, 34),
		material = Enum.Material.Metal,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(12, 14, 22)
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 60)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = HubConfig.COLORS.Hall
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "Entries"
	list.Size = UDim2.new(1, -20, 1, -70)
	list.Position = UDim2.fromOffset(10, 65)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextSize = 28
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextColor3 = Color3.fromRGB(230, 230, 240)
	list.Text = ""
	list.Parent = frame

	HubWorldBuilder.updateLeaderboardBoard(hub, leaderboardEntries)

	return hub
end

function HubWorldBuilder.updateLeaderboardBoard(hub, entries)
	if not hub then return end
	local board = hub:FindFirstChild("LeaderboardBoard")
	if not board then return end
	local surface = board:FindFirstChildOfClass("SurfaceGui")
	if not surface then return end
	local list = surface:FindFirstChild("Frame") and surface.Frame:FindFirstChild("Entries")
	if not list then return end

	local lines = {}
	for _, entry in entries or {} do
		table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	list.Text = table.concat(lines, "\n")
end

return HubWorldBuilder
