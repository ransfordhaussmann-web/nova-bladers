local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	return part
end

local function addZoneLabel(parent, text)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.TextSize = 20
	label.Text = text
	label.Parent = billboard
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		return existing
	end

	local origin = HubConfig.HUB_ORIGIN
	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = origin + Vector3.new(0, -0.5, 0),
		Color = Color3.fromRGB(35, 38, 48),
		Material = Enum.Material.Slate,
	})
	floor.Parent = hub

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallY = origin.Y + HubConfig.WALL_HEIGHT / 2

	local walls = {
		{ Vector3.new(0, wallY, halfZ + 1), Vector3.new(HubConfig.FLOOR_SIZE.X + 2, HubConfig.WALL_HEIGHT, 2) },
		{ Vector3.new(0, wallY, -halfZ - 1), Vector3.new(HubConfig.FLOOR_SIZE.X + 2, HubConfig.WALL_HEIGHT, 2) },
		{ Vector3.new(halfX + 1, wallY, 0), Vector3.new(2, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z + 2) },
		{ Vector3.new(-halfX - 1, wallY, 0), Vector3.new(2, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z + 2) },
	}

	for index, wallData in walls do
		local wall = makePart({
			Name = "Wall" .. index,
			Size = wallData[2],
			Position = origin + wallData[1],
			Color = Color3.fromRGB(50, 55, 70),
			Material = Enum.Material.Concrete,
		})
		wall.Parent = hub
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local marker = makePart({
			Name = zone.id,
			Size = zone.size,
			Position = zone.position,
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.55,
			CanCollide = false,
		})
		marker:SetAttribute("ZoneId", zone.id)
		marker:SetAttribute("Action", zone.action)
		addZoneLabel(marker, zone.label)
		marker.Parent = zonesFolder
	end

	local spawn = makePart({
		Name = "Spawn",
		Size = Vector3.new(6, 1, 6),
		Position = origin + HubConfig.SPAWN_OFFSET,
		Color = Color3.fromRGB(90, 200, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.7,
		CanCollide = false,
	})
	spawn.Parent = hub

	return hub
end

function HubWorldBuilder.getSpawnCFrame()
	return CFrame.new(HubConfig.HUB_ORIGIN + HubConfig.SPAWN_OFFSET + Vector3.new(0, 3, 0))
end

return HubWorldBuilder
