local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Color = props.Color or Color3.fromRGB(40, 44, 58)
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Name = props.Name or "Part"
	part.Transparency = props.Transparency or 0
	part.Parent = props.Parent
	return part
end

local function makeNeonRing(parent, center, radius, color)
	local ring = makePart({
		Name = "NeonRing",
		Parent = parent,
		Size = Vector3.new(0.4, radius * 2, radius * 2),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = color,
		CanCollide = false,
	})
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.35
	return ring
end

local function makeZoneMarker(parent, zoneName, zoneDef, worldPos)
	local folder = Instance.new("Folder")
	folder.Name = zoneName
	folder.Parent = parent

	local pad = makePart({
		Name = "Pad",
		Parent = folder,
		Size = zoneDef.size,
		CFrame = CFrame.new(worldPos + Vector3.new(0, zoneDef.size.Y / 2, 0)),
		Color = Color3.fromRGB(55, 60, 80),
		Material = Enum.Material.Slate,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zoneDef.label
	prompt.ObjectText = zoneDef.hint
	prompt.MaxActivationDistance = math.max(zoneDef.size.X, zoneDef.size.Z) * 0.6 + 4
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, zoneDef.size.Y / 2 + 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = pad

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(220, 230, 255)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 18
	label.Text = zoneDef.label
	label.Parent = billboard

	return folder, pad, prompt
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		return existing
	end

	local origin = HubConfig.ORIGIN
	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local floor = makePart({
		Name = "HubFloor",
		Parent = hub,
		Size = Vector3.new(HubConfig.PLATFORM_HEIGHT, HubConfig.PLATFORM_RADIUS * 2, HubConfig.PLATFORM_RADIUS * 2),
		CFrame = CFrame.new(origin) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(32, 36, 48),
		Material = Enum.Material.Concrete,
	})

	local accent = makePart({
		Name = "HubAccent",
		Parent = hub,
		Size = Vector3.new(0.3, HubConfig.PLATFORM_RADIUS * 1.6, HubConfig.PLATFORM_RADIUS * 1.6),
		CFrame = CFrame.new(origin + Vector3.new(0, HubConfig.PLATFORM_HEIGHT / 2 + 0.05, 0))
			* CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(90, 120, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	accent.Transparency = 0.7

	makeNeonRing(hub, origin + Vector3.new(0, 0.2, 0), HubConfig.PLATFORM_RADIUS - 2, Color3.fromRGB(100, 140, 255))

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	local zones = {}
	for zoneName, zoneDef in HubConfig.ZONES do
		local worldPos = origin + zoneDef.offset
		local folder, pad, prompt = makeZoneMarker(zonesFolder, zoneName, zoneDef, worldPos)
		zones[zoneName] = { folder = folder, pad = pad, prompt = prompt }
	end

	local gateZone = zones.ArenaGate
	if gateZone then
		local gateFrame = makePart({
			Name = "GateFrame",
			Parent = gateZone.folder,
			Size = Vector3.new(1.2, 10, 14),
			CFrame = CFrame.new(origin + HubConfig.ZONES.ArenaGate.offset + Vector3.new(0, 5, -3)),
			Color = Color3.fromRGB(70, 90, 200),
			Material = Enum.Material.Metal,
		})
		local gatePortal = makePart({
			Name = "GatePortal",
			Parent = gateZone.folder,
			Size = Vector3.new(0.5, 8, 10),
			CFrame = CFrame.new(origin + HubConfig.ZONES.ArenaGate.offset + Vector3.new(0, 4, 0)),
			Color = Color3.fromRGB(120, 180, 255),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		gatePortal.Transparency = 0.4

		local portalLight = Instance.new("PointLight")
		portalLight.Color = Color3.fromRGB(120, 180, 255)
		portalLight.Brightness = 2
		portalLight.Range = 16
		portalLight.Parent = gatePortal
	end

	local spawns = Instance.new("Folder")
	spawns.Name = "SpawnPoints"
	spawns.Parent = hub

	for i, offset in HubConfig.SPAWN_POINTS do
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn" .. i
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.CFrame = CFrame.new(origin + offset + Vector3.new(0, HubConfig.PLATFORM_HEIGHT / 2 + 0.5, 0))
		spawn.Anchored = true
		spawn.CanCollide = false
		spawn.Neutral = true
		spawn.Transparency = 1
		spawn.Duration = 0
		spawn.Parent = spawns
	end

	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2
		local dist = HubConfig.PLATFORM_RADIUS - 4
		local pillarPos = origin + Vector3.new(math.sin(angle) * dist, 4, math.cos(angle) * dist)
		makePart({
			Name = "Pillar" .. i,
			Parent = hub,
			Size = Vector3.new(2, 8, 2),
			CFrame = CFrame.new(pillarPos),
			Color = Color3.fromRGB(50, 54, 70),
			Material = Enum.Material.Marble,
		})
	end

	local titleBoard = makePart({
		Name = "TitleBoard",
		Parent = hub,
		Size = Vector3.new(1, 6, 20),
		CFrame = CFrame.new(origin + Vector3.new(0, 5, HubConfig.PLATFORM_RADIUS - 2)),
		Color = Color3.fromRGB(25, 28, 38),
		Material = Enum.Material.SmoothPlastic,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.Parent = titleBoard

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextColor3 = Color3.fromRGB(140, 180, 255)
	title.TextSize = 48
	title.Text = "NOVA BLADERS"
	title.Parent = surface

	hub:SetAttribute("Built", true)
	return hub, zones
end

function HubWorldBuilder.getSpawnCFrame(index)
	local origin = HubConfig.ORIGIN
	local offset = HubConfig.SPAWN_POINTS[index] or HubConfig.SPAWN_POINTS[1]
	return CFrame.new(origin + offset + Vector3.new(0, 4, 0))
end

return HubWorldBuilder
