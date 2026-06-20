local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

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

local function addSign(parent, text, offset)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = offset or Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard
end

function HubWorldBuilder.getHubFolder()
	local existing = Workspace:FindFirstChild(HubConfig.HUB_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_NAME
	hub.Parent = Workspace
	return hub
end

function HubWorldBuilder.build()
	local hub = HubWorldBuilder.getHubFolder()
	if hub:FindFirstChild("Floor") then
		return hub
	end

	local origin = HubConfig.HUB_ORIGIN
	local floorSize = HubConfig.FLOOR_SIZE

	local floor = makePart({
		Name = "Floor",
		Size = floorSize,
		Position = origin,
		Color = Color3.fromRGB(45, 48, 58),
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	local wallThickness = 2
	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2

	local walls = {
		{ Name = "WallNorth", Size = Vector3.new(floorSize.X, HubConfig.WALL_HEIGHT, wallThickness), Position = origin + Vector3.new(0, HubConfig.WALL_HEIGHT / 2, -halfZ) },
		{ Name = "WallSouth", Size = Vector3.new(floorSize.X, HubConfig.WALL_HEIGHT, wallThickness), Position = origin + Vector3.new(0, HubConfig.WALL_HEIGHT / 2, halfZ) },
		{ Name = "WallWest", Size = Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, floorSize.Z), Position = origin + Vector3.new(-halfX, HubConfig.WALL_HEIGHT / 2, 0) },
		{ Name = "WallEast", Size = Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, floorSize.Z), Position = origin + Vector3.new(halfX, HubConfig.WALL_HEIGHT / 2, 0) },
	}

	for _, wall in walls do
		makePart({
			Name = wall.Name,
			Size = wall.Size,
			Position = wall.Position,
			Color = Color3.fromRGB(60, 64, 78),
			Material = Enum.Material.Concrete,
			Parent = hub,
		})
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zonePart = makePart({
			Name = zone.id,
			Size = zone.size,
			Position = origin + zone.position + Vector3.new(0, zone.size.Y / 2, 0),
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.35,
			CanCollide = true,
			Parent = zonesFolder,
		})
		zonePart:SetAttribute("ZoneId", zone.id)
		zonePart:SetAttribute("Action", zone.action)
		addSign(zonePart, zone.name, Vector3.new(0, 5, 0))
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = origin + HubConfig.SPAWN_OFFSET
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = hub

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 40
	light.Parent = floor

	return hub
end

function HubWorldBuilder.getSpawnCFrame()
	local hub = HubWorldBuilder.getHubFolder()
	local spawn = hub:FindFirstChild("HubSpawn")
	if spawn then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubConfig.HUB_ORIGIN + HubConfig.SPAWN_OFFSET)
end

return HubWorldBuilder
