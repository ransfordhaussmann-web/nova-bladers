local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.Position = props.Position
	part.Color = props.Color or Color3.fromRGB(60, 60, 60)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Name = props.Name or "Part"
	part.Parent = props.Parent
	if props.Transparency then
		part.Transparency = props.Transparency
	end
	if props.Shape then
		part.Shape = props.Shape
	end
	return part
end

local function addPrompt(parent, zoneKey)
	local zone = HubConfig.ZONES[zoneKey]
	if not zone or not zone.promptText then
		return nil
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = zoneKey .. "Prompt"
	prompt.ActionText = zone.promptText
	prompt.ObjectText = "Nova Hub"
	prompt.KeyboardKeyCode = zone.promptKey or Enum.KeyCode.E
	prompt.MaxActivationDistance = zone.maxDistance or 10
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

local function addSign(parent, text, offset)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Size = UDim2.fromOffset(220, 56)
	billboard.StudsOffset = offset or Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(15, 18, 30)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 20
	label.Text = text
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	return billboard
end

local function addSurfaceBoard(parent, face, title)
	local gui = Instance.new("SurfaceGui")
	gui.Name = title .. "Board"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = parent

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(18, 22, 36)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local header = Instance.new("TextLabel")
	header.Name = "Title"
	header.Size = UDim2.new(1, 0, 0, 48)
	header.BackgroundColor3 = HubConfig.COLORS.Trim
	header.TextColor3 = Color3.new(1, 1, 1)
	header.Font = Enum.Font.GothamBold
	header.TextSize = 22
	header.Text = title
	header.Parent = frame

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Size = UDim2.new(1, -16, 1, -56)
	body.Position = UDim2.fromOffset(8, 52)
	body.BackgroundTransparency = 1
	body.TextColor3 = Color3.fromRGB(220, 230, 255)
	body.Font = Enum.Font.Gotham
	body.TextSize = 18
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.Text = ""
	body.Parent = frame

	return body
end

function HubWorldBuilder.getSpawnCFrame()
	local center = HubConfig.PLATFORM_CENTER
	local offset = HubConfig.SPAWN_OFFSET
	return CFrame.new(center + offset)
end

function HubWorldBuilder.getArenaTeleportCFrame()
	local arena = HubConfig.TELEPORT.ArenaCenter
	local y = HubConfig.TELEPORT.ArenaYOffset
	return CFrame.new(arena + Vector3.new(0, y, 0))
end

