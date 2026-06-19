local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.fromRGB(60, 60, 70)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function addBillboard(parent, text, color)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ZoneLabel"
	gui.Size = UDim2.fromOffset(200, 50)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 22
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Text = text
	label.Parent = gui
end

local function addZoneLight(parent, color)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 1.2
	light.Range = 18
	light.Parent = parent
end

local function addProximityPrompt(parent, actionText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = actionText
	prompt.ObjectText = parent.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

function HubWorldBuilder.build(parent)
	local hub = parent:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if hub then
		return hub
	end

	hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = parent

	local floorY = 0
	local floor = makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR.size,
		cframe = CFrame.new(0, floorY - HubConfig.FLOOR.size.Y / 2, 0),
		color = HubConfig.FLOOR.color,
		material = HubConfig.FLOOR.material,
	})

	local halfX = floor.Size.X / 2
	local halfZ = floor.Size.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS
	local wallColor = Color3.fromRGB(55, 58, 72)

	local walls = {
		{ Vector3.new(0, wallH / 2, -halfZ - wallT / 2), Vector3.new(floor.Size.X + wallT * 2, wallH, wallT) },
		{ Vector3.new(0, wallH / 2, halfZ + wallT / 2), Vector3.new(floor.Size.X + wallT * 2, wallH, wallT) },
		{ Vector3.new(-halfX - wallT / 2, wallH / 2, 0), Vector3.new(wallT, wallH, floor.Size.Z) },
		{ Vector3.new(halfX + wallT / 2, wallH / 2, 0), Vector3.new(wallT, wallH, floor.Size.Z) },
	}

	for index, wall in walls do
		makePart({
			name = "Wall" .. index,
			parent = hub,
			size = wall[2],
			cframe = CFrame.new(wall[1]),
			color = wallColor,
			material = Enum.Material.Concrete,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.CFrame = CFrame.new(HubConfig.SPAWN_OFFSET)
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zonePart = makePart({
			name = zone.id,
			parent = zonesFolder,
			size = zone.size,
			cframe = CFrame.new(zone.position + Vector3.new(0, zone.size.Y / 2, 0)),
			color = zone.color,
			material = Enum.Material.Neon,
		})
		zonePart.Transparency = 0.25
		zonePart:SetAttribute("ZoneId", zone.id)
		addBillboard(zonePart, zone.label, zone.lightColor)
		addZoneLight(zonePart, zone.lightColor)
		addProximityPrompt(zonePart, zone.prompt)
	end

	local ceilingLight = Instance.new("Part")
	ceilingLight.Name = "HubLight"
	ceilingLight.Anchored = true
	ceilingLight.CanCollide = false
	ceilingLight.Transparency = 1
	ceilingLight.Size = Vector3.new(4, 1, 4)
	ceilingLight.CFrame = CFrame.new(0, wallH - 1, 0)
	ceilingLight.Parent = hub

	local light = Instance.new("PointLight")
	light.Brightness = 0.8
	light.Range = 80
	light.Parent = ceilingLight

	return hub
end

function HubWorldBuilder.getSpawnCFrame(hub)
	local spawn = hub:FindFirstChild("HubSpawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubConfig.SPAWN_OFFSET)
end

return HubWorldBuilder
