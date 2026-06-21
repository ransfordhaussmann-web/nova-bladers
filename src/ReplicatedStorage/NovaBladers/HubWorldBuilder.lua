local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Name = props.name or "Part"
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.fromRGB(60, 60, 70)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Transparency = props.transparency or 0
	part.Parent = props.parent
	return part
end

local function addSign(parent, text, position, color)
	local sign = makePart({
		name = "Sign",
		size = Vector3.new(8, 3, 0.4),
		cframe = CFrame.new(position),
		color = color,
		material = Enum.Material.Neon,
		parent = parent,
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

	return sign
end

local function addZoneTrigger(zoneFolder, zone)
	local trigger = makePart({
		name = zone.id,
		size = zone.size,
		cframe = CFrame.new(zone.position),
		color = zone.color,
		material = Enum.Material.ForceField,
		transparency = 0.65,
		canCollide = false,
		parent = zoneFolder,
	})
	trigger:SetAttribute("ZoneId", zone.id)
	trigger:SetAttribute("ZoneAction", zone.action)
	trigger:SetAttribute("ZoneHint", zone.hint)
	trigger:SetAttribute("ZoneName", zone.name)
	return trigger
end

function HubWorldBuilder.buildLeaderboardBoard(parent, entries)
	local boardCfg = HubConfig.LEADERBOARD_BOARD
	local board = parent:FindFirstChild("LeaderboardBoard")
	if not board then
		board = makePart({
			name = "LeaderboardBoard",
			size = boardCfg.size,
			cframe = CFrame.new(boardCfg.position),
			color = Color3.fromRGB(25, 28, 38),
			material = Enum.Material.Metal,
			parent = parent,
		})

		local gui = Instance.new("SurfaceGui")
		gui.Name = "BoardGui"
		gui.Face = Enum.NormalId.Back
		gui.Parent = board

		local label = Instance.new("TextLabel")
		label.Name = "EntriesLabel"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.fromRGB(255, 220, 120)
		label.TextScaled = false
		label.TextSize = 28
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.Text = ""
		label.Parent = gui
	end

	local label = board.BoardGui.EntriesLabel
	local lines = { "🏆 Ruhmeshalle" }
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	label.Text = table.concat(lines, "\n")
	return board
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		return existing
	end

	local origin = HubConfig.ORIGIN
	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local floorCfg = HubConfig.FLOOR
	makePart({
		name = "Floor",
		size = floorCfg.size,
		cframe = CFrame.new(origin + Vector3.new(0, -floorCfg.size.Y / 2, 0)),
		color = floorCfg.color,
		material = floorCfg.material,
		parent = hub,
	})

	local halfX = floorCfg.size.X / 2
	local halfZ = floorCfg.size.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS

	local walls = {
		{ pos = Vector3.new(0, wallH / 2, halfZ), size = Vector3.new(floorCfg.size.X, wallH, wallT) },
		{ pos = Vector3.new(0, wallH / 2, -halfZ), size = Vector3.new(floorCfg.size.X, wallH, wallT) },
		{ pos = Vector3.new(halfX, wallH / 2, 0), size = Vector3.new(wallT, wallH, floorCfg.size.Z) },
		{ pos = Vector3.new(-halfX, wallH / 2, 0), size = Vector3.new(wallT, wallH, floorCfg.size.Z) },
	}

	for i, wall in walls do
		makePart({
			name = "Wall" .. i,
			size = wall.size,
			cframe = CFrame.new(origin + wall.pos),
			color = Color3.fromRGB(50, 55, 70),
			material = Enum.Material.Concrete,
			parent = hub,
		})
	end

	local spawn = makePart({
		name = "HubSpawn",
		size = Vector3.new(6, 0.5, 6),
		cframe = CFrame.new(HubConfig.SPAWN),
		color = Color3.fromRGB(100, 180, 255),
		material = Enum.Material.Neon,
		transparency = 0.3,
		parent = hub,
	})
	spawn.CanCollide = false

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		addZoneTrigger(zonesFolder, zone)
		addSign(hub, zone.name, zone.position + Vector3.new(0, zone.size.Y / 2 + 2.5, 0), zone.color)
	end

	HubWorldBuilder.buildLeaderboardBoard(hub, {})

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 40
	light.Parent = spawn

	return hub
end

return HubWorldBuilder
