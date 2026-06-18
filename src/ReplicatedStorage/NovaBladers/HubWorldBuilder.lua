local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.Position = props.position
	part.Color = props.color or Color3.fromRGB(60, 60, 70)
	part.Material = props.material or Enum.Material.Concrete
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function addSign(zonePart, title, subtitle)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneSign"
	billboard.Size = UDim2.fromOffset(200, 80)
	billboard.StudsOffset = Vector3.new(0, zonePart.Size.Y / 2 + 4, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = zonePart

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -8, 0.55, 0)
	titleLabel.Position = UDim2.fromOffset(4, 2)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextScaled = true
	titleLabel.Text = title
	titleLabel.Parent = frame

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "Subtitle"
	subLabel.Size = UDim2.new(1, -8, 0.4, 0)
	subLabel.Position = UDim2.new(0, 4, 0.55, 0)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
	subLabel.TextScaled = true
	subLabel.Text = subtitle
	subLabel.Parent = frame
end

local function addProximityPrompt(zonePart, actionName)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = "Interagieren"
	prompt.ObjectText = zonePart:GetAttribute("ZoneName") or zonePart.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("HubAction", actionName)
	prompt.Parent = zonePart
end

local function buildWalls(hub, origin, floorSize, wallHeight)
	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local wallThickness = 2
	local wallY = origin.Y + wallHeight / 2

	local walls = {
		{ size = Vector3.new(floorSize.X + wallThickness * 2, wallHeight, wallThickness), pos = Vector3.new(origin.X, wallY, origin.Z - halfZ - wallThickness / 2) },
		{ size = Vector3.new(floorSize.X + wallThickness * 2, wallHeight, wallThickness), pos = Vector3.new(origin.X, wallY, origin.Z + halfZ + wallThickness / 2) },
		{ size = Vector3.new(wallThickness, wallHeight, floorSize.Z), pos = Vector3.new(origin.X - halfX - wallThickness / 2, wallY, origin.Z) },
		{ size = Vector3.new(wallThickness, wallHeight, floorSize.Z), pos = Vector3.new(origin.X + halfX + wallThickness / 2, wallY, origin.Z) },
	}

	local wallsFolder = Instance.new("Folder")
	wallsFolder.Name = "Walls"
	wallsFolder.Parent = hub

	for i, wall in walls do
		makePart({
			name = "Wall" .. i,
			parent = wallsFolder,
			size = wall.size,
			position = wall.pos,
			color = Color3.fromRGB(45, 48, 58),
			material = Enum.Material.Brick,
		})
	end
end

function HubWorldBuilder.buildLeaderboardDisplay(zonePart, entries)
	local existing = zonePart:FindFirstChild("LeaderboardDisplay")
	if existing then
		existing:Destroy()
	end

	local surface = Instance.new("SurfaceGui")
	surface.Name = "LeaderboardDisplay"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.Parent = zonePart

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = false
	label.TextSize = 18
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true

	local lines = { "🏆 Ruhmeshalle", "" }
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	else
		for _, entry in entries do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
	end
	label.Text = table.concat(lines, "\n")
	label.Parent = frame
end

function HubWorldBuilder.build()
	local existing = Workspace:FindFirstChild(HubConfig.HUB_MODEL_NAME)
	if existing then
		return existing
	end

	local origin = HubConfig.HUB_ORIGIN
	local hub = Instance.new("Model")
	hub.Name = HubConfig.HUB_MODEL_NAME
	hub.Parent = Workspace

	local floor = makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		position = origin + Vector3.new(0, -HubConfig.FLOOR_SIZE.Y / 2, 0),
		color = Color3.fromRGB(55, 58, 68),
		material = Enum.Material.Slate,
	})

	local spawn = makePart({
		name = HubConfig.HUB_SPAWN_NAME,
		parent = hub,
		size = Vector3.new(6, 1, 6),
		position = origin + HubConfig.SPAWN_OFFSET,
		color = Color3.fromRGB(100, 200, 255),
		material = Enum.Material.Neon,
		canCollide = false,
	})
	spawn.Transparency = 0.5

	buildWalls(hub, origin, HubConfig.FLOOR_SIZE, HubConfig.WALL_HEIGHT)

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for zoneId, zone in HubConfig.ZONES do
		local zonePart = makePart({
			name = zoneId,
			parent = zonesFolder,
			size = zone.size,
			position = origin + zone.position + Vector3.new(0, zone.size.Y / 2, 0),
			color = zone.color,
			material = Enum.Material.SmoothPlastic,
		})
		zonePart:SetAttribute("ZoneName", zone.name)
		zonePart:SetAttribute("HubAction", zone.action)
		addSign(zonePart, zone.name, zone.description)
		addProximityPrompt(zonePart, zone.action)

		if zoneId == "HallOfFame" then
			HubWorldBuilder.buildLeaderboardDisplay(zonePart, {})
		end
	end

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 60
	light.Parent = floor

	hub.PrimaryPart = floor
	return hub
end

function HubWorldBuilder.getHubSpawn()
	local hub = Workspace:FindFirstChild(HubConfig.HUB_MODEL_NAME)
	if not hub then return nil end
	return hub:FindFirstChild(HubConfig.HUB_SPAWN_NAME)
end

function HubWorldBuilder.getZonePart(zoneId)
	local hub = Workspace:FindFirstChild(HubConfig.HUB_MODEL_NAME)
	if not hub then return nil end
	local zones = hub:FindFirstChild("Zones")
	if not zones then return nil end
	return zones:FindFirstChild(zoneId)
end

return HubWorldBuilder
