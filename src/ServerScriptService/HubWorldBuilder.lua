local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local BeyCatalog = require(ReplicatedStorage.NovaBladers.BeyCatalog)

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

local function addPrompt(part, promptConfig, name)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name or "Prompt"
	prompt.ActionText = promptConfig.ActionText
	prompt.ObjectText = promptConfig.ObjectText
	prompt.MaxActivationDistance = promptConfig.MaxActivationDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

local function addBillboard(parent, text, offsetY)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, offsetY or 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard
end

local function buildPlatform(parent)
	local floor = makePart({
		Name = "Floor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(HubConfig.PLATFORM_THICKNESS, HubConfig.PLATFORM_RADIUS * 2, HubConfig.PLATFORM_RADIUS * 2),
		CFrame = CFrame.new(0, -HubConfig.PLATFORM_THICKNESS / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = HubConfig.COLORS.Floor,
		Material = Enum.Material.Slate,
		Parent = parent,
	})

	local ring = makePart({
		Name = "CenterRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 18, 18),
		CFrame = CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = HubConfig.COLORS.FloorAccent,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
		Parent = parent,
	})

	return floor, ring
end

local function buildRailing(parent)
	local segments = 24
	local radius = HubConfig.PLATFORM_RADIUS - 1
	for i = 0, segments - 1 do
		local angle = (i / segments) * math.pi * 2
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		makePart({
			Name = "Railing_" .. i,
			Size = Vector3.new(2.5, HubConfig.RAILING_HEIGHT, 1),
			CFrame = CFrame.new(x, HubConfig.RAILING_HEIGHT / 2, z) * CFrame.Angles(0, -angle, 0),
			Color = HubConfig.COLORS.Railing,
			Material = Enum.Material.Metal,
			Transparency = 0.15,
			Parent = parent,
		})
	end
end

local function buildArenaPortal(parent)
	local zone = HubConfig.ZONES.ArenaPortal
	local portalFolder = Instance.new("Folder")
	portalFolder.Name = "ArenaPortal"
	portalFolder.Parent = parent

	local base = makePart({
		Name = "PortalBase",
		Size = Vector3.new(14, 1, 6),
		CFrame = CFrame.new(zone.X, zone.Y + 0.5, zone.Z),
		Color = HubConfig.COLORS.FloorAccent,
		Material = Enum.Material.Concrete,
		Parent = portalFolder,
	})

	local leftPillar = makePart({
		Name = "LeftPillar",
		Size = Vector3.new(1.2, 10, 1.2),
		CFrame = CFrame.new(zone.X - 5, zone.Y + 5.5, zone.Z),
		Color = HubConfig.COLORS.Portal,
		Material = Enum.Material.Neon,
		Parent = portalFolder,
	})

	local rightPillar = makePart({
		Name = "RightPillar",
		Size = Vector3.new(1.2, 10, 1.2),
		CFrame = CFrame.new(zone.X + 5, zone.Y + 5.5, zone.Z),
		Color = HubConfig.COLORS.Portal,
		Material = Enum.Material.Neon,
		Parent = portalFolder,
	})

	local arch = makePart({
		Name = "Arch",
		Size = Vector3.new(11, 1.2, 1.2),
		CFrame = CFrame.new(zone.X, zone.Y + 10.5, zone.Z),
		Color = HubConfig.COLORS.PortalGlow,
		Material = Enum.Material.Neon,
		Parent = portalFolder,
	})

	local gate = makePart({
		Name = "GateTrigger",
		Size = Vector3.new(8, 8, 4),
		CFrame = CFrame.new(zone.X, zone.Y + 5, zone.Z),
		Transparency = 1,
		CanCollide = false,
		Parent = portalFolder,
	})

	local light = Instance.new("PointLight")
	light.Color = HubConfig.COLORS.PortalGlow
	light.Brightness = 2
	light.Range = 18
	light.Parent = arch

	addBillboard(arch, "Spin-Arena", 3)
	addPrompt(gate, HubConfig.PROMPT.Arena, "ArenaPrompt")

	return portalFolder, gate
end

local function buildLeaderboardKiosk(parent)
	local zone = HubConfig.ZONES.Leaderboard
	local kioskFolder = Instance.new("Folder")
	kioskFolder.Name = "LeaderboardKiosk"
	kioskFolder.Parent = parent

	local pedestal = makePart({
		Name = "Pedestal",
		Size = Vector3.new(6, 3, 6),
		CFrame = CFrame.new(zone.X, zone.Y + 1.5, zone.Z),
		Color = HubConfig.COLORS.Kiosk,
		Material = Enum.Material.SmoothPlastic,
		Parent = kioskFolder,
	})

	local screen = makePart({
		Name = "Screen",
		Size = Vector3.new(5, 4, 0.4),
		CFrame = CFrame.new(zone.X, zone.Y + 5, zone.Z),
		Color = Color3.fromRGB(20, 28, 42),
		Material = Enum.Material.Glass,
		Parent = kioskFolder,
	})

	local trigger = makePart({
		Name = "StatsTrigger",
		Size = Vector3.new(7, 8, 7),
		CFrame = CFrame.new(zone.X, zone.Y + 4, zone.Z),
		Transparency = 1,
		CanCollide = false,
		Parent = kioskFolder,
	})

	addBillboard(screen, "Top 5 Rangliste", 2.5)
	addPrompt(trigger, HubConfig.PROMPT.Stats, "StatsPrompt")

	return kioskFolder, trigger
end

local function buildBeyGallery(parent)
	local zone = HubConfig.ZONES.BeyGallery
	local galleryFolder = Instance.new("Folder")
	galleryFolder.Name = "BeyGallery"
	galleryFolder.Parent = parent

	local platform = makePart({
		Name = "GalleryPlatform",
		Size = Vector3.new(16, 1, 10),
		CFrame = CFrame.new(zone.X, zone.Y + 0.5, zone.Z),
		Color = HubConfig.COLORS.Gallery,
		Material = Enum.Material.Marble,
		Parent = galleryFolder,
	})

	addBillboard(platform, "Bey-Auswahl", 5)

	for index, bey in ipairs(BeyCatalog) do
		local offset = (index - (#BeyCatalog + 1) / 2) * 3.5
		local pedestal = makePart({
			Name = bey.id .. "Pedestal",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.2, 2.4, 2.4),
			CFrame = CFrame.new(zone.X + offset, zone.Y + 1.8, zone.Z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = bey.color,
			Material = Enum.Material.Neon,
			Parent = galleryFolder,
		})

		local topper = makePart({
			Name = bey.id .. "Top",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.8, 1.8, 1.8),
			CFrame = CFrame.new(zone.X + offset, zone.Y + 3.4, zone.Z),
			Color = bey.color,
			Material = Enum.Material.Neon,
			Parent = galleryFolder,
		})

		addBillboard(topper, bey.name, 1.5)
	end

	return galleryFolder
end

local function buildSpawns(parent)
	local spawnsFolder = Instance.new("Folder")
	spawnsFolder.Name = "Spawns"
	spawnsFolder.Parent = parent

	local center = HubConfig.ZONES.SpawnCenter
	local offsets = {
		Vector3.new(0, 0, 0),
		Vector3.new(6, 0, -4),
		Vector3.new(-6, 0, -4),
		Vector3.new(0, 0, -8),
	}

	for index, offset in offsets do
		local spawn = Instance.new("Part")
		spawn.Name = "Spawn" .. index
		spawn.Size = Vector3.new(3, 1, 3)
		spawn.Anchored = true
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.CFrame = CFrame.new(center + offset) + Vector3.new(0, HubConfig.SPAWN_HEIGHT, 0)
		spawn.Parent = spawnsFolder
	end

	return spawnsFolder
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	buildPlatform(hub)
	buildRailing(hub)
	buildArenaPortal(hub)
	buildLeaderboardKiosk(hub)
	buildBeyGallery(hub)
	buildSpawns(hub)

	return hub
end

return HubWorldBuilder
