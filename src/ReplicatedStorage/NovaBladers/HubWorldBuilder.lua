local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function createPart(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

local function createLabel(parent, title, subtitle)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 70)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextStrokeTransparency = 0.4
	titleLabel.TextSize = 22
	titleLabel.Text = title
	titleLabel.Parent = billboard

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "Subtitle"
	subLabel.Position = UDim2.fromScale(0, 0.55)
	subLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	subLabel.TextStrokeTransparency = 0.5
	subLabel.TextSize = 16
	subLabel.Text = subtitle
	subLabel.Parent = billboard
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.ROOT_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.ROOT_NAME
	hub.Parent = workspace

	local floorCenter = HubConfig.FLOOR_CENTER
	local floorSize = HubConfig.FLOOR_SIZE

	createPart(
		hub,
		"Floor",
		floorSize,
		CFrame.new(floorCenter),
		Color3.fromRGB(35, 38, 48),
		Enum.Material.Slate
	)

	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local wallY = floorCenter.Y + HubConfig.WALL_HEIGHT / 2
	local wallH = Vector3.new(HubConfig.WALL_THICKNESS, HubConfig.WALL_HEIGHT, floorSize.Z + HubConfig.WALL_THICKNESS)
	local wallV = Vector3.new(floorSize.X + HubConfig.WALL_THICKNESS, HubConfig.WALL_HEIGHT, HubConfig.WALL_THICKNESS)
	local wallColor = Color3.fromRGB(50, 55, 68)

	createPart(hub, "WallLeft", wallH, CFrame.new(floorCenter.X - halfX, wallY, floorCenter.Z), wallColor)
	createPart(hub, "WallRight", wallH, CFrame.new(floorCenter.X + halfX, wallY, floorCenter.Z), wallColor)
	createPart(hub, "WallBack", wallV, CFrame.new(floorCenter.X, wallY, floorCenter.Z - halfZ), wallColor)
	createPart(hub, "WallFront", wallV, CFrame.new(floorCenter.X, wallY, floorCenter.Z + halfZ), wallColor)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(floorCenter + HubConfig.SPAWN_OFFSET)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zonePart = createPart(
			zonesFolder,
			zone.id,
			zone.size,
			CFrame.new(zone.position),
			zone.color,
			Enum.Material.Neon
		)
		zonePart.Transparency = 0.35
		zonePart.CanCollide = false
		zonePart:SetAttribute("ZoneAction", zone.action)
		createLabel(zonePart, zone.name, zone.subtitle)

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ZonePrompt"
		prompt.ActionText = zone.promptText
		prompt.ObjectText = zone.name
		prompt.MaxActivationDistance = HubConfig.PROMPT_MAX_DISTANCE
		prompt.HoldDuration = HubConfig.PROMPT_HOLD
		prompt.RequiresLineOfSight = false
		prompt.Parent = zonePart
	end

	return hub
end

return HubWorldBuilder
