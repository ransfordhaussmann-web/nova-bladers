local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

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

local function addNeonRing(parent, center, radius, color)
	local ring = makePart({
		name = "NeonRing",
		size = Vector3.new(radius * 2, 0.3, radius * 2),
		cframe = CFrame.new(center) * CFrame.Angles(0, 0, 0),
		color = color,
		material = HubConfig.MATERIALS.neon,
		parent = parent,
	})
	ring.Shape = Enum.PartType.Cylinder
	ring.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	return ring
end

local function addProximityPrompt(part, actionText, objectText, keyCode)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText or ""
	prompt.KeyboardKeyCode = keyCode or Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

local function addSurfaceGui(part, face, title)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = part

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(16, 20, 32)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 48)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = HubConfig.COLORS.neon
	titleLabel.TextSize = 22
	titleLabel.Text = title
	titleLabel.Parent = frame

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Size = UDim2.new(1, -16, 1, -56)
	body.Position = UDim2.fromOffset(8, 52)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Gotham
	body.TextColor3 = Color3.fromRGB(220, 225, 240)
	body.TextSize = 18
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.Text = ""
	body.Parent = frame

	return gui, body
end

function HubWorldBuilder.build(origin)
	origin = origin or HubConfig.HUB_ORIGIN

	local existing = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Model")
	hub.Name = HubConfig.HUB_NAME
	hub.Parent = workspace

	local floorSize = HubConfig.FLOOR_SIZE
	makePart({
		name = "Floor",
		size = floorSize,
		cframe = CFrame.new(origin + Vector3.new(0, -floorSize.Y / 2, 0)),
		color = HubConfig.COLORS.floor,
		material = HubConfig.MATERIALS.floor,
		parent = hub,
	})

	makePart({
		name = "FloorAccent",
		size = Vector3.new(floorSize.X - 8, 0.2, floorSize.Z - 8),
		cframe = CFrame.new(origin + Vector3.new(0, 0.1, 0)),
		color = HubConfig.COLORS.floorAccent,
		material = HubConfig.MATERIALS.neon,
		transparency = 0.4,
		parent = hub,
	})

	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallY = origin.Y + wallH / 2

	local walls = {
		{ name = "WallNorth", size = Vector3.new(floorSize.X, wallH, 1), pos = origin + Vector3.new(0, wallH / 2, -halfZ) },
		{ name = "WallSouth", size = Vector3.new(floorSize.X, wallH, 1), pos = origin + Vector3.new(0, wallH / 2, halfZ) },
		{ name = "WallEast", size = Vector3.new(1, wallH, floorSize.Z), pos = origin + Vector3.new(halfX, wallH / 2, 0) },
		{ name = "WallWest", size = Vector3.new(1, wallH, floorSize.Z), pos = origin + Vector3.new(-halfX, wallH / 2, 0) },
	}
	for _, wall in walls do
		makePart({
			name = wall.name,
			size = wall.size,
			cframe = CFrame.new(wall.pos),
			color = HubConfig.COLORS.wall,
			material = HubConfig.MATERIALS.wall,
			parent = hub,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(origin + HubConfig.SPAWN_POSITION)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	addNeonRing(hub, origin + Vector3.new(0, 0.2, HubConfig.SPAWN_POSITION.Z), 5, HubConfig.COLORS.neon)

	local gateCfg = HubConfig.ARENA_GATE
	local gatePos = origin + gateCfg.position
	local gate = makePart({
		name = "ArenaGate",
		size = gateCfg.size,
		cframe = CFrame.new(gatePos),
		color = HubConfig.COLORS.gateGlow,
		material = HubConfig.MATERIALS.glass,
		transparency = 0.35,
		parent = hub,
	})
	addProximityPrompt(gate, gateCfg.promptText, "Arena", gateCfg.promptKey)

	local gateFrame = makePart({
		name = "GateFrame",
		size = Vector3.new(gateCfg.size.X + 1, gateCfg.size.Y + 1, 0.5),
		cframe = CFrame.new(gatePos),
		color = HubConfig.COLORS.neon,
		material = HubConfig.MATERIALS.neon,
		parent = hub,
	})
	gateFrame.CanCollide = false

	local kioskCfg = HubConfig.BEY_KIOSK
	local kioskPos = origin + kioskCfg.position
	local kiosk = makePart({
		name = "BeyKiosk",
		size = kioskCfg.size,
		cframe = CFrame.new(kioskPos),
		color = HubConfig.COLORS.kiosk,
		material = Enum.Material.Metal,
		parent = hub,
	})
	addProximityPrompt(kiosk, kioskCfg.promptText, "Bey-Station", kioskCfg.promptKey)

	local kioskScreen = makePart({
		name = "KioskScreen",
		size = Vector3.new(3.5, 2.5, 0.2),
		cframe = CFrame.new(kioskPos + Vector3.new(0, 1, -kioskCfg.size.Z / 2 - 0.1)),
		color = HubConfig.COLORS.neonAlt,
		material = HubConfig.MATERIALS.neon,
		parent = hub,
	})

	local lbCfg = HubConfig.LEADERBOARD
	local lbPos = origin + lbCfg.position
	local leaderboard = makePart({
		name = "LeaderboardBoard",
		size = lbCfg.size,
		cframe = CFrame.new(lbPos) * CFrame.Angles(0, math.rad(25), 0),
		color = Color3.fromRGB(24, 28, 42),
		material = Enum.Material.SmoothPlastic,
		parent = hub,
	})
	local _, lbBody = addSurfaceGui(leaderboard, Enum.NormalId.Front, lbCfg.title)
	lbBody.Name = "LeaderboardBody"

	local statsCfg = HubConfig.STATS_BOARD
	local statsPos = origin + statsCfg.position
	local statsBoard = makePart({
		name = "StatsBoard",
		size = statsCfg.size,
		cframe = CFrame.new(statsPos) * CFrame.Angles(0, math.rad(-25), 0),
		color = Color3.fromRGB(24, 28, 42),
		material = Enum.Material.SmoothPlastic,
		parent = hub,
	})
	local _, statsBody = addSurfaceGui(statsBoard, Enum.NormalId.Front, statsCfg.title)
	statsBody.Name = "StatsBody"

	-- Decorative pillars
	for _, offset in { Vector3.new(-14, 4, -14), Vector3.new(14, 4, -14), Vector3.new(-14, 4, 14), Vector3.new(14, 4, 14) } do
		makePart({
			name = "Pillar",
			size = Vector3.new(2, 8, 2),
			cframe = CFrame.new(origin + offset),
			color = HubConfig.COLORS.wall,
			material = HubConfig.MATERIALS.wall,
			parent = hub,
		})
	end

	hub:SetAttribute("HubOrigin", origin)
	return hub
end

function HubWorldBuilder.getSpawnCFrame(hub)
	local spawn = hub:FindFirstChild("HubSpawn")
	if spawn then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(hub:GetAttribute("HubOrigin") or HubConfig.HUB_ORIGIN) + HubConfig.SPAWN_POSITION
end

function HubWorldBuilder.formatLeaderboard(entries)
	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		return "Noch keine Einträge"
	end
	return table.concat(lines, "\n")
end

function HubWorldBuilder.formatStats(wins, losses, rank)
	return string.format("Siege: %d\nNiederlagen: %d\nRang: %d", wins, losses, rank)
end

return HubWorldBuilder
