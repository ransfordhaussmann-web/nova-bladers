local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local function addZoneLabel(parent, zone)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 60)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 18
	label.Text = zone.name
	label.Parent = billboard
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER
	hub.Parent = workspace

	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = Vector3.new(0, 0, 0),
		Color = HubConfig.COLORS.Floor,
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallY = HubConfig.WALL_HEIGHT / 2

	local walls = {
		{ Name = "WallNorth", Size = Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, 2), Position = Vector3.new(0, wallY, -halfZ) },
		{ Name = "WallSouth", Size = Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, 2), Position = Vector3.new(0, wallY, halfZ) },
		{ Name = "WallWest", Size = Vector3.new(2, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), Position = Vector3.new(-halfX, wallY, 0) },
		{ Name = "WallEast", Size = Vector3.new(2, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), Position = Vector3.new(halfX, wallY, 0) },
	}

	for _, wall in walls do
		makePart({
			Name = wall.Name,
			Size = wall.Size,
			Position = wall.Position,
			Color = HubConfig.COLORS.Wall,
			Material = Enum.Material.Concrete,
			Parent = hub,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_OFFSET
	spawn.Color = HubConfig.COLORS.Accent
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.35
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local pad = makePart({
			Name = zone.id,
			Size = zone.size,
			Position = zone.position,
			Color = HubConfig.COLORS[zone.colorKey],
			Material = Enum.Material.Neon,
			Transparency = 0.55,
			CanCollide = false,
			Parent = zonesFolder,
		})
		pad:SetAttribute("ZoneId", zone.id)
		pad:SetAttribute("Action", zone.action)
		addZoneLabel(pad, zone)
	end

	local centerLight = Instance.new("PointLight")
	centerLight.Brightness = 1.2
	centerLight.Range = 40
	centerLight.Parent = floor

	return hub
end

function HubWorldBuilder.getHubSpawnCFrame()
	local hub = workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	local spawn = hub and hub:FindFirstChild("HubSpawn")
	if spawn then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubConfig.SPAWN_OFFSET)
end

function HubWorldBuilder.getArenaSpawnCFrame()
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER)
	local spawn = arena and arena:FindFirstChild(HubConfig.ARENA_SPAWN_NAME)
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	if arena then
		local bowl = arena:FindFirstChild("Bowl") or arena:FindFirstChildWhichIsA("BasePart")
		if bowl and bowl:IsA("BasePart") then
			return bowl.CFrame + Vector3.new(0, 6, 0)
		end
	end
	return CFrame.new(0, 8, 0)
end

return HubWorldBuilder
