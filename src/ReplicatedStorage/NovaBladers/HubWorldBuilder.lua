local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function setPartDefaults(part)
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function createBillboard(parent, title, subtitle)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ZoneLabel"
	gui.Size = UDim2.fromOffset(220, 72)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = false
	gui.Parent = parent

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextScaled = true
	titleLabel.Text = title
	titleLabel.Parent = gui

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "Subtitle"
	subLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subLabel.Position = UDim2.fromScale(0, 0.55)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
	subLabel.TextScaled = true
	subLabel.Text = subtitle
	subLabel.Parent = gui
end

local function createZonePlatform(root, zoneConfig)
	local center = HubConfig.CENTER + zoneConfig.offset
	local platform = Instance.new("Part")
	platform.Name = zoneConfig.id
	platform.Size = Vector3.new(12, 0.6, 12)
	platform.CFrame = CFrame.new(center + Vector3.new(0, HubConfig.PLATFORM_HEIGHT / 2 + 0.3, 0))
	platform.Color = zoneConfig.color
	platform.Material = Enum.Material.Neon
	platform.Transparency = 0.35
	setPartDefaults(platform)
	platform.Parent = root

	local marker = Instance.new("Part")
	marker.Name = "Marker"
	marker.Size = Vector3.new(2.5, 6, 2.5)
	marker.CFrame = CFrame.new(center + Vector3.new(0, 3.5, 0))
	marker.Color = zoneConfig.color
	marker.Material = Enum.Material.SmoothPlastic
	marker.Transparency = 0.1
	setPartDefaults(marker)
	marker.Parent = platform

	local light = Instance.new("PointLight")
	light.Color = zoneConfig.color
	light.Brightness = 1.2
	light.Range = 14
	light.Parent = marker

	createBillboard(marker, zoneConfig.label, zoneConfig.hint)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zoneConfig.label
	prompt.ObjectText = "Nova Hub"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("HubAction", zoneConfig.action)
	prompt:SetAttribute("ZoneId", zoneConfig.id)
	prompt.Parent = marker

	return platform
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.ROOT_NAME)
	if existing then
		return existing
	end

	local root = Instance.new("Folder")
	root.Name = HubConfig.ROOT_NAME
	root.Parent = workspace

	local floor = Instance.new("Part")
	floor.Name = "HubFloor"
	floor.Shape = Enum.PartType.Cylinder
	floor.Size = Vector3.new(HubConfig.PLATFORM_HEIGHT, HubConfig.PLATFORM_RADIUS * 2, HubConfig.PLATFORM_RADIUS * 2)
	floor.CFrame = CFrame.new(HubConfig.CENTER + Vector3.new(0, HubConfig.PLATFORM_HEIGHT / 2, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	floor.Color = HubConfig.THEME.floor
	floor.Material = Enum.Material.Slate
	setPartDefaults(floor)
	floor.Parent = root

	local ring = Instance.new("Part")
	ring.Name = "HubRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.4, HubConfig.PLATFORM_RADIUS * 2 - 4, HubConfig.PLATFORM_RADIUS * 2 - 4)
	ring.CFrame = floor.CFrame
	ring.Color = HubConfig.THEME.ring
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.25
	setPartDefaults(ring)
	ring.CanCollide = false
	ring.Parent = root

	local plaza = Instance.new("Part")
	plaza.Name = "CentralPlaza"
	plaza.Shape = Enum.PartType.Cylinder
	plaza.Size = Vector3.new(0.5, 16, 16)
	plaza.CFrame = CFrame.new(HubConfig.CENTER + Vector3.new(0, HubConfig.PLATFORM_HEIGHT + 0.25, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	plaza.Color = HubConfig.THEME.floorAccent
	plaza.Material = Enum.Material.Metal
	setPartDefaults(plaza)
	plaza.Parent = root

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(HubConfig.CENTER + HubConfig.SPAWN_OFFSET)
	spawn.Color = HubConfig.THEME.ring
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.5
	spawn.Neutral = true
	spawn.AllowTeamChangeOnTouch = false
	spawn.Duration = 0
	spawn.Parent = root

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = root

	for _, zoneConfig in HubConfig.ZONES do
		local zone = createZonePlatform(zonesFolder, zoneConfig)
		zone:SetAttribute("ZoneId", zoneConfig.id)
		zone:SetAttribute("HubAction", zoneConfig.action)
	end

	local welcome = Instance.new("Part")
	welcome.Name = "WelcomeSign"
	welcome.Size = Vector3.new(14, 8, 0.6)
	welcome.CFrame = CFrame.new(HubConfig.CENTER + Vector3.new(0, 6, -8))
	welcome.Color = HubConfig.THEME.floorAccent
	welcome.Material = Enum.Material.SmoothPlastic
	setPartDefaults(welcome)
	welcome.Parent = root
	createBillboard(welcome, "Nova Bladers", "Willkommen im Hub — erkunde die Zonen")

	root:SetAttribute("HubBuilt", true)
	return root
end

function HubWorldBuilder.getSpawnCFrame()
	return CFrame.new(HubConfig.CENTER + HubConfig.SPAWN_OFFSET)
end

return HubWorldBuilder
