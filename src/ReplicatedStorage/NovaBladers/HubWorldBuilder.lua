local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.fromRGB(60, 60, 60)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name
	part.Parent = props.parent
	return part
end

local function addBillboard(parent, text, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 50)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 22
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Text = text
	label.Parent = gui
end

local function buildZone(folder, zoneId, zone)
	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = zoneId
	zoneFolder.Parent = folder

	local platform = makePart({
		name = "Platform",
		parent = zoneFolder,
		size = zone.size,
		cframe = CFrame.new(zone.position),
		color = zone.color,
		material = Enum.Material.Neon,
	})
	platform.Transparency = 0.35

	local pillar = makePart({
		name = "Sign",
		parent = zoneFolder,
		size = Vector3.new(1.5, 6, 1.5),
		cframe = CFrame.new(zone.position + Vector3.new(0, 3.5, 0)),
		color = zone.color,
		material = Enum.Material.Metal,
	})
	addBillboard(pillar, zone.label, zone.color)

	local trigger = makePart({
		name = "Trigger",
		parent = zoneFolder,
		size = zone.size + Vector3.new(4, 8, 4),
		cframe = CFrame.new(zone.position + Vector3.new(0, 4, 0)),
		color = zone.color,
		canCollide = false,
	})
	trigger.Transparency = 1

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = zone.promptAction
	prompt.ObjectText = zone.promptObject
	prompt.MaxActivationDistance = 12
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = trigger

	local marker = Instance.new("StringValue")
	marker.Name = "ZoneId"
	marker.Value = zoneId
	marker.Parent = zoneFolder
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.FOLDER_NAME
	hub.Parent = workspace

	local half = HubConfig.FLOOR_SIZE / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS

	makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		cframe = CFrame.new(0, 0, 0),
		color = HubConfig.COLORS.Floor,
		material = Enum.Material.Slate,
	})

	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = hub

	local wallDefs = {
		{ name = "North", size = Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT), pos = Vector3.new(0, wallH / 2, -half.Z - wallT / 2) },
		{ name = "South", size = Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT), pos = Vector3.new(0, wallH / 2, half.Z + wallT / 2) },
		{ name = "East", size = Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z), pos = Vector3.new(half.X + wallT / 2, wallH / 2, 0) },
		{ name = "West", size = Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z), pos = Vector3.new(-half.X - wallT / 2, wallH / 2, 0) },
	}

	for _, def in wallDefs do
		makePart({
			name = def.name,
			parent = walls,
			size = def.size,
			cframe = CFrame.new(def.pos),
			color = HubConfig.COLORS.Wall,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = HubConfig.SPAWN_CFRAME
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = hub

	for zoneId, zone in HubConfig.ZONES do
		buildZone(zones, zoneId, zone)
	end

	local lighting = Instance.new("PointLight")
	lighting.Brightness = 2
	lighting.Range = 40
	lighting.Parent = spawn

	return hub
end

return HubWorldBuilder
