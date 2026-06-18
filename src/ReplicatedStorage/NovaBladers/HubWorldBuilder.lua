local HubWorldConfig = require(script.Parent.HubWorldConfig)

local HubWorldBuilder = {}

local function createPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Color = props.color or Color3.fromRGB(35, 40, 55)
	part.Size = props.size
	part.CFrame = props.cframe
	part.Name = props.name
	part.Transparency = props.transparency or 0
	part.Parent = props.parent
	return part
end

local function createBillboard(parent, title, subtitle, color)
	local anchor = Instance.new("Part")
	anchor.Name = "SignAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = parent:IsA("BasePart") and parent.CFrame * CFrame.new(0, 4, 0)
		or CFrame.new(parent.Position + Vector3.new(0, 4, 0))
	anchor.Parent = parent.Parent or parent

	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(220, 80)
	gui.StudsOffset = Vector3.new(0, 0, 0)
	gui.AlwaysOnTop = true
	gui.Parent = anchor

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	titleLabel.TextScaled = true
	titleLabel.Text = title
	titleLabel.Parent = gui

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Position = UDim2.fromScale(0, 0.55)
	subtitleLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subtitleLabel.Font = Enum.Font.Gotham
	subtitleLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
	subtitleLabel.TextScaled = true
	subtitleLabel.Text = subtitle or ""
	subtitleLabel.Parent = gui

	return anchor
end

