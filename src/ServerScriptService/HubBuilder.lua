local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Name = props.name or "Part"
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.new(1, 1, 1)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Transparency = props.transparency or 0
	part.Parent = props.parent
	return part
end

local function addBillboard(parent, title, subtitle, color)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ZoneLabel"
	gui.Size = UDim2.fromOffset(220, 80)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 22
	titleLabel.TextColor3 = color
	titleLabel.Text = title
	titleLabel.Parent = gui

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "Subtitle"
	subLabel.Position = UDim2.fromScale(0, 0.55)
	subLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextSize = 14
	subLabel.TextColor3 = Color3.fromRGB(210, 215, 230)
	subLabel.Text = subtitle
	subLabel.Parent = gui
end

local function buildFloor(parent)
	local floor = makePart({
		name = "Floor",
		parent = parent,
		size = Vector3.new(HubConfig.FLOOR.radius * 2, HubConfig.FLOOR.thickness, HubConfig.FLOOR.radius * 2),
		cframe = CFrame.new(0, HubConfig.FLOOR.thickness / 2, 0),
		color = HubConfig.FLOOR.color,
		material = HubConfig.FLOOR.material,
	})
	floor.Shape = Enum.PartType.Cylinder
	floor.Orientation = Vector3.new(0, 0, 90)
	return floor
end

local function buildRim(parent, radius)
	local segments = 24
	local rim = Instance.new("Model")
	rim.Name = "Rim"
	rim.Parent = parent

	for i = 0, segments - 1 do
		local angle = (i / segments) * math.pi * 2
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		local width = (2 * math.pi * radius) / segments + 0.4

		makePart({
			name = "RimSegment",
			parent = rim,
			size = Vector3.new(width, HubConfig.RIM.height, HubConfig.RIM.thickness),
			cframe = CFrame.lookAt(Vector3.new(x, HubConfig.RIM.height / 2 + HubConfig.FLOOR.thickness, z), Vector3.new(x, 0, z) + tangent),
			color = HubConfig.RIM.color,
			material = HubConfig.RIM.material,
			transparency = 0.15,
		})
	end
end

local function buildSpawn(parent)
	local spawn = makePart({
		name = "Spawn",
		parent = parent,
		size = Vector3.new(8, 0.4, 8),
		cframe = CFrame.new(HubConfig.SPAWN_OFFSET),
		color = Color3.fromRGB(120, 200, 255),
		material = Enum.Material.Neon,
		transparency = 0.35,
		canCollide = false,
	})

	local ring = makePart({
		name = "SpawnRing",
		parent = spawn,
		size = Vector3.new(10, 0.2, 10),
		cframe = CFrame.new(0, 0.3, 0),
		color = Color3.fromRGB(80, 160, 255),
		material = Enum.Material.Neon,
		transparency = 0.5,
		canCollide = false,
	})
	ring.Shape = Enum.PartType.Cylinder
	ring.Orientation = Vector3.new(0, 0, 90)

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(120, 180, 255)
	light.Brightness = 2
	light.Range = 18
	light.Parent = spawn

	addBillboard(spawn, "Nova Hub", "Willkommen, Blader!", Color3.fromRGB(140, 200, 255))
	return spawn
end

local function buildZone(parent, zone)
	local model = Instance.new("Model")
	model.Name = zone.id
	model.Parent = parent

	local platform = makePart({
		name = "Platform",
		parent = model,
		size = Vector3.new(zone.size.X, 1, zone.size.Z),
		cframe = CFrame.new(zone.position.X, zone.position.Y - zone.size.Y / 2 + 0.5, zone.position.Z),
		color = zone.color,
		material = Enum.Material.SmoothPlastic,
	})

	local marker = makePart({
		name = "Marker",
		parent = model,
		size = zone.size,
		cframe = CFrame.new(zone.position),
		color = zone.color,
		material = Enum.Material.Neon,
		transparency = 0.82,
		canCollide = false,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zone.label
	prompt.ObjectText = zone.hint
	prompt.MaxActivationDistance = HubConfig.PROXIMITY.maxActivationDistance
	prompt.HoldDuration = HubConfig.PROXIMITY.holdDuration
	prompt.RequiresLineOfSight = false
	prompt.Parent = marker

	marker:SetAttribute("ZoneId", zone.id)
	marker:SetAttribute("ZoneAction", zone.action)
	CollectionService:AddTag(marker, "HubZone")

	local zoneLight = Instance.new("PointLight")
	zoneLight.Color = zone.color
	zoneLight.Brightness = 1.4
	zoneLight.Range = 14
	zoneLight.Parent = marker

	addBillboard(marker, zone.label, zone.hint, zone.color)
	return model
end

local function applyLighting()
	local lighting = game:GetService("Lighting")
	lighting.Ambient = HubConfig.LIGHTING.ambient
	lighting.Brightness = HubConfig.LIGHTING.brightness
	lighting.ClockTime = HubConfig.LIGHTING.clockTime
end

function HubBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.ROOT_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Model")
	hub.Name = HubConfig.ROOT_NAME
	hub.Parent = workspace

	buildFloor(hub)
	buildRim(hub, HubConfig.FLOOR.radius - 1)
	buildSpawn(hub)

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		buildZone(zonesFolder, zone)
	end

	applyLighting()
	return hub
end

return HubBuilder
