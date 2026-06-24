local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Color = props.color or Color3.fromRGB(40, 44, 58)
	part.Size = props.size
	part.CFrame = props.cframe
	part.Name = props.name or "Part"
	part.Transparency = props.transparency or 0
	part.Parent = props.parent
	return part
end

local function addSign(parent, text, color, offsetY)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, offsetY or 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.5
	label.TextSize = 20
	label.Text = text
	label.Parent = billboard
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_NAME
	hub.Parent = workspace

	local floorY = 0
	local floorSize = HubConfig.FLOOR_SIZE

	makePart({
		name = "Floor",
		parent = hub,
		size = floorSize,
		cframe = CFrame.new(0, floorY - floorSize.Y / 2, 0),
		color = Color3.fromRGB(32, 36, 48),
		material = Enum.Material.Slate,
	})

	makePart({
		name = "FloorAccent",
		parent = hub,
		size = Vector3.new(floorSize.X - 8, 0.2, floorSize.Z - 8),
		cframe = CFrame.new(0, floorY + 0.1, 0),
		color = Color3.fromRGB(50, 56, 72),
		material = Enum.Material.Neon,
		canCollide = false,
	})

	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS
	local wallY = floorY + wallH / 2

	local walls = {
		{ Vector3.new(0, wallY, -halfZ), Vector3.new(floorSize.X, wallH, wallT) },
		{ Vector3.new(0, wallY, halfZ), Vector3.new(floorSize.X, wallH, wallT) },
		{ Vector3.new(-halfX, wallY, 0), Vector3.new(wallT, wallH, floorSize.Z) },
		{ Vector3.new(halfX, wallY, 0), Vector3.new(wallT, wallH, floorSize.Z) },
	}
	for i, wall in walls do
		makePart({
			name = "Wall" .. i,
			parent = hub,
			size = wall[2],
			cframe = CFrame.new(wall[1]),
			color = Color3.fromRGB(24, 28, 38),
			material = Enum.Material.Concrete,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN_POSITION - Vector3.new(0, 3, 0))
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for zoneKey, zone in HubConfig.ZONES do
		local zoneFolder = Instance.new("Folder")
		zoneFolder.Name = zoneKey
		zoneFolder.Parent = zonesFolder

		local pad = makePart({
			name = "Pad",
			parent = zoneFolder,
			size = Vector3.new(zone.size.X, 0.4, zone.size.Z),
			cframe = CFrame.new(zone.position + Vector3.new(0, 0.2, 0)),
			color = zone.color,
			material = Enum.Material.Neon,
			canCollide = false,
		})
		pad.Transparency = 0.35

		local pillar = makePart({
			name = "Pillar",
			parent = zoneFolder,
			size = Vector3.new(3, zone.size.Y, 3),
			cframe = CFrame.new(zone.position + Vector3.new(0, zone.size.Y / 2, 0)),
			color = zone.color,
			material = Enum.Material.Metal,
		})

		addSign(pillar, zone.name, zone.color, zone.size.Y / 2 + 2)

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ZonePrompt"
		prompt.ActionText = zone.hint
		prompt.ObjectText = zone.name
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("ZoneId", zone.id)
		prompt:SetAttribute("ZoneAction", zone.action)
		prompt.Parent = pillar

		local trigger = makePart({
			name = "Trigger",
			parent = zoneFolder,
			size = Vector3.new(zone.size.X, zone.size.Y, zone.size.Z),
			cframe = CFrame.new(zone.position + Vector3.new(0, zone.size.Y / 2, 0)),
			transparency = 1,
			canCollide = false,
		})
		trigger:SetAttribute("ZoneId", zone.id)
	end

	return hub
end

return HubWorldBuilder
