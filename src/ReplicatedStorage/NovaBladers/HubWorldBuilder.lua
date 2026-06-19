local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Color = props.color or Color3.fromRGB(60, 60, 70)
	part.Size = props.size
	part.CFrame = props.cframe
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function addLabel(part, text, subtext)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(180, 64)
	billboard.StudsOffset = Vector3.new(0, part.Size.Y * 0.75 + 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0.55, 0)
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0.4
	title.TextSize = 20
	title.Text = text
	title.Parent = billboard

	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.fromScale(0, 0.55)
	hint.Size = UDim2.new(1, 0, 0.45, 0)
	hint.Font = Enum.Font.Gotham
	hint.TextColor3 = Color3.fromRGB(220, 220, 230)
	hint.TextStrokeTransparency = 0.5
	hint.TextSize = 14
	hint.Text = subtext or ""
	hint.Parent = billboard
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	local floorY = HubConfig.FLOOR_SIZE.Y * 0.5
	local floor = makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		cframe = CFrame.new(0, floorY, 0),
		color = HubConfig.FLOOR_COLOR,
		material = Enum.Material.Slate,
	})

	local halfX = HubConfig.FLOOR_SIZE.X * 0.5
	local halfZ = HubConfig.FLOOR_SIZE.Z * 0.5
	local wallY = floorY + HubConfig.WALL_HEIGHT * 0.5
	local wallColor = Color3.fromRGB(40, 44, 58)

	local walls = {
		{ size = Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, HubConfig.WALL_THICKNESS), pos = Vector3.new(0, wallY, halfZ) },
		{ size = Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, HubConfig.WALL_THICKNESS), pos = Vector3.new(0, wallY, -halfZ) },
		{ size = Vector3.new(HubConfig.WALL_THICKNESS, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), pos = Vector3.new(halfX, wallY, 0) },
		{ size = Vector3.new(HubConfig.WALL_THICKNESS, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), pos = Vector3.new(-halfX, wallY, 0) },
	}

	local wallsFolder = Instance.new("Folder")
	wallsFolder.Name = "Walls"
	wallsFolder.Parent = hub

	for index, wall in walls do
		makePart({
			name = "Wall" .. index,
			parent = wallsFolder,
			size = wall.size,
			cframe = CFrame.new(wall.pos),
			color = wallColor,
			material = Enum.Material.Concrete,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.CFrame = CFrame.new(HubConfig.SPAWN_OFFSET + Vector3.new(0, floorY + 0.5, 0))
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for zoneId, zone in HubConfig.ZONES do
		local marker = makePart({
			name = zoneId,
			parent = zonesFolder,
			size = zone.size,
			cframe = CFrame.new(zone.position + Vector3.new(0, floorY, 0)),
			color = zone.color,
			material = Enum.Material.Neon,
			canCollide = false,
		})
		marker.Transparency = 0.35

		addLabel(marker, zone.label, zone.hint)

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ZonePrompt"
		prompt.ActionText = zone.hint
		prompt.ObjectText = zone.label
		prompt.HoldDuration = zone.holdDuration or 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("ZoneId", zoneId)
		prompt.Parent = marker
	end

	local lighting = Instance.new("PointLight")
	lighting.Brightness = 1.2
	lighting.Range = 40
	lighting.Parent = floor

	return hub, spawn
end

return HubWorldBuilder
