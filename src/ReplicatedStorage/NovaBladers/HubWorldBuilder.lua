local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.fromRGB(50, 55, 70)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Transparency = props.transparency or 0
	part.Name = props.name
	part.Parent = props.parent
	return part
end

local function addBillboard(part, title, subtitle)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ZoneLabel"
	gui.Size = UDim2.fromOffset(200, 80)
	gui.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 2, 0)
	gui.AlwaysOnTop = true
	gui.Parent = part

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0.5, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextScaled = true
	titleLabel.Text = title
	titleLabel.Parent = gui

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "Subtitle"
	subLabel.Size = UDim2.new(1, 0, 0.5, 0)
	subLabel.Position = UDim2.fromScale(0, 0.5)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
	subLabel.TextScaled = true
	subLabel.Text = subtitle
	subLabel.Parent = gui
end

local function addZonePrompt(part, zoneId, actionText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = actionText
	prompt.ObjectText = part.Name
	prompt.MaxActivationDistance = HubConfig.ZONE_TRIGGER_RADIUS
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ZoneId", zoneId)
	prompt.Parent = part
end

function HubWorldBuilder.getHubFolder()
	return workspace:FindFirstChild(HubConfig.HUB_NAME)
end

function HubWorldBuilder.build(origin)
	origin = origin or Vector3.zero

	local existing = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_NAME
	hub.Parent = workspace

	local floorY = origin.Y
	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2

	makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		cframe = CFrame.new(origin + Vector3.new(0, floorY - HubConfig.FLOOR_SIZE.Y / 2, 0)),
		color = Color3.fromRGB(35, 40, 55),
		material = Enum.Material.Slate,
	})

	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS
	local wallY = floorY + wallH / 2
	local wallColor = Color3.fromRGB(45, 50, 68)

	local walls = {
		{ name = "WallNorth", size = Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT), pos = Vector3.new(0, wallY, -halfZ - wallT / 2) },
		{ name = "WallSouth", size = Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT), pos = Vector3.new(0, wallY, halfZ + wallT / 2) },
		{ name = "WallWest", size = Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z), pos = Vector3.new(-halfX - wallT / 2, wallY, 0) },
		{ name = "WallEast", size = Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z), pos = Vector3.new(halfX + wallT / 2, wallY, 0) },
	}
	for _, wall in walls do
		makePart({
			name = wall.name,
			parent = hub,
			size = wall.size,
			cframe = CFrame.new(origin + wall.pos),
			color = wallColor,
			material = Enum.Material.Concrete,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(origin + HubConfig.SPAWN_OFFSET)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Transparency = 0.4
	spawn.Color = Color3.fromRGB(100, 180, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zonePart = makePart({
			name = zone.name,
			parent = zonesFolder,
			size = zone.size,
			cframe = CFrame.new(origin + zone.position + Vector3.new(0, zone.size.Y / 2, 0)),
			color = zone.color,
			material = Enum.Material.Neon,
			transparency = 0.35,
		})
		zonePart:SetAttribute("ZoneId", zone.id)
		zonePart:SetAttribute("ZoneAction", zone.action)
		addBillboard(zonePart, zone.name, zone.desc)
		addZonePrompt(zonePart, zone.id, "Öffnen")
	end

	local light = Instance.new("PointLight")
	light.Brightness = 1.5
	light.Range = 60
	light.Color = Color3.fromRGB(180, 200, 255)
	light.Parent = hub:FindFirstChild("Floor")

	return hub
end

function HubWorldBuilder.getSpawnCFrame()
	local hub = HubWorldBuilder.getHubFolder()
	if hub then
		local spawn = hub:FindFirstChild("HubSpawn")
		if spawn then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(HubConfig.SPAWN_OFFSET)
end

function HubWorldBuilder.findZonePart(zoneId)
	local hub = HubWorldBuilder.getHubFolder()
	if not hub then return nil end
	local zones = hub:FindFirstChild("Zones")
	if not zones then return nil end
	for _, part in zones:GetChildren() do
		if part:GetAttribute("ZoneId") == zoneId then
			return part
		end
	end
	return nil
end

return HubWorldBuilder
