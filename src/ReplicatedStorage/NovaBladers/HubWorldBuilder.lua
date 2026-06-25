local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Color = props.color or Color3.fromRGB(45, 48, 58)
	part.Size = props.size
	part.CFrame = props.cframe
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function makeSign(parent, text, position, color)
	local sign = makePart({
		parent = parent,
		name = "Sign",
		size = Vector3.new(10, 3, 0.4),
		cframe = CFrame.new(position) * CFrame.Angles(0, 0, 0),
		color = Color3.fromRGB(30, 32, 40),
		canCollide = false,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	return sign
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local origin = HubConfig.HUB_ORIGIN

	makePart({
		parent = hub,
		name = "Floor",
		size = HubConfig.FLOOR_SIZE,
		cframe = CFrame.new(origin + Vector3.new(0, -0.5, 0)),
		color = Color3.fromRGB(38, 42, 52),
		material = Enum.Material.Slate,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local t = HubConfig.WALL_THICKNESS

	local walls = {
		{ Vector3.new(0, wallH / 2, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X + t, wallH, t) },
		{ Vector3.new(0, wallH / 2, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X + t, wallH, t) },
		{ Vector3.new(-halfX, wallH / 2, 0), Vector3.new(t, wallH, HubConfig.FLOOR_SIZE.Z + t) },
		{ Vector3.new(halfX, wallH / 2, 0), Vector3.new(t, wallH, HubConfig.FLOOR_SIZE.Z + t) },
	}

	for i, wall in walls do
		makePart({
			parent = hub,
			name = "Wall" .. i,
			size = wall[2],
			cframe = CFrame.new(origin + wall[1]),
			color = Color3.fromRGB(28, 30, 38),
		})
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zonePart = makePart({
			parent = zonesFolder,
			name = zone.id,
			size = zone.size,
			cframe = CFrame.new(origin + zone.position),
			color = zone.color,
			material = Enum.Material.Neon,
			canCollide = true,
		})
		zonePart.Transparency = 0.35

		local marker = Instance.new("Part")
		marker.Name = "Marker"
		marker.Anchored = true
		marker.CanCollide = false
		marker.Size = Vector3.new(1, 1, 1)
		marker.Transparency = 1
		marker.CFrame = zonePart.CFrame
		marker.Parent = zonePart

		local prompt = Instance.new("ProximityPrompt")
		prompt.Enabled = false
		prompt.Parent = marker

		makeSign(
			zonesFolder,
			zone.name,
			origin + zone.position + Vector3.new(0, 5, 0),
			zone.color
		)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(origin + HubConfig.SPAWN_OFFSET)
	spawn.Parent = hub

	return hub
end

function HubWorldBuilder.getSpawnCFrame()
	return CFrame.new(HubConfig.HUB_ORIGIN + HubConfig.SPAWN_OFFSET)
end

return HubWorldBuilder
