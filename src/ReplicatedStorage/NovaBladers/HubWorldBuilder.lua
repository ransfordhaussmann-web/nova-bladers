local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function createPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.Position = props.position
	part.Color = props.color or Color3.fromRGB(60, 65, 80)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function createZoneMarker(parent, zoneDef)
	local marker = createPart({
		name = zoneDef.id,
		parent = parent,
		size = zoneDef.size,
		position = zoneDef.position,
		color = zoneDef.color,
		material = Enum.Material.Neon,
	})
	marker.Transparency = 0.35
	marker.CanCollide = false

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, zoneDef.size.Y * 0.5 + 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = marker

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0.5
	title.TextSize = 20
	title.Text = zoneDef.label
	title.Parent = billboard

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zoneDef.hint
	prompt.ObjectText = zoneDef.label
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("HubAction", zoneDef.action)
	prompt.Parent = marker

	return marker
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	local floor = createPart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		position = Vector3.new(0, 0, 0),
		color = Color3.fromRGB(45, 50, 65),
		material = Enum.Material.Slate,
	})

	local halfX = HubConfig.FLOOR_SIZE.X * 0.5
	local halfZ = HubConfig.FLOOR_SIZE.Z * 0.5
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS

	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = hub

	local wallDefs = {
		{ Vector3.new(0, wallH * 0.5, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X + wallT, wallH, wallT) },
		{ Vector3.new(0, wallH * 0.5, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X + wallT, wallH, wallT) },
		{ Vector3.new(-halfX, wallH * 0.5, 0), Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(halfX, wallH * 0.5, 0), Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
	}
	for i, def in wallDefs do
		createPart({
			name = "Wall" .. i,
			parent = walls,
			position = def[1],
			size = def[2],
			color = Color3.fromRGB(35, 38, 50),
			material = Enum.Material.Concrete,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = HubConfig.SPAWN_POSITION
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hub

	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = hub

	for _, zoneDef in HubConfig.ZONES do
		createZoneMarker(zones, zoneDef)
	end

	local centerLight = Instance.new("PointLight")
	centerLight.Brightness = 1.2
	centerLight.Range = 80
	centerLight.Parent = floor

	return hub
end

return HubWorldBuilder
