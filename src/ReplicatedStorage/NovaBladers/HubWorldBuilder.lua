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
	part.Parent = props.parent
	return part
end

local function addSign(parent, text, color)
	local sign = Instance.new("Part")
	sign.Name = "Sign"
	sign.Anchored = true
	sign.CanCollide = false
	sign.Size = Vector3.new(8, 4, 0.4)
	sign.Material = Enum.Material.Neon
	sign.Color = color
	sign.CFrame = parent.CFrame * CFrame.new(0, parent.Size.Y / 2 + 2.5, 0)
	sign.Parent = parent.Parent

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
	if not board then
		board = Instance.new("Part")
		board.Name = "LeaderboardBoard"
		board.Anchored = true
		board.CanCollide = true
		board.Size = Vector3.new(12, 8, 0.5)
		board.Material = Enum.Material.SmoothPlastic
		board.Color = Color3.fromRGB(30, 32, 40)
		board.CFrame = parent.CFrame * CFrame.new(0, 4, -parent.Size.Z / 2 - 1) * CFrame.Angles(0, math.pi, 0)
		board.Parent = parent.Parent

		local gui = Instance.new("SurfaceGui")
		gui.Name = "BoardGui"
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = HubConfig.LEADERBOARD_BOARD_SIZE
		gui.Parent = board

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, 0, 0, 60)
		title.BackgroundTransparency = 1
		title.Text = "🏆 Ruhmeshalle"
		title.TextColor3 = Color3.fromRGB(255, 210, 80)
		title.TextScaled = true
		title.Font = Enum.Font.GothamBold
		title.Parent = gui

		local list = Instance.new("TextLabel")
		list.Name = "List"
		list.Size = UDim2.new(1, -20, 1, -80)
		list.Position = UDim2.fromOffset(10, 70)
		list.BackgroundTransparency = 1
		list.TextXAlignment = Enum.TextXAlignment.Left
		list.TextYAlignment = Enum.TextYAlignment.Top
		list.TextColor3 = Color3.new(1, 1, 1)
		list.TextSize = 28
		list.Font = Enum.Font.Gotham
		list.TextWrapped = true
		list.Parent = gui
	end

	local list = board.BoardGui.List
	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	list.Text = table.concat(lines, "\n")
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		return existing
	end

	local hub = Instance.new("Model")
	hub.Name = "NovaHub"

	local floorSize = HubConfig.FLOOR_SIZE
	local floor = makePart({
		name = "Floor",
		size = floorSize,
		cframe = CFrame.new(0, floorSize.Y / 2, 0),
		color = Color3.fromRGB(35, 38, 48),
		material = Enum.Material.Slate,
		parent = hub,
	})

	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS
	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2

	local walls = {
		{ size = Vector3.new(floorSize.X + wallT * 2, wallH, wallT), pos = Vector3.new(0, wallH / 2, -halfZ - wallT / 2) },
		{ size = Vector3.new(floorSize.X + wallT * 2, wallH, wallT), pos = Vector3.new(0, wallH / 2, halfZ + wallT / 2) },
		{ size = Vector3.new(wallT, wallH, floorSize.Z), pos = Vector3.new(-halfX - wallT / 2, wallH / 2, 0) },
		{ size = Vector3.new(wallT, wallH, floorSize.Z), pos = Vector3.new(halfX + wallT / 2, wallH / 2, 0) },
	}
	for i, wall in walls do
		makePart({
			name = "Wall" .. i,
			size = wall.size,
			cframe = CFrame.new(wall.pos),
			color = Color3.fromRGB(50, 54, 68),
			parent = hub,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN)
	spawn.Neutral = true
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for zoneKey, zone in HubConfig.ZONES do
		local zonePart = makePart({
			name = zoneKey,
			size = zone.size,
			cframe = CFrame.new(zone.position + Vector3.new(0, zone.size.Y / 2, 0)),
			color = zone.color,
			material = Enum.Material.Neon,
			canCollide = false,
			parent = zonesFolder,
		})
		zonePart.Transparency = 0.65
		zonePart:SetAttribute("ZoneId", zone.id)
		zonePart:SetAttribute("ZoneAction", zone.action)

		addSign(zonePart, zone.name, zone.color)

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ZonePrompt"
		prompt.ActionText = zone.promptText
		prompt.ObjectText = zone.name
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("ZoneAction", zone.action)
		prompt.Parent = zonePart
	end

	hub.PrimaryPart = floor
	hub.Parent = workspace
	return hub
end

return HubWorldBuilder
