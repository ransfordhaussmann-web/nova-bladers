local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage.NovaBladers.HubWorldConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Color = props.Color or Config.COLORS.Floor
	part.Size = props.Size or Vector3.new(4, 1, 4)
	part.CFrame = props.CFrame or CFrame.new(props.Position or Vector3.zero)
	part.Name = props.Name or "Part"
	part.Transparency = props.Transparency or 0
	part.Parent = props.Parent
	return part
end

local function addNeonTrim(parent, position, size, color)
	local trim = makePart({
		Name = "NeonTrim",
		Parent = parent,
		Position = position,
		Size = size,
		Color = color or Config.COLORS.Neon,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	trim.Transparency = 0.15
	return trim
end

local function buildZonePad(parent, zone)
	local pad = makePart({
		Name = zone.id,
		Parent = parent,
		Position = zone.position,
		Size = zone.size,
		Color = zone.color,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	pad.Transparency = 0.35
	pad:SetAttribute("ZoneId", zone.id)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zone.label
	prompt.ObjectText = "Nova Hub"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = zone.radius + 2
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(180, 48)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = pad

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 18
	label.Text = zone.label
	label.Parent = billboard

	return pad
end

function HubWorldBuilder.applyLighting()
	Lighting.Ambient = Config.LIGHTING.Ambient
	Lighting.OutdoorAmbient = Config.LIGHTING.OutdoorAmbient
	Lighting.Brightness = Config.LIGHTING.Brightness
	Lighting.ClockTime = Config.LIGHTING.ClockTime
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(Config.ROOT_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = Config.ROOT_NAME
	hub.Parent = workspace

	local floorSize = Config.HUB.FLOOR_SIZE
	local floorY = Config.HUB.FLOOR_Y

	makePart({
		Name = "Floor",
		Parent = hub,
		Position = Vector3.new(0, floorY - floorSize.Y / 2, 0),
		Size = floorSize,
		Color = Config.COLORS.Floor,
		Material = Enum.Material.Slate,
	})

	makePart({
		Name = "FloorAccent",
		Parent = hub,
		Position = Vector3.new(0, floorY + 0.05, 0),
		Size = Vector3.new(floorSize.X - 8, 0.2, floorSize.Z - 8),
		Color = Config.COLORS.FloorAccent,
		Material = Enum.Material.Metal,
		CanCollide = false,
	})

	local wallHeight = Config.HUB.WALL_HEIGHT
	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local wallThickness = 2

	local walls = {
		{ pos = Vector3.new(0, wallHeight / 2, -halfZ), size = Vector3.new(floorSize.X, wallHeight, wallThickness) },
		{ pos = Vector3.new(0, wallHeight / 2, halfZ), size = Vector3.new(floorSize.X, wallHeight, wallThickness) },
		{ pos = Vector3.new(-halfX, wallHeight / 2, 0), size = Vector3.new(wallThickness, wallHeight, floorSize.Z) },
		{ pos = Vector3.new(halfX, wallHeight / 2, 0), size = Vector3.new(wallThickness, wallHeight, floorSize.Z) },
	}

	for index, wall in walls do
		makePart({
			Name = "Wall" .. index,
			Parent = hub,
			Position = wall.pos,
			Size = wall.size,
			Color = Config.COLORS.Wall,
			Material = Enum.Material.Concrete,
		})
	end

	addNeonTrim(hub, Vector3.new(0, 0.6, -halfZ + 1), Vector3.new(floorSize.X - 4, 0.3, 0.4), Config.COLORS.Neon)
	addNeonTrim(hub, Vector3.new(0, 0.6, halfZ - 1), Vector3.new(floorSize.X - 4, 0.3, 0.4), Config.COLORS.Trim)

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in Config.ZONES do
		buildZonePad(zonesFolder, zone)
	end

	local centerRing = makePart({
		Name = "CenterRing",
		Parent = hub,
		Position = Vector3.new(0, 1.2, 12),
		Size = Vector3.new(12, 0.3, 12),
		Color = Config.COLORS.Neon,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	centerRing.Transparency = 0.4
	centerRing.Shape = Enum.PartType.Cylinder
	centerRing.Orientation = Vector3.new(0, 0, 90)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = Config.HUB.SPAWN
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	local sign = makePart({
		Name = "HubSign",
		Parent = hub,
		Position = Vector3.new(0, 6, 12),
		Size = Vector3.new(18, 3, 0.5),
		Color = Config.COLORS.Trim,
		Material = Enum.Material.Metal,
		CanCollide = false,
	})

	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.Parent = sign

	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.BackgroundTransparency = 1
	signLabel.Font = Enum.Font.GothamBlack
	signLabel.TextColor3 = Config.COLORS.Neon
	signLabel.TextSize = 42
	signLabel.Text = "NOVA BLADERS"
	signLabel.Parent = signGui

	HubWorldBuilder.applyLighting()
	return hub
end

return HubWorldBuilder
