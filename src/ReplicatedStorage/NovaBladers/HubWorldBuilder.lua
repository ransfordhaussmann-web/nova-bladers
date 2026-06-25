local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.Position = props.Position
	part.Color = props.Color or Color3.fromRGB(200, 200, 200)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Transparency = props.Transparency or 0
	part.Name = props.Name or "Part"
	part.Parent = props.Parent
	return part
end

local function addBillboard(parent, title, subtitle, color)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ZoneLabel"
	gui.Size = UDim2.fromOffset(200, 70)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 20
	titleLabel.TextColor3 = color
	titleLabel.Text = title
	titleLabel.Parent = gui

	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subLabel.Position = UDim2.fromScale(0, 0.55)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextSize = 14
	subLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	subLabel.Text = subtitle
	subLabel.Parent = gui
end

local function addProximityPrompt(parent, actionText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = HubConfig.PROMPT.ActionText
	prompt.ObjectText = actionText
	prompt.MaxActivationDistance = HubConfig.PROMPT.MaxActivationDistance
	prompt.HoldDuration = HubConfig.PROMPT.HoldDuration
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

local function buildWalls(parent, floorSize, floorPos, wallHeight, thickness, color)
	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local y = floorPos.Y + wallHeight / 2

	local walls = {
		{ name = "WallNorth", size = Vector3.new(floorSize.X + thickness * 2, wallHeight, thickness), pos = Vector3.new(floorPos.X, y, floorPos.Z + halfZ + thickness / 2) },
		{ name = "WallSouth", size = Vector3.new(floorSize.X + thickness * 2, wallHeight, thickness), pos = Vector3.new(floorPos.X, y, floorPos.Z - halfZ - thickness / 2) },
		{ name = "WallEast", size = Vector3.new(thickness, wallHeight, floorSize.Z), pos = Vector3.new(floorPos.X + halfX + thickness / 2, y, floorPos.Z) },
		{ name = "WallWest", size = Vector3.new(thickness, wallHeight, floorSize.Z), pos = Vector3.new(floorPos.X - halfX - thickness / 2, y, floorPos.Z) },
	}

	local folder = Instance.new("Folder")
	folder.Name = "Walls"
	folder.Parent = parent

	for _, wall in walls do
		makePart({
			Name = wall.name,
			Size = wall.size,
			Position = wall.pos,
			Color = color,
			Material = Enum.Material.Concrete,
			Parent = folder,
		})
	end
end

local function buildZone(parent, zoneConfig)
	local zonePart = makePart({
		Name = zoneConfig.id,
		Size = zoneConfig.size,
		Position = zoneConfig.position,
		Color = zoneConfig.color,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		Parent = parent,
	})
	zonePart:SetAttribute("HubAction", zoneConfig.action)

	local light = Instance.new("PointLight")
	light.Color = zoneConfig.lightColor
	light.Brightness = 1.2
	light.Range = 18
	light.Parent = zonePart

	addBillboard(zonePart, zoneConfig.label, zoneConfig.hint, zoneConfig.lightColor)
	local prompt = addProximityPrompt(zonePart, zoneConfig.label)
	prompt:SetAttribute("HubAction", zoneConfig.action)

	return zonePart
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Model")
	hub.Name = HubConfig.HUB_NAME

	makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = HubConfig.FLOOR_POSITION,
		Color = HubConfig.FLOOR_COLOR,
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	buildWalls(hub, HubConfig.FLOOR_SIZE, HubConfig.FLOOR_POSITION, HubConfig.WALL_HEIGHT, HubConfig.WALL_THICKNESS, HubConfig.WALL_COLOR)

	local spawn = makePart({
		Name = HubConfig.SPAWN_NAME,
		Size = Vector3.new(6, 1, 6),
		Position = HubConfig.FLOOR_POSITION + HubConfig.SPAWN_OFFSET,
		Color = Color3.fromRGB(100, 180, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.6,
		CanCollide = false,
		Parent = hub,
	})

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zoneConfig in HubConfig.ZONES do
		buildZone(zonesFolder, zoneConfig)
	end

	hub.PrimaryPart = spawn
	hub.Parent = workspace
	return hub
end

function HubWorldBuilder.getSpawnCFrame()
	local hub = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if hub and hub:FindFirstChild(HubConfig.SPAWN_NAME) then
		local spawn = hub[HubConfig.SPAWN_NAME]
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubConfig.FLOOR_POSITION + HubConfig.SPAWN_OFFSET + Vector3.new(0, 3, 0))
end

return HubWorldBuilder
