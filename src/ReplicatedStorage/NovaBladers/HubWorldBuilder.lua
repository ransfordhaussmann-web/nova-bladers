local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function createPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.Position = props.position
	part.Color = props.color or Color3.fromRGB(45, 50, 65)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	if props.transparency then
		part.Transparency = props.transparency
	end
	part.Parent = props.parent
	return part
end

local function addBillboard(parent, title, subtitle, color)
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, parent.Size.Y / 2 + 2, 0)
	attachment.Parent = parent

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 70)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = attachment

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 18
	titleLabel.TextColor3 = color
	titleLabel.Text = title
	titleLabel.Parent = billboard

	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subLabel.Position = UDim2.fromScale(0, 0.55)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextSize = 13
	subLabel.TextColor3 = Color3.fromRGB(200, 205, 220)
	subLabel.Text = subtitle
	subLabel.Parent = billboard
end

local function buildZone(parent, zone)
	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = zone.id
	zoneFolder.Parent = parent

	local platform = createPart({
		name = "Platform",
		parent = zoneFolder,
		size = zone.size,
		position = zone.position + Vector3.new(0, zone.size.Y / 2, 0),
		color = zone.color,
		material = Enum.Material.Neon,
	})

	local marker = createPart({
		name = "Marker",
		parent = zoneFolder,
		size = zone.markerSize,
		position = zone.position + Vector3.new(0, zone.markerSize.Y / 2 + zone.size.Y, 0),
		color = zone.color,
		material = Enum.Material.Glass,
		canCollide = false,
	})
	marker.Transparency = 0.35

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zone.name
	prompt.ObjectText = "Nova Bladers"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = HubConfig.INTERACT_RANGE
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = marker

	addBillboard(marker, zone.name, zone.hint, zone.color)

	local attr = Instance.new("StringValue")
	attr.Name = "ZoneId"
	attr.Value = zone.id
	attr.Parent = zoneFolder

	return zoneFolder
end

function HubWorldBuilder.build(workspace)
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER
	hub.Parent = workspace

	local floorY = 0
	local floor = createPart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		position = Vector3.new(0, floorY - HubConfig.FLOOR_SIZE.Y / 2, 0),
		color = Color3.fromRGB(35, 38, 48),
		material = Enum.Material.Slate,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = hub

	local wallDefs = {
		{ name = "NorthWall", pos = Vector3.new(0, wallH / 2, -halfZ), size = Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 2) },
		{ name = "SouthWall", pos = Vector3.new(0, wallH / 2, halfZ), size = Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 2) },
		{ name = "EastWall", pos = Vector3.new(halfX, wallH / 2, 0), size = Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ name = "WestWall", pos = Vector3.new(-halfX, wallH / 2, 0), size = Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z) },
	}
	for _, def in wallDefs do
		createPart({
			name = def.name,
			parent = walls,
			size = def.size,
			position = def.pos,
			color = Color3.fromRGB(55, 60, 75),
			material = Enum.Material.Concrete,
		})
	end

	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = hub
	for _, zone in HubConfig.ZONES do
		buildZone(zones, zone)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION - Vector3.new(0, 0.5, 0)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 0.5
	spawn.BrickColor = BrickColor.new("Bright blue")
	spawn.Neutral = true
	spawn.Parent = hub

	local centerSign = createPart({
		name = "WelcomeSign",
		parent = hub,
		size = Vector3.new(12, 0.5, 4),
		position = Vector3.new(0, 0.25, 10),
		color = Color3.fromRGB(25, 28, 38),
		material = Enum.Material.Metal,
		canCollide = false,
	})
	addBillboard(centerSign, "Nova Bladers", "Wähle eine Zone und drücke E", Color3.fromRGB(120, 200, 255))

	local lighting = game:GetService("Lighting")
	lighting.Ambient = Color3.fromRGB(55, 60, 75)
	lighting.OutdoorAmbient = Color3.fromRGB(70, 75, 90)
	lighting.Brightness = 2.2
	lighting.ClockTime = 15.5

	return hub
end

return HubWorldBuilder
