local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.new(1, 1, 1)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function addPrompt(parent, zoneKey, zone)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = zoneKey .. "Prompt"
	prompt.ActionText = zone.promptText
	prompt.ObjectText = "Nova Bladers"
	prompt.KeyboardKeyCode = zone.promptKey
	prompt.MaxActivationDistance = zone.maxDistance
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

local function addBillboard(parent, text, size)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(size or 200, 50)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(220, 230, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	return gui
end

local function addSurfaceDisplay(parent, face, title, displayName)
	local gui = Instance.new("SurfaceGui")
	gui.Name = displayName or (title .. "Display")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = parent

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 48)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title
	titleLabel.TextColor3 = Color3.fromRGB(120, 180, 255)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = frame

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Size = UDim2.new(1, -16, 1, -56)
	body.Position = UDim2.fromOffset(8, 52)
	body.BackgroundTransparency = 1
	body.Text = "..."
	body.TextColor3 = Color3.fromRGB(200, 210, 230)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.TextSize = 18
	body.Font = Enum.Font.Gotham
	body.Parent = frame

	return body
end

function HubWorldBuilder.build()
	local origin = HubConfig.ORIGIN
	local folder = Instance.new("Folder")
	folder.Name = "NovaHub"
	folder.Parent = workspace

	makePart({
		name = "Platform",
		size = HubConfig.PLATFORM.size,
		cframe = CFrame.new(origin),
		color = HubConfig.PLATFORM.color,
		material = HubConfig.PLATFORM.material,
		parent = folder,
	})

	local rimThickness = HubConfig.RIM.thickness
	local rimHeight = HubConfig.RIM.height
	local halfX = HubConfig.PLATFORM.size.X / 2
	local halfZ = HubConfig.PLATFORM.size.Z / 2

	for _, offset in {
		Vector3.new(halfX, rimHeight / 2, 0),
		Vector3.new(-halfX, rimHeight / 2, 0),
		Vector3.new(0, rimHeight / 2, halfZ),
		Vector3.new(0, rimHeight / 2, -halfZ),
	} do
		local isX = offset.X ~= 0
		makePart({
			name = "Rim",
			size = isX and Vector3.new(rimThickness, rimHeight, HubConfig.PLATFORM.size.Z)
				or Vector3.new(HubConfig.PLATFORM.size.X, rimHeight, rimThickness),
			cframe = CFrame.new(origin + offset + Vector3.new(0, HubConfig.PLATFORM.size.Y / 2, 0)),
			color = HubConfig.RIM.color,
			material = HubConfig.RIM.material,
			parent = folder,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(origin + HubConfig.SPAWN_OFFSET)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = folder

	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = folder

	local arenaZone = HubConfig.ZONES.arenaPortal
	local portalBase = makePart({
		name = "ArenaPortal",
		size = Vector3.new(14, 1, 8),
		cframe = CFrame.new(origin + arenaZone.position),
		color = Color3.fromRGB(25, 30, 45),
		material = Enum.Material.Metal,
		parent = zones,
	})
	addPrompt(portalBase, "ArenaPortal", arenaZone)
	addBillboard(portalBase, HubConfig.LABELS.arenaSubtitle, 260)

	local ringCount = 8
	for i = 1, ringCount do
		local angle = (i / ringCount) * math.pi * 2
		local radius = HubConfig.ARENA_PORTAL.ringRadius
		local offset = Vector3.new(math.cos(angle) * radius, 2, math.sin(angle) * radius)
		makePart({
			name = "PortalRing",
			size = Vector3.new(2, HubConfig.ARENA_PORTAL.ringHeight, 2),
			cframe = CFrame.new(origin + arenaZone.position + offset),
			color = HubConfig.ARENA_PORTAL.color,
			material = Enum.Material.Neon,
			parent = zones,
		})
	end

	local portalGlow = makePart({
		name = "PortalGlow",
		size = Vector3.new(10, 0.2, 10),
		cframe = CFrame.new(origin + arenaZone.position + Vector3.new(0, 3, 0)),
		color = HubConfig.ARENA_PORTAL.glowColor,
		material = Enum.Material.Neon,
		canCollide = false,
		parent = zones,
	})
	portalGlow.Transparency = 0.4

	local beyZone = HubConfig.ZONES.beySelect
	local beyPedestal = makePart({
		name = "BeySelect",
		size = Vector3.new(8, 3, 8),
		cframe = CFrame.new(origin + beyZone.position + Vector3.new(0, 1.5, 0)),
		color = Color3.fromRGB(255, 180, 60),
		material = Enum.Material.SmoothPlastic,
		parent = zones,
	})
	addPrompt(beyPedestal, "BeySelect", beyZone)
	addBillboard(beyPedestal, "Bey-Auswahl", 180)

	local statsZone = HubConfig.ZONES.statsBoard
	local statsBoard = makePart({
		name = "StatsBoard",
		size = Vector3.new(10, 8, 1),
		cframe = CFrame.new(origin + statsZone.position + Vector3.new(0, 4, 0)),
		color = Color3.fromRGB(30, 35, 50),
		material = Enum.Material.SmoothPlastic,
		parent = zones,
	})
	addPrompt(statsBoard, "StatsBoard", statsZone)
	local statsBody = addSurfaceDisplay(statsBoard, Enum.NormalId.Front, "Deine Stats", "StatsDisplay")
	statsBody.Name = "StatsBody"

	local lbZone = HubConfig.ZONES.leaderboard
	local lbBoard = makePart({
		name = "LeaderboardBoard",
		size = Vector3.new(12, 8, 1),
		cframe = CFrame.new(origin + lbZone.position + Vector3.new(0, 4, 0)),
		color = Color3.fromRGB(30, 35, 50),
		material = Enum.Material.SmoothPlastic,
		parent = zones,
	})
	addPrompt(lbBoard, "Leaderboard", lbZone)
	local lbBody = addSurfaceDisplay(lbBoard, Enum.NormalId.Back, "Top Spieler", "LeaderboardDisplay")
	lbBody.Name = "LeaderboardBody"

	local titleSign = makePart({
		name = "HubTitle",
		size = Vector3.new(20, 4, 1),
		cframe = CFrame.new(origin + Vector3.new(0, 12, HubConfig.PLATFORM.size.Z / 2 - 2)),
		color = Color3.fromRGB(20, 24, 36),
		material = Enum.Material.SmoothPlastic,
		parent = folder,
	})
	addBillboard(titleSign, HubConfig.LABELS.hubTitle, 320)

	local lighting = Instance.new("PointLight")
	lighting.Brightness = 2
	lighting.Range = 30
	lighting.Color = Color3.fromRGB(120, 180, 255)
	lighting.Parent = portalGlow

	return folder
end

return HubWorldBuilder
