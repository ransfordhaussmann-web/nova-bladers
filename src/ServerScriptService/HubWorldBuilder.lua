local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldBuilder = {}

local function setPartDefaults(part: BasePart)
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function createFloor(parent: Instance)
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Shape = Enum.PartType.Cylinder
	floor.Size = Vector3.new(HubConfig.FLOOR_HEIGHT, HubConfig.HUB_RADIUS * 2, HubConfig.HUB_RADIUS * 2)
	floor.CFrame = CFrame.new(0, HubConfig.FLOOR_HEIGHT / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	floor.Color = HubConfig.COLORS.Floor
	floor.Material = Enum.Material.Slate
	setPartDefaults(floor)
	floor.Parent = parent

	local accent = floor:Clone()
	accent.Name = "FloorRing"
	accent.Size = Vector3.new(0.15, HubConfig.HUB_RADIUS * 1.6, HubConfig.HUB_RADIUS * 1.6)
	accent.Color = HubConfig.COLORS.FloorAccent
	accent.Material = Enum.Material.Neon
	accent.Transparency = 0.35
	accent.Parent = parent

	return floor
end

local function createRim(parent: Instance)
	local rimFolder = Instance.new("Folder")
	rimFolder.Name = "Rim"
	rimFolder.Parent = parent

	local segmentCount = 24
	local radius = HubConfig.HUB_RADIUS + 1
	for i = 0, segmentCount - 1 do
		local angle = (i / segmentCount) * math.pi * 2
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius

		local wall = Instance.new("Part")
		wall.Name = "Segment" .. i
		wall.Size = Vector3.new(6, 12, 2)
		wall.CFrame = CFrame.new(x, 6, z) * CFrame.Angles(0, -angle + math.pi / 2, 0)
		wall.Color = HubConfig.COLORS.Rim
		wall.Material = Enum.Material.Metal
		wall.Transparency = 0.15
		setPartDefaults(wall)
		wall.Parent = rimFolder
	end
end

local function createSpawn(parent: Instance)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN_OFFSET)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = parent
	return spawn
end

local function createCentralPillar(parent: Instance)
	local pillar = Instance.new("Part")
	pillar.Name = "CentralPillar"
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Size = Vector3.new(14, 5, 5)
	pillar.CFrame = CFrame.new(0, 7, 0) * CFrame.Angles(0, 0, math.rad(90))
	pillar.Color = HubConfig.COLORS.Pillar
	pillar.Material = Enum.Material.DiamondPlate
	setPartDefaults(pillar)
	pillar.Parent = parent

	local ring = Instance.new("Part")
	ring.Name = "PillarGlow"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 6, 6)
	ring.CFrame = pillar.CFrame
	ring.Color = HubConfig.COLORS.Neon
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.2
	setPartDefaults(ring)
	ring.Parent = parent

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Title"
	billboard.Size = UDim2.fromOffset(220, 60)
	billboard.StudsOffset = Vector3.new(0, 8, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = pillar

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 28
	title.TextColor3 = HubConfig.COLORS.Neon
	title.Text = "NOVA BLADERS"
	title.Parent = billboard

	local light = Instance.new("PointLight")
	light.Color = HubConfig.COLORS.Neon
	light.Brightness = 1.2
	light.Range = 18
	light.Parent = pillar
end

local function createZonePad(parent: Instance, zoneConfig)
	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = zoneConfig.id
	zoneFolder.Parent = parent

	local pad = Instance.new("Part")
	pad.Name = "Pad"
	pad.Shape = Enum.PartType.Cylinder
	pad.Size = Vector3.new(0.6, 14, 14)
	pad.CFrame = CFrame.new(zoneConfig.position + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pad.Color = zoneConfig.color
	pad.Material = Enum.Material.Neon
	pad.Transparency = 0.25
	setPartDefaults(pad)
	pad:SetAttribute("ZoneId", zoneConfig.id)
	pad:SetAttribute("ZoneMode", zoneConfig.mode)
	pad.Parent = zoneFolder

	local ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.15, 16, 16)
	ring.CFrame = pad.CFrame
	ring.Color = zoneConfig.color
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.5
	setPartDefaults(ring)
	ring.Parent = zoneFolder

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterPrompt"
	prompt.ActionText = "Betreten"
	prompt.ObjectText = zoneConfig.label
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(160, 48)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = pad

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextColor3 = zoneConfig.color
	label.Text = zoneConfig.label
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	local light = Instance.new("PointLight")
	light.Color = zoneConfig.color
	light.Brightness = 0.8
	light.Range = 14
	light.Parent = pad

	return zoneFolder, pad, prompt
end

local function createPathways(parent: Instance)
	local paths = Instance.new("Folder")
	paths.Name = "Pathways"
	paths.Parent = parent

	for _, zoneConfig in HubConfig.ZONES do
		local start = HubConfig.SPAWN_OFFSET
		local finish = zoneConfig.position
		local mid = (start + finish) / 2
		local delta = finish - start
		local length = delta.Magnitude

		local path = Instance.new("Part")
		path.Name = zoneConfig.id .. "Path"
		path.Size = Vector3.new(4, 0.2, length)
		path.CFrame = CFrame.new(mid + Vector3.new(0, 0.15, 0), finish)
		path.Color = HubConfig.COLORS.FloorAccent
		path.Material = Enum.Material.Neon
		path.Transparency = 0.6
		setPartDefaults(path)
		path.Parent = paths
	end
end

local function applyLighting()
	Lighting.ClockTime = 17.5
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(55, 60, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(70, 75, 95)
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaBladersHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Model")
	hub.Name = "NovaBladersHub"
	hub.Parent = workspace

	createFloor(hub)
	createRim(hub)
	createSpawn(hub)
	createCentralPillar(hub)
	createPathways(hub)

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	local zones = {}
	for _, zoneConfig in HubConfig.ZONES do
		local folder, pad, prompt = createZonePad(zonesFolder, zoneConfig)
		zones[zoneConfig.id] = {
			folder = folder,
			pad = pad,
			prompt = prompt,
			config = zoneConfig,
		}
	end

	applyLighting()

	return hub, zones
end

return HubWorldBuilder
