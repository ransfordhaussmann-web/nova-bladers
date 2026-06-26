local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color or HubConfig.FLOOR_COLOR
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Name = props.Name or "Part"
	part.Parent = props.Parent
	return part
end

local function addPrompt(part, zone)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = zone.promptAction
	prompt.ActionText = zone.promptText
	prompt.ObjectText = "Nova Hub"
	prompt.MaxActivationDistance = HubConfig.PROMPT_MAX_DISTANCE
	prompt.HoldDuration = HubConfig.PROMPT_HOLD_DURATION
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
end

local function addBoardLabel(part, face, title)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = part

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 40)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = HubConfig.ACCENT_COLOR
	titleLabel.TextSize = 22
	titleLabel.Text = title
	titleLabel.Parent = frame

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Size = UDim2.new(1, -12, 1, -48)
	body.Position = UDim2.new(0, 6, 0, 44)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Gotham
	body.TextColor3 = Color3.fromRGB(220, 225, 235)
	body.TextSize = 18
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.Text = "Laden…"
	body.Parent = frame
end

function HubWorldBuilder.build(parent)
	local existing = parent:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = parent

	local origin = HubConfig.SPAWN_POSITION - Vector3.new(0, 4, 0)

	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		CFrame = CFrame.new(origin),
		Color = HubConfig.FLOOR_COLOR,
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	local rimThickness = 1.2
	local rimHeight = 2
	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	for _, spec in {
		{ Vector3.new(0, rimHeight / 2, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X + rimThickness, rimHeight, rimThickness) },
		{ Vector3.new(0, rimHeight / 2, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X + rimThickness, rimHeight, rimThickness) },
		{ Vector3.new(-halfX, rimHeight / 2, 0), Vector3.new(rimThickness, rimHeight, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(halfX, rimHeight / 2, 0), Vector3.new(rimThickness, rimHeight, HubConfig.FLOOR_SIZE.Z) },
	} do
		makePart({
			Name = "Rim",
			Size = spec[2],
			CFrame = CFrame.new(origin + spec[1]),
			Color = HubConfig.RIM_COLOR,
			Parent = hub,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	for zoneName, zone in HubConfig.ZONES do
		local pos = origin + zone.offset + Vector3.new(0, zone.size.Y / 2, 0)
		local part = makePart({
			Name = zoneName,
			Size = zone.size,
			CFrame = CFrame.new(pos),
			Color = zone.color,
			Parent = hub,
		})

		if zoneName == "LeaderboardBoard" then
			part.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(180), 0)
			addBoardLabel(part, Enum.NormalId.Front, "Top Spieler")
		elseif zoneName == "StatsBoard" then
			part.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, 0)
			addBoardLabel(part, Enum.NormalId.Front, "Deine Stats")
		elseif zone.promptAction then
			addPrompt(part, zone)
		end
	end

	local light = Instance.new("PointLight")
	light.Brightness = 1.2
	light.Range = 40
	light.Color = HubConfig.ACCENT_COLOR
	light.Parent = floor

	local marker = makePart({
		Name = "CenterMarker",
		Size = Vector3.new(4, 0.4, 4),
		CFrame = CFrame.new(origin + Vector3.new(0, HubConfig.FLOOR_SIZE.Y / 2 + 0.2, 0)),
		Color = HubConfig.ACCENT_COLOR,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = hub,
	})
	marker.Transparency = 0.35

	return hub
end

return HubWorldBuilder
