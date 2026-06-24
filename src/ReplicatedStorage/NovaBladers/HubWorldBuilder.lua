local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function createPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.fromRGB(60, 60, 70)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function createLabel(parent, text, offset)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160, 40)
	billboard.StudsOffset = offset or Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 18
	label.Text = text
	label.Parent = billboard
end

local function createZone(parent, zoneId, zoneConfig, origin)
	local zone = createPart({
		name = zoneId,
		parent = parent,
		size = zoneConfig.size,
		cframe = CFrame.new(origin + zoneConfig.offset),
		color = zoneConfig.color,
		material = Enum.Material.Neon,
	})
	zone.Transparency = 0.35
	zone:SetAttribute("ZoneId", zoneId)
	zone:SetAttribute("HubZone", true)

	createLabel(zone, zoneConfig.label, Vector3.new(0, 3.5, 0))

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = zoneConfig.label
	prompt.ActionText = zoneConfig.prompt
	prompt.KeyboardKeyCode = zoneConfig.promptKey
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 0
	prompt.Parent = zone

	return zone
end

function HubWorldBuilder.build(origin)
	origin = origin or HubConfig.ORIGIN

	local existing = workspace:FindFirstChild("NovaBladersHub")
	if existing then
		return existing
	end

	local hub = Instance.new("Model")
	hub.Name = "NovaBladersHub"

	local floor = createPart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR.size,
		cframe = CFrame.new(origin),
		color = HubConfig.FLOOR.color,
		material = HubConfig.FLOOR.material,
	})

	local halfX = HubConfig.FLOOR.size.X / 2
	local halfZ = HubConfig.FLOOR.size.Z / 2
	local wallY = origin.Y + HubConfig.WALL_HEIGHT / 2

	for _, wall in {
		{ Vector3.new(0, 0, -halfZ), Vector3.new(HubConfig.FLOOR.size.X, HubConfig.WALL_HEIGHT, 1) },
		{ Vector3.new(0, 0, halfZ), Vector3.new(HubConfig.FLOOR.size.X, HubConfig.WALL_HEIGHT, 1) },
		{ Vector3.new(-halfX, 0, 0), Vector3.new(1, HubConfig.WALL_HEIGHT, HubConfig.FLOOR.size.Z) },
		{ Vector3.new(halfX, 0, 0), Vector3.new(1, HubConfig.WALL_HEIGHT, HubConfig.FLOOR.size.Z) },
	} do
		local wallPart = createPart({
			name = "Wall",
			parent = hub,
			size = wall[2],
			cframe = CFrame.new(origin + wall[1] + Vector3.new(0, HubConfig.WALL_HEIGHT / 2, 0)),
			color = Color3.fromRGB(25, 28, 38),
			material = Enum.Material.Concrete,
		})
		wallPart.Transparency = 0.15
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(origin + HubConfig.SPAWN_OFFSET)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for zoneId, zoneConfig in HubConfig.ZONES do
		createZone(zonesFolder, zoneId, zoneConfig, origin)
	end

	hub.PrimaryPart = floor
	hub:SetAttribute("HubOrigin", origin)
	hub.Parent = workspace

	return hub
end

function HubWorldBuilder.getSpawnCFrame(hub)
	local spawn = hub:FindFirstChild("HubSpawn")
	if spawn then
		return spawn.CFrame + Vector3.new(0, 2, 0)
	end
	return CFrame.new(HubConfig.ORIGIN + HubConfig.SPAWN_OFFSET)
end

return HubWorldBuilder
