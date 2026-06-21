local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.fromRGB(60, 65, 80)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function makeLabel(parent, text, offset)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = offset or Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard

	return billboard
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	local floorY = HubConfig.SPAWN_POSITION.Y - 2.5
	local floor = makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		cframe = CFrame.new(0, floorY, 0),
		color = Color3.fromRGB(45, 50, 65),
		material = Enum.Material.Slate,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallY = floorY + wallH / 2 + 0.5

	local walls = {
		{ name = "WallNorth", pos = Vector3.new(0, wallY, -halfZ), size = Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 2) },
		{ name = "WallSouth", pos = Vector3.new(0, wallY, halfZ), size = Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 2) },
		{ name = "WallWest", pos = Vector3.new(-halfX, wallY, 0), size = Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ name = "WallEast", pos = Vector3.new(halfX, wallY, 0), size = Vector3.new(2, wallH, HubConfig.FLOOR_SIZE.Z) },
	}
	for _, w in walls do
		makePart({
			name = w.name,
			parent = hub,
			size = w.size,
			cframe = CFrame.new(w.pos),
			color = Color3.fromRGB(35, 38, 50),
			material = Enum.Material.Concrete,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zonePart = makePart({
			name = zone.id,
			parent = zonesFolder,
			size = zone.size,
			cframe = CFrame.new(zone.position + Vector3.new(0, floorY + zone.size.Y / 2 + 0.5, 0)),
			color = zone.color,
			material = Enum.Material.Neon,
			canCollide = false,
		})
		zonePart.Transparency = 0.35

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Interact"
		prompt.ActionText = zone.label
		prompt.ObjectText = "Nova Bladers"
		prompt.MaxActivationDistance = HubConfig.INTERACT_DISTANCE
		prompt.HoldDuration = 0
		prompt.Parent = zonePart

		makeLabel(zonePart, zone.label, Vector3.new(0, zone.size.Y / 2 + 2, 0))

		local attr = Instance.new("StringValue")
		attr.Name = "Action"
		attr.Value = zone.action
		attr.Parent = zonePart
	end

	local boardFolder = Instance.new("Folder")
	boardFolder.Name = "LeaderboardBoard"
	boardFolder.Parent = hub

	local board = makePart({
		name = "Board",
		parent = boardFolder,
		size = Vector3.new(12, 8, 0.5),
		cframe = CFrame.new(
			HubConfig.ZONES.HallOfFame.position.X,
			floorY + 6,
			HubConfig.ZONES.HallOfFame.position.Z + 8
		),
		color = Color3.fromRGB(25, 28, 38),
		material = Enum.Material.Metal,
	})

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 40
	surfaceGui.Parent = board

	local boardLabel = Instance.new("TextLabel")
	boardLabel.Name = "BoardText"
	boardLabel.Size = UDim2.fromScale(1, 1)
	boardLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	boardLabel.BackgroundTransparency = 0.2
	boardLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
	boardLabel.Font = Enum.Font.GothamBold
	boardLabel.TextSize = 28
	boardLabel.TextWrapped = true
	boardLabel.TextYAlignment = Enum.TextYAlignment.Top
	boardLabel.Text = "🏆 Ruhmeshalle\nLade..."
	boardLabel.Parent = surfaceGui

	return hub
end

function HubWorldBuilder.getArenaSpawnCFrame()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		for _, name in HubConfig.ARENA_SPAWN_NAMES do
			local spawn = arena:FindFirstChild(name)
			if spawn and spawn:IsA("BasePart") then
				return spawn.CFrame + Vector3.new(0, 3, 0)
			end
		end
	end

	local bowl = workspace:FindFirstChild("Bowl") or workspace:FindFirstChild("ArenaBowl")
	if bowl and bowl:IsA("BasePart") then
		return bowl.CFrame + Vector3.new(0, bowl.Size.Y / 2 + 4, 0)
	end

	return CFrame.new(0, 10, 0)
end

return HubWorldBuilder
