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
	part.Transparency = props.Transparency or 0
	part.Name = props.Name or "Part"
	part.Parent = props.Parent
	return part
end

local function addBillboard(parent, title, subtitle)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ZoneLabel"
	gui.Size = UDim2.fromOffset(200, 60)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextScaled = true
	titleLabel.Text = title
	titleLabel.Parent = gui

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "Subtitle"
	subLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subLabel.Position = UDim2.fromScale(0, 0.55)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
	subLabel.TextScaled = true
	subLabel.Text = subtitle or ""
	subLabel.Parent = gui
end

local function addProximityPrompt(parent, actionText, objectText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

function HubWorldBuilder.build(parent)
	local existing = parent:FindFirstChild(HubConfig.HUB_MODEL_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Model")
	hub.Name = HubConfig.HUB_MODEL_NAME
	hub.Parent = parent

	local floorW = HubConfig.FLOOR_SIZE.X
	local floorD = HubConfig.FLOOR_SIZE.Y
	local wallH = HubConfig.WALL_HEIGHT

	makePart({
		Name = "Floor",
		Parent = hub,
		Size = Vector3.new(floorW, 1, floorD),
		CFrame = CFrame.new(0, 0, 0),
		Color = HubConfig.COLORS.Floor,
		Material = Enum.Material.Slate,
	})

	local wallThickness = 2
	local wallDefs = {
		{ name = "WallNorth", size = Vector3.new(floorW, wallH, wallThickness), pos = Vector3.new(0, wallH / 2, -floorD / 2) },
		{ name = "WallSouth", size = Vector3.new(floorW, wallH, wallThickness), pos = Vector3.new(0, wallH / 2, floorD / 2) },
		{ name = "WallWest", size = Vector3.new(wallThickness, wallH, floorD), pos = Vector3.new(-floorW / 2, wallH / 2, 0) },
		{ name = "WallEast", size = Vector3.new(wallThickness, wallH, floorD), pos = Vector3.new(floorW / 2, wallH / 2, 0) },
	}
	for _, wall in wallDefs do
		makePart({
			Name = wall.name,
			Parent = hub,
			Size = wall.size,
			CFrame = CFrame.new(wall.pos),
			Color = HubConfig.COLORS.Wall,
			Material = Enum.Material.Concrete,
		})
	end

	makePart({
		Name = "SpawnPad",
		Parent = hub,
		Size = Vector3.new(10, 0.4, 10),
		CFrame = CFrame.new(HubConfig.SPAWN_POSITION - Vector3.new(0, 2.7, 0)),
		Color = HubConfig.COLORS.SpawnPad,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zonePart = makePart({
			Name = zone.id,
			Parent = zonesFolder,
			Size = zone.size,
			CFrame = CFrame.new(zone.position + Vector3.new(0, zone.size.Y / 2, 0)),
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.35,
			CanCollide = false,
		})
		zonePart:SetAttribute("ZoneAction", zone.action)
		zonePart:SetAttribute("ZoneId", zone.id)

		addBillboard(zonePart, zone.name, zone.hint)
		addProximityPrompt(zonePart, zone.hint, zone.name)

		if zone.id == "HallOfFame" then
			local board = Instance.new("Part")
			board.Name = "LeaderboardBoard"
			board.Anchored = true
			board.CanCollide = false
			board.Size = Vector3.new(8, 5, 0.4)
			board.CFrame = zonePart.CFrame * CFrame.new(0, 0, -(zone.size.Z / 2 + 0.3))
			board.Color = Color3.fromRGB(25, 28, 40)
			board.Material = Enum.Material.SmoothPlastic
			board.Parent = zonePart

			local surface = Instance.new("SurfaceGui")
			surface.Name = "LeaderboardGui"
			surface.Face = Enum.NormalId.Front
			surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			surface.PixelsPerStud = 40
			surface.Parent = board

			local label = Instance.new("TextLabel")
			label.Name = "LeaderboardLabel"
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamMedium
			label.TextColor3 = Color3.new(1, 1, 1)
			label.TextScaled = false
			label.TextSize = 18
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextYAlignment = Enum.TextYAlignment.Top
			label.Text = "🏆 Top Spieler\nLade…"
			label.Parent = surface
		end
	end

	hub.PrimaryPart = hub:FindFirstChild("Floor")
	return hub
end

function HubWorldBuilder.getZonePart(hub, zoneId)
	local zones = hub:FindFirstChild("Zones")
	if not zones then
		return nil
	end
	return zones:FindFirstChild(zoneId)
end

function HubWorldBuilder.updateLeaderboardBoard(hub, lines)
	local zone = HubWorldBuilder.getZonePart(hub, "HallOfFame")
	if not zone then
		return
	end
	local board = zone:FindFirstChild("LeaderboardBoard")
	if not board then
		return
	end
	local gui = board:FindFirstChild("LeaderboardGui")
	local label = gui and gui:FindFirstChild("LeaderboardLabel")
	if label then
		label.Text = table.concat(lines, "\n")
	end
end

return HubWorldBuilder
