local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function worldPos(localPos)
	return HubConfig.ORIGIN + localPos
end

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	return part
end

local function addLabel(part, text, color)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Text = text
	label.Parent = billboard
end

local function addProximityPrompt(part, actionText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = actionText
	prompt.ObjectText = part.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	local floorCfg = HubConfig.FLOOR
	local floor = makePart({
		Name = "Floor",
		Size = Vector3.new(floorCfg.size.X, floorCfg.thickness, floorCfg.size.Y),
		Position = worldPos(Vector3.new(0, -floorCfg.thickness / 2, 0)),
		Color = floorCfg.color,
		Material = Enum.Material.Slate,
	})
	floor.Parent = hub

	local wallCfg = HubConfig.WALLS
	local halfX = floorCfg.size.X / 2
	local halfZ = floorCfg.size.Y / 2
	local wallY = wallCfg.height / 2

	local walls = {
		{ name = "WallNorth", size = Vector3.new(floorCfg.size.X + wallCfg.thickness * 2, wallCfg.height, wallCfg.thickness), pos = Vector3.new(0, wallY, -halfZ) },
		{ name = "WallSouth", size = Vector3.new(floorCfg.size.X + wallCfg.thickness * 2, wallCfg.height, wallCfg.thickness), pos = Vector3.new(0, wallY, halfZ) },
		{ name = "WallWest", size = Vector3.new(wallCfg.thickness, wallCfg.height, floorCfg.size.Y), pos = Vector3.new(-halfX, wallY, 0) },
		{ name = "WallEast", size = Vector3.new(wallCfg.thickness, wallCfg.height, floorCfg.size.Y), pos = Vector3.new(halfX, wallY, 0) },
	}

	for _, wall in walls do
		local part = makePart({
			Name = wall.name,
			Size = wall.size,
			Position = worldPos(wall.pos),
			Color = wallCfg.color,
			Material = Enum.Material.Concrete,
		})
		part.Parent = hub
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = worldPos(HubConfig.SPAWN)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zonePart = makePart({
			Name = zone.id,
			Size = zone.size,
			Position = worldPos(zone.position + Vector3.new(0, zone.size.Y / 2, 0)),
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.35,
			CanCollide = false,
		})
		zonePart:SetAttribute("ZoneAction", zone.action)
		addLabel(zonePart, zone.label, zone.color)
		addProximityPrompt(zonePart, zone.hint)
		zonePart.Parent = zonesFolder
	end

	local centerSign = makePart({
		Name = "WelcomeSign",
		Size = Vector3.new(12, 4, 1),
		Position = worldPos(Vector3.new(0, 6, 8)),
		Color = Color3.fromRGB(30, 32, 40),
		Material = Enum.Material.Metal,
	})
	addLabel(centerSign, "Nova Bladers Hub", Color3.fromRGB(180, 200, 255))
	centerSign.Parent = hub

	return hub
end

function HubWorldBuilder.getHubSpawnCFrame()
	return CFrame.new(worldPos(HubConfig.SPAWN), worldPos(HubConfig.SPAWN_LOOK))
end

function HubWorldBuilder.getArenaSpawnCFrame()
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER)
	if not arena then return nil end
	local spawn = arena:FindFirstChild(HubConfig.ARENA_SPAWN, true)
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return nil
end

return HubWorldBuilder
