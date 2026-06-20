local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.Position = props.position
	part.Color = props.color or Color3.fromRGB(45, 48, 58)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function makeSign(parent, text, position, color)
	local sign = makePart({
		parent = parent,
		name = "Sign",
		size = Vector3.new(10, 4, 0.4),
		position = position + Vector3.new(0, 6, 0),
		color = color,
		canCollide = false,
	})
	sign.Material = Enum.Material.Neon

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

local function makeZoneMarker(parent, zone)
	local marker = makePart({
		parent = parent,
		name = zone.id,
		size = Vector3.new(zone.size.X, 0.4, zone.size.Z),
		position = zone.position + Vector3.new(0, 0.3, 0),
		color = zone.color,
		canCollide = false,
	})
	marker.Material = Enum.Material.Neon
	marker.Transparency = 0.35

	local trigger = makePart({
		parent = marker,
		name = "Trigger",
		size = zone.size,
		position = zone.position + Vector3.new(0, zone.size.Y * 0.5, 0),
		color = zone.color,
		canCollide = false,
	})
	trigger.Transparency = 1

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = zone.name
	prompt.ObjectText = zone.hint
	prompt.MaxActivationDistance = 12
	prompt.HoldDuration = 0
	prompt.Parent = trigger

	local attr = Instance.new("StringValue")
	attr.Name = "ZoneAction"
	attr.Value = zone.action
	attr.Parent = trigger

	makeSign(parent, zone.name, zone.position, zone.color)
	return marker
end

function HubWorldBuilder.buildLeaderboardBoard(parent, entries)
	local board = parent:FindFirstChild("LeaderboardBoard")
	if not board then
		board = makePart({
			parent = parent,
			name = "LeaderboardBoard",
			size = Vector3.new(14, 10, 0.6),
			position = HubConfig.ZONES.HallOfFame.position + Vector3.new(0, 6, -6),
			color = Color3.fromRGB(30, 32, 40),
			canCollide = true,
		})
		board.Material = Enum.Material.Metal
	end

	local gui = board:FindFirstChild("BoardGui")
	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Name = "BoardGui"
		gui.Face = Enum.NormalId.Front
		gui.Parent = board
	end

	local label = gui:FindFirstChild("TextLabel")
	if not label then
		label = Instance.new("TextLabel")
		label.Name = "TextLabel"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(255, 220, 100)
		label.TextScaled = false
		label.TextSize = 22
		label.Font = Enum.Font.GothamMedium
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.Parent = gui
	end

	local lines = {"🏆 Ruhmeshalle — Top 5"}
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
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local floorY = HubConfig.SPAWN.Y - 2
	makePart({
		parent = hub,
		name = "Floor",
		size = HubConfig.FLOOR_SIZE,
		position = Vector3.new(0, floorY, 0),
		color = Color3.fromRGB(38, 42, 52),
		material = Enum.Material.Slate,
	})

	local halfX = HubConfig.FLOOR_SIZE.X * 0.5
	local halfZ = HubConfig.FLOOR_SIZE.Z * 0.5
	local wallH = HubConfig.WALL_HEIGHT
	local wallY = floorY + wallH * 0.5

	local walls = {
		{ Vector3.new(0, wallY, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 2) },
		{ Vector3.new(0, wallY, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 2) },
		{ Vector3.new(-halfX, wallY, 0), Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(halfX, wallY, 0), Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z) },
	}
	for i, wall in walls do
		makePart({
			parent = hub,
			name = "Wall" .. i,
			size = wall[2],
			position = wall[1],
			color = Color3.fromRGB(28, 30, 38),
			material = Enum.Material.Concrete,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.CanCollide = false
	spawn.Transparency = 0.5
	spawn.BrickColor = BrickColor.new("Bright blue")
	spawn.Parent = hub

	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = hub

	for _, zone in HubConfig.ZONES do
		makeZoneMarker(zones, zone)
	end

	HubWorldBuilder.buildLeaderboardBoard(hub, {})
	return hub
end

return HubWorldBuilder
