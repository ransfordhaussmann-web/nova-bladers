local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldConfig = require(ReplicatedStorage.NovaBladers.HubWorldConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Color = props.Color or Color3.new(1, 1, 1)
	part.Size = props.Size or Vector3.new(4, 1, 4)
	part.CFrame = props.CFrame or CFrame.new(props.Position or Vector3.zero)
	part.Name = props.Name or "Part"
	part.Transparency = props.Transparency or 0
	part.Parent = props.Parent
	return part
end

local function addSurfaceLabel(part, text, textSize)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextSize = textSize or 28
	label.Parent = gui

	return gui
end

local function addBillboard(part, title, subtitle)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 70)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = part

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -12, 0.55, 0)
	titleLabel.Position = UDim2.fromOffset(6, 4)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextScaled = true
	titleLabel.Text = title
	titleLabel.Parent = frame

	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, -12, 0.4, 0)
	subLabel.Position = UDim2.new(0, 6, 0.55, 0)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
	subLabel.TextScaled = true
	subLabel.Text = subtitle
	subLabel.Parent = frame

	return gui
end

local function addProximityPrompt(part, actionText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = part.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

local function addZonePad(folder, zoneKey, zone)
	local pad = makePart({
		Name = zone.id,
		Parent = folder,
		Position = zone.position,
		Size = zone.size,
		Color = zone.color,
		Material = Enum.Material.Neon,
	})
	pad:SetAttribute("HubZone", zone.action)
	pad:SetAttribute("ZoneKey", zoneKey)

	local trim = makePart({
		Name = zone.id .. "Trim",
		Parent = pad,
		Size = Vector3.new(zone.size.X + 1.2, 0.25, zone.size.Z + 1.2),
		Position = Vector3.new(0, -0.5, 0),
		Color = HubWorldConfig.THEME.trim,
		Material = Enum.Material.Metal,
	})
	trim.CanCollide = false

	addBillboard(pad, zone.label, zone.hint)
	addProximityPrompt(pad, zone.promptText)

	local light = Instance.new("PointLight")
	light.Color = zone.color
	light.Brightness = 1.2
	light.Range = 16
	light.Parent = pad

	return pad
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("HubWorld")
	if existing then
		return existing
	end

	local theme = HubWorldConfig.THEME
	local hub = Instance.new("Model")
	hub.Name = "HubWorld"

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = HubWorldConfig.SPAWN - Vector3.new(0, 2.5, 0)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	local floor = makePart({
		Name = "MainFloor",
		Parent = hub,
		Position = Vector3.new(0, -HubWorldConfig.PLATFORM_HEIGHT / 2, 0),
		Size = Vector3.new(HubWorldConfig.PLATFORM_RADIUS * 2, HubWorldConfig.PLATFORM_HEIGHT, HubWorldConfig.PLATFORM_RADIUS * 2),
		Color = theme.floor,
		Material = Enum.Material.Slate,
	})
	floor.Shape = Enum.PartType.Cylinder
	floor.CFrame = CFrame.new(floor.Position) * CFrame.Angles(0, 0, math.rad(90))

	local accentRing = makePart({
		Name = "AccentRing",
		Parent = hub,
		Position = Vector3.new(0, 0.05, 0),
		Size = Vector3.new(HubWorldConfig.PLATFORM_RADIUS * 1.85, 0.3, HubWorldConfig.PLATFORM_RADIUS * 1.85),
		Color = theme.floorAccent,
		Material = Enum.Material.Metal,
	})
	accentRing.Shape = Enum.PartType.Cylinder
	accentRing.CFrame = CFrame.new(accentRing.Position) * CFrame.Angles(0, 0, math.rad(90))

	local centerPlaza = makePart({
		Name = "CenterPlaza",
		Parent = hub,
		Position = Vector3.new(0, 0.15, 0),
		Size = Vector3.new(18, 0.4, 18),
		Color = theme.trim,
		Material = Enum.Material.Neon,
	})
	centerPlaza.CanCollide = false

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for zoneKey, zone in HubWorldConfig.ZONES do
		addZonePad(zonesFolder, zoneKey, zone)
	end

	local lb = HubWorldConfig.LEADERBOARD
	local board = makePart({
		Name = "LeaderboardMonument",
		Parent = hub,
		Position = lb.position + Vector3.new(0, lb.size.Y / 2, 0),
		Size = lb.size,
		Color = theme.floorAccent,
		Material = Enum.Material.Metal,
	})
	board:SetAttribute("HubZone", "leaderboard")

	local boardGui = addSurfaceLabel(board, lb.label .. "\n\nLade...", 24)
	boardGui.Name = "LeaderboardSurface"
	boardGui.Face = Enum.NormalId.Back

	local boardLight = Instance.new("PointLight")
	boardLight.Color = theme.trimSecondary
	boardLight.Brightness = 1
	boardLight.Range = 20
	boardLight.Parent = board

	local decor = HubWorldConfig.DECOR
	for i = 1, decor.pillarCount do
		local angle = (i / decor.pillarCount) * math.pi * 2
		local x = math.cos(angle) * decor.pillarRadius
		local z = math.sin(angle) * decor.pillarRadius
		local pillar = makePart({
			Name = "Pillar_" .. i,
			Parent = hub,
			Position = Vector3.new(x, decor.pillarHeight / 2, z),
			Size = Vector3.new(2.5, decor.pillarHeight, 2.5),
			Color = theme.floorAccent,
			Material = Enum.Material.Concrete,
		})

		local cap = makePart({
			Name = "PillarCap",
			Parent = pillar,
			Position = Vector3.new(0, decor.pillarHeight / 2 + 0.5, 0),
			Size = Vector3.new(3.5, 1, 3.5),
			Color = theme.trim,
			Material = Enum.Material.Neon,
		})
		cap.CanCollide = false

		local pillarLight = Instance.new("PointLight")
		pillarLight.Color = theme.trim
		pillarLight.Brightness = 0.8
		pillarLight.Range = 14
		pillarLight.Parent = cap
	end

	local boundaryFolder = Instance.new("Folder")
	boundaryFolder.Name = "Boundaries"
	boundaryFolder.Parent = hub

	local segments = 16
	local wallRadius = HubWorldConfig.PLATFORM_RADIUS + 2
	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		local nextAngle = ((i + 1) / segments) * math.pi * 2
		local midAngle = (angle + nextAngle) / 2
		local chord = 2 * wallRadius * math.sin(math.pi / segments)
		local x = math.cos(midAngle) * wallRadius
		local z = math.sin(midAngle) * wallRadius

		makePart({
			Name = "Boundary_" .. i,
			Parent = boundaryFolder,
			Position = Vector3.new(x, HubWorldConfig.BOUNDARY_HEIGHT / 2, z),
			Size = Vector3.new(chord + 1, HubWorldConfig.BOUNDARY_HEIGHT, 1.5),
			Color = theme.floor,
			Material = Enum.Material.Glass,
			Transparency = 0.65,
			CFrame = CFrame.new(x, HubWorldConfig.BOUNDARY_HEIGHT / 2, z)
				* CFrame.Angles(0, -midAngle + math.pi / 2, 0),
		})
	end

	hub.PrimaryPart = floor
	hub.Parent = workspace

	return hub
end

function HubWorldBuilder.updateLeaderboard(hub, lines)
	local board = hub:FindFirstChild("LeaderboardMonument")
	if not board then return end
	local gui = board:FindFirstChild("LeaderboardSurface")
	if not gui then return end
	local label = gui:FindFirstChildOfClass("TextLabel")
	if label then
		label.Text = table.concat(lines, "\n")
	end
end

return HubWorldBuilder