local function createModePad(folder, padConfig)
	local pad = createPart({
		name = "ModePad_" .. padConfig.id,
		parent = folder,
		size = Vector3.new(14, 1, 14),
		cframe = CFrame.new(padConfig.position),
		color = padConfig.color,
		material = Enum.Material.Neon,
	})
	pad:SetAttribute("HubModeId", padConfig.id)

	local ring = createPart({
		name = "Ring",
		parent = pad,
		size = Vector3.new(15, 0.4, 15),
		cframe = pad.CFrame * CFrame.new(0, -0.5, 0),
		color = Color3.fromRGB(20, 24, 34),
		material = Enum.Material.Metal,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterPrompt"
	prompt.ActionText = "Betreten"
	prompt.ObjectText = padConfig.label
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad

	createBillboard(pad, padConfig.label, padConfig.subtitle, padConfig.color)

	local light = Instance.new("PointLight")
	light.Color = padConfig.color
	light.Brightness = 1.2
	light.Range = 16
	light.Parent = pad

	return pad, ring
end

function HubWorldBuilder.getOrCreate(parent)
	parent = parent or workspace
	local existing = parent:FindFirstChild(HubWorldConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end
	return HubWorldBuilder.build(parent)
end

function HubWorldBuilder.build(parent)
	parent = parent or workspace

	local hub = Instance.new("Model")
	hub.Name = HubWorldConfig.HUB_FOLDER_NAME

	local geometry = Instance.new("Folder")
	geometry.Name = "Geometry"
	geometry.Parent = hub

	local interactables = Instance.new("Folder")
	interactables.Name = "Interactables"
	interactables.Parent = hub

	createPart({
		name = "Platform",
		parent = geometry,
		size = HubWorldConfig.PLATFORM_SIZE,
		cframe = CFrame.new(0, HubWorldConfig.PLATFORM_Y, 0),
		color = Color3.fromRGB(28, 32, 44),
		material = Enum.Material.Slate,
	})

	createPart({
		name = "CenterRing",
		parent = geometry,
		size = Vector3.new(24, 0.5, 24),
		cframe = CFrame.new(0, HubWorldConfig.PLATFORM_Y + 1.1, 0),
		color = Color3.fromRGB(60, 120, 255),
		material = Enum.Material.Neon,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = HubWorldConfig.SPAWN_CFRAME
	spawn.Color = Color3.fromRGB(90, 160, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.35
	spawn.Parent = interactables

	for _, padConfig in HubWorldConfig.MODE_PADS do
		createModePad(interactables, padConfig)
	end

	local kioskPos = HubWorldConfig.BEY_KIOSK.position
	local kiosk = createPart({
		name = "BeyKiosk",
		parent = interactables,
		size = Vector3.new(10, 8, 4),
		cframe = CFrame.new(kioskPos + Vector3.new(0, 4, 0)),
		color = Color3.fromRGB(45, 55, 80),
		material = Enum.Material.Metal,
	})
	createBillboard(kiosk, HubWorldConfig.BEY_KIOSK.label, "Wähle deinen Bey", Color3.fromRGB(120, 200, 255))

	local podiumPos = HubWorldConfig.LEADERBOARD_PODIUM.position
	local podium = createPart({
		name = "LeaderboardPodium",
		parent = interactables,
		size = Vector3.new(12, 3, 8),
		cframe = CFrame.new(podiumPos + Vector3.new(0, 1.5, 0)),
		color = Color3.fromRGB(55, 45, 90),
		material = Enum.Material.Marble,
	})
	createBillboard(podium, HubWorldConfig.LEADERBOARD_PODIUM.label, "Top 5 global", Color3.fromRGB(255, 210, 80))

	local bounds = HubWorldConfig.PLATFORM_SIZE
	local wallHeight = 12
	local halfX = bounds.X / 2
	local halfZ = bounds.Z / 2
	local wallThickness = 2
	local wallY = HubWorldConfig.PLATFORM_Y + wallHeight / 2

	local walls = {
		{ Vector3.new(0, wallY, -halfZ), Vector3.new(bounds.X + 4, wallHeight, wallThickness) },
		{ Vector3.new(0, wallY, halfZ), Vector3.new(bounds.X + 4, wallHeight, wallThickness) },
		{ Vector3.new(-halfX, wallY, 0), Vector3.new(wallThickness, wallHeight, bounds.Z + 4) },
		{ Vector3.new(halfX, wallY, 0), Vector3.new(wallThickness, wallHeight, bounds.Z + 4) },
	}

	for index, wallData in walls do
		createPart({
			name = "BoundaryWall" .. index,
			parent = geometry,
			size = wallData[2],
			cframe = CFrame.new(wallData[1]),
			color = Color3.fromRGB(20, 22, 30),
			transparency = 0.15,
		})
	end

	local welcome = createPart({
		name = "WelcomeArch",
		parent = geometry,
		size = Vector3.new(18, 1, 2),
		cframe = CFrame.new(0, HubWorldConfig.PLATFORM_Y + 8, 42),
		color = Color3.fromRGB(70, 130, 255),
		material = Enum.Material.Neon,
	})
	createBillboard(welcome, "Nova Bladers", "Spin-Arena Hub", Color3.fromRGB(120, 200, 255))

	hub.Parent = parent
	return hub
end

function HubWorldBuilder.getSpawnCFrame(hub)
	local spawn = hub:FindFirstChild("Interactables", true)
		and hub.Interactables:FindFirstChild("HubSpawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return HubWorldConfig.SPAWN_CFRAME
end

function HubWorldBuilder.getModePad(hub, modeId)
	local interactables = hub:FindFirstChild("Interactables")
	if not interactables then
		return nil
	end
	return interactables:FindFirstChild("ModePad_" .. modeId)
end

function HubWorldBuilder.findArenaSpawn(modeId)
	local arena = workspace:FindFirstChild("Arena") or workspace:FindFirstChild("BattleArena")
	if not arena then
		return nil
	end

	local spawnName = HubWorldConfig.ARENA_SPAWN_NAMES[modeId]
	if spawnName then
		local named = arena:FindFirstChild(spawnName, true)
		if named and named:IsA("BasePart") then
			return named.CFrame + Vector3.new(0, 3, 0)
		end
	end

	local fallback = arena:FindFirstChild("Spawn", true) or arena:FindFirstChild("ArenaSpawn", true)
	if fallback and fallback:IsA("BasePart") then
		return fallback.CFrame + Vector3.new(0, 3, 0)
	end

	return nil
end

return HubWorldBuilder