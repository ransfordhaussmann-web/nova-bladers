local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.CastShadow = props.castShadow ~= false
	part.Name = props.name or "Part"
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.new(1, 1, 1)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Transparency = props.transparency or 0
	part.Parent = props.parent
	return part
end

local function addBillboard(parent, text, sizeY)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(180, sizeY or 48)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = false
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

	return billboard
end

local function addSurfaceText(parent, text)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Display"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
	label.BackgroundTransparency = 0.15
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextSize = 22
	label.TextWrapped = true
	label.Text = text
	label.Parent = gui

	return label
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaBladers_Hub")
	if existing then
		return existing
	end

	local hub = Instance.new("Model")
	hub.Name = "NovaBladers_Hub"

	local origin = HubConfig.ORIGIN
	local floorCfg = HubConfig.FLOOR

	local floor = makePart({
		name = "Floor",
		size = floorCfg.size,
		cframe = CFrame.new(origin + Vector3.new(0, floorCfg.size.Y * 0.5, 0)),
		color = floorCfg.color,
		material = floorCfg.material,
		parent = hub,
	})

	local rimCfg = HubConfig.RIM
	local halfX = floorCfg.size.X * 0.5
	local halfZ = floorCfg.size.Z * 0.5
	local rimY = floorCfg.size.Y + rimCfg.height * 0.5

	for _, spec in {
		{ Vector3.new(0, rimY, halfZ + rimCfg.thickness * 0.5), Vector3.new(floorCfg.size.X + rimCfg.thickness * 2, rimCfg.height, rimCfg.thickness) },
		{ Vector3.new(0, rimY, -halfZ - rimCfg.thickness * 0.5), Vector3.new(floorCfg.size.X + rimCfg.thickness * 2, rimCfg.height, rimCfg.thickness) },
		{ Vector3.new(halfX + rimCfg.thickness * 0.5, rimY, 0), Vector3.new(rimCfg.thickness, rimCfg.height, floorCfg.size.Z) },
		{ Vector3.new(-halfX - rimCfg.thickness * 0.5, rimY, 0), Vector3.new(rimCfg.thickness, rimCfg.height, floorCfg.size.Z) },
	} do
		makePart({
			name = "Rim",
			size = spec[2],
			cframe = CFrame.new(origin + spec[1]),
			color = rimCfg.color,
			material = Enum.Material.Neon,
			parent = hub,
		})
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for zoneId, zone in HubConfig.ZONES do
		local zoneModel = Instance.new("Model")
		zoneModel.Name = zoneId
		zoneModel.Parent = zonesFolder

		local pad = makePart({
			name = "Pad",
			size = Vector3.new(zone.size.X, zone.size.Y, zone.size.Z),
			cframe = CFrame.new(origin + zone.center),
			color = zone.color,
			material = Enum.Material.Neon,
			transparency = 0.35,
			parent = zoneModel,
		})
		pad:SetAttribute("ZoneId", zoneId)
		pad:SetAttribute("HubAction", zone.action or "")

		local marker = makePart({
			name = "Marker",
			size = Vector3.new(2, 6, 2),
			cframe = CFrame.new(origin + zone.center + Vector3.new(0, 3.5, 0)),
			color = zone.color,
			material = Enum.Material.SmoothPlastic,
			parent = zoneModel,
		})

		addBillboard(marker, zone.label, 40)

		if zoneId == "Leaderboard" then
			local board = makePart({
				name = "Board",
				size = Vector3.new(10, 8, 0.4),
				cframe = CFrame.new(origin + zone.center + Vector3.new(0, 5, -5)),
				color = Color3.fromRGB(20, 24, 36),
				parent = zoneModel,
			})
			local leaderboardLabel = addSurfaceText(board, "🏆 Top Spieler\nLade…")
			leaderboardLabel.Name = "LeaderboardLabel"
		elseif zoneId == "Stats" then
			local board = makePart({
				name = "Board",
				size = Vector3.new(14, 6, 0.4),
				cframe = CFrame.new(origin + zone.center + Vector3.new(0, 4.5, 5)),
				color = Color3.fromRGB(20, 24, 36),
				parent = zoneModel,
			})
			local statsLabel = addSurfaceText(board, "Wins: 0\nLosses: 0\nRank: —")
			statsLabel.Name = "StatsLabel"
		elseif zone.action then
			local promptAnchor = makePart({
				name = "PromptAnchor",
				size = Vector3.new(1, 1, 1),
				cframe = CFrame.new(origin + zone.center + Vector3.new(0, 3, 0)),
				color = zone.color,
				transparency = 1,
				canCollide = false,
				castShadow = false,
				parent = zoneModel,
			})

			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "HubPrompt"
			prompt.ActionText = zone.prompt
			prompt.ObjectText = zone.label
			prompt.MaxActivationDistance = HubConfig.PROXIMITY_RANGE
			prompt.RequiresLineOfSight = false
			prompt:SetAttribute("HubAction", zone.action)
			prompt.Parent = promptAnchor
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(origin + HubConfig.SPAWN)
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 0.4
	spawn.Color = Color3.fromRGB(100, 180, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Parent = hub

	local title = makePart({
		name = "TitleSign",
		size = Vector3.new(1, 1, 1),
		cframe = CFrame.new(origin + Vector3.new(0, 10, 0)),
		transparency = 1,
		canCollide = false,
		castShadow = false,
		parent = hub,
	})
	addBillboard(title, "Nova Bladers Hub", 56)

	hub.PrimaryPart = floor
	hub.Parent = workspace

	return hub
end

return HubWorldBuilder
