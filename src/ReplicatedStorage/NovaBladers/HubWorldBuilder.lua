local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.fromRGB(45, 50, 65)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function addSign(parent, text, offset)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = offset or Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 20
	label.Text = text
	label.Parent = billboard
end

local function addZone(folder, zoneId, zone)
	local platform = makePart({
		name = zoneId,
		parent = folder,
		size = zone.size,
		cframe = CFrame.new(zone.position),
		color = zone.color,
		material = Enum.Material.Neon,
	})
	platform.Transparency = 0.35

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = zone.prompt
	prompt.ObjectText = zone.name
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 0
	prompt:SetAttribute("HubAction", zone.action)
	prompt.Parent = platform

	addSign(platform, zone.name, Vector3.new(0, 4, 0))
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.FOLDER_NAME
	hub.Parent = workspace

	local floorSize = HubConfig.FLOOR_SIZE
	makePart({
		name = "Floor",
		parent = hub,
		size = floorSize,
		cframe = CFrame.new(0, -0.5, 0),
		color = Color3.fromRGB(35, 40, 52),
		material = Enum.Material.Slate,
	})

	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallThickness = 2

	local walls = {
		{ Vector3.new(0, wallH / 2, -halfZ), Vector3.new(floorSize.X, wallH, wallThickness) },
		{ Vector3.new(0, wallH / 2, halfZ), Vector3.new(floorSize.X, wallH, wallThickness) },
		{ Vector3.new(-halfX, wallH / 2, 0), Vector3.new(wallThickness, wallH, floorSize.Z) },
		{ Vector3.new(halfX, wallH / 2, 0), Vector3.new(wallThickness, wallH, floorSize.Z) },
	}
	for i, wall in walls do
		makePart({
			name = "Wall" .. i,
			parent = hub,
			size = wall[2],
			cframe = CFrame.new(wall[1]),
			color = Color3.fromRGB(55, 60, 75),
		})
	end

	local spawn = makePart({
		name = "HubSpawn",
		parent = hub,
		size = Vector3.new(6, 1, 6),
		cframe = CFrame.new(0, 0.5, 12),
		color = Color3.fromRGB(100, 200, 255),
		material = Enum.Material.Neon,
	})
	spawn.Transparency = 0.5
	addSign(spawn, "Nova Hub", Vector3.new(0, 3, 0))

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for zoneId, zone in HubConfig.ZONES do
		addZone(zonesFolder, zoneId, zone)
	end

	return hub
end

function HubWorldBuilder.getSpawnCFrame(hub)
	local spawn = hub:FindFirstChild("HubSpawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + HubConfig.SPAWN_OFFSET
	end
	return CFrame.new(HubConfig.SPAWN_OFFSET)
end

return HubWorldBuilder
