local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.fromRGB(60, 65, 80)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function addLabel(parent, text, offset)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = offset or Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard
end

local function buildZone(parent, zoneConfig)
	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = zoneConfig.id
	zoneFolder.Parent = parent

	local baseY = HubConfig.ORIGIN.Y + zoneConfig.size.Y / 2
	local center = HubConfig.ORIGIN + zoneConfig.position + Vector3.new(0, baseY, 0)

	local building = makePart({
		name = "Building",
		parent = zoneFolder,
		size = zoneConfig.size,
		cframe = CFrame.new(center),
		color = zoneConfig.color,
		material = Enum.Material.Neon,
	})
	building.Transparency = 0.25

	makePart({
		name = "Platform",
		parent = zoneFolder,
		size = Vector3.new(zoneConfig.size.X + 4, 0.5, zoneConfig.size.Z + 4),
		cframe = CFrame.new(HubConfig.ORIGIN + zoneConfig.position + Vector3.new(0, 0.25, 0)),
		color = Color3.fromRGB(45, 48, 58),
		material = Enum.Material.Slate,
	})

	addLabel(building, zoneConfig.label, Vector3.new(0, zoneConfig.size.Y / 2 + 2, 0))

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = HubConfig.PROXIMITY.ActionText
	prompt.ObjectText = zoneConfig.label
	prompt.HoldDuration = HubConfig.PROXIMITY.HoldDuration
	prompt.MaxActivationDistance = HubConfig.PROXIMITY.MaxActivationDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = building
	prompt:SetAttribute("ZoneId", zoneConfig.id)

	if zoneConfig.id == "ArenaGate" then
		local glow = Instance.new("PointLight")
		glow.Name = "GateGlow"
		glow.Color = zoneConfig.glowColor or zoneConfig.color
		glow.Brightness = 2
		glow.Range = 16
		glow.Parent = building
	end

	if zoneConfig.id == "HallOfFame" then
		local board = makePart({
			name = "LeaderboardBoard",
			parent = zoneFolder,
			size = Vector3.new(8, 5, 0.4),
			cframe = CFrame.new(center + Vector3.new(0, 0, zoneConfig.size.Z / 2 + 1)),
			color = Color3.fromRGB(30, 32, 40),
			material = Enum.Material.Glass,
		})
		local surface = Instance.new("SurfaceGui")
		surface.Face = Enum.NormalId.Front
		surface.Parent = board
		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0.25, 0)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextColor3 = Color3.fromRGB(255, 220, 100)
		title.TextScaled = true
		title.Text = "🏆 Top Spieler"
		title.Parent = surface
	end

	return zoneFolder, prompt
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local origin = HubConfig.ORIGIN

	makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		cframe = CFrame.new(origin + Vector3.new(0, -0.5, 0)),
		color = Color3.fromRGB(35, 38, 48),
		material = Enum.Material.Concrete,
	})

	local wallHeight = 6
	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local walls = {
		{ Vector3.new(0, wallHeight / 2, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, wallHeight, 1) },
		{ Vector3.new(0, wallHeight / 2, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, wallHeight, 1) },
		{ Vector3.new(-halfX, wallHeight / 2, 0), Vector3.new(1, wallHeight, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(halfX, wallHeight / 2, 0), Vector3.new(1, wallHeight, HubConfig.FLOOR_SIZE.Z) },
	}
	for i, wall in walls do
		makePart({
			name = "Wall" .. i,
			parent = hub,
			size = wall[2],
			cframe = CFrame.new(origin + wall[1]),
			color = Color3.fromRGB(50, 54, 68),
			material = Enum.Material.Brick,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(origin + HubConfig.HUB_SPAWN)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	local prompts = {}
	for _, zoneConfig in HubConfig.ZONES do
		local _, prompt = buildZone(zonesFolder, zoneConfig)
		prompts[zoneConfig.id] = prompt
	end

	return hub, prompts
end

return HubWorldBuilder
