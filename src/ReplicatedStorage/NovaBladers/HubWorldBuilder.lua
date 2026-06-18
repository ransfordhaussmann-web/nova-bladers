local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Color = props.color or Color3.fromRGB(45, 48, 58)
	part.Size = props.size
	part.CFrame = props.cframe
	part.Name = props.name or "Part"
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = props.parent
	return part
end

local function addSign(parent, text, color)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(220, 56)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	label.TextColor3 = color
	label.Font = Enum.Font.GothamBold
	label.TextSize = 22
	label.Text = text
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
end

local function addPrompt(part, action, promptText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = promptText
	prompt.ObjectText = part.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("HubAction", action)
	prompt.Parent = part
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local origin = HubConfig.ORIGIN
	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	local floorY = origin.Y + 0.5
	makePart({
		name = "Floor",
		parent = hub,
		size = Vector3.new(HubConfig.FLOOR_SIZE.X, 1, HubConfig.FLOOR_SIZE.Y),
		cframe = CFrame.new(origin.X, floorY, origin.Z),
		color = Color3.fromRGB(38, 42, 54),
		material = Enum.Material.Slate,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Y / 2
	local wallH = HubConfig.WALL_HEIGHT
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = hub

	local wallDefs = {
		{ Vector3.new(halfX * 2 + 2, wallH, 2), Vector3.new(origin.X, floorY + wallH / 2, origin.Z - halfZ - 1) },
		{ Vector3.new(halfX * 2 + 2, wallH, 2), Vector3.new(origin.X, floorY + wallH / 2, origin.Z + halfZ + 1) },
		{ Vector3.new(2, wallH, halfZ * 2 + 2), Vector3.new(origin.X - halfX - 1, floorY + wallH / 2, origin.Z) },
		{ Vector3.new(2, wallH, halfZ * 2 + 2), Vector3.new(origin.X + halfX + 1, floorY + wallH / 2, origin.Z) },
	}
	for index, def in wallDefs do
		makePart({
			name = "Wall" .. index,
			parent = walls,
			size = def[1],
			cframe = CFrame.new(def[2]),
			color = Color3.fromRGB(28, 30, 40),
			material = Enum.Material.Concrete,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CFrame = CFrame.new(origin + HubConfig.SPAWN_OFFSET)
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for zoneId, zone in HubConfig.ZONES do
		local zonePos = origin + zone.offset + Vector3.new(0, zone.size.Y / 2, 0)
		local platform = makePart({
			name = zoneId,
			parent = zonesFolder,
			size = zone.size,
			cframe = CFrame.new(zonePos),
			color = zone.color,
			material = Enum.Material.Neon,
		})
		platform.Transparency = 0.25
		platform:SetAttribute("HubZone", zoneId)
		platform:SetAttribute("HubAction", zone.action)
		addSign(platform, zone.displayName, zone.color)
		addPrompt(platform, zone.action, zone.prompt)
	end

	local leaderboardBoard = Instance.new("Part")
	leaderboardBoard.Name = "LeaderboardBoard"
	leaderboardBoard.Anchored = true
	leaderboardBoard.CanCollide = false
	leaderboardBoard.Transparency = 1
	leaderboardBoard.Size = Vector3.new(1, 1, 1)
	local hallZone = HubConfig.ZONES.HallOfFame
	leaderboardBoard.CFrame = CFrame.new(origin + hallZone.offset + Vector3.new(0, 5, hallZone.size.Z / 2 + 2))
	leaderboardBoard.Parent = zonesFolder

	local boardGui = Instance.new("SurfaceGui")
	boardGui.Name = "LeaderboardSurface"
	boardGui.Face = Enum.NormalId.Front
	boardGui.CanvasSize = Vector2.new(400, 280)
	boardGui.Parent = leaderboardBoard

	local boardLabel = Instance.new("TextLabel")
	boardLabel.Name = "BoardText"
	boardLabel.Size = UDim2.fromScale(1, 1)
	boardLabel.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	boardLabel.BackgroundTransparency = 0.1
	boardLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
	boardLabel.Font = Enum.Font.GothamMedium
	boardLabel.TextSize = 20
	boardLabel.TextXAlignment = Enum.TextXAlignment.Left
	boardLabel.TextYAlignment = Enum.TextYAlignment.Top
	boardLabel.Text = "🏆 Ruhmeshalle\nLade..."
	boardLabel.Parent = boardGui

	return hub
end

function HubWorldBuilder.getSpawnCFrame(hub)
	local spawn = hub:FindFirstChild("HubSpawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubConfig.ORIGIN + HubConfig.SPAWN_OFFSET)
end

function HubWorldBuilder.updateLeaderboardBoard(hub, lines)
	local board = hub:FindFirstChild("Zones")
		and hub.Zones:FindFirstChild("LeaderboardBoard")
	if not board then
		return
	end
	local gui = board:FindFirstChild("LeaderboardSurface")
	local label = gui and gui:FindFirstChild("BoardText")
	if label then
		label.Text = table.concat(lines, "\n")
	end
end

return HubWorldBuilder
