local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Color = props.color or Color3.new(1, 1, 1)
	part.Size = props.size
	part.CFrame = props.cframe
	part.Name = props.name or "Part"
	part.Transparency = props.transparency or 0
	if props.parent then
		part.Parent = props.parent
	end
	return part
end

local function makeSign(parent, text, position, color)
	local sign = makePart({
		name = "Sign",
		size = Vector3.new(8, 3, 0.4),
		cframe = CFrame.new(position),
		color = color,
		parent = parent,
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

	return sign
end

function HubWorldBuilder.createZone(parent, zone)
	local folder = Instance.new("Folder")
	folder.Name = zone.id
	folder.Parent = parent

	makePart({
		name = "Pad",
		size = zone.size,
		cframe = CFrame.new(zone.position),
		color = zone.color,
		transparency = 0.35,
		canCollide = false,
		parent = folder,
	})

	local trigger = makePart({
		name = "Trigger",
		size = zone.size + Vector3.new(2, 4, 2),
		cframe = CFrame.new(zone.position + Vector3.new(0, 2, 0)),
		color = zone.color,
		transparency = 1,
		canCollide = false,
		parent = folder,
	})

	local signPos = zone.position + Vector3.new(0, zone.size.Y / 2 + 2.5, -zone.size.Z / 2 - 1)
	makeSign(folder, zone.name, signPos, zone.color)

	return folder, trigger
end

function HubWorldBuilder.createLeaderboardBoard(parent, entries)
	local cfg = HubConfig.LEADERBOARD_BOARD
	local board = makePart({
		name = "LeaderboardBoard",
		size = cfg.size,
		cframe = CFrame.new(cfg.position),
		color = Color3.fromRGB(25, 28, 38),
		parent = parent,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.Text = "🏆 Ruhmeshalle"
	title.TextColor3 = Color3.fromRGB(255, 220, 80)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "Entries"
	list.Size = UDim2.new(1, -12, 1, -44)
	list.Position = UDim2.fromOffset(6, 40)
	list.BackgroundTransparency = 1
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextSize = 18
	list.Font = Enum.Font.Gotham
	list.TextWrapped = true
	list.Parent = frame

	HubWorldBuilder.updateLeaderboardBoard(board, entries)
	return board
end

function HubWorldBuilder.updateLeaderboardBoard(board, entries)
	local gui = board:FindFirstChildOfClass("SurfaceGui")
	if not gui then return end
	local entriesLabel = gui:FindFirstChild("Frame") and gui.Frame:FindFirstChild("Entries")
	if not entriesLabel then return end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	entriesLabel.Text = table.concat(lines, "\n")
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Model")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	makePart({
		name = "Floor",
		size = HubConfig.HUB_SIZE,
		cframe = CFrame.new(0, 0, 0),
		color = HubConfig.FLOOR_COLOR,
		material = Enum.Material.Slate,
		parent = hub,
	})

	local halfX = HubConfig.HUB_SIZE.X / 2
	local halfZ = HubConfig.HUB_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT

	local walls = {
		{ Vector3.new(0, wallH / 2, halfZ), Vector3.new(HubConfig.HUB_SIZE.X, wallH, 2) },
		{ Vector3.new(0, wallH / 2, -halfZ), Vector3.new(HubConfig.HUB_SIZE.X, wallH, 2) },
		{ Vector3.new(halfX, wallH / 2, 0), Vector3.new(2, wallH, HubConfig.HUB_SIZE.Z) },
		{ Vector3.new(-halfX, wallH / 2, 0), Vector3.new(2, wallH, HubConfig.HUB_SIZE.Z) },
	}
	for i, wall in walls do
		makePart({
			name = "Wall" .. i,
			size = wall[2],
			cframe = CFrame.new(wall[1]),
			color = HubConfig.WALL_COLOR,
			parent = hub,
		})
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	local triggers = {}
	for _, zone in HubConfig.ZONES do
		local _, trigger = HubWorldBuilder.createZone(zonesFolder, zone)
		triggers[zone.id] = trigger
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Parent = hub

	return hub, triggers
end

return HubWorldBuilder
