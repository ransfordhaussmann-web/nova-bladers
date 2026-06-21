local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function createPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.Position = props.position
	part.Color = props.color or Color3.fromRGB(40, 44, 56)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Transparency = props.transparency or 0
	part.Parent = props.parent
	return part
end

local function createLabel(parent, text, face)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.Parent = gui
	return gui
end

local function createZoneMarker(parent, zone)
	local marker = createPart({
		name = zone.id,
		parent = parent,
		size = zone.size,
		position = zone.position + Vector3.new(0, zone.size.Y * 0.5, 0),
		color = zone.color,
		material = Enum.Material.Neon,
		transparency = 0.55,
		canCollide = false,
	})
	marker:SetAttribute("ZoneId", zone.id)
	marker:SetAttribute("ZoneAction", zone.action)

	createLabel(marker, zone.name, Enum.NormalId.Front)
	createLabel(marker, zone.name, Enum.NormalId.Back)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = zone.name
	prompt.ActionText = "Öffnen"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.Parent = marker

	return marker
end

function HubWorldBuilder.buildLeaderboardBoard(parent, entries)
	local board = parent:FindFirstChild("LeaderboardBoard")
	if not board then
		board = createPart({
			name = "LeaderboardBoard",
			parent = parent,
			size = Vector3.new(10, 8, 0.5),
			position = HubConfig.ZONES.HallOfFame.position + Vector3.new(0, 5, -6),
			color = Color3.fromRGB(30, 32, 42),
			material = Enum.Material.Slate,
		})
		board.CFrame = CFrame.new(board.Position) * CFrame.Angles(0, math.rad(-90), 0)

		local titleGui = Instance.new("SurfaceGui")
		titleGui.Face = Enum.NormalId.Front
		titleGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		titleGui.PixelsPerStud = 40
		titleGui.Parent = board

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, 0, 0.18, 0)
		title.BackgroundTransparency = 1
		title.Text = "🏆 Ruhmeshalle"
		title.TextColor3 = Color3.fromRGB(255, 220, 100)
		title.TextScaled = true
		title.Font = Enum.Font.GothamBold
		title.Parent = titleGui

		local list = Instance.new("TextLabel")
		list.Name = "List"
		list.Size = UDim2.new(1, -12, 0.78, 0)
		list.Position = UDim2.new(0, 6, 0.2, 0)
		list.BackgroundTransparency = 1
		list.TextColor3 = Color3.new(1, 1, 1)
		list.TextXAlignment = Enum.TextXAlignment.Left
		list.TextYAlignment = Enum.TextYAlignment.Top
		list.TextSize = 22
		list.Font = Enum.Font.GothamMedium
		list.TextWrapped = true
		list.Parent = titleGui
	end

	local list = board:FindFirstChildWhichIsA("SurfaceGui"):FindFirstChild("List")
	if list then
		local lines = {}
		if #entries == 0 then
			table.insert(lines, "Noch keine Einträge")
		else
			for _, entry in entries do
				table.insert(lines, string.format("%d. %s — %d Pkt.", entry.rank, entry.name, entry.points))
			end
		end
		list.Text = table.concat(lines, "\n")
	end

	return board
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_NAME
	hub.Parent = workspace

	local floor = createPart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		position = HubConfig.FLOOR_POSITION,
		color = Color3.fromRGB(32, 36, 48),
		material = Enum.Material.Slate,
	})

	local halfX = HubConfig.FLOOR_SIZE.X * 0.5
	local halfZ = HubConfig.FLOOR_SIZE.Z * 0.5
	local wallY = HubConfig.FLOOR_POSITION.Y + HubConfig.WALL_HEIGHT * 0.5

	local walls = {
		{ Vector3.new(0, wallY, halfZ + 0.5), Vector3.new(HubConfig.FLOOR_SIZE.X + 2, HubConfig.WALL_HEIGHT, 1) },
		{ Vector3.new(0, wallY, -halfZ - 0.5), Vector3.new(HubConfig.FLOOR_SIZE.X + 2, HubConfig.WALL_HEIGHT, 1) },
		{ Vector3.new(halfX + 0.5, wallY, 0), Vector3.new(1, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z + 2) },
		{ Vector3.new(-halfX - 0.5, wallY, 0), Vector3.new(1, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z + 2) },
	}
	for i, wall in walls do
		createPart({
			name = "Wall" .. i,
			parent = hub,
			size = wall[2],
			position = wall[1],
			color = Color3.fromRGB(24, 26, 34),
			material = Enum.Material.Concrete,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.FLOOR_POSITION + HubConfig.SPAWN_OFFSET
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in pairs(HubConfig.ZONES) do
		createZoneMarker(zonesFolder, zone)
	end

	local gate = zonesFolder:FindFirstChild("ArenaGate")
	if gate then
		local arch = createPart({
			name = "GateArch",
			parent = gate,
			size = Vector3.new(gate.Size.X + 2, 1.5, 1),
			position = gate.Position + Vector3.new(0, gate.Size.Y * 0.5 + 0.75, gate.Size.Z * 0.5),
			color = Color3.fromRGB(255, 140, 100),
			material = Enum.Material.Neon,
			canCollide = false,
		})
		arch.Transparency = 0.2
	end

	createPart({
		name = "CenterPad",
		parent = hub,
		size = Vector3.new(10, 0.2, 10),
		position = HubConfig.FLOOR_POSITION + Vector3.new(0, 0.6, 0),
		color = Color3.fromRGB(60, 70, 100),
		material = Enum.Material.Neon,
		canCollide = false,
	}).Transparency = 0.35

	HubWorldBuilder.buildLeaderboardBoard(hub, {})

	return hub
end

return HubWorldBuilder
