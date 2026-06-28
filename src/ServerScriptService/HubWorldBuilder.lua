local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local BeyCatalog = require(ReplicatedStorage.NovaBladers.BeyCatalog)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.fromRGB(60, 64, 78)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function tagZone(part, zoneName, label)
	part:SetAttribute("ZoneName", zoneName)
	part:SetAttribute("ZoneLabel", label)
	CollectionService:AddTag(part, "HubZone")
end

local function addBillboard(parent, text, offsetY)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 48)
	billboard.StudsOffset = Vector3.new(0, offsetY or 6, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(235, 240, 255)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 20
	label.Text = text
	label.Parent = billboard
end

local function addProximityPrompt(parent, actionText, objectText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Model")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local origin = HubConfig.ORIGIN
	local floor = makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		cframe = CFrame.new(origin + Vector3.new(0, -0.5, 0)),
		color = HubConfig.FLOOR_COLOR,
		material = Enum.Material.Slate,
	})
	tagZone(floor, "Floor", "Nova Hub")

	local spawnPlaza = HubConfig.ZONES.SpawnPlaza
	local plaza = makePart({
		name = "SpawnPlaza",
		parent = hub,
		size = spawnPlaza.size,
		cframe = CFrame.new(origin + spawnPlaza.center + Vector3.new(0, 0.05, 0)),
		color = Color3.fromRGB(52, 58, 74),
		material = Enum.Material.Cobblestone,
	})
	tagZone(plaza, "SpawnPlaza", spawnPlaza.label)
	addBillboard(plaza, spawnPlaza.label, 8)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(origin + HubConfig.SPAWN_OFFSET)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = HubConfig.ACCENT_COLOR
	spawn.Material = Enum.Material.Neon
	spawn.Parent = hub

	local arenaZone = HubConfig.ZONES.ArenaGate
	local gateFolder = Instance.new("Folder")
	gateFolder.Name = "ArenaGate"
	gateFolder.Parent = hub

	local gateBase = makePart({
		name = "GateBase",
		parent = gateFolder,
		size = Vector3.new(arenaZone.size.X, 2, arenaZone.size.Z),
		cframe = CFrame.new(origin + arenaZone.center + Vector3.new(0, 1, 0)),
		color = Color3.fromRGB(70, 74, 90),
	})
	tagZone(gateBase, "ArenaGate", arenaZone.label)

	local archHeight = arenaZone.size.Y
	local leftPillar = makePart({
		name = "LeftPillar",
		parent = gateFolder,
		size = Vector3.new(3, archHeight, 3),
		cframe = CFrame.new(origin + arenaZone.center + Vector3.new(-8, archHeight / 2, 0)),
		color = HubConfig.ACCENT_COLOR,
		material = Enum.Material.Metal,
	})
	local rightPillar = makePart({
		name = "RightPillar",
		parent = gateFolder,
		size = Vector3.new(3, archHeight, 3),
		cframe = CFrame.new(origin + arenaZone.center + Vector3.new(8, archHeight / 2, 0)),
		color = HubConfig.ACCENT_COLOR,
		material = Enum.Material.Metal,
	})
	local lintel = makePart({
		name = "Lintel",
		parent = gateFolder,
		size = Vector3.new(19, 2, 4),
		cframe = CFrame.new(origin + arenaZone.center + Vector3.new(0, archHeight - 1, 0)),
		color = Color3.fromRGB(120, 180, 255),
		material = Enum.Material.Neon,
	})

	addBillboard(lintel, arenaZone.label, 4)
	local arenaPrompt = addProximityPrompt(gateBase, arenaZone.promptAction, "Arena-Tor")
	arenaPrompt.Name = "ArenaEnterPrompt"

	local beyZone = HubConfig.ZONES.BeyBay
	local beyFolder = Instance.new("Folder")
	beyFolder.Name = "BeyBay"
	beyFolder.Parent = hub

	local beyPad = makePart({
		name = "BeyBayFloor",
		parent = beyFolder,
		size = beyZone.size,
		cframe = CFrame.new(origin + beyZone.center + Vector3.new(0, 0.05, 0)),
		color = Color3.fromRGB(48, 52, 66),
		material = Enum.Material.Marble,
	})
	tagZone(beyPad, "BeyBay", beyZone.label)
	addBillboard(beyPad, beyZone.label, 10)

	local beyPrompt = addProximityPrompt(beyPad, beyZone.promptAction, "Bey-Bucht")
	beyPrompt.Name = "BeySelectPrompt"

	local pedestalCount = #BeyCatalog
	local spacing = 7
	local startX = -(pedestalCount - 1) * spacing / 2
	for index, bey in BeyCatalog do
		local offset = Vector3.new(startX + (index - 1) * spacing, 0, 0)
		local pedestal = makePart({
			name = bey.id .. "Pedestal",
			parent = beyFolder,
			size = Vector3.new(4, HubConfig.PEDESTAL_HEIGHT, 4),
			cframe = CFrame.new(origin + beyZone.center + offset + Vector3.new(0, HubConfig.PEDESTAL_HEIGHT / 2, 0)),
			color = bey.color,
			material = Enum.Material.Metal,
		})

		local glow = makePart({
			name = bey.id .. "Glow",
			parent = beyFolder,
			size = Vector3.new(3.2, 0.4, 3.2),
			cframe = pedestal.CFrame * CFrame.new(0, HubConfig.PEDESTAL_HEIGHT / 2 + 0.3, 0),
			color = bey.color,
			material = Enum.Material.Neon,
			canCollide = false,
		})

		local namePlate = makePart({
			name = bey.id .. "NamePlate",
			parent = beyFolder,
			size = Vector3.new(4.5, 2.5, 0.2),
			cframe = pedestal.CFrame * CFrame.new(0, 2.5, 2.6),
			color = Color3.fromRGB(30, 32, 40),
			material = Enum.Material.SmoothPlastic,
			canCollide = false,
		})

		local surface = Instance.new("SurfaceGui")
		surface.Face = Enum.NormalId.Front
		surface.Parent = namePlate

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0.55, 0)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextColor3 = bey.color
		title.TextScaled = true
		title.Text = bey.name
		title.Parent = surface

		local subtitle = Instance.new("TextLabel")
		subtitle.Size = UDim2.new(1, 0, 0.4, 0)
		subtitle.Position = UDim2.fromScale(0, 0.55)
		subtitle.BackgroundTransparency = 1
		subtitle.Font = Enum.Font.Gotham
		subtitle.TextColor3 = Color3.fromRGB(200, 205, 220)
		subtitle.TextScaled = true
		subtitle.Text = bey.beyType
		subtitle.Parent = surface

		glow.Transparency = 0.35
	end

	local lbZone = HubConfig.ZONES.Leaderboard
	local lbFolder = Instance.new("Folder")
	lbFolder.Name = "Leaderboard"
	lbFolder.Parent = hub

	local lbBase = makePart({
		name = "LeaderboardBase",
		parent = lbFolder,
		size = Vector3.new(lbZone.size.X, 2, lbZone.size.Z),
		cframe = CFrame.new(origin + lbZone.center + Vector3.new(0, 1, 0)),
		color = Color3.fromRGB(58, 62, 76),
	})
	tagZone(lbBase, "Leaderboard", lbZone.label)

	local lbScreen = makePart({
		name = "LeaderboardScreen",
		parent = lbFolder,
		size = Vector3.new(lbZone.size.X - 2, lbZone.size.Y - 4, 0.4),
		cframe = CFrame.new(origin + lbZone.center + Vector3.new(0, lbZone.size.Y / 2, -lbZone.size.Z / 2 + 0.3)),
		color = Color3.fromRGB(20, 22, 30),
		material = Enum.Material.Glass,
		canCollide = false,
	})

	local screenGui = Instance.new("SurfaceGui")
	screenGui.Name = "HubLeaderboardGui"
	screenGui.Face = Enum.NormalId.Front
	screenGui.Parent = lbScreen

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0.18, 0)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.GothamBold
	header.TextColor3 = Color3.fromRGB(255, 215, 90)
	header.TextScaled = true
	header.Text = "🏆 Top Spieler"
	header.Parent = screenGui

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Size = UDim2.new(1, -12, 0.78, 0)
	body.Position = UDim2.new(0, 6, 0.2, 0)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Gotham
	body.TextColor3 = Color3.fromRGB(220, 225, 240)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextSize = 18
	body.TextWrapped = true
	body.Text = "Lade Rangliste..."
	body.Parent = screenGui

	addBillboard(lbScreen, lbZone.label, 6)

	for _, walkway in {
		{ size = Vector3.new(10, 0.6, 50), offset = Vector3.new(0, 0.3, 12) },
		{ size = Vector3.new(50, 0.6, 10), offset = Vector3.new(0, 0.3, -4) },
	} do
		makePart({
			name = "Walkway",
			parent = hub,
			size = walkway.size,
			cframe = CFrame.new(origin + walkway.offset),
			color = Color3.fromRGB(56, 60, 72),
			material = Enum.Material.Concrete,
		})
	end

	local light = Instance.new("PointLight")
	light.Brightness = 1.2
	light.Range = 40
	light.Color = HubConfig.ACCENT_COLOR
	light.Parent = lintel

	hub.PrimaryPart = floor
	return hub, {
		arenaPrompt = arenaPrompt,
		beyPrompt = beyPrompt,
		leaderboardBody = body,
		spawn = spawn,
	}
end

return HubWorldBuilder
