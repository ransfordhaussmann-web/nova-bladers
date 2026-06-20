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

local function makeSign(parent, text, offset)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = offset or Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		return existing
	end

	local hub = Instance.new("Model")
	hub.Name = "NovaHub"

	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = Vector3.new(0, 0, 0),
		Color = Color3.fromRGB(35, 38, 48),
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT

	local walls = {
		{ Name = "WallNorth", Size = Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 2), Position = Vector3.new(0, wallH / 2, -halfZ) },
		{ Name = "WallSouth", Size = Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 2), Position = Vector3.new(0, wallH / 2, halfZ) },
		{ Name = "WallWest", Size = Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z), Position = Vector3.new(-halfX, wallH / 2, 0) },
		{ Name = "WallEast", Size = Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z), Position = Vector3.new(halfX, wallH / 2, 0) },
	}

	for _, wallData in walls do
		makePart({
			Name = wallData.Name,
			Size = wallData.Size,
			Position = wallData.Position,
			Color = Color3.fromRGB(50, 55, 70),
			Material = Enum.Material.Concrete,
			Transparency = 0.15,
			Parent = hub,
		})
	end

	local spawn = makePart({
		Name = "HubSpawn",
		Size = Vector3.new(6, 1, 6),
		Position = HubConfig.SPAWN,
		Color = Color3.fromRGB(90, 200, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.4,
		CanCollide = false,
		Parent = hub,
	})
	makeSign(spawn, "Nova Hub", Vector3.new(0, 4, 0))

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zonePart = makePart({
			Name = zone.id,
			Size = zone.size,
			Position = zone.position,
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.55,
			CanCollide = true,
			Parent = zonesFolder,
		})
		zonePart:SetAttribute("ZoneId", zone.id)
		zonePart:SetAttribute("ZoneAction", zone.action)
		makeSign(zonePart, zone.name, Vector3.new(0, zone.size.Y / 2 + 2, 0))

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = zone.prompt
		prompt.ObjectText = zone.name
		prompt.MaxActivationDistance = 12
		prompt.HoldDuration = 0
		prompt.Parent = zonePart
	end

	hub.PrimaryPart = floor
	hub.Parent = workspace

	return hub
end

return HubWorldBuilder
