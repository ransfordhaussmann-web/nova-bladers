local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Color = props.Color or Color3.fromRGB(45, 48, 58)
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Name = props.Name or "Part"
	part.Transparency = props.Transparency or 0
	if props.Parent then
		part.Parent = props.Parent
	end
	return part
end

local function addSign(parent, text, position, color)
	local sign = makePart({
		Name = "Sign",
		Size = Vector3.new(10, 5, 0.4),
		CFrame = CFrame.new(position + Vector3.new(0, 5, 0)),
		Color = color,
		Material = Enum.Material.Neon,
		Parent = parent,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 60)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard
end

local function buildZone(parent, zone)
	local platform = makePart({
		Name = zone.id,
		Size = Vector3.new(zone.radius * 2, 1, zone.radius * 2),
		CFrame = CFrame.new(zone.position + Vector3.new(0, 0.5, 0)),
		Color = zone.color,
		Material = Enum.Material.Neon,
		Parent = parent,
	})
	platform.Transparency = 0.35

	local marker = makePart({
		Name = "Marker",
		Size = Vector3.new(2, 8, 2),
		CFrame = CFrame.new(zone.position + Vector3.new(0, 4.5, 0)),
		Color = zone.color,
		Material = Enum.Material.Neon,
		Parent = platform,
	})
	marker.Transparency = 0.2

	platform:SetAttribute("ZoneId", zone.id)
	addSign(platform, zone.name, zone.position, zone.color)

	return platform
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		return existing
	end

	local hub = Instance.new("Model")
	hub.Name = "NovaHub"

	local world = HubConfig.WORLD
	local floorCenter = world.FLOOR_CENTER
	local floorSize = world.FLOOR_SIZE

	makePart({
		Name = "Floor",
		Size = floorSize,
		CFrame = CFrame.new(floorCenter + Vector3.new(0, -0.5, 0)),
		Color = Color3.fromRGB(32, 34, 42),
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local wallH = world.WALL_HEIGHT
	local wallT = world.WALL_THICKNESS

	local walls = {
		{ Vector3.new(0, wallH / 2, -halfZ), Vector3.new(floorSize.X, wallH, wallT) },
		{ Vector3.new(0, wallH / 2, halfZ), Vector3.new(floorSize.X, wallH, wallT) },
		{ Vector3.new(-halfX, wallH / 2, 0), Vector3.new(wallT, wallH, floorSize.Z) },
		{ Vector3.new(halfX, wallH / 2, 0), Vector3.new(wallT, wallH, floorSize.Z) },
	}

	for i, wall in walls do
		makePart({
			Name = "Wall" .. i,
			Size = wall[2],
			CFrame = CFrame.new(floorCenter + wall[1]),
			Color = Color3.fromRGB(55, 58, 70),
			Material = Enum.Material.Concrete,
			Parent = hub,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	for _, zone in HubConfig.ZONES do
		buildZone(hub, zone)
	end

	makePart({
		Name = "CenterPillar",
		Size = Vector3.new(6, 12, 6),
		CFrame = CFrame.new(floorCenter + Vector3.new(0, 6, 0)),
		Color = Color3.fromRGB(90, 100, 130),
		Material = Enum.Material.Metal,
		Parent = hub,
	})

	hub.Parent = workspace
	return hub
end

return HubWorldBuilder
