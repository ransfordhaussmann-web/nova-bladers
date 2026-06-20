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

local function addZoneLabel(part, zone)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 60)
	billboard.StudsOffset = Vector3.new(0, zone.size.Y * 0.5 + 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 18
	label.Text = zone.name
	label.Parent = billboard
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HubFolderName)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HubFolderName
	hub.Parent = workspace

	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.FloorSize,
		Position = HubConfig.FloorPosition,
		Color = HubConfig.Colors.Floor,
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	local halfX = HubConfig.FloorSize.X * 0.5
	local halfZ = HubConfig.FloorSize.Z * 0.5
	local wallY = HubConfig.FloorPosition.Y + HubConfig.WallHeight * 0.5

	local walls = {
		{ Name = "WallNorth", Size = Vector3.new(HubConfig.FloorSize.X, HubConfig.WallHeight, HubConfig.WallThickness), Position = Vector3.new(0, wallY, -halfZ) },
		{ Name = "WallSouth", Size = Vector3.new(HubConfig.FloorSize.X, HubConfig.WallHeight, HubConfig.WallThickness), Position = Vector3.new(0, wallY, halfZ) },
		{ Name = "WallWest", Size = Vector3.new(HubConfig.WallThickness, HubConfig.WallHeight, HubConfig.FloorSize.Z), Position = Vector3.new(-halfX, wallY, 0) },
		{ Name = "WallEast", Size = Vector3.new(HubConfig.WallThickness, HubConfig.WallHeight, HubConfig.FloorSize.Z), Position = Vector3.new(halfX, wallY, 0) },
	}

	for _, wallData in walls do
		makePart({
			Name = wallData.Name,
			Size = wallData.Size,
			Position = wallData.Position,
			Color = HubConfig.Colors.Wall,
			Material = Enum.Material.Concrete,
			Parent = hub,
		})
	end

	local spawn = makePart({
		Name = HubConfig.SpawnName,
		Size = Vector3.new(6, 1, 6),
		Position = Vector3.new(0, HubConfig.FloorPosition.Y + 0.5, 10),
		Transparency = 1,
		CanCollide = false,
		Parent = hub,
	})
	spawn:SetAttribute("IsHubSpawn", true)

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.Zones do
		local zonePart = makePart({
			Name = zone.id,
			Size = zone.size,
			Position = zone.position,
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.35,
			CanCollide = false,
			Parent = zonesFolder,
		})
		zonePart:SetAttribute("ZoneId", zone.id)
		zonePart:SetAttribute("ZoneAction", zone.action)
		zonePart:SetAttribute("ZoneHint", zone.hint)
		addZoneLabel(zonePart, zone)
	end

	return hub
end

function HubWorldBuilder.getSpawnCFrame()
	local hub = workspace:FindFirstChild(HubConfig.HubFolderName)
	if hub then
		local spawn = hub:FindFirstChild(HubConfig.SpawnName)
		if spawn then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(0, 5, 10)
end

return HubWorldBuilder
