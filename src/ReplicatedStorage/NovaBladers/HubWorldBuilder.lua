local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(name, size, position, color, anchored)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = anchored ~= false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function addZoneLabel(parent, zoneId, zone)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextSize = 18
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.5
	text.Text = zone.label
	text.Parent = billboard

	local attr = Instance.new("StringValue")
	attr.Name = "ZoneId"
	attr.Value = zoneId
	attr.Parent = parent
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	local floorSize = HubConfig.FLOOR_SIZE
	local floor = makePart("Floor", floorSize, Vector3.new(0, -0.5, 0), Color3.fromRGB(35, 38, 48))
	floor.Material = Enum.Material.Slate
	hub:AddChild(floor)

	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallThick = 2

	local walls = {
		{ "WallNorth", Vector3.new(floorSize.X + wallThick, wallH, wallThick), Vector3.new(0, wallH / 2, -halfZ) },
		{ "WallSouth", Vector3.new(floorSize.X + wallThick, wallH, wallThick), Vector3.new(0, wallH / 2, halfZ) },
		{ "WallEast", Vector3.new(wallThick, wallH, floorSize.Z + wallThick), Vector3.new(halfX, wallH / 2, 0) },
		{ "WallWest", Vector3.new(wallThick, wallH, floorSize.Z + wallThick), Vector3.new(-halfX, wallH / 2, 0) },
	}
	for _, wall in walls do
		local part = makePart(wall[1], wall[2], wall[3], Color3.fromRGB(50, 55, 68))
		part.Material = Enum.Material.Concrete
		hub:AddChild(part)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_OFFSET
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for zoneId, zone in HubConfig.ZONES do
		local marker = makePart(zoneId .. "Marker", Vector3.new(zone.radius * 2, 0.4, zone.radius * 2), zone.position, zone.color)
		marker.Material = Enum.Material.Neon
		marker.Transparency = 0.35
		marker.CanCollide = false
		addZoneLabel(marker, zoneId, zone)
		marker.Parent = zonesFolder
	end

	local lighting = Instance.new("PointLight")
	lighting.Brightness = 0.6
	lighting.Range = 40
	lighting.Parent = spawn

	return hub
end

function HubWorldBuilder.getSpawnCFrame()
	local hub = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if hub then
		local spawn = hub:FindFirstChild("HubSpawn")
		if spawn then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(HubConfig.SPAWN_OFFSET)
end

return HubWorldBuilder
