local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color or Color3.new(1, 1, 1)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Name = props.Name
	part.Transparency = props.Transparency or 0
	if props.Parent then
		part.Parent = props.Parent
	end
	return part
end

local function addSign(parent, text, position, color)
	local sign = makePart({
		Name = "Sign",
		Size = Vector3.new(10, 4, 0.4),
		CFrame = CFrame.new(position + Vector3.new(0, 5, 0)),
		Color = color,
		Parent = parent,
	})

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

function HubWorldBuilder.build(hubFolder)
	local center = HubConfig.HUB_CENTER
	local half = HubConfig.HUB_SIZE / 2

	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.HUB_SIZE,
		CFrame = CFrame.new(center),
		Color = HubConfig.FLOOR_COLOR,
		Material = Enum.Material.Slate,
		Parent = hubFolder,
	})

	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = hubFolder

	local wallDefs = {
		{ Vector3.new(half.X, HubConfig.WALL_HEIGHT / 2, 0), Vector3.new(2, HubConfig.WALL_HEIGHT, HubConfig.HUB_SIZE.Z) },
		{ Vector3.new(-half.X, HubConfig.WALL_HEIGHT / 2, 0), Vector3.new(2, HubConfig.WALL_HEIGHT, HubConfig.HUB_SIZE.Z) },
		{ Vector3.new(0, HubConfig.WALL_HEIGHT / 2, half.Z), Vector3.new(HubConfig.HUB_SIZE.X, HubConfig.WALL_HEIGHT, 2) },
		{ Vector3.new(0, HubConfig.WALL_HEIGHT / 2, -half.Z), Vector3.new(HubConfig.HUB_SIZE.X, HubConfig.WALL_HEIGHT, 2) },
	}

	for i, def in wallDefs do
		makePart({
			Name = "Wall" .. i,
			Size = def[2],
			CFrame = CFrame.new(center + def[1]),
			Color = HubConfig.WALL_COLOR,
			Parent = walls,
		})
	end

	local spawn = makePart({
		Name = "Spawn",
		Size = Vector3.new(6, 1, 6),
		CFrame = CFrame.new(center + HubConfig.SPAWN_OFFSET),
		Color = HubConfig.ACCENT_COLOR,
		Transparency = 0.35,
		CanCollide = false,
		Parent = hubFolder,
	})
	spawn:SetAttribute("IsHubSpawn", true)

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hubFolder

	for _, zone in HubConfig.ZONES do
		local zonePart = makePart({
			Name = zone.id,
			Size = zone.size,
			CFrame = CFrame.new(center + zone.offset + Vector3.new(0, 0.6, 0)),
			Color = zone.color,
			Transparency = 0.55,
			CanCollide = false,
			Parent = zonesFolder,
		})
		zonePart:SetAttribute("ZoneId", zone.id)
		zonePart:SetAttribute("ZoneAction", zone.action)
		addSign(zonesFolder, zone.name, center + zone.offset, zone.color)
	end

	local boardPart = makePart({
		Name = "LeaderboardBoard",
		Size = Vector3.new(14, 10, 0.5),
		CFrame = CFrame.new(center + Vector3.new(38, 6, -22)),
		Color = Color3.fromRGB(25, 28, 40),
		Parent = hubFolder,
	})

	local boardGui = Instance.new("SurfaceGui")
	boardGui.Name = "BoardGui"
	boardGui.Face = Enum.NormalId.Front
	boardGui.Parent = boardPart

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.Text = "🏆 Nova Liga"
	title.TextColor3 = Color3.fromRGB(255, 220, 100)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = boardGui

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Size = UDim2.new(1, -12, 1, -44)
	list.Position = UDim2.new(0, 6, 0, 40)
	list.BackgroundTransparency = 1
	list.Text = "Lade Rangliste..."
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextSize = 18
	list.Font = Enum.Font.Gotham
	list.TextWrapped = true
	list.Parent = boardGui

	return {
		Folder = hubFolder,
		Floor = floor,
		Spawn = spawn,
		Zones = zonesFolder,
		LeaderboardBoard = boardPart,
	}
end

return HubWorldBuilder
