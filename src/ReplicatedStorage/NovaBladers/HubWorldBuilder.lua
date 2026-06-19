local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.Position = props.position
	part.Color = props.color or Color3.fromRGB(60, 65, 80)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	if props.transparency then
		part.Transparency = props.transparency
	end
	return part
end

local function addBillboard(parent, title, subtitle, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 80)
	gui.StudsOffset = Vector3.new(0, 6, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -8, 0.55, 0)
	titleLabel.Position = UDim2.fromOffset(4, 2)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 18
	titleLabel.TextColor3 = color
	titleLabel.Text = title
	titleLabel.Parent = frame

	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, -8, 0.4, 0)
	subLabel.Position = UDim2.new(0, 4, 0.55, 0)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextSize = 13
	subLabel.TextColor3 = Color3.fromRGB(200, 205, 220)
	subLabel.Text = subtitle
	subLabel.Parent = frame
end

local function addProximityPrompt(part, action, label)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = label
	prompt.ObjectText = "Nova Hub"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("HubAction", action)
	prompt.Parent = part
	return prompt
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_NAME
	hub.Parent = workspace

	local floor = makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		position = Vector3.new(0, HubConfig.FLOOR_SIZE.Y / 2, 0),
		color = Color3.fromRGB(45, 50, 65),
		material = Enum.Material.Slate,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_OFFSET
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS
	local wallY = wallH / 2 + HubConfig.FLOOR_SIZE.Y

	local walls = {
		{ name = "WallNorth", pos = Vector3.new(0, wallY, -halfZ), size = Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT) },
		{ name = "WallSouth", pos = Vector3.new(0, wallY, halfZ), size = Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT) },
		{ name = "WallEast", pos = Vector3.new(halfX, wallY, 0), size = Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ name = "WallWest", pos = Vector3.new(-halfX, wallY, 0), size = Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
	}

	for _, wall in walls do
		makePart({
			name = wall.name,
			parent = hub,
			size = wall.size,
			position = wall.pos,
			color = Color3.fromRGB(35, 38, 50),
			material = Enum.Material.Concrete,
		})
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zoneY = zone.size.Y / 2 + HubConfig.FLOOR_SIZE.Y
		local zonePart = makePart({
			name = zone.id,
			parent = zonesFolder,
			size = zone.size,
			position = zone.position + Vector3.new(0, zoneY, 0),
			color = zone.color,
			material = Enum.Material.Neon,
			transparency = 0.55,
			canCollide = false,
		})
		zonePart:SetAttribute("HubZone", zone.id)
		zonePart:SetAttribute("HubAction", zone.action)

		addBillboard(zonePart, zone.label, zone.hint, zone.color)
		addProximityPrompt(zonePart, zone.action, zone.label)
	end

	-- Ambient ceiling light disc
	makePart({
		name = "CeilingLight",
		parent = hub,
		size = Vector3.new(40, 0.5, 40),
		position = Vector3.new(0, wallH - 1, 0),
		color = Color3.fromRGB(180, 200, 255),
		material = Enum.Material.Neon,
		transparency = 0.7,
		canCollide = false,
	})

	return hub
end

return HubWorldBuilder
