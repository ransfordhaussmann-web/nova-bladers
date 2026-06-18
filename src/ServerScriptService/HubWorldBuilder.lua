local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldBuilder = {}

local HUB_FOLDER_NAME = "NovaHub"
local ZONE_TAG = "NovaHubZone"

local function anchorPart(part: BasePart)
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function createPart(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?)
	local part = anchorPart(Instance.new("Part"))
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	return part
end

local function addZoneLabel(parent: BasePart, title: string, subtitle: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(220, 72)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 2)
	layout.Parent = billboard

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.fromOffset(220, 28)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 20
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextStrokeTransparency = 0.4
	titleLabel.Text = title
	titleLabel.Parent = billboard

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Size = UDim2.fromOffset(220, 20)
	subtitleLabel.Font = Enum.Font.Gotham
	subtitleLabel.TextSize = 14
	subtitleLabel.TextColor3 = Color3.fromRGB(210, 220, 240)
	subtitleLabel.TextStrokeTransparency = 0.5
	subtitleLabel.Text = subtitle
	subtitleLabel.Parent = billboard
end

local function addProximityPrompt(parent: BasePart, action: string, promptText: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = promptText
	prompt.ObjectText = "Nova Hub"
	prompt.MaxActivationDistance = HubConfig.PROXIMITY_MAX
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("HubAction", action)
	prompt.Parent = parent
end

local function buildRim(parent: Instance, origin: Vector3, floorSize: Vector3)
	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local height = HubConfig.RIM_HEIGHT
	local thickness = HubConfig.RIM_THICKNESS
	local y = origin.Y + floorSize.Y / 2 + height / 2
	local color = Color3.fromRGB(18, 22, 34)

	local walls = {
		{ size = Vector3.new(floorSize.X + thickness * 2, height, thickness), pos = Vector3.new(0, 0, halfZ + thickness / 2) },
		{ size = Vector3.new(floorSize.X + thickness * 2, height, thickness), pos = Vector3.new(0, 0, -(halfZ + thickness / 2)) },
		{ size = Vector3.new(thickness, height, floorSize.Z), pos = Vector3.new(halfX + thickness / 2, 0, 0) },
		{ size = Vector3.new(thickness, height, floorSize.Z), pos = Vector3.new(-(halfX + thickness / 2), 0, 0) },
	}

	local rimFolder = Instance.new("Folder")
	rimFolder.Name = "Rim"
	rimFolder.Parent = parent

	for index, wall in walls do
		local part = createPart(
			"Wall" .. index,
			wall.size,
			CFrame.new(origin + Vector3.new(wall.pos.X, y - origin.Y, wall.pos.Z)),
			color,
			Enum.Material.Concrete
		)
		part.CanCollide = true
		part.Parent = rimFolder
	end
end

local function buildLandmarks(parent: Instance, origin: Vector3)
	local folder = Instance.new("Folder")
	folder.Name = "Landmarks"
	folder.Parent = parent

	for index, landmark in HubConfig.LANDMARKS do
		local baseY = origin.Y + HubConfig.FLOOR.size.Y / 2
		local pillar = createPart(
			"Pillar" .. index,
			Vector3.new(3, landmark.height, 3),
			CFrame.new(origin + landmark.offset + Vector3.new(0, landmark.height / 2, 0)),
			landmark.color,
			Enum.Material.Neon
		)
		pillar.CanCollide = false
		pillar.Parent = folder

		local cap = createPart(
			"Cap" .. index,
			Vector3.new(5, 1, 5),
			CFrame.new(origin + landmark.offset + Vector3.new(0, landmark.height + 0.5, 0)),
			landmark.color,
			Enum.Material.Neon
		)
		cap.CanCollide = false
		cap.Parent = folder

		local light = Instance.new("PointLight")
		light.Brightness = 1.2
		light.Range = 16
		light.Color = landmark.color
		light.Parent = cap
	end
end

function HubWorldBuilder.getFolder(): Folder?
	return workspace:FindFirstChild(HUB_FOLDER_NAME)
end

function HubWorldBuilder.getSpawnCFrame(): CFrame
	local origin = HubConfig.ORIGIN
	return CFrame.new(origin + HubConfig.SPAWN_OFFSET)
end

function HubWorldBuilder.build(): Folder
	local existing = HubWorldBuilder.getFolder()
	if existing then
		return existing
	end

	local origin = HubConfig.ORIGIN
	local floorSize = HubConfig.FLOOR.size

	local hub = Instance.new("Folder")
	hub.Name = HUB_FOLDER_NAME
	hub.Parent = workspace

	local floor = createPart(
		"Floor",
		floorSize,
		CFrame.new(origin),
		HubConfig.FLOOR.color,
		HubConfig.FLOOR.material
	)
	floor.Parent = hub

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = HubWorldBuilder.getSpawnCFrame()
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Transparency = 0.35
	spawn.Color = Color3.fromRGB(120, 200, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for zoneId, zone in HubConfig.ZONES do
		local pad = createPart(
			zoneId,
			Vector3.new(zone.size.X, 1, zone.size.Z),
			CFrame.new(origin + zone.offset + Vector3.new(0, floorSize.Y / 2 + 0.5, 0)),
			zone.color,
			Enum.Material.Neon
		)
		pad.Transparency = 0.25
		pad:SetAttribute("ZoneId", zoneId)
		pad:SetAttribute("HubAction", zone.action)
		CollectionService:AddTag(pad, ZONE_TAG)
		addZoneLabel(pad, zone.label, zone.prompt)
		addProximityPrompt(pad, zone.action, zone.prompt)
		pad.Parent = zonesFolder
	end

	buildRim(hub, origin, floorSize)
	buildLandmarks(hub, origin)

	local sign = createPart(
		"WelcomeSign",
		Vector3.new(24, 8, 1),
		CFrame.new(origin + Vector3.new(0, 10, -36)),
		Color3.fromRGB(22, 26, 40),
		Enum.Material.Metal
	)
	sign.CanCollide = false
	sign.Parent = hub

	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.Parent = sign

	local signText = Instance.new("TextLabel")
	signText.Size = UDim2.fromScale(1, 1)
	signText.BackgroundTransparency = 1
	signText.Font = Enum.Font.GothamBlack
	signText.TextSize = 42
	signText.TextColor3 = Color3.fromRGB(255, 230, 120)
	signText.Text = "NOVA BLADERS"
	signText.Parent = signGui

	return hub
end

HubWorldBuilder.ZONE_TAG = ZONE_TAG

return HubWorldBuilder
