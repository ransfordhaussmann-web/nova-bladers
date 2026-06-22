local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Color = props.Color or Color3.fromRGB(45, 48, 58)
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Name = props.Name or "Part"
	part.Transparency = props.Transparency or 0
	part.Parent = props.Parent
	return part
end

local function makeSign(parent, text, position, color)
	local sign = makePart({
		Name = "Sign",
		Parent = parent,
		Size = Vector3.new(10, 4, 0.4),
		CFrame = CFrame.new(position + Vector3.new(0, 6, 0)),
		Color = color,
		Material = Enum.Material.Neon,
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
	if not board then
		board = makePart({
			Name = "LeaderboardBoard",
			Parent = parent,
			Size = Vector3.new(12, 8, 0.5),
			CFrame = CFrame.new(HubConfig.ZONES[3].position + Vector3.new(0, 5, -6)),
			Color = Color3.fromRGB(30, 32, 40),
			Material = Enum.Material.Slate,
		})
	end

	local gui = board:FindFirstChildOfClass("SurfaceGui")
	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.Parent = board
	end

	local label = gui:FindFirstChild("BoardLabel")
	if not label then
		label = Instance.new("TextLabel")
		label.Name = "BoardLabel"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextScaled = false
		label.TextSize = 22
		label.Font = Enum.Font.GothamBold
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.Parent = gui
	end

	local lines = { "🏆 Ruhmeshalle — Top 5" }
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	label.Text = table.concat(lines, "\n")
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local floor = makePart({
		Name = "Floor",
		Parent = hub,
		Size = HubConfig.FLOOR_SIZE,
		CFrame = CFrame.new(HubConfig.FLOOR_CENTER),
		Color = Color3.fromRGB(55, 58, 68),
		Material = Enum.Material.Concrete,
	})

	local wallThickness = 2
	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local center = HubConfig.FLOOR_CENTER
	local wallY = center.Y + HubConfig.WALL_HEIGHT / 2

	local walls = {
		{ Vector3.new(halfX + wallThickness / 2, wallY, 0), Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(-(halfX + wallThickness / 2), wallY, 0), Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(0, wallY, halfZ + wallThickness / 2), Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, wallThickness) },
		{ Vector3.new(0, wallY, -(halfZ + wallThickness / 2)), Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, wallThickness) },
	}

	for i, wall in walls do
		makePart({
			Name = "Wall" .. i,
			Parent = hub,
			Size = wall[2],
			CFrame = CFrame.new(center + wall[1]),
			Color = Color3.fromRGB(38, 40, 50),
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
		local zonePart = makePart({
			Name = zone.id,
			Parent = zonesFolder,
			Size = zone.size,
			CFrame = CFrame.new(zone.position),
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.55,
			CanCollide = false,
		})
		zonePart:SetAttribute("ZoneId", zone.id)
		zonePart:SetAttribute("ZoneName", zone.name)
		zonePart:SetAttribute("ZoneHint", zone.hint)
		zonePart:SetAttribute("ZoneAction", zone.action)

		makeSign(zonesFolder, zone.name, zone.position, zone.color)
	end

	HubWorldBuilder.buildLeaderboardBoard(hub, {})

	return hub
end

return HubWorldBuilder
