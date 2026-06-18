local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.fromRGB(60, 65, 80)
	part.Material = props.material or Enum.Material.Concrete
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function addZoneLabel(parent, zone)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, zone.size.Y / 2 + 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Text = zone.name
	label.Parent = billboard
end

local function addProximityPrompt(parent, zone)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zone.prompt
	prompt.ObjectText = zone.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ZoneAction", zone.action)
	prompt:SetAttribute("ZoneId", zone.id)
	prompt.Parent = parent
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Model")
	hub.Name = HubConfig.HUB_NAME
	hub.Parent = workspace

	local floorY = HubConfig.SPAWN_POSITION.Y - 2.5
	local floorCenter = Vector3.new(0, floorY, 0)

	makePart({
		name = "Floor",
		size = HubConfig.FLOOR_SIZE,
		cframe = CFrame.new(floorCenter),
		color = Color3.fromRGB(45, 50, 65),
		material = Enum.Material.Slate,
		parent = hub,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local t = HubConfig.WALL_THICKNESS

	local walls = {
		{ name = "WallNorth", size = Vector3.new(HubConfig.FLOOR_SIZE.X + t * 2, wallH, t), pos = Vector3.new(0, floorY + wallH / 2, -halfZ - t / 2) },
		{ name = "WallSouth", size = Vector3.new(HubConfig.FLOOR_SIZE.X + t * 2, wallH, t), pos = Vector3.new(0, floorY + wallH / 2, halfZ + t / 2) },
		{ name = "WallWest", size = Vector3.new(t, wallH, HubConfig.FLOOR_SIZE.Z), pos = Vector3.new(-halfX - t / 2, floorY + wallH / 2, 0) },
		{ name = "WallEast", size = Vector3.new(t, wallH, HubConfig.FLOOR_SIZE.Z), pos = Vector3.new(halfX + t / 2, floorY + wallH / 2, 0) },
	}

	for _, wall in walls do
		makePart({
			name = wall.name,
			size = wall.size,
			cframe = CFrame.new(wall.pos),
			color = Color3.fromRGB(35, 38, 50),
			material = Enum.Material.Brick,
			parent = hub,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 0.4
	spawn.BrickColor = BrickColor.new("Bright blue")
	spawn.Neutral = true
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zonePart = makePart({
			name = zone.id,
			size = zone.size,
			cframe = CFrame.new(floorCenter + zone.position + Vector3.new(0, zone.size.Y / 2, 0)),
			color = zone.color,
			material = Enum.Material.Neon,
			parent = zonesFolder,
		})
		zonePart.Transparency = 0.35
		addZoneLabel(zonePart, zone)
		addProximityPrompt(zonePart, zone)
	end

	hub.PrimaryPart = hub:FindFirstChild("Floor")
	return hub
end

return HubWorldBuilder
