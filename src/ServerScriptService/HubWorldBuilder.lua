local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldBuilder = {}

local function setPart(part, props)
	for key, value in props do
		part[key] = value
	end
end

local function makePart(parent, name, props)
	local part = Instance.new("Part")
	part.Name = name
	setPart(part, props)
	part.Parent = parent
	return part
end

local function makeWedgeRing(parent, radius, y, color)
	local segments = 24
	for i = 0, segments - 1 do
		local angle = (i / segments) * math.pi * 2
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		makePart(parent, "Ring_" .. i, {
			Size = Vector3.new(4, 1.2, 2),
			CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, -angle + math.pi / 2, 0),
			Color = color,
			Material = Enum.Material.Metal,
			Anchored = true,
			CanCollide = true,
		})
	end
end

local function addBillboard(parent, title, subtitle, color)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(220, 80)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = color
	titleLabel.TextScaled = true
	titleLabel.Text = title
	titleLabel.Parent = gui

	if subtitle then
		local subLabel = Instance.new("TextLabel")
		subLabel.Name = "Subtitle"
		subLabel.Position = UDim2.fromScale(0, 0.55)
		subLabel.Size = UDim2.new(1, 0, 0.45, 0)
		subLabel.BackgroundTransparency = 1
		subLabel.Font = Enum.Font.Gotham
		subLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
		subLabel.TextScaled = true
		subLabel.Text = subtitle
		subLabel.Parent = gui
	end
end

