local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldBuilder = {}

local FOLDER_NAME = "NovaBladersHub"

local function anchor(part)
	part.Anchored = true
	part.CanCollide = true
	return part
end

local function makePart(props)
	local part = Instance.new("Part")
	part.Size = props.size or Vector3.new(4, 1, 4)
	part.CFrame = props.cframe or CFrame.new(HubConfig.HUB_ORIGIN)
	part.Color = props.color or Color3.fromRGB(60, 65, 80)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Transparency = props.transparency or 0
	part.Name = props.name or "Part"
	return anchor(part)
end

local function addBillboard(parent, text, color)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ZoneLabel"
	gui.Size = UDim2.fromOffset(200, 60)
	gui.StudsOffset = Vector3.new(0, 6, 0)
	gui.AlwaysOnTop = false
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	label.TextColor3 = color
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = text
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	return gui
end

function HubWorldBuilder.getFolder()
	return workspace:FindFirstChild(FOLDER_NAME)
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(FOLDER_NAME)
	if existing then
		return existing
	end

	local origin = HubConfig.HUB_ORIGIN
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = workspace

	-- Hauptplattform
	local platform = makePart({
		name = "Platform",
		size = Vector3.new(HubConfig.PLATFORM_RADIUS * 2, HubConfig.PLATFORM_HEIGHT, HubConfig.PLATFORM_RADIUS * 2),
		cframe = CFrame.new(origin + Vector3.new(0, HubConfig.PLATFORM_HEIGHT / 2, 0)),
		color = Color3.fromRGB(45, 50, 62),
		material = Enum.Material.Slate,
	})
	platform.Shape = Enum.PartType.Cylinder
	platform.Parent = folder

	-- Spawn-Pad in der Mitte
	local spawnPad = makePart({
		name = "SpawnPad",
		size = Vector3.new(14, 1, 14),
		cframe = CFrame.new(origin + Vector3.new(0, HubConfig.PLATFORM_HEIGHT + 0.5, 0)),
		color = Color3.fromRGB(70, 75, 95),
		material = Enum.Material.Neon,
		transparency = 0.15,
	})
	spawnPad.Parent = folder

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(origin + HubConfig.SPAWN_OFFSET)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Parent = folder

	-- Randring als visuelle Begrenzung
	local ring = makePart({
		name = "EdgeRing",
		size = Vector3.new(HubConfig.PLATFORM_RADIUS * 2 + 4, 1.2, HubConfig.PLATFORM_RADIUS * 2 + 4),
		cframe = CFrame.new(origin + Vector3.new(0, HubConfig.PLATFORM_HEIGHT + 0.1, 0)),
		color = Color3.fromRGB(100, 110, 140),
		material = Enum.Material.Neon,
		transparency = 0.4,
	})
	ring.Shape = Enum.PartType.Cylinder
	ring.CanCollide = false
	ring.Parent = folder

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = folder

	for zoneId, zone in HubConfig.ZONES do
		local zoneOrigin = origin + zone.position + Vector3.new(0, HubConfig.PLATFORM_HEIGHT, 0)

		local disc = makePart({
			name = zoneId,
			size = Vector3.new(zone.radius * 2, 0.6, zone.radius * 2),
			cframe = CFrame.new(zoneOrigin),
			color = zone.color,
			material = Enum.Material.Neon,
			transparency = 0.55,
		})
		disc.Shape = Enum.PartType.Cylinder
		disc.CanCollide = false
		disc:SetAttribute("ZoneId", zoneId)
		disc.Parent = zonesFolder

		local marker = makePart({
			name = zoneId .. "Marker",
			size = Vector3.new(2, 8, 2),
			cframe = CFrame.new(zoneOrigin + Vector3.new(0, 4, 0)),
			color = zone.color,
			material = Enum.Material.Neon,
			transparency = 0.2,
		})
		marker.CanCollide = false
		marker.Parent = zonesFolder

		addBillboard(marker, zone.label, zone.color)

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "EnterPrompt"
		prompt.ActionText = "Arena betreten"
		prompt.ObjectText = zone.label
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = zone.radius
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("ZoneId", zoneId)
		prompt.Parent = disc
	end

	-- Ambient-Licht über dem Hub
	local light = Instance.new("PointLight")
	light.Brightness = 1.2
	light.Range = HubConfig.PLATFORM_RADIUS * 1.5
	light.Color = Color3.fromRGB(180, 200, 255)
	light.Parent = spawnPad

	return folder
end

return HubWorldBuilder
