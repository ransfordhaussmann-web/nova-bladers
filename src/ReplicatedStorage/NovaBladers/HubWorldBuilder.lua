local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = CFrame.new(props.position)
	part.Color = props.color or Color3.fromRGB(60, 60, 60)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function makeSign(parent, text, position, color)
	local sign = makePart({
		name = "Sign",
		parent = parent,
		size = Vector3.new(10, 4, 0.4),
		position = position + Vector3.new(0, 6, 0),
		color = color,
		canCollide = false,
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

local function makeZone(folder, zoneId, zone, origin)
	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = zoneId
	zoneFolder.Parent = folder

	local worldPos = origin + zone.position
	local platform = makePart({
		name = "Platform",
		parent = zoneFolder,
		size = Vector3.new(zone.size.X, 1, zone.size.Z),
		position = worldPos + Vector3.new(0, 0.5, 0),
		color = zone.color,
		material = Enum.Material.Neon,
	})

	local trigger = makePart({
		name = "Trigger",
		parent = zoneFolder,
		size = Vector3.new(zone.size.X, 8, zone.size.Z),
		position = worldPos + Vector3.new(0, 4, 0),
		color = zone.color,
		canCollide = false,
	})
	trigger.Transparency = 1

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = zone.promptText
	prompt.ObjectText = zone.name
	prompt.MaxActivationDistance = 12
	prompt.HoldDuration = 0
	prompt.Parent = trigger

	makeSign(zoneFolder, zone.name, worldPos, zone.color)

	return zoneFolder, trigger
end

function HubWorldBuilder.build()
	local origin = HubConfig.ORIGIN
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER
	hub.Parent = workspace

	local floor = makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		position = origin + Vector3.new(0, 0, 0),
		color = HubConfig.FLOOR_COLOR,
		material = Enum.Material.Slate,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT

	local walls = {
		{ Vector3.new(0, wallH / 2, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 2) },
		{ Vector3.new(0, wallH / 2, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 2) },
		{ Vector3.new(halfX, wallH / 2, 0), Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(-halfX, wallH / 2, 0), Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z) },
	}
	for i, wall in walls do
		makePart({
			name = "Wall" .. i,
			parent = hub,
			size = wall[2],
			position = origin + wall[1],
			color = HubConfig.WALL_COLOR,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = origin + HubConfig.SPAWN_OFFSET
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	local zones = {}
	for zoneId, zone in HubConfig.ZONES do
		local folder, trigger = makeZone(zonesFolder, zoneId, zone, origin)
		zones[zoneId] = { folder = folder, trigger = trigger, config = zone }
	end

	local boardPos = origin + Vector3.new(0, 0, -30)
	local board = makePart({
		name = "HallOfFameBoard",
		parent = hub,
		size = Vector3.new(16, 10, 1),
		position = boardPos + Vector3.new(0, 5, 0),
		color = HubConfig.ACCENT_COLOR,
		canCollide = false,
	})

	local boardGui = Instance.new("SurfaceGui")
	boardGui.Face = Enum.NormalId.Front
	boardGui.Parent = board

	local boardLabel = Instance.new("TextLabel")
	boardLabel.Name = "LeaderboardText"
	boardLabel.Size = UDim2.fromScale(1, 1)
	boardLabel.BackgroundTransparency = 1
	boardLabel.Text = "🏆 Ruhmeshalle\nLade..."
	boardLabel.TextColor3 = Color3.new(1, 1, 1)
	boardLabel.TextScaled = true
	boardLabel.Font = Enum.Font.GothamBold
	boardLabel.Parent = boardGui

	return {
		hub = hub,
		spawn = spawn,
		zones = zones,
		leaderboardLabel = boardLabel,
		origin = origin,
	}
end

return HubWorldBuilder
