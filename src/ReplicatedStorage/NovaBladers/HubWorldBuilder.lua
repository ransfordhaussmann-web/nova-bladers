local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function createPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = props.cframe or CFrame.new(props.position or Vector3.zero)
	part.Color = props.color or Color3.fromRGB(200, 200, 200)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Transparency = props.transparency or 0
	if props.parent then
		part.Parent = props.parent
	end
	return part
end

local function createBillboard(parent, text, color)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ZoneLabel"
	gui.Size = UDim2.fromOffset(200, 50)
	gui.StudsOffset = Vector3.new(0, HubConfig.BILLBOARD_HEIGHT, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(10, 12, 20)
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = text
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	return gui
end

local function createZonePrompt(zonePart, zone)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zone.promptText
	prompt.ObjectText = zone.label
	prompt.MaxActivationDistance = zone.maxDistance or 12
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("HubAction", zone.promptAction)
	prompt:SetAttribute("ZoneId", zone.id)
	prompt.Parent = zonePart
	return prompt
end

local function buildArenaArch(parent, arch)
	local frame = Instance.new("Model")
	frame.Name = "ArenaGateArch"
	frame.Parent = parent

	local center = arch.position
	local halfW = arch.width / 2
	local halfH = arch.height / 2

	createPart({
		name = "LeftPillar",
		size = Vector3.new(arch.depth, arch.height, arch.depth),
		cframe = CFrame.new(center + Vector3.new(-halfW, 0, 0)),
		color = arch.color,
		material = Enum.Material.Metal,
		parent = frame,
	})

	createPart({
		name = "RightPillar",
		size = Vector3.new(arch.depth, arch.height, arch.depth),
		cframe = CFrame.new(center + Vector3.new(halfW, 0, 0)),
		color = arch.color,
		material = Enum.Material.Metal,
		parent = frame,
	})

	createPart({
		name = "TopBeam",
		size = Vector3.new(arch.width, arch.depth, arch.depth),
		cframe = CFrame.new(center + Vector3.new(0, halfH, 0)),
		color = arch.color,
		material = Enum.Material.Metal,
		parent = frame,
	})

	local glow = createPart({
		name = "GateGlow",
		size = Vector3.new(arch.width - 4, arch.height - 4, 0.4),
		cframe = CFrame.new(center),
		color = arch.glowColor,
		material = Enum.Material.Neon,
		transparency = 0.35,
		canCollide = false,
		parent = frame,
	})
	glow:SetAttribute("PulseGlow", true)

	return frame
end

local function buildPillars(parent, config)
	local folder = Instance.new("Folder")
	folder.Name = "Pillars"
	folder.Parent = parent

	for i = 1, config.count do
		local angle = (i / config.count) * math.pi * 2
		local x = math.cos(angle) * config.radius
		local z = math.sin(angle) * config.radius
		createPart({
			name = "Pillar" .. i,
			size = Vector3.new(3, config.height, 3),
			cframe = CFrame.new(x, config.height / 2, z),
			color = config.color,
			material = Enum.Material.Concrete,
			parent = folder,
		})
	end

	return folder
end

local function buildPlazaRing(parent, ring)
	local segments = 32
	local folder = Instance.new("Folder")
	folder.Name = "PlazaRing"
	folder.Parent = parent

	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		local midRadius = (ring.innerRadius + ring.outerRadius) / 2
		local thickness = ring.outerRadius - ring.innerRadius
		local x = math.cos(angle) * midRadius
		local z = math.sin(angle) * midRadius
		local segmentLength = (2 * math.pi * midRadius) / segments + 0.5

		createPart({
			name = "RingSegment" .. i,
			size = Vector3.new(thickness, ring.height, segmentLength),
			cframe = CFrame.new(x, ring.height / 2 + 0.05, z) * CFrame.Angles(0, -angle, 0),
			color = ring.color,
			material = ring.material,
			parent = folder,
		})
	end

	return folder
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Model")
	hub.Name = HubConfig.HUB_NAME
	hub.Parent = workspace

	local floor = createPart({
		name = "Floor",
		size = HubConfig.FLOOR.size,
		position = HubConfig.FLOOR.position + Vector3.new(0, -HubConfig.FLOOR.size.Y / 2, 0),
		color = HubConfig.FLOOR.color,
		material = HubConfig.FLOOR.material,
		parent = hub,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = HubConfig.SPAWN_CFRAME
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	buildPlazaRing(hub, HubConfig.PLAZA_RING)
	buildPillars(hub, HubConfig.PILLARS)
	buildArenaArch(hub, HubConfig.ARENA_GATE_ARCH)

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local pad = createPart({
			name = zone.id,
			size = zone.size,
			position = zone.position,
			color = zone.color,
			material = Enum.Material.Neon,
			transparency = 0.15,
			parent = zonesFolder,
		})
		pad:SetAttribute("ZoneId", zone.id)
		createBillboard(pad, zone.label, zone.color)
		createZonePrompt(pad, zone)
	end

	local bounds = Instance.new("Part")
	bounds.Name = "HubBounds"
	bounds.Size = HubConfig.FLOOR.size + Vector3.new(0, 20, 0)
	bounds.CFrame = CFrame.new(HubConfig.FLOOR.position + Vector3.new(0, 10, 0))
	bounds.Anchored = true
	bounds.CanCollide = false
	bounds.Transparency = 1
	bounds.Parent = hub
	hub.PrimaryPart = floor

	return hub
end

return HubWorldBuilder
