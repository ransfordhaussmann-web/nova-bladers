local HubWorldConfig = require(script.Parent.HubWorldConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size or Vector3.new(4, 1, 4)
	part.CFrame = props.cframe or CFrame.new(0, 0, 0)
	part.Color = props.color or HubWorldConfig.THEME.FLOOR
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	if props.transparency then
		part.Transparency = props.transparency
	end
	return part
end

local function addNeonStrip(parent, cframe, size, color)
	local strip = makePart({
		parent = parent,
		name = "NeonStrip",
		size = size,
		cframe = cframe,
		color = color,
		material = Enum.Material.Neon,
		canCollide = false,
	})
	return strip
end

local function buildPlaza(root)
	local plaza = Instance.new("Model")
	plaza.Name = "Plaza"
	plaza.Parent = root

	local radius = HubWorldConfig.PLAZA.RADIUS
	local height = HubWorldConfig.PLAZA.HEIGHT

	makePart({
		parent = plaza,
		name = "Floor",
		size = Vector3.new(radius * 2, height, radius * 2),
		cframe = CFrame.new(0, height / 2, 0),
		color = HubWorldConfig.THEME.FLOOR,
		material = Enum.Material.Slate,
	})

	local _ring = makePart({
		parent = plaza,
		name = "FloorRing",
		size = Vector3.new(radius * 2 + 2, 0.3, radius * 2 + 2),
		cframe = CFrame.new(0, height + 0.15, 0),
		color = HubWorldConfig.THEME.FLOOR_ACCENT,
		material = Enum.Material.Metal,
	})

	addNeonStrip(
		plaza,
		CFrame.new(0, height + 0.35, 0),
		Vector3.new(radius * 2 + 2, 0.15, radius * 2 + 2),
		HubWorldConfig.THEME.NEON
	)

	local spawnPad = makePart({
		parent = plaza,
		name = "SpawnPad",
		size = Vector3.new(8, 0.4, 8),
		cframe = CFrame.new(HubWorldConfig.SPAWN_POSITION.X, height + 0.2, HubWorldConfig.SPAWN_POSITION.Z),
		color = HubWorldConfig.THEME.GLOW,
		material = Enum.Material.Neon,
	})
	spawnPad.CanCollide = false

	return plaza, spawnPad
end

local function buildPath(root, fromPos, toPos, width)
	local path = Instance.new("Model")
	path.Name = "Path"
	path.Parent = root

	local mid = (fromPos + toPos) / 2
	local delta = toPos - fromPos
	local length = delta.Magnitude
	local angle = math.atan2(delta.X, delta.Z)

	makePart({
		parent = path,
		name = "Walkway",
		size = Vector3.new(width, 0.5, length),
		cframe = CFrame.new(mid.X, 0.25, mid.Z) * CFrame.Angles(0, angle, 0),
		color = HubWorldConfig.THEME.FLOOR_ACCENT,
		material = Enum.Material.Concrete,
	})

	return path
end

local function buildZoneStructure(root, zoneConfig)
	local zone = Instance.new("Model")
	zone.Name = zoneConfig.id
	zone.Parent = root

	local pos = zoneConfig.position
	local size = zoneConfig.size

	local platform = makePart({
		parent = zone,
		name = "Platform",
		size = Vector3.new(size.X, 1, size.Z),
		cframe = CFrame.new(pos.X, 0.5, pos.Z),
		color = HubWorldConfig.THEME.FLOOR_ACCENT,
		material = Enum.Material.Metal,
	})

	local trigger = makePart({
		parent = zone,
		name = "ZoneTrigger",
		size = Vector3.new(size.X - 2, size.Y, size.Z - 2),
		cframe = CFrame.new(pos.X, pos.Y, pos.Z),
		color = HubWorldConfig.THEME.GLOW,
		canCollide = false,
	})
	trigger.Transparency = 1
	trigger:SetAttribute("ZoneId", zoneConfig.id)
	trigger:SetAttribute("Remote", zoneConfig.remote or "")
	trigger:SetAttribute("Label", zoneConfig.label)
	trigger:SetAttribute("Hint", zoneConfig.hint)

	if zoneConfig.id == "ArenaGate" then
		local archLeft = makePart({
			parent = zone,
			name = "ArchLeft",
			size = Vector3.new(2, 10, 2),
			cframe = CFrame.new(pos.X - 6, 5, pos.Z),
			color = HubWorldConfig.THEME.WALL,
			material = Enum.Material.Metal,
		})
		local archRight = archLeft:Clone()
		archRight.Name = "ArchRight"
		archRight.CFrame = CFrame.new(pos.X + 6, 5, pos.Z)
		archRight.Parent = zone

		addNeonStrip(
			zone,
			CFrame.new(pos.X, 10.5, pos.Z),
			Vector3.new(14, 0.4, 0.4),
			HubWorldConfig.THEME.NEON
		)
	elseif zoneConfig.id == "BeySelect" then
		makePart({
			parent = zone,
			name = "Kiosk",
			size = Vector3.new(6, 6, 4),
			cframe = CFrame.new(pos.X, 3.5, pos.Z - 2),
			color = HubWorldConfig.THEME.WALL,
			material = Enum.Material.SmoothPlastic,
		})
		addNeonStrip(
			zone,
			CFrame.new(pos.X, 7, pos.Z - 2),
			Vector3.new(5, 0.3, 0.3),
			HubWorldConfig.THEME.NEON_WARM
		)
	elseif zoneConfig.id == "Leaderboard" then
		makePart({
			parent = zone,
			name = "Board",
			size = Vector3.new(8, 6, 0.5),
			cframe = CFrame.new(pos.X, 4, pos.Z + 2),
			color = HubWorldConfig.THEME.WALL,
			material = Enum.Material.Glass,
		})
		addNeonStrip(
			zone,
			CFrame.new(pos.X, 7.5, pos.Z + 2),
			Vector3.new(7, 0.3, 0.3),
			HubWorldConfig.THEME.NEON
		)
	end

	buildPath(root, Vector3.new(0, 0, 0), Vector3.new(pos.X, 0, pos.Z), 6)

	return zone, trigger
end

local function buildBoundary(root)
	local boundary = Instance.new("Model")
	boundary.Name = "Boundary"
	boundary.Parent = root

	local radius = HubWorldConfig.PLAZA.RADIUS + 8
	local segments = 12
	for i = 0, segments - 1 do
		local angle = (i / segments) * math.pi * 2
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		makePart({
			parent = boundary,
			name = "Wall_" .. i,
			size = Vector3.new(4, 8, 1.5),
			cframe = CFrame.new(x, 4, z) * CFrame.Angles(0, -angle + math.pi / 2, 0),
			color = HubWorldConfig.THEME.WALL,
			material = Enum.Material.Metal,
		})
	end

	return boundary
end

local function buildLighting(root)
	local light = Instance.new("Part")
	light.Name = "HubLight"
	light.Anchored = true
	light.CanCollide = false
	light.Transparency = 1
	light.Size = Vector3.new(1, 1, 1)
	light.CFrame = CFrame.new(0, 20, 0)
	light.Parent = root

	local point = Instance.new("PointLight")
	point.Brightness = 1.2
	point.Range = 80
	point.Color = HubWorldConfig.THEME.GLOW
	point.Parent = light

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(180, 200, 255)
	atmosphere.Decay = Color3.fromRGB(80, 100, 160)
	atmosphere.Glare = 0.1
	atmosphere.Haze = 1.5
	atmosphere.Parent = game:GetService("Lighting")

	return light
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubWorldConfig.ROOT_NAME)
	if existing then
		return existing
	end

	local root = Instance.new("Model")
	root.Name = HubWorldConfig.ROOT_NAME
	root.Parent = workspace

	buildPlaza(root)
	buildBoundary(root)
	buildLighting(root)

	for _, zoneConfig in HubWorldConfig.ZONES do
		buildZoneStructure(root, zoneConfig)
	end

	local sign = makePart({
		parent = root,
		name = "HubSign",
		size = Vector3.new(12, 3, 0.5),
		cframe = CFrame.new(0, 8, 12),
		color = HubWorldConfig.THEME.WALL,
		material = Enum.Material.Neon,
		canCollide = false,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Title"
	billboard.Size = UDim2.fromScale(10, 3)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = sign

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 1
	title.Text = "NOVA BLADERS"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = billboard

	return root
end

function HubWorldBuilder.getSpawnCFrame()
	local pos = HubWorldConfig.SPAWN_POSITION
	return CFrame.new(pos.X, pos.Y, pos.Z)
end

return HubWorldBuilder
