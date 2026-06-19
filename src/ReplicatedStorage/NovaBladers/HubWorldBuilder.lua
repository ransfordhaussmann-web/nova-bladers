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

local function makeSign(text, position, parent)
	local sign = makePart({
		Name = "Sign",
		Size = Vector3.new(10, 3, 0.4),
		Position = position,
		Color = Color3.fromRGB(30, 35, 50),
		Material = Enum.Material.SmoothPlastic,
	})
	sign.Parent = parent

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	return sign
end

local function makeZone(id, zoneDef, parent)
	local zone = makePart({
		Name = id,
		Size = zoneDef.size,
		Position = zoneDef.position,
		Color = zoneDef.color,
		Transparency = 0.35,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	zone:SetAttribute("ZoneAction", zoneDef.action)
	zone:SetAttribute("PromptText", zoneDef.promptText)
	zone.Parent = parent

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = zoneDef.promptText
	prompt.ObjectText = zoneDef.name
	prompt.MaxActivationDistance = 12
	prompt.HoldDuration = 0
	prompt.Parent = zone

	makeSign(zoneDef.name, zoneDef.position + Vector3.new(0, zoneDef.size.Y * 0.5 + 2, 0), parent)

	return zone
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		return existing
	end

	local hub = Instance.new("Model")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = Vector3.new(0, 0, 0),
		Color = Color3.fromRGB(45, 50, 65),
		Material = Enum.Material.Slate,
	})
	floor.Parent = hub

	local halfX = HubConfig.FLOOR_SIZE.X * 0.5
	local halfZ = HubConfig.FLOOR_SIZE.Z * 0.5
	local wallH = HubConfig.WALL_HEIGHT

	local walls = {
		{ Vector3.new(0, wallH * 0.5, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 2) },
		{ Vector3.new(0, wallH * 0.5, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 2) },
		{ Vector3.new(-halfX, wallH * 0.5, 0), Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(halfX, wallH * 0.5, 0), Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z) },
	}
	for i, wallDef in walls do
		local wall = makePart({
			Name = "Wall" .. i,
			Size = wallDef[2],
			Position = wallDef[1],
			Color = Color3.fromRGB(35, 40, 55),
			Material = Enum.Material.Concrete,
		})
		wall.Parent = hub
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = hub

	for id, zoneDef in HubConfig.ZONES do
		makeZone(id, zoneDef, hub)
	end

	local fameZone = hub:FindFirstChild("HallOfFame")
	if fameZone then
		local board = makePart({
			Name = "StatsBoard",
			Size = Vector3.new(12, 8, 0.5),
			Position = fameZone.Position + HubConfig.BOARD_OFFSET,
			Color = Color3.fromRGB(25, 28, 38),
			Material = Enum.Material.SmoothPlastic,
		})
		board.Parent = hub

		local boardGui = Instance.new("SurfaceGui")
		boardGui.Face = Enum.NormalId.Front
		boardGui.Parent = board

		local boardLabel = Instance.new("TextLabel")
		boardLabel.Name = "BoardText"
		boardLabel.Size = UDim2.fromScale(1, 1)
		boardLabel.BackgroundTransparency = 1
		boardLabel.Text = "Ruhmeshalle\n— Stats laden —"
		boardLabel.TextColor3 = Color3.new(1, 1, 1)
		boardLabel.TextScaled = false
		boardLabel.TextSize = 22
		boardLabel.TextWrapped = true
		boardLabel.Font = Enum.Font.GothamMedium
		boardLabel.Parent = boardGui
	end

	return hub
end

return HubWorldBuilder
