local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubWorldConfig = require(NovaBladers.HubWorldConfig)
local BeyCatalog = require(NovaBladers.BeyCatalog)

local HubWorldBuilder = {}

local function createPart(props)
	local part = Instance.new("Part")
	part.Name = props.Name or "Part"
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color or Color3.fromRGB(255, 255, 255)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Transparency = props.Transparency or 0
	if props.Shape then
		part.Shape = props.Shape
	end
	part.Parent = props.Parent
	return part
end

local function createWalls(hub, origin, floorSize, wallHeight, color)
	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local wallThickness = 2
	local wallY = origin.Y + wallHeight / 2

	local wallDefs = {
		{ size = Vector3.new(floorSize.X + wallThickness, wallHeight, wallThickness), pos = Vector3.new(origin.X, wallY, origin.Z - halfZ) },
		{ size = Vector3.new(floorSize.X + wallThickness, wallHeight, wallThickness), pos = Vector3.new(origin.X, wallY, origin.Z + halfZ) },
		{ size = Vector3.new(wallThickness, wallHeight, floorSize.Z), pos = Vector3.new(origin.X - halfX, wallY, origin.Z) },
		{ size = Vector3.new(wallThickness, wallHeight, floorSize.Z), pos = Vector3.new(origin.X + halfX, wallY, origin.Z) },
	}

	local wallsFolder = Instance.new("Folder")
	wallsFolder.Name = "Walls"
	wallsFolder.Parent = hub

	for index, def in wallDefs do
		createPart({
			Name = "Wall" .. index,
			Size = def.size,
			CFrame = CFrame.new(def.pos),
			Color = color,
			Material = Enum.Material.Concrete,
			Parent = wallsFolder,
		})
	end
end