local function addProximityPrompt(parent, actionText, objectText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = actionText
	prompt.ObjectText = objectText or "Nova Hub"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("HubAction", actionText)
	prompt.Parent = parent
	return prompt
end

local function buildArenaGate(parent, zone)
	local gateFolder = Instance.new("Folder")
	gateFolder.Name = "ArenaGate"
	gateFolder.Parent = parent

	local arch = makePart(gateFolder, "PortalFrame", {
		Size = zone.size,
		CFrame = CFrame.new(zone.position),
		Color = HubConfig.COLORS.portal,
		Material = Enum.Material.Neon,
		Anchored = true,
		CanCollide = false,
		Transparency = 0.15,
	})
	arch:SetAttribute("HubZone", "ArenaGate")

	local leftPillar = makePart(gateFolder, "LeftPillar", {
		Size = Vector3.new(2, zone.size.Y + 4, 2),
		CFrame = CFrame.new(zone.position + Vector3.new(-zone.size.X / 2 - 1, -1, 0)),
		Color = HubConfig.COLORS.railing,
		Material = Enum.Material.Metal,
		Anchored = true,
		CanCollide = true,
	})

	local rightPillar = makePart(gateFolder, "RightPillar", {
		Size = Vector3.new(2, zone.size.Y + 4, 2),
		CFrame = CFrame.new(zone.position + Vector3.new(zone.size.X / 2 + 1, -1, 0)),
		Color = HubConfig.COLORS.railing,
		Material = Enum.Material.Metal,
		Anchored = true,
		CanCollide = true,
	})

	local trigger = makePart(gateFolder, "Trigger", {
		Size = Vector3.new(zone.size.X, zone.size.Y, 6),
		CFrame = CFrame.new(zone.position),
		Transparency = 1,
		Anchored = true,
		CanCollide = false,
	})
	trigger:SetAttribute("HubZone", "ArenaGate")

	local light = Instance.new("PointLight")
	light.Color = HubConfig.COLORS.portalGlow
	light.Brightness = 2
	light.Range = 20
	light.Parent = arch

	addBillboard(arch, "Arena-Tor", "Betrete die Spin-Arena", HubConfig.COLORS.portalGlow)
	addProximityPrompt(trigger, zone.promptAction, zone.promptText)

	return gateFolder
end

local function buildForge(parent, zone)
	local forge = makePart(parent, "BeyForge", {
		Size = zone.size,
		CFrame = CFrame.new(zone.position),
		Color = HubConfig.COLORS.forge,
		Material = Enum.Material.SmoothPlastic,
		Anchored = true,
		CanCollide = true,
	})
	forge:SetAttribute("HubZone", "BeyForge")
	addBillboard(forge, zone.label, zone.subtitle, HubConfig.COLORS.forge)
	addProximityPrompt(forge, "OpenBeySelect", zone.label)
	return forge
end

local function buildLeaderboardMonument(parent, zone)
	local monument = makePart(parent, "LeaderboardMonument", {
		Size = zone.size,
		CFrame = CFrame.new(zone.position),
		Color = HubConfig.COLORS.leaderboard,
		Material = Enum.Material.Marble,
		Anchored = true,
		CanCollide = true,
	})
	monument:SetAttribute("HubZone", "Leaderboard")

	local surface = Instance.new("SurfaceGui")
	surface.Name = "BoardGui"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.Parent = monument

	local label = Instance.new("TextLabel")
	label.Name = "BoardText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 35)
	label.BackgroundTransparency = 0.2
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(240, 240, 250)
	label.TextSize = 22
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = zone.label .. "\nLädt..."
	label.Parent = surface

	addBillboard(monument, zone.label, "Top 5 Spieler", HubConfig.COLORS.leaderboard)
	return monument
end

local function buildTrainingPad(parent, zone)
	local pad = makePart(parent, "TrainingPad", {
		Size = zone.size,
		CFrame = CFrame.new(zone.position),
		Color = HubConfig.COLORS.training,
		Material = Enum.Material.Grass,
		Anchored = true,
		CanCollide = true,
	})
	pad:SetAttribute("HubZone", "TrainingInfo")
	addBillboard(pad, zone.label, "1 Spieler = Training | 2 = 1v1 | 3+ = FFA", HubConfig.COLORS.training)
	return pad
end

local function applyLighting()
	Lighting.ClockTime = HubConfig.CLOCK_TIME
	Lighting.Brightness = HubConfig.BRIGHTNESS
	Lighting.Ambient = HubConfig.AMBIENT
	Lighting.OutdoorAmbient = HubConfig.OUTDOOR_AMBIENT
	Lighting.GlobalShadows = true

	if not Lighting:FindFirstChild("HubAtmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "HubAtmosphere"
		atmosphere.Density = 0.32
		atmosphere.Offset = 0.15
		atmosphere.Color = Color3.fromRGB(120, 140, 200)
		atmosphere.Decay = Color3.fromRGB(60, 70, 110)
		atmosphere.Glare = 0.1
		atmosphere.Haze = 1.2
		atmosphere.Parent = Lighting
	end
end

function HubWorldBuilder.getOrCreate()
	local existing = workspace:FindFirstChild(HubConfig.ROOT_NAME)
	if existing then
		return existing
	end
	return HubWorldBuilder.build()
end

function HubWorldBuilder.build()
	local hub = Instance.new("Folder")
	hub.Name = HubConfig.ROOT_NAME
	hub.Parent = workspace

	local geometry = Instance.new("Folder")
	geometry.Name = "Geometry"
	geometry.Parent = hub

	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = hub

	makePart(geometry, "Floor", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(HubConfig.FLOOR_THICKNESS, HubConfig.FLOOR_RADIUS * 2, HubConfig.FLOOR_RADIUS * 2),
		CFrame = CFrame.new(0, HubConfig.FLOOR_THICKNESS / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = HubConfig.COLORS.floor,
		Material = Enum.Material.Slate,
		Anchored = true,
		CanCollide = true,
	})

	makePart(geometry, "FloorAccent", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, (HubConfig.FLOOR_RADIUS - 4) * 2, (HubConfig.FLOOR_RADIUS - 4) * 2),
		CFrame = CFrame.new(0, HubConfig.FLOOR_THICKNESS + 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = HubConfig.COLORS.floorAccent,
		Material = Enum.Material.Neon,
		Anchored = true,
		CanCollide = false,
		Transparency = 0.6,
	})

	makeWedgeRing(geometry, HubConfig.FLOOR_RADIUS - 1, 1.6, HubConfig.COLORS.railing)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = HubConfig.SPAWN_CFRAME
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = geometry

	buildArenaGate(zones, HubConfig.ARENA_GATE)
	buildForge(zones, HubConfig.BEY_FORGE)
	buildLeaderboardMonument(zones, HubConfig.LEADERBOARD)
	buildTrainingPad(zones, HubConfig.TRAINING_PAD)

	applyLighting()
	return hub
end

function HubWorldBuilder.updateLeaderboardBoard(hub, lines)
	local monument = hub:FindFirstChild("Zones")
		and hub.Zones:FindFirstChild("LeaderboardMonument")
	if not monument then return end
	local board = monument:FindFirstChild("BoardGui")
		and monument.BoardGui:FindFirstChild("BoardText")
	if board then
		board.Text = table.concat(lines, "\n")
	end
end

return HubWorldBuilder
