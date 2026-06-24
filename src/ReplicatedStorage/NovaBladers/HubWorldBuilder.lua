local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function createPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Name = props.Name
	part.Size = props.Size
	part.Position = props.Position
	part.Color = props.Color or Color3.fromRGB(35, 40, 55)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.CanCollide = props.CanCollide ~= false
	part.Transparency = props.Transparency or 0
	part.Parent = props.Parent
	return part
end

local function createLabel(parent, title, subtitle)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 60)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextScaled = true
	titleLabel.Text = title
	titleLabel.Parent = billboard

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subtitleLabel.Position = UDim2.fromScale(0, 0.55)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Font = Enum.Font.Gotham
	subtitleLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
	subtitleLabel.TextScaled = true
	subtitleLabel.Text = subtitle
	subtitleLabel.Parent = billboard
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_NAME
	hub.Parent = workspace

	local floorSize = HubConfig.FLOOR_SIZE
	createPart({
		Name = "Floor",
		Size = floorSize,
		Position = Vector3.new(0, 0, 0),
		Color = Color3.fromRGB(28, 32, 48),
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	createPart({
		Name = "SpawnPad",
		Size = Vector3.new(10, 0.4, 10),
		Position = HubConfig.SPAWN_POSITION - Vector3.new(0, 3.2, 0),
		Color = Color3.fromRGB(90, 120, 255),
		Material = Enum.Material.Neon,
		Parent = hub,
	})

	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS
	local wallY = wallH / 2

	local walls = {
		{ Name = "WallNorth", Size = Vector3.new(floorSize.X + wallT * 2, wallH, wallT), Position = Vector3.new(0, wallY, -halfZ - wallT / 2) },
		{ Name = "WallSouth", Size = Vector3.new(floorSize.X + wallT * 2, wallH, wallT), Position = Vector3.new(0, wallY, halfZ + wallT / 2) },
		{ Name = "WallWest", Size = Vector3.new(wallT, wallH, floorSize.Z), Position = Vector3.new(-halfX - wallT / 2, wallY, 0) },
		{ Name = "WallEast", Size = Vector3.new(wallT, wallH, floorSize.Z), Position = Vector3.new(halfX + wallT / 2, wallY, 0) },
	}

	for _, wall in walls do
		createPart({
			Name = wall.Name,
			Size = wall.Size,
			Position = wall.Position,
			Color = Color3.fromRGB(45, 50, 68),
			Material = Enum.Material.Concrete,
			Parent = hub,
		})
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local marker = createPart({
			Name = zone.id,
			Size = zone.size,
			Position = zone.position,
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.35,
			Parent = zonesFolder,
		})
		marker:SetAttribute("ZoneId", zone.id)
		marker:SetAttribute("ZoneAction", zone.action)
		createLabel(marker, zone.name, zone.subtitle)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION - Vector3.new(0, 2.5, 0)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	return hub
end

function HubWorldBuilder.getZoneParts()
	local hub = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if not hub then return {} end
	local zonesFolder = hub:FindFirstChild("Zones")
	if not zonesFolder then return {} end

	local parts = {}
	for _, child in zonesFolder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end
	return parts
end

return HubWorldBuilder
