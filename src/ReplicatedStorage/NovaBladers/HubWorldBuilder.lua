local Workspace = game:GetService("Workspace")

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

local function addZoneLabel(parent, zone)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 60)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.TextSize = 20
	label.Text = zone.name
	label.Parent = billboard
end

function HubWorldBuilder.build()
	local existing = Workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = Workspace

	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = Vector3.new(0, 0, 0),
		Color = Color3.fromRGB(35, 38, 48),
		Material = Enum.Material.Slate,
	})
	floor.Parent = hub

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallThickness = 2
	local wallY = HubConfig.WALL_HEIGHT / 2

	local walls = {
		{ Size = Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, wallThickness), Position = Vector3.new(0, wallY, -halfZ) },
		{ Size = Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.WALL_HEIGHT, wallThickness), Position = Vector3.new(0, wallY, halfZ) },
		{ Size = Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), Position = Vector3.new(-halfX, wallY, 0) },
		{ Size = Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z), Position = Vector3.new(halfX, wallY, 0) },
	}

	for index, wall in walls do
		local part = makePart({
			Name = "Wall" .. index,
			Size = wall.Size,
			Position = wall.Position,
			Color = Color3.fromRGB(50, 54, 68),
			Material = Enum.Material.Concrete,
			Transparency = 0.15,
		})
		part.Parent = hub
	end

	local spawn = makePart({
		Name = "HubSpawn",
		Size = Vector3.new(6, 1, 6),
		Position = HubConfig.SPAWN_POSITION - Vector3.new(0, 2.5, 0),
		Color = Color3.fromRGB(90, 200, 140),
		Material = Enum.Material.Neon,
		Transparency = 0.35,
	})
	spawn:SetAttribute("ZoneId", "Spawn")
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local pad = makePart({
			Name = zone.id,
			Size = zone.size,
			Position = zone.position,
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.45,
		})
		pad:SetAttribute("ZoneId", zone.id)
		pad:SetAttribute("Hint", zone.hint)
		pad.Parent = zonesFolder
		addZoneLabel(pad, zone)
	end

	return hub
end

return HubWorldBuilder
