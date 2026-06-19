local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	return part
end

local function addBillboard(parent, text, color)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, parent.Size.Y / 2 + 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	label.TextColor3 = color
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	return billboard
end

local function addProximityPrompt(parent, actionText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = actionText
	prompt.ObjectText = parent:GetAttribute("ZoneName") or parent.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

function HubWorldBuilder.build()
	local existing = Workspace:FindFirstChild("NovaHub")
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = Workspace

	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = HubConfig.SPAWN - Vector3.new(0, 2.5, 0),
		Color = Color3.fromRGB(45, 48, 58),
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hub

	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = hub

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallThickness = 2
	local wallY = floor.Position.Y + HubConfig.WALL_HEIGHT / 2

	local wallDefs = {
		{ Vector3.new(0, wallY, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, wallThickness) },
		{ Vector3.new(0, wallY, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, wallThickness) },
		{ Vector3.new(-halfX, wallY, 0), Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(halfX, wallY, 0), Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z) },
	}

	for index, def in wallDefs do
		makePart({
			Name = "Wall" .. index,
			Size = def[2],
			Position = def[1],
			Color = Color3.fromRGB(60, 64, 78),
			Material = Enum.Material.Concrete,
			Parent = walls,
		})
	end

	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = hub

	for zoneId, zone in HubConfig.ZONES do
		local zonePart = makePart({
			Name = zoneId,
			Size = zone.size,
			Position = zone.position,
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.55,
			CanCollide = false,
			Parent = zones,
		})
		zonePart:SetAttribute("ZoneId", zoneId)
		zonePart:SetAttribute("ZoneAction", zone.action)
		zonePart:SetAttribute("ZoneName", zone.name)

		addBillboard(zonePart, zone.name, zone.color)
		addProximityPrompt(zonePart, zone.promptText)
	end

	Lighting.Ambient = Color3.fromRGB(90, 95, 110)
	Lighting.OutdoorAmbient = Color3.fromRGB(110, 115, 130)

	return hub
end

return HubWorldBuilder
