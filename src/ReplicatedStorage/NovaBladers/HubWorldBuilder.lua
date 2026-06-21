local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.Position = props.position
	part.Color = props.color or HubConfig.COLORS.Floor
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	if props.transparency then
		part.Transparency = props.transparency
	end
	return part
end

local function addBillboard(parent, title, subtitle, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 80)
	gui.StudsOffset = Vector3.new(0, 6, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -8, 0.55, 0)
	titleLabel.Position = UDim2.fromOffset(4, 2)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 18
	titleLabel.TextColor3 = color
	titleLabel.Text = title
	titleLabel.Parent = frame

	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, -8, 0.4, 0)
	subLabel.Position = UDim2.new(0, 4, 0.55, 0)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextSize = 13
	subLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
	subLabel.Text = subtitle
	subLabel.TextWrapped = true
	subLabel.Parent = frame
end

local function addProximityPrompt(part, actionText, objectText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_NAME
	hub.Parent = workspace

	local floorY = HubConfig.FLOOR_Y
	local floor = makePart({
		name = "Floor",
		size = HubConfig.FLOOR_SIZE,
		position = Vector3.new(0, floorY, 0),
		color = HubConfig.COLORS.Floor,
		material = Enum.Material.Slate,
		parent = hub,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallY = floorY + wallH / 2

	local walls = {
		{ name = "WallNorth", size = Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 2), pos = Vector3.new(0, wallY, -halfZ) },
		{ name = "WallSouth", size = Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 2), pos = Vector3.new(0, wallY, halfZ) },
		{ name = "WallEast", size = Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z), pos = Vector3.new(halfX, wallY, 0) },
		{ name = "WallWest", size = Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z), pos = Vector3.new(-halfX, wallY, 0) },
	}
	for _, wall in walls do
		makePart({
			name = wall.name,
			size = wall.size,
			position = wall.pos,
			color = HubConfig.COLORS.Wall,
			material = Enum.Material.Concrete,
			parent = hub,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = Vector3.new(
		HubConfig.SPAWN_OFFSET.X,
		floorY + 1,
		HubConfig.SPAWN_OFFSET.Z
	)
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
		local color = HubConfig.COLORS[zone.colorKey] or HubConfig.COLORS.Trim
		local zonePart = makePart({
			name = zone.id,
			size = zone.size,
			position = zone.position + Vector3.new(0, floorY, 0),
			color = color,
			material = Enum.Material.Neon,
			parent = zonesFolder,
			transparency = 0.35,
		})
		zonePart:SetAttribute("ZoneId", zone.id)
		zonePart:SetAttribute("ZoneAction", zone.action)

		addBillboard(zonePart, zone.name, zone.hint, color)

		local actionText = "Betreten"
		if zone.action == "openBeySelect" then
			actionText = "Auswählen"
		elseif zone.action == "hallOfFame" then
			actionText = "Ansehen"
		end
		addProximityPrompt(zonePart, actionText, zone.name)
	end

	local lbCfg = HubConfig.LEADERBOARD
	local board = makePart({
		name = "LeaderboardBoard",
		size = lbCfg.partSize,
		position = lbCfg.offset + Vector3.new(0, floorY, 0),
		color = HubConfig.COLORS.HallOfFame,
		material = Enum.Material.SmoothPlastic,
		parent = hub,
	})
	board.CFrame = CFrame.new(board.Position) * CFrame.Angles(0, math.rad(90), 0)

	local surface = Instance.new("SurfaceGui")
	surface.Name = "BoardGui"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.Parent = board

	local label = Instance.new("TextLabel")
	label.Name = "Entries"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	label.BackgroundTransparency = 0.1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 22
	label.TextColor3 = Color3.fromRGB(255, 230, 120)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = "🏆 Ruhmeshalle\nLade Rangliste…"
	label.Parent = surface

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = label

	return hub, spawn, board
end

function HubWorldBuilder.formatLeaderboard(entries)
	local lines = { "🏆 Nova Liga — Top 5" }
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	else
		for _, entry in entries do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
	end
	return table.concat(lines, "\n")
end

function HubWorldBuilder.updateLeaderboardBoard(board, entries)
	if not board then return end
	local gui = board:FindFirstChild("BoardGui")
	local label = gui and gui:FindFirstChild("Entries")
	if label then
		label.Text = HubWorldBuilder.formatLeaderboard(entries)
	end
end

return HubWorldBuilder