function HubWorldBuilder.build(parent)
	local existing = parent:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = parent

	local center = HubConfig.PLATFORM_CENTER
	local colors = HubConfig.COLORS

	-- Main walkable platform
	local platform = makePart({
		Name = "Platform",
		Parent = hub,
		Size = HubConfig.PLATFORM_SIZE,
		Position = center + Vector3.new(0, -HubConfig.PLATFORM_SIZE.Y / 2, 0),
		Color = colors.Platform,
		Material = Enum.Material.Slate,
	})

	-- Trim ring around the edge
	local trim = makePart({
		Name = "TrimRing",
		Parent = hub,
		Size = Vector3.new(
			HubConfig.PLATFORM_SIZE.X + 4,
			0.6,
			HubConfig.PLATFORM_SIZE.Z + 4
		),
		Position = center + Vector3.new(0, 0.3, 0),
		Color = colors.Trim,
		Material = Enum.Material.Neon,
	})

	-- Spawn marker (invisible, for reference)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = (center + HubConfig.SPAWN_OFFSET) - Vector3.new(0, 2, 0)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hub

	-- Decorative corner pillars
	local halfX = HubConfig.PLATFORM_SIZE.X / 2 - 6
	local halfZ = HubConfig.PLATFORM_SIZE.Z / 2 - 6
	for _, offset in {
		Vector3.new(halfX, 6, halfZ),
		Vector3.new(-halfX, 6, halfZ),
		Vector3.new(halfX, 6, -halfZ),
		Vector3.new(-halfX, 6, -halfZ),
	} do
		makePart({
			Name = "Pillar",
			Parent = hub,
			Size = Vector3.new(4, 12, 4),
			Position = center + offset,
			Color = colors.Trim,
			Material = Enum.Material.Metal,
		})
	end

	-- Arena portal
	local portalZone = HubConfig.ZONES.ArenaPortal
	local portalBase = makePart({
		Name = "ArenaPortal",
		Parent = hub,
		Size = Vector3.new(14, 1, 6),
		Position = portalZone.position - Vector3.new(0, 1.5, 0),
		Color = colors.Platform,
		Material = Enum.Material.Metal,
	})
	local portalRing = makePart({
		Name = "PortalRing",
		Parent = portalBase,
		Size = Vector3.new(10, 10, 1.2),
		Position = portalBase.Position + Vector3.new(0, 6, 0),
		Color = colors.Portal,
		Material = Enum.Material.Neon,
		Transparency = 0.15,
	})
	addPrompt(portalBase, "ArenaPortal")
	addSign(portalBase, "⚔ Arena", Vector3.new(0, 8, 0))

	local portalLight = Instance.new("PointLight")
	portalLight.Color = colors.Portal
	portalLight.Brightness = 2
	portalLight.Range = 18
	portalLight.Parent = portalRing

	-- Bey selection station
	local beyZone = HubConfig.ZONES.BeyStation
	local beyStation = makePart({
		Name = "BeyStation",
		Parent = hub,
		Size = Vector3.new(10, 6, 10),
		Position = beyZone.position,
		Color = colors.BeyStation,
		Material = Enum.Material.SmoothPlastic,
	})
	addPrompt(beyStation, "BeyStation")
	addSign(beyStation, "🔧 Bey Lab", Vector3.new(0, 5, 0))

	-- Stats kiosk (3D board)
	local statsZone = HubConfig.ZONES.StatsKiosk
	local statsKiosk = makePart({
		Name = "StatsKiosk",
		Parent = hub,
		Size = Vector3.new(12, 10, 2),
		Position = statsZone.position,
		Color = colors.Accent,
		Material = Enum.Material.SmoothPlastic,
	})
	addSurfaceBoard(statsKiosk, Enum.NormalId.Front, "Deine Stats")

	-- Leaderboard pillar (3D board)
	local lbZone = HubConfig.ZONES.Leaderboard
	local leaderboard = makePart({
		Name = "Leaderboard",
		Parent = hub,
		Size = Vector3.new(14, 12, 2),
		Position = lbZone.position,
		Color = colors.Trim,
		Material = Enum.Material.SmoothPlastic,
	})
	addSurfaceBoard(leaderboard, Enum.NormalId.Front, "🏆 Top Spieler")

	-- Path markers (walkable guide strips)
	for _, path in {
		{ from = center + Vector3.new(0, 0.2, 10), size = Vector3.new(4, 0.2, 30) },
		{ from = center + Vector3.new(-20, 0.2, 0), size = Vector3.new(30, 0.2, 4) },
		{ from = center + Vector3.new(20, 0.2, 0), size = Vector3.new(30, 0.2, 4) },
	} do
		makePart({
			Name = "Path",
			Parent = hub,
			Size = path.size,
			Position = path.from,
			Color = colors.Trim,
			Material = Enum.Material.Neon,
			Transparency = 0.6,
			CanCollide = false,
		})
	end

	-- Hub metadata for clients
	local hubMode = Instance.new("BoolValue")
	hubMode.Name = "HubMode"
	hubMode.Value = true
	hubMode.Parent = hub

	return hub
end

function HubWorldBuilder.findBoardBody(hub, boardName)
	local board = hub:FindFirstChild(boardName, true)
	if not board then
		return nil
	end
	local gui = board:FindFirstChildWhichIsA("SurfaceGui")
	if not gui then
		return nil
	end
	local frame = gui:FindFirstChildWhichIsA("Frame")
	return frame and frame:FindFirstChild("Body")
end

return HubWorldBuilder
