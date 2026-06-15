--[[
	Baut die begehbare 3D-Hub-Welt in Workspace.NovaHub.
	Wird einmalig vom HubManager auf dem Server aufgerufen.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldBuilder = {}

local function setPartDefaults(part: BasePart)
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function createPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	setPartDefaults(part)
	part.Parent = parent
	return part
end

local function addNeonRing(parent: Instance, name: string, center: Vector3, innerR: number, outerR: number, height: number, color: Color3)
	local segments = 24
	local midR = (innerR + outerR) * 0.5
	local thickness = outerR - innerR
	for i = 0, segments - 1 do
		local angle = (i / segments) * math.pi * 2
		local x = math.cos(angle) * midR
		local z = math.sin(angle) * midR
		local part = createPart(
			parent,
			name .. "_" .. i,
			Vector3.new(thickness + 0.5, height, 2.5),
			CFrame.new(center + Vector3.new(x, height * 0.5, z)) * CFrame.Angles(0, -angle, 0),
			color,
			Enum.Material.Neon
		)
		part.Transparency = 0.15
	end
end

local function addSign(parent: Instance, anchor: BasePart, title: string, subtitle: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Size = UDim2.fromOffset(220, 72)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = anchor

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(18, 20, 32)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -12, 0, 34)
	titleLabel.Position = UDim2.fromOffset(6, 4)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 20
	titleLabel.TextColor3 = Color3.fromRGB(240, 244, 255)
	titleLabel.Text = title
	titleLabel.Parent = frame

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "Subtitle"
	subLabel.Size = UDim2.new(1, -12, 0, 28)
	subLabel.Position = UDim2.fromOffset(6, 38)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextSize = 14
	subLabel.TextColor3 = Color3.fromRGB(170, 180, 210)
	subLabel.Text = subtitle
	subLabel.TextWrapped = true
	subLabel.Parent = frame
end

local function addZonePad(folder: Instance, zoneKey: string, zone)
	local worldPos = HubConfig.getZoneWorldPosition(zoneKey)
	local pad = createPart(
		folder,
		zone.id .. "Pad",
		zone.padSize,
		CFrame.new(worldPos + Vector3.new(0, zone.padSize.Y * 0.5 + 1.2, 0)),
		zone.padColor,
		Enum.Material.SmoothPlastic
	)
	pad.Transparency = 0.08

	local promptAnchor = createPart(
		folder,
		zone.id .. "Prompt",
		Vector3.new(4, 4, 4),
		CFrame.new(worldPos + Vector3.new(0, 3.5, 0)),
		zone.padColor,
		Enum.Material.Neon
	)
	promptAnchor.Transparency = 1
	promptAnchor.CanCollide = false

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = zone.prompt
	prompt.ObjectText = zone.label
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("HubZoneId", zone.id)
	prompt:SetAttribute("HubAction", zone.action)
	prompt.Parent = promptAnchor

	local pillar = createPart(
		folder,
		zone.id .. "Pillar",
		Vector3.new(HubConfig.PILLAR.radius * 2, HubConfig.PILLAR.height, HubConfig.PILLAR.radius * 2),
		CFrame.new(worldPos + Vector3.new(0, HubConfig.PILLAR.height * 0.5 + 1.5, 0)),
		HubConfig.PILLAR.color,
		Enum.Material.Concrete
	)
	pillar.Shape = Enum.PartType.Cylinder
	pillar.CFrame = CFrame.new(worldPos + Vector3.new(0, HubConfig.PILLAR.height * 0.5 + 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90))

	local light = Instance.new("PointLight")
	light.Color = zone.padColor
	light.Brightness = 1.2
	light.Range = 18
	light.Parent = pillar

	addSign(folder, pillar, zone.label, zone.hint)

	local padTag = Instance.new("StringValue")
	padTag.Name = "ZoneId"
	padTag.Value = zone.id
	padTag.Parent = pad
end

local function applyAmbient()
	Lighting.ClockTime = HubConfig.AMBIENT.clockTime
	Lighting.Brightness = HubConfig.AMBIENT.brightness
	Lighting.FogColor = HubConfig.AMBIENT.fogColor
	Lighting.FogStart = HubConfig.AMBIENT.fogStart
	Lighting.FogEnd = HubConfig.AMBIENT.fogEnd
	Lighting.GlobalShadows = true
end

function HubWorldBuilder.build(): Folder
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		existing:Destroy()
	end

	applyAmbient()

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local origin = HubConfig.ORIGIN

	createPart(
		hub,
		"Floor",
		HubConfig.FLOOR.size,
		CFrame.new(origin + Vector3.new(0, -HubConfig.FLOOR.size.Y * 0.5, 0)),
		HubConfig.FLOOR.color,
		HubConfig.FLOOR.material
	)

	local plazaY = 1 + HubConfig.PLAZA.height * 0.5
	createPart(
		hub,
		"Plaza",
		Vector3.new(HubConfig.PLAZA.radius * 2, HubConfig.PLAZA.height, HubConfig.PLAZA.radius * 2),
		CFrame.new(origin + Vector3.new(0, plazaY, 0)),
		HubConfig.PLAZA.color,
		HubConfig.PLAZA.material
	)

	addNeonRing(
		hub,
		"PlazaRing",
		origin + Vector3.new(0, plazaY + 0.3, 0),
		HubConfig.RING.innerRadius,
		HubConfig.RING.outerRadius,
		HubConfig.RING.height,
		HubConfig.NEON_ACCENT
	)

	for zoneKey, zone in pairs(HubConfig.ZONES) do
		addZonePad(hub, zoneKey, zone)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = HubConfig.getSpawnCFrame()
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hub

	local welcome = createPart(
		hub,
		"WelcomeMonolith",
		Vector3.new(3, 10, 3),
		CFrame.new(origin + Vector3.new(0, 6, 8)),
		Color3.fromRGB(50, 58, 86),
		Enum.Material.Metal
	)
	addSign(hub, welcome, "Nova Bladers", "Wähle eine Zone auf der Plaza")

	local bounds = Instance.new("Part")
	bounds.Name = "HubBounds"
	bounds.Size = Vector3.new(120, 40, 120)
	bounds.CFrame = CFrame.new(origin + Vector3.new(0, 20, 0))
	bounds.Anchored = true
	bounds.Transparency = 1
	bounds.CanCollide = false
	bounds.Parent = hub

	return hub
end

return HubWorldBuilder
