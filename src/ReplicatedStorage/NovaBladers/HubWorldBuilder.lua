local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.Position = props.position
	part.Color = props.color or Color3.fromRGB(60, 60, 70)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "HubPart"
	part.Parent = props.parent
	if props.transparency then
		part.Transparency = props.transparency
	end
	return part
end

local function addNeonTrim(part, color)
	local light = Instance.new("PointLight")
	light.Color = color or HubConfig.ACCENT_COLOR
	light.Brightness = 1.2
	light.Range = 14
	light.Parent = part

	local highlight = Instance.new("SurfaceLight")
	highlight.Color = color or HubConfig.ACCENT_COLOR
	highlight.Brightness = 0.6
	highlight.Range = 10
	highlight.Face = Enum.NormalId.Top
	highlight.Parent = part
end

local function addBillboard(parent, text, offsetY)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 60)
	gui.StudsOffset = Vector3.new(0, offsetY or 4, 0)
	gui.AlwaysOnTop = false
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
	label.TextColor3 = Color3.fromRGB(230, 235, 255)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.Text = text
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	return gui
end

function HubWorldBuilder.build(parent)
	parent = parent or workspace

	local existing = parent:FindFirstChild("NovaHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = parent

	-- Main walkable floor
	local floor = makePart({
		name = "HubFloor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		position = HubConfig.FLOOR_POSITION,
		color = HubConfig.FLOOR_COLOR,
		material = Enum.Material.Slate,
	})
	addNeonTrim(floor, HubConfig.ACCENT_COLOR)

	-- Spawn location
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = HubConfig.SPAWN_OFFSET
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hub

	-- Arena portal gate
	local portalFolder = Instance.new("Folder")
	portalFolder.Name = "ArenaPortal"
	portalFolder.Parent = hub

	local portalFrame = makePart({
		name = "PortalFrame",
		parent = portalFolder,
		size = HubConfig.ARENA_PORTAL_SIZE,
		position = HubConfig.ARENA_PORTAL_POSITION,
		color = HubConfig.ACCENT_COLOR,
		material = Enum.Material.Neon,
		canCollide = false,
	})
	portalFrame.Transparency = 0.35
	addBillboard(portalFrame, "⚔ Arena", 6)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterArenaPrompt"
	prompt.ActionText = "Kämpfen"
	prompt.ObjectText = "Arena"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = HubConfig.ARENA_PROMPT_RANGE
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.RequiresLineOfSight = false
	prompt.Parent = portalFrame

	-- Bey selection kiosk
	local kiosk = makePart({
		name = "BeyKiosk",
		parent = hub,
		size = HubConfig.BEY_KIOSK_SIZE,
		position = HubConfig.BEY_KIOSK_POSITION,
		color = Color3.fromRGB(45, 50, 65),
		material = Enum.Material.Metal,
	})
	addNeonTrim(kiosk, Color3.fromRGB(255, 200, 60))
	addBillboard(kiosk, "Bey-Auswahl", 5)

	local kioskZone = Instance.new("Part")
	kioskZone.Name = "BeyKioskZone"
	kioskZone.Anchored = true
	kioskZone.CanCollide = false
	kioskZone.Transparency = 1
	kioskZone.Size = Vector3.new(HubConfig.ZONE_RADIUS * 2, 8, HubConfig.ZONE_RADIUS * 2)
	kioskZone.Position = HubConfig.BEY_KIOSK_POSITION
	kioskZone.Parent = hub

	-- Leaderboard pillar
	local leaderboard = makePart({
		name = "LeaderboardPillar",
		parent = hub,
		size = HubConfig.LEADERBOARD_SIZE,
		position = HubConfig.LEADERBOARD_POSITION,
		color = Color3.fromRGB(55, 45, 75),
		material = Enum.Material.Marble,
	})
	addNeonTrim(leaderboard, Color3.fromRGB(200, 160, 255))
	addBillboard(leaderboard, "🏆 Rangliste", 7)

	local leaderboardZone = Instance.new("Part")
	leaderboardZone.Name = "LeaderboardZone"
	leaderboardZone.Anchored = true
	leaderboardZone.CanCollide = false
	leaderboardZone.Transparency = 1
	leaderboardZone.Size = Vector3.new(HubConfig.ZONE_RADIUS * 2, 10, HubConfig.ZONE_RADIUS * 2)
	leaderboardZone.Position = HubConfig.LEADERBOARD_POSITION
	leaderboardZone.Parent = hub

	-- Info sign at back of hub
	local infoSign = makePart({
		name = "InfoSign",
		parent = hub,
		size = Vector3.new(20, 5, 1),
		position = HubConfig.INFO_SIGN_POSITION,
		color = Color3.fromRGB(25, 28, 38),
		material = Enum.Material.SmoothPlastic,
		canCollide = false,
	})
	addBillboard(infoSign, "Nova Bladers — Lauf zur Arena!", 4)

	-- Decorative pillars around the plaza
	for i = 1, HubConfig.PILLAR_COUNT do
		local angle = (i / HubConfig.PILLAR_COUNT) * math.pi * 2
		local x = math.cos(angle) * HubConfig.PILLAR_RADIUS
		local z = HubConfig.FLOOR_POSITION.Z + math.sin(angle) * HubConfig.PILLAR_RADIUS * 0.6
		local pillar = makePart({
			name = "Pillar" .. i,
			parent = hub,
			size = Vector3.new(3, 14, 3),
			position = Vector3.new(x, HubConfig.FLOOR_POSITION.Y + 8, z),
			color = HubConfig.PILLAR_COLOR,
			material = Enum.Material.Concrete,
		})
		addNeonTrim(pillar, HubConfig.ACCENT_COLOR)
	end

	-- Zone markers folder for client detection
	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = hub

	local arenaZone = Instance.new("Part")
	arenaZone.Name = "ArenaZone"
	arenaZone.Anchored = true
	arenaZone.CanCollide = false
	arenaZone.Transparency = 1
	arenaZone.Size = Vector3.new(HubConfig.ZONE_RADIUS * 2, 10, HubConfig.ZONE_RADIUS * 2)
	arenaZone.Position = HubConfig.ARENA_PORTAL_POSITION
	arenaZone.Parent = zones

	return hub
end

return HubWorldBuilder
