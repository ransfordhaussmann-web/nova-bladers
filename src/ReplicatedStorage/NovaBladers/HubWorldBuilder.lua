local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.fromRGB(200, 200, 200)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Transparency = props.transparency or 0
	part.Parent = props.parent
	return part
end

local function makeSign(parent, text, position, color)
	local sign = makePart({
		parent = parent,
		name = "Sign",
		size = Vector3.new(10, 3, 0.4),
		cframe = CFrame.new(position),
		color = color,
		material = Enum.Material.Neon,
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

local function makeZoneTrigger(parent, zone)
	local colors = HubConfig.COLORS
	local color = colors[zone.colorKey] or colors.Accent

	local trigger = Instance.new("Part")
	trigger.Name = zone.id
	trigger.Anchored = true
	trigger.CanCollide = false
	trigger.Transparency = 0.65
	trigger.Size = zone.size
	trigger.CFrame = CFrame.new(zone.position)
	trigger.Color = color
	trigger.Material = Enum.Material.ForceField
	trigger.Parent = parent

	local hint = Instance.new("BillboardGui")
	hint.Name = "ZoneHint"
	hint.Size = UDim2.fromOffset(200, 50)
	hint.StudsOffset = Vector3.new(0, zone.size.Y * 0.5 + 2, 0)
	hint.AlwaysOnTop = true
	hint.Parent = trigger

	local hintLabel = Instance.new("TextLabel")
	hintLabel.Size = UDim2.fromScale(1, 1)
	hintLabel.BackgroundTransparency = 0.3
	hintLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	hintLabel.TextColor3 = Color3.new(1, 1, 1)
	hintLabel.Text = zone.name
	hintLabel.TextScaled = true
	hintLabel.Font = Enum.Font.GothamBold
	hintLabel.Parent = hint

	local action = Instance.new("StringValue")
	action.Name = "Action"
	action.Value = zone.action
	action.Parent = trigger

	local hintText = Instance.new("StringValue")
	hintText.Name = "HintText"
	hintText.Value = zone.hint
	hintText.Parent = trigger

	return trigger
end

function HubWorldBuilder.createLeaderboardBoard(parent, entries)
	local cfg = HubConfig.LEADERBOARD
	local board = makePart({
		parent = parent,
		name = "LeaderboardBoard",
		size = cfg.size,
		cframe = CFrame.new(cfg.position),
		color = Color3.fromRGB(25, 28, 38),
		material = Enum.Material.Slate,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = board

	local label = Instance.new("TextLabel")
	label.Name = "BoardLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 220, 100)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextSize = 22
	label.Font = Enum.Font.GothamBold
	label.Text = "🏆 Ruhmeshalle\n\nLade..."
	label.Parent = gui

	return board
end

function HubWorldBuilder.updateLeaderboardBoard(board, entries)
	if not board then return end
	local gui = board:FindFirstChildOfClass("SurfaceGui")
	if not gui then return end
	local label = gui:FindFirstChild("BoardLabel")
	if not label then return end

	local lines = {"🏆 Top Spieler", ""}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	label.Text = table.concat(lines, "\n")
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_NAME
	hub.Parent = workspace

	local geometry = Instance.new("Folder")
	geometry.Name = "Geometry"
	geometry.Parent = hub

	local colors = HubConfig.COLORS
	local halfFloor = HubConfig.FLOOR_SIZE * 0.5

	makePart({
		parent = geometry,
		name = "Floor",
		size = HubConfig.FLOOR_SIZE,
		cframe = CFrame.new(0, 0, 0),
		color = colors.Floor,
		material = Enum.Material.Concrete,
	})

	local wallThickness = 2
	local wallY = HubConfig.WALL_HEIGHT * 0.5
	local wallSpecs = {
		{ name = "WallNorth", pos = Vector3.new(0, wallY, -halfFloor.Z), size = Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, wallThickness) },
		{ name = "WallSouth", pos = Vector3.new(0, wallY, halfFloor.Z), size = Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, wallThickness) },
		{ name = "WallEast", pos = Vector3.new(halfFloor.X, wallY, 0), size = Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
		{ name = "WallWest", pos = Vector3.new(-halfFloor.X, wallY, 0), size = Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
	}
	for _, spec in wallSpecs do
		makePart({
			parent = geometry,
			name = spec.name,
			size = spec.size,
			cframe = CFrame.new(spec.pos),
			color = colors.Wall,
			material = Enum.Material.Concrete,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 0.5
	spawn.Color = colors.Accent
	spawn.Material = Enum.Material.Neon
	spawn.Neutral = true
	spawn.Parent = hub

	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = hub

	for _, zone in HubConfig.ZONES do
		makeZoneTrigger(zones, zone)
		local signPos = zone.position + Vector3.new(0, zone.size.Y * 0.5 + 4, 0)
		makeSign(zones, zone.name, signPos, colors[zone.colorKey] or colors.Accent)
	end

	local board = HubWorldBuilder.createLeaderboardBoard(hub, {})
	hub:SetAttribute("LeaderboardBoardName", board.Name)

	return hub
end

return HubWorldBuilder
