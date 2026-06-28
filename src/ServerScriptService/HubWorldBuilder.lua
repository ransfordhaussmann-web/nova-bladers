local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldBuilder = {}

local function setPartDefaults(part)
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function createFloor(parent, origin)
	local floor = Instance.new("Part")
	floor.Name = "HubFloor"
	floor.Shape = Enum.PartType.Cylinder
	floor.Size = Vector3.new(HubConfig.FLOOR_HEIGHT, HubConfig.HUB_RADIUS * 2, HubConfig.HUB_RADIUS * 2)
	floor.CFrame = CFrame.new(origin + Vector3.new(0, HubConfig.FLOOR_HEIGHT / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	floor.Color = Color3.fromRGB(45, 48, 58)
	floor.Material = Enum.Material.Slate
	setPartDefaults(floor)
	floor.Parent = parent
	return floor
end

local function createSpawnPad(parent, origin)
	local pad = Instance.new("Part")
	pad.Name = "SpawnPad"
	pad.Size = Vector3.new(14, 0.6, 14)
	pad.CFrame = CFrame.new(origin + Vector3.new(0, HubConfig.FLOOR_HEIGHT + 0.3, 0))
	pad.Color = Color3.fromRGB(70, 75, 90)
	pad.Material = Enum.Material.Neon
	pad.Transparency = 0.35
	setPartDefaults(pad)
	pad.Parent = parent

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(180, 200, 255)
	light.Brightness = 1.2
	light.Range = 18
	light.Parent = pad

	return pad
end

local function createZoneSign(zonePart, zoneData)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 60)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = zonePart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 20
	label.Text = zoneData.label
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
end

local function createZone(parent, zoneData, origin)
	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = zoneData.id
	zoneFolder.Parent = parent

	local worldPos = origin + zoneData.position + Vector3.new(0, HubConfig.FLOOR_HEIGHT, 0)

	local pad = Instance.new("Part")
	pad.Name = "ZonePad"
	pad.Size = Vector3.new(zoneData.size.X, 0.5, zoneData.size.Z)
	pad.CFrame = CFrame.new(worldPos + Vector3.new(0, 0.25, 0))
	pad.Color = zoneData.color
	pad.Material = Enum.Material.Neon
	pad.Transparency = 0.55
	setPartDefaults(pad)
	pad:SetAttribute("ZoneId", zoneData.id)
	pad.Parent = zoneFolder

	local trigger = Instance.new("Part")
	trigger.Name = "ZoneTrigger"
	trigger.Size = zoneData.size
	trigger.CFrame = CFrame.new(worldPos + Vector3.new(0, zoneData.size.Y / 2, 0))
	trigger.Transparency = 1
	trigger.CanCollide = false
	trigger.CanQuery = false
	trigger.CanTouch = false
	setPartDefaults(trigger)
	trigger:SetAttribute("ZoneId", zoneData.id)
	trigger.Parent = zoneFolder

	createZoneSign(pad, zoneData)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterPrompt"
	prompt.ActionText = "Starten"
	prompt.ObjectText = zoneData.label
	prompt.MaxActivationDistance = 12
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ZoneId", zoneData.id)
	prompt.Parent = pad

	return zoneFolder, pad, trigger
end

local function createBoundaryRing(parent, origin)
	local segments = 24
	local ringRadius = HubConfig.HUB_RADIUS - 2

	for index = 1, segments do
		local angle = (index / segments) * math.pi * 2
		local x = math.cos(angle) * ringRadius
		local z = math.sin(angle) * ringRadius

		local wall = Instance.new("Part")
		wall.Name = "Boundary_" .. index
		wall.Size = Vector3.new(6, 10, 2)
		wall.CFrame = CFrame.new(origin + Vector3.new(x, 5, z)) * CFrame.Angles(0, -angle, 0)
		wall.Color = Color3.fromRGB(35, 38, 48)
		wall.Material = Enum.Material.Metal
		wall.Transparency = 0.15
		setPartDefaults(wall)
		wall.Parent = parent
	end
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaBladersHub")
	if existing then
		existing:Destroy()
	end

	local hubModel = Instance.new("Model")
	hubModel.Name = "NovaBladersHub"
	hubModel.Parent = workspace

	local origin = HubConfig.HUB_ORIGIN

	createFloor(hubModel, origin)
	createSpawnPad(hubModel, origin)

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hubModel

	local zoneTriggers = {}
	for _, zoneData in HubConfig.ZONES do
		local _, _, trigger = createZone(zonesFolder, zoneData, origin)
		zoneTriggers[zoneData.id] = trigger
	end

	local boundaries = Instance.new("Folder")
	boundaries.Name = "Boundaries"
	boundaries.Parent = hubModel
	createBoundaryRing(boundaries, origin)

	hubModel:SetAttribute("Built", true)
	return hubModel, zoneTriggers
end

return HubWorldBuilder
