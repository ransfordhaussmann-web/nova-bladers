local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = props.cframe or CFrame.new(props.position)
	part.Color = props.color or Color3.new(1, 1, 1)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Transparency = props.transparency or 0
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function buildWalls(parent, floorSize, floorY)
	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local h = HubConfig.WALL_HEIGHT
	local t = HubConfig.WALL_THICKNESS
	local y = floorY + h / 2

	local walls = {
		{ size = Vector3.new(floorSize.X + t * 2, h, t), pos = Vector3.new(0, y, halfZ + t / 2) },
		{ size = Vector3.new(floorSize.X + t * 2, h, t), pos = Vector3.new(0, y, -halfZ - t / 2) },
		{ size = Vector3.new(t, h, floorSize.Z), pos = Vector3.new(halfX + t / 2, y, 0) },
		{ size = Vector3.new(t, h, floorSize.Z), pos = Vector3.new(-halfX - t / 2, y, 0) },
	}

	local folder = Instance.new("Folder")
	folder.Name = "Walls"
	folder.Parent = parent

	for i, wall in walls do
		makePart({
			name = "Wall" .. i,
			parent = folder,
			size = wall.size,
			position = wall.pos,
			color = HubConfig.WALL_COLOR,
			material = Enum.Material.Concrete,
		})
	end
end

local function addBillboard(part, title, subtitle)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 80)
	gui.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 2, 0)
	gui.AlwaysOnTop = true
	gui.Parent = part

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 20
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextStrokeTransparency = 0.5
	titleLabel.Text = title
	titleLabel.Parent = gui

	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subLabel.Position = UDim2.fromScale(0, 0.55)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextSize = 14
	subLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	subLabel.TextStrokeTransparency = 0.6
	subLabel.Text = subtitle or ""
	subLabel.Parent = gui
end

local function buildLeaderboardBoard(parent)
	local cfg = HubConfig.LEADERBOARD_BOARD
	local board = makePart({
		name = "LeaderboardBoard",
		parent = parent,
		size = cfg.size,
		cframe = CFrame.new(cfg.position) * cfg.rotation,
		color = Color3.fromRGB(20, 22, 30),
		material = Enum.Material.Metal,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextColor3 = Color3.fromRGB(255, 210, 80)
	title.Text = "🏆 Ruhmeshalle"
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "Entries"
	list.Size = UDim2.new(1, 0, 1, -40)
	list.Position = UDim2.fromOffset(0, 40)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.Gotham
	list.TextSize = 16
	list.TextColor3 = Color3.fromRGB(230, 230, 230)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextWrapped = true
	list.Text = "Lade Rangliste…"
	list.Parent = frame

	return list
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_NAME
	hub.Parent = workspace

	local floorCfg = HubConfig.FLOOR
	makePart({
		name = "Floor",
		parent = hub,
		size = floorCfg.size,
		position = floorCfg.position,
		color = floorCfg.color,
		material = floorCfg.material,
	})

	buildWalls(hub, floorCfg.size, floorCfg.position.Y)

	local spawn = makePart({
		name = "Spawn",
		parent = hub,
		size = Vector3.new(6, 0.2, 6),
		cframe = HubConfig.SPAWN_CFRAME * CFrame.new(0, -3.3, 0),
		color = Color3.fromRGB(60, 180, 255),
		material = Enum.Material.Neon,
		transparency = 0.4,
		canCollide = false,
	})
	spawn:SetAttribute("IsHubSpawn", true)

	local signCfg = HubConfig.SPAWN_SIGN
	local sign = makePart({
		name = "WelcomeSign",
		parent = hub,
		size = Vector3.new(14, 1, 0.5),
		position = signCfg.position,
		color = Color3.fromRGB(45, 50, 65),
		material = Enum.Material.SmoothPlastic,
		canCollide = false,
	})
	addBillboard(sign, signCfg.text, signCfg.subtitle)

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	local zones = {}
	for _, zoneCfg in HubConfig.ZONES do
		local zonePart = makePart({
			name = zoneCfg.name,
			parent = zonesFolder,
			size = zoneCfg.size,
			position = zoneCfg.position,
			color = zoneCfg.color,
			material = Enum.Material.Neon,
			transparency = 0.55,
			canCollide = false,
		})
		zonePart:SetAttribute("ZoneId", zoneCfg.id)
		zonePart:SetAttribute("PromptAction", zoneCfg.promptAction)
		addBillboard(zonePart, zoneCfg.name, zoneCfg.subtitle)

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = zoneCfg.hint
		prompt.ObjectText = zoneCfg.name
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0
		prompt.Parent = zonePart

		table.insert(zones, {
			part = zonePart,
			prompt = prompt,
			config = zoneCfg,
		})
	end

	local leaderboardLabel = buildLeaderboardBoard(hub)

	local lighting = hub:FindFirstChild("HubLighting")
	if not lighting then
		lighting = Instance.new("Folder")
		lighting.Name = "HubLighting"
		lighting.Parent = hub
	end

	local centerLight = makePart({
		name = "CeilingLight",
		parent = lighting,
		size = Vector3.new(2, 0.5, 2),
		position = Vector3.new(0, HubConfig.WALL_HEIGHT - 1, 0),
		color = Color3.fromRGB(255, 240, 200),
		material = Enum.Material.Neon,
		canCollide = false,
	})

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 60
	light.Parent = centerLight

	return {
		hub = hub,
		zones = zones,
		leaderboardLabel = leaderboardLabel,
	}
end

return HubWorldBuilder
