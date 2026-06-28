local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Color = props.Color or HubConfig.PLATFORM_COLOR
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Name = props.Name or "Part"
	part.Transparency = props.Transparency or 0
	if props.Shape then
		part.Shape = props.Shape
	end
	part.Parent = props.Parent
	return part
end

local function buildPlatform(model, origin)
	local platform = makePart({
		Name = "Platform",
		Size = HubConfig.PLATFORM_SIZE,
		CFrame = CFrame.new(origin + Vector3.new(0, -1, 0)),
		Material = Enum.Material.Slate,
		Color = HubConfig.PLATFORM_COLOR,
		Parent = model,
	})

	local trim = makePart({
		Name = "PlatformTrim",
		Size = Vector3.new(
			HubConfig.PLATFORM_SIZE.X + 2,
			0.4,
			HubConfig.PLATFORM_SIZE.Z + 2
		),
		CFrame = platform.CFrame * CFrame.new(0, HubConfig.PLATFORM_SIZE.Y / 2 + 0.2, 0),
		Material = Enum.Material.Neon,
		Color = HubConfig.ACCENT_COLOR,
		Parent = model,
	})

	return platform, trim
end

local function buildArenaGate(model, origin)
	local gateFolder = Instance.new("Folder")
	gateFolder.Name = "ArenaGate"
	gateFolder.Parent = model

	local gatePos = origin + Vector3.new(0, 0, 28)
	local pillarSize = Vector3.new(3, 14, 3)

	makePart({
		Name = "GatePillarLeft",
		Size = pillarSize,
		CFrame = CFrame.new(gatePos + Vector3.new(-7, 7, 0)),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(50, 55, 70),
		Parent = gateFolder,
	})

	makePart({
		Name = "GatePillarRight",
		Size = pillarSize,
		CFrame = CFrame.new(gatePos + Vector3.new(7, 7, 0)),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(50, 55, 70),
		Parent = gateFolder,
	})

	local lintel = makePart({
		Name = "GateLintel",
		Size = Vector3.new(17, 2.5, 3),
		CFrame = CFrame.new(gatePos + Vector3.new(0, 14.5, 0)),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(50, 55, 70),
		Parent = gateFolder,
	})

	local glow = makePart({
		Name = "GateGlow",
		Size = Vector3.new(12, 10, 1),
		CFrame = CFrame.new(gatePos + Vector3.new(0, 7, 0.5)),
		Material = Enum.Material.Neon,
		Color = HubConfig.GLOW_COLOR,
		Transparency = 0.35,
		CanCollide = false,
		Parent = gateFolder,
	})
	glow:SetAttribute("PulseGlow", true)

	local light = Instance.new("PointLight")
	light.Color = HubConfig.GLOW_COLOR
	light.Brightness = 2
	light.Range = 18
	light.Parent = glow

	local sign = makePart({
		Name = "GateSign",
		Size = Vector3.new(10, 2, 0.5),
		CFrame = CFrame.new(gatePos + Vector3.new(0, 16.5, 0)),
		Material = Enum.Material.Neon,
		Color = HubConfig.ACCENT_COLOR,
		CanCollide = false,
		Parent = gateFolder,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.AlwaysOnTop = true
	billboard.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Text = "ARENA"
	label.Parent = billboard

	return gateFolder
end

local function buildBeyLab(model, origin)
	local labFolder = Instance.new("Folder")
	labFolder.Name = "BeyLab"
	labFolder.Parent = model

	local labPos = origin + Vector3.new(-28, 0, -12)

	makePart({
		Name = "LabPad",
		Size = Vector3.new(18, 1, 18),
		CFrame = CFrame.new(labPos + Vector3.new(0, 0.5, 0)),
		Material = Enum.Material.Glass,
		Color = Color3.fromRGB(40, 60, 90),
		Transparency = 0.3,
		Parent = labFolder,
	})

	local pedestalOffsets = {
		Vector3.new(-4, 0, -4),
		Vector3.new(4, 0, -4),
		Vector3.new(-4, 0, 4),
		Vector3.new(4, 0, 4),
	}

	for i, offset in pedestalOffsets do
		makePart({
			Name = "Pedestal" .. i,
			Size = Vector3.new(2.5, 3, 2.5),
			CFrame = CFrame.new(labPos + offset + Vector3.new(0, 2, 0)),
			Material = Enum.Material.Metal,
			Color = HubConfig.ACCENT_COLOR,
			Parent = labFolder,
		})
	end

	local sign = makePart({
		Name = "LabSign",
		Size = Vector3.new(8, 2, 0.5),
		CFrame = CFrame.new(labPos + Vector3.new(0, 6, -8)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 200, 60),
		CanCollide = false,
		Parent = labFolder,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(180, 44)
	billboard.AlwaysOnTop = true
	billboard.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Text = "BEY-LABOR"
	label.Parent = billboard

	return labFolder
end

local function buildHallOfFame(model, origin)
	local hallFolder = Instance.new("Folder")
	hallFolder.Name = "HallOfFame"
	hallFolder.Parent = model

	local hallPos = origin + Vector3.new(28, 0, -12)

	for i = -1, 1, 2 do
		makePart({
			Name = "Column" .. (i == -1 and "Left" or "Right"),
			Size = Vector3.new(2.5, 10, 2.5),
			CFrame = CFrame.new(hallPos + Vector3.new(i * 5, 5, 0)),
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(200, 180, 120),
			Parent = hallFolder,
		})
	end

	makePart({
		Name = "Monument",
		Size = Vector3.new(10, 1, 6),
		CFrame = CFrame.new(hallPos + Vector3.new(0, 1, 0)),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(180, 160, 100),
		Parent = hallFolder,
	})

	local trophy = makePart({
		Name = "Trophy",
		Size = Vector3.new(3, 5, 3),
		Shape = Enum.PartType.Ball,
		CFrame = CFrame.new(hallPos + Vector3.new(0, 4, 0)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 215, 80),
		Parent = hallFolder,
	})

	local sign = makePart({
		Name = "HallSign",
		Size = Vector3.new(10, 2, 0.5),
		CFrame = CFrame.new(hallPos + Vector3.new(0, 8, -4)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 215, 80),
		CanCollide = false,
		Parent = hallFolder,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 44)
	billboard.AlwaysOnTop = true
	billboard.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Text = "RUHMESHALLE"
	label.Parent = billboard

	return hallFolder, trophy
end

local function buildCenterSign(model, origin)
	local signPart = makePart({
		Name = "HubTitle",
		Size = Vector3.new(14, 3, 1),
		CFrame = CFrame.new(origin + Vector3.new(0, 12, -5)),
		Material = Enum.Material.Neon,
		Color = HubConfig.ACCENT_COLOR,
		CanCollide = false,
		Parent = model,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(280, 60)
	billboard.AlwaysOnTop = true
	billboard.Parent = signPart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Text = "NOVA BLADERS"
	label.Parent = billboard
end

local function buildZoneMarker(model, zone, origin)
	local worldPos = origin + zone.position - HubConfig.ORIGIN

	local marker = makePart({
		Name = "Zone_" .. zone.id,
		Size = Vector3.new(zone.radius * 2, 1, zone.radius * 2),
		CFrame = CFrame.new(worldPos - Vector3.new(0, 3, 0)),
		Material = Enum.Material.SmoothPlastic,
		Color = HubConfig.ACCENT_COLOR,
		Transparency = 0.85,
		CanCollide = false,
		Parent = model,
	})
	marker:SetAttribute("ZoneId", zone.id)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zone.prompt
	prompt.ObjectText = zone.name
	prompt.MaxActivationDistance = zone.radius
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = marker

	return marker
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = HubConfig.HUB_FOLDER_NAME
	model.Parent = workspace

	local origin = HubConfig.ORIGIN

	buildPlatform(model, origin)
	buildArenaGate(model, origin)
	buildBeyLab(model, origin)
	buildHallOfFame(model, origin)
	buildCenterSign(model, origin)

	for _, zone in HubConfig.ZONES do
		buildZoneMarker(model, zone, origin)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = HubConfig.SPAWN + CFrame.new(HubConfig.ORIGIN)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = model

	model.PrimaryPart = model:FindFirstChild("Platform")
	return model
end

return HubWorldBuilder