local function createBeyPedestals(hub, origin, config)
	local folder = Instance.new("Folder")
	folder.Name = "BeyShowcase"
	folder.Parent = hub

	local count = #BeyCatalog
	for index, bey in BeyCatalog do
		local angle = ((index - 1) / count) * math.pi * 2
		local offset = Vector3.new(
			math.cos(angle) * config.BEY_PEDESTAL_RADIUS,
			config.BEY_PEDESTAL_HEIGHT / 2,
			math.sin(angle) * config.BEY_PEDESTAL_RADIUS
		)
		local position = origin + offset

		local pedestal = createPart({
			Name = bey.id .. "Pedestal",
			Size = Vector3.new(5, config.BEY_PEDESTAL_HEIGHT, 5),
			CFrame = CFrame.new(position),
			Color = bey.color,
			Material = Enum.Material.Neon,
			Parent = folder,
		})

		local top = createPart({
			Name = bey.id .. "Top",
			Size = Vector3.new(3.6, 0.6, 3.6),
			CFrame = CFrame.new(position + Vector3.new(0, config.BEY_PEDESTAL_HEIGHT / 2 + 0.3, 0)),
			Color = Color3.fromRGB(240, 240, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.15,
			Parent = folder,
		})

		local sign = Instance.new("BillboardGui")
		sign.Name = "Label"
		sign.Size = UDim2.fromOffset(180, 56)
		sign.StudsOffset = Vector3.new(0, 3.2, 0)
		sign.AlwaysOnTop = true
		sign.Parent = pedestal

		local title = Instance.new("TextLabel")
		title.Size = UDim2.fromScale(1, 0.55)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.TextColor3 = Color3.new(1, 1, 1)
		title.TextScaled = true
		title.Text = bey.name
		title.Parent = sign

		local subtitle = Instance.new("TextLabel")
		subtitle.Size = UDim2.new(1, 0, 0.45, 0)
		subtitle.Position = UDim2.fromScale(0, 0.55)
		subtitle.BackgroundTransparency = 1
		subtitle.Font = Enum.Font.Gotham
		subtitle.TextColor3 = Color3.fromRGB(200, 210, 230)
		subtitle.TextScaled = true
		subtitle.Text = bey.special
		subtitle.Parent = sign

		local glow = Instance.new("PointLight")
		glow.Color = bey.color
		glow.Brightness = 1.2
		glow.Range = 10
		glow.Parent = top
	end
end

local function createArenaPortal(hub, position, accentColor)
	local portalFolder = Instance.new("Folder")
	portalFolder.Name = "ArenaPortal"
	portalFolder.Parent = hub

	local pad = createPart({
		Name = "Pad",
		Size = Vector3.new(14, 1, 14),
		CFrame = CFrame.new(position),
		Color = accentColor,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
		Parent = portalFolder,
	})

	local ring = createPart({
		Name = "Ring",
		Size = Vector3.new(16, 0.4, 16),
		CFrame = CFrame.new(position + Vector3.new(0, 0.8, 0)),
		Color = Color3.fromRGB(255, 230, 140),
		Material = Enum.Material.Neon,
		Shape = Enum.PartType.Cylinder,
		Parent = portalFolder,
	})
	ring.Orientation = Vector3.new(0, 0, 90)

	local arch = createPart({
		Name = "Arch",
		Size = Vector3.new(12, 10, 1.2),
		CFrame = CFrame.new(position + Vector3.new(0, 6, -6)),
		Color = Color3.fromRGB(30, 34, 52),
		Material = Enum.Material.Metal,
		Parent = portalFolder,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterArenaPrompt"
	prompt.ActionText = "Arena betreten"
	prompt.ObjectText = "Nova Arena"
	prompt.MaxActivationDistance = 12
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad

	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(220, 48)
	sign.StudsOffset = Vector3.new(0, 5, 0)
	sign.AlwaysOnTop = false
	sign.Parent = arch

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 230, 150)
	label.TextScaled = true
	label.Text = "Zur Arena"
	label.Parent = sign

	local light = Instance.new("PointLight")
	light.Color = accentColor
	light.Brightness = 2
	light.Range = 18
	light.Parent = pad

	return portalFolder, prompt
end

local function createHallOfFame(hub, position, accentColor)
	local hallFolder = Instance.new("Folder")
	hallFolder.Name = "HallOfFame"
	hallFolder.Parent = hub

	local pad = createPart({
		Name = "Pad",
		Size = Vector3.new(12, 1, 12),
		CFrame = CFrame.new(position),
		Color = accentColor,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
		Parent = hallFolder,
	})

	local board = createPart({
		Name = "LeaderboardBoard",
		Size = Vector3.new(10, 7, 0.5),
		CFrame = CFrame.new(position + Vector3.new(0, 4.5, -7)),
		Color = Color3.fromRGB(24, 26, 34),
		Material = Enum.Material.Metal,
		Parent = hallFolder,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "LeaderboardSurface"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 60)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 28
	title.TextColor3 = accentColor
	title.Text = "🏆 Ruhmeshalle"
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "Entries"
	list.Size = UDim2.new(1, -20, 1, -70)
	list.Position = UDim2.new(0, 10, 0, 60)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextSize = 22
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextColor3 = Color3.fromRGB(230, 230, 240)
	list.Text = "Lade Rangliste..."
	list.Parent = frame

	return hallFolder
end

function HubWorldBuilder.updateLeaderboardBoard(entries)
	local hub = workspace:FindFirstChild("NovaBladersHub")
	if not hub then
		return
	end
	local hall = hub:FindFirstChild("HallOfFame")
	if not hall then
		return
	end
	local board = hall:FindFirstChild("LeaderboardBoard")
	if not board then
		return
	end
	local surface = board:FindFirstChild("LeaderboardSurface")
	if not surface then
		return
	end
	local list = surface.Frame:FindFirstChild("Entries")
	if not list then
		return
	end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	list.Text = table.concat(lines, "\n")
end

function HubWorldBuilder.build()
	local config = HubWorldConfig
	local origin = config.ORIGIN

	local existing = workspace:FindFirstChild("NovaBladersHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaBladersHub"

	local floor = createPart({
		Name = "Floor",
		Size = config.FLOOR_SIZE,
		CFrame = CFrame.new(origin + Vector3.new(0, -config.FLOOR_SIZE.Y / 2, 0)),
		Color = config.COLORS.Floor,
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(config.getSpawnPosition())
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.Parent = hub

	createWalls(hub, origin, config.FLOOR_SIZE, config.WALL_HEIGHT, config.COLORS.Wall)

	createPart({
		Name = "CenterPlatform",
		Size = Vector3.new(18, 0.6, 18),
		CFrame = CFrame.new(origin + Vector3.new(0, 0.3, 0)),
		Color = config.COLORS.Accent,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		Parent = hub,
	})

	local _, portalPrompt = createArenaPortal(hub, config.getPortalPosition(), config.COLORS.Portal)
	createHallOfFame(hub, config.getHallOfFamePosition(), config.COLORS.Hall)
	createBeyPedestals(hub, origin, config)

	local lighting = game:GetService("Lighting")
	lighting.Ambient = config.LIGHTING.Ambient
	lighting.Brightness = config.LIGHTING.Brightness
	lighting.ClockTime = config.LIGHTING.ClockTime

	hub.Parent = workspace

	return {
		hub = hub,
		spawn = spawn,
		floor = floor,
		portalPrompt = portalPrompt,
	}
end

return HubWorldBuilder
