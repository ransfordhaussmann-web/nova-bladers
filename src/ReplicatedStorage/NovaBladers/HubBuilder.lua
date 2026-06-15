local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubBuilder = {}

local function createPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.fromRGB(200, 200, 200)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function createRim(parent, center, size, thickness, height, color)
	local halfX = size.X / 2
	local halfZ = size.Z / 2
	local y = center.Y + height / 2

	local segments = {
		{ Vector3.new(0, y, center.Z - halfZ - thickness / 2), Vector3.new(size.X + thickness * 2, height, thickness) },
		{ Vector3.new(0, y, center.Z + halfZ + thickness / 2), Vector3.new(size.X + thickness * 2, height, thickness) },
		{ Vector3.new(center.X - halfX - thickness / 2, y, center.Z), Vector3.new(thickness, height, size.Z) },
		{ Vector3.new(center.X + halfX + thickness / 2, y, center.Z), Vector3.new(thickness, height, size.Z) },
	}

	for index, segment in segments do
		createPart({
			parent = parent,
			name = "Rim_" .. index,
			size = segment[2],
			cframe = CFrame.new(segment[1]),
			color = color,
			material = Enum.Material.Concrete,
		})
	end
end

local function createBillboard(parent, text, color)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(180, 48)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
	label.TextColor3 = color
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	return billboard
end

function HubBuilder.build(parent)
	local existing = parent:FindFirstChild(HubConfig.ROOT_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Model")
	hub.Name = HubConfig.ROOT_NAME
	hub.Parent = parent

	local floorCenter = HubConfig.SPAWN - Vector3.new(0, HubConfig.FLOOR_SIZE.Y / 2 + 2, 0)
	createPart({
		parent = hub,
		name = "Floor",
		size = HubConfig.FLOOR_SIZE,
		cframe = CFrame.new(floorCenter),
		color = HubConfig.FLOOR_COLOR,
		material = HubConfig.FLOOR_MATERIAL,
	})

	createRim(
		hub,
		floorCenter,
		HubConfig.FLOOR_SIZE,
		HubConfig.RIM_THICKNESS,
		HubConfig.RIM_HEIGHT,
		Color3.fromRGB(45, 50, 68)
	)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	local gate = HubConfig.ARENA_GATE
	local gatePart = createPart({
		parent = hub,
		name = "ArenaGate",
		size = gate.size,
		cframe = CFrame.new(gate.position),
		color = gate.color,
		material = Enum.Material.Neon,
	})
	gatePart:SetAttribute("HubZone", "ArenaGate")

	local gatePrompt = Instance.new("ProximityPrompt")
	gatePrompt.Name = "EnterArenaPrompt"
	gatePrompt.ActionText = gate.promptText
	gatePrompt.ObjectText = "Spin Arena"
	gatePrompt.KeyboardKeyCode = gate.promptKey
	gatePrompt.HoldDuration = 0
	gatePrompt.MaxActivationDistance = 14
	gatePrompt.RequiresLineOfSight = false
	gatePrompt.Parent = gatePart

	createBillboard(gatePart, "Arena", gate.color)

	local leaderboard = HubConfig.LEADERBOARD
	local leaderboardPart = createPart({
		parent = hub,
		name = "LeaderboardMonolith",
		size = leaderboard.size,
		cframe = CFrame.new(leaderboard.position),
		color = leaderboard.color,
		material = Enum.Material.Marble,
	})
	leaderboardPart:SetAttribute("HubZone", "Leaderboard")
	createBillboard(leaderboardPart, "Top 5", leaderboard.color)

	local podsFolder = Instance.new("Folder")
	podsFolder.Name = "BeyPods"
	podsFolder.Parent = hub

	for _, pod in HubConfig.BEY_PODS do
		local podPart = createPart({
			parent = podsFolder,
			name = pod.name:gsub(" ", ""),
			size = Vector3.new(6, 1.5, 6),
			cframe = CFrame.new(floorCenter + pod.offset + Vector3.new(0, HubConfig.FLOOR_SIZE.Y / 2 + 0.75, 0)),
			color = pod.color,
			material = Enum.Material.Neon,
		})
		podPart:SetAttribute("HubZone", "BeyPod")

		local beacon = createPart({
			parent = podPart,
			name = "Beacon",
			size = Vector3.new(1.2, 8, 1.2),
			cframe = podPart.CFrame * CFrame.new(0, 4.5, 0),
			color = pod.color,
			material = Enum.Material.Neon,
			canCollide = false,
		})
		beacon.Transparency = 0.25

		createBillboard(podPart, pod.name, pod.color)
	end

	local lightingFolder = Instance.new("Folder")
	lightingFolder.Name = "AccentLights"
	lightingFolder.Parent = hub

	for _, offset in {
		Vector3.new(-40, 12, -30),
		Vector3.new(40, 12, -30),
		Vector3.new(-40, 12, 30),
		Vector3.new(40, 12, 30),
	} do
		local lightPart = createPart({
			parent = lightingFolder,
			name = "Accent",
			size = Vector3.new(2, 2, 2),
			cframe = CFrame.new(floorCenter + offset),
			color = Color3.fromRGB(120, 180, 255),
			material = Enum.Material.Neon,
			canCollide = false,
		})
		lightPart.Transparency = 0.2

		local pointLight = Instance.new("PointLight")
		pointLight.Brightness = 1.5
		pointLight.Range = 28
		pointLight.Color = Color3.fromRGB(130, 190, 255)
		pointLight.Parent = lightPart
	end

	hub:SetAttribute("Built", true)
	return hub
end

function HubBuilder.applyLighting()
	local lighting = game:GetService("Lighting")
	lighting.Ambient = HubConfig.LIGHTING.ambient
	lighting.Brightness = HubConfig.LIGHTING.brightness
	lighting.ClockTime = HubConfig.LIGHTING.clockTime
end

function HubBuilder.getSpawnCFrame()
	return CFrame.new(HubConfig.SPAWN + HubConfig.RETURN_SPAWN_OFFSET)
end

return HubBuilder
