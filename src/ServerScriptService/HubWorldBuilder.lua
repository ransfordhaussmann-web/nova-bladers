local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldBuilder = {}
local built = false

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

local function createBillboard(parent, title, subtitle, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 72)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 1.5
	stroke.Parent = frame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, -12, 0, 28)
	titleLabel.Position = UDim2.fromOffset(6, 6)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 16
	titleLabel.TextColor3 = Color3.fromRGB(240, 244, 255)
	titleLabel.Text = title
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = frame

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Size = UDim2.new(1, -12, 0, 22)
	subtitleLabel.Position = UDim2.fromOffset(6, 34)
	subtitleLabel.Font = Enum.Font.Gotham
	subtitleLabel.TextSize = 13
	subtitleLabel.TextColor3 = Color3.fromRGB(170, 180, 210)
	subtitleLabel.Text = subtitle
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel.Parent = frame
end

local function createZone(folder, zoneId, zone)
	local platform = createPart({
		Name = zoneId,
		Size = zone.size,
		Position = zone.position,
		Color = zone.color,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = true,
	})
	platform:SetAttribute("ZoneId", zoneId)
	platform:SetAttribute("Proximity", zone.proximity)
	CollectionService:AddTag(platform, HubConfig.HUB_ZONE_TAG)
	platform.Parent = folder

	local ring = createPart({
		Name = zoneId .. "Ring",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, zone.size.X * 0.9, zone.size.Z * 0.9),
		CFrame = CFrame.new(zone.position + Vector3.new(0, -zone.size.Y * 0.5 + 0.2, 0))
			* CFrame.Angles(0, 0, math.rad(90)),
		Color = zone.color,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
		CanCollide = false,
	})
	ring.Parent = folder

	createBillboard(platform, zone.label, zone.hint, zone.color)
end

function HubWorldBuilder.build()
	if built then
		return workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	end

	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	if existing then
		built = true
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER
	hub.Parent = workspace

	local floor = createPart({
		Name = "PlazaFloor",
		Size = HubConfig.FLOOR_SIZE,
		Position = Vector3.new(0, 0.5, 0),
		Color = HubConfig.FLOOR_COLOR,
		Material = Enum.Material.Slate,
	})
	floor.Parent = hub

	local spawnPad = createPart({
		Name = "SpawnPad",
		Size = Vector3.new(16, 0.6, 16),
		Position = HubConfig.SPAWN - Vector3.new(0, 1.3, 0),
		Color = HubConfig.ACCENT_COLOR,
		Material = Enum.Material.Neon,
		Transparency = 0.45,
	})
	spawnPad.Parent = hub

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = HubConfig.SPAWN
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.Parent = hub

	for zoneId, zone in HubConfig.ZONES do
		createZone(hub, zoneId, zone)
	end

	local rimPositions = {
		Vector3.new(0, 1.2, -48),
		Vector3.new(48, 1.2, 0),
		Vector3.new(0, 1.2, 48),
		Vector3.new(-48, 1.2, 0),
	}
	for index, position in rimPositions do
		local pillar = createPart({
			Name = "RimPillar" .. index,
			Size = Vector3.new(2, 6, 2),
			Position = position,
			Color = HubConfig.ACCENT_COLOR,
			Material = Enum.Material.Metal,
		})
		pillar.Parent = hub
	end

	local hubLight = Instance.new("PointLight")
	hubLight.Brightness = 2
	hubLight.Range = 80
	hubLight.Color = HubConfig.ACCENT_COLOR
	hubLight.Parent = spawnPad

	Lighting.ClockTime = 16.5
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(55, 60, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(90, 95, 120)

	built = true
	return hub
end

return HubWorldBuilder
