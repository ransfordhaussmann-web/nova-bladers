local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Color = props.color or Color3.fromRGB(55, 60, 75)
	part.Size = props.size
	part.CFrame = props.cframe
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function addSign(parent, text, offsetY)
	local sign = makePart({
		name = "Sign",
		size = Vector3.new(8, 3, 0.4),
		color = Color3.fromRGB(30, 32, 40),
		cframe = parent.CFrame * CFrame.new(0, offsetY or 7, -(parent.Size.Z / 2 + 0.5)),
		parent = parent.Parent,
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
end

local function buildZone(folder, zoneDef)
	local zone = makePart({
		name = zoneDef.id,
		size = zoneDef.size,
		color = zoneDef.color,
		material = Enum.Material.Neon,
		cframe = CFrame.new(zoneDef.position + Vector3.new(0, zoneDef.size.Y / 2, 0)),
		parent = folder,
	})
	zone.Transparency = 0.35
	zone.CanCollide = false

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zoneDef.name
	prompt.ObjectText = zoneDef.hint
	prompt.MaxActivationDistance = HubConfig.INTERACT_DISTANCE
	prompt.HoldDuration = 0
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = zone

	local attr = Instance.new("StringValue")
	attr.Name = "ZoneAction"
	attr.Value = zoneDef.action
	attr.Parent = zone

	addSign(zone, zoneDef.name, zoneDef.size.Y / 2 + 2)
	return zone
end

function HubWorldBuilder.buildHallBoard(hubFolder, entries)
	local boardPart = hubFolder:FindFirstChild("HallBoard")
	if not boardPart then
		boardPart = makePart({
			name = "HallBoard",
			size = Vector3.new(18, 10, 1),
			color = Color3.fromRGB(25, 28, 38),
			cframe = CFrame.new(0, 7, 36),
			parent = hubFolder,
		})
	end

	local gui = boardPart:FindFirstChildOfClass("SurfaceGui")
	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.Parent = boardPart
	end

	local label = gui:FindFirstChild("BoardLabel")
	if not label then
		label = Instance.new("TextLabel")
		label.Name = "BoardLabel"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextScaled = false
		label.TextSize = 28
		label.Font = Enum.Font.GothamMedium
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.Parent = gui
	end

	local lines = { "🏆 Ruhmeshalle — Top 5" }
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #entries == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	label.Text = table.concat(lines, "\n")
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	local floorY = HubConfig.SPAWN_POSITION.Y - 3.5
	local center = Vector3.new(HubConfig.SPAWN_POSITION.X, floorY, HubConfig.SPAWN_POSITION.Z)

	makePart({
		name = "Floor",
		size = HubConfig.FLOOR_SIZE,
		color = Color3.fromRGB(42, 46, 58),
		material = Enum.Material.Slate,
		cframe = CFrame.new(center),
		parent = hub,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS

	local walls = {
		{ Vector3.new(0, wallH / 2, halfZ + wallT / 2), Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT) },
		{ Vector3.new(0, wallH / 2, -halfZ - wallT / 2), Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT) },
		{ Vector3.new(halfX + wallT / 2, wallH / 2, 0), Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(-halfX - wallT / 2, wallH / 2, 0), Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
	}
	for i, wall in walls do
		makePart({
			name = "Wall" .. i,
			size = wall[2],
			color = Color3.fromRGB(32, 35, 45),
			material = Enum.Material.Concrete,
			cframe = CFrame.new(center + wall[1]),
			parent = hub,
		})
	end

	local spawn = makePart({
		name = "HubSpawn",
		size = Vector3.new(6, 0.5, 6),
		color = Color3.fromRGB(90, 200, 255),
		material = Enum.Material.Neon,
		cframe = CFrame.new(HubConfig.SPAWN_POSITION - Vector3.new(0, 3, 0)),
		parent = hub,
	})
	spawn.Transparency = 0.5
	spawn.CanCollide = false

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zoneDef in HubConfig.ZONES do
		buildZone(zonesFolder, zoneDef)
	end

	buildHallBoard(hub, {})
	return hub
end

return HubWorldBuilder
