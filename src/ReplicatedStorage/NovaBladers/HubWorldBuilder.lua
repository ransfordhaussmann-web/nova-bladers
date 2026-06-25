local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function createPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	return part
end

local function createLabel(parent, text, offsetY)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, offsetY or 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.TextSize = 18
	label.Text = text
	label.Parent = billboard
end

local function createWall(parent, position, size)
	local wall = createPart({
		Name = "Wall",
		Size = size,
		Position = position,
		Color = Color3.fromRGB(35, 40, 55),
		Material = Enum.Material.Concrete,
		Transparency = 0.15,
		Parent = parent,
	})
	return wall
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	local floor = createPart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = HubConfig.FLOOR_CENTER + Vector3.new(0, HubConfig.FLOOR_SIZE.Y / 2, 0),
		Color = Color3.fromRGB(28, 32, 48),
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS
	local floorY = floor.Position.Y + HubConfig.FLOOR_SIZE.Y / 2

	createWall(hub, Vector3.new(0, floorY + wallH / 2, -halfZ - wallT / 2), Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT))
	createWall(hub, Vector3.new(0, floorY + wallH / 2, halfZ + wallT / 2), Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT))
	createWall(hub, Vector3.new(-halfX - wallT / 2, floorY + wallH / 2, 0), Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z))
	createWall(hub, Vector3.new(halfX + wallT / 2, floorY + wallH / 2, 0), Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z))

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local platform = createPart({
			Name = zone.id,
			Size = zone.size,
			Position = zone.position + Vector3.new(0, zone.size.Y / 2 + 0.05, 0),
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.35,
			Parent = zonesFolder,
		})
		createLabel(platform, zone.name, 5)

		local marker = createPart({
			Name = zone.id .. "_Beacon",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, 3, 3),
			CFrame = CFrame.new(zone.position + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.2,
			CanCollide = false,
			Parent = zonesFolder,
		})
		marker.Name = zone.id .. "_Beacon"
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION - Vector3.new(0, 2, 0)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	return hub
end

return HubWorldBuilder
