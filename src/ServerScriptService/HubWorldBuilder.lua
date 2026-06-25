local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color or Color3.fromRGB(45, 48, 58)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Name = props.Name or "Part"
	part.Parent = props.Parent
	if props.Transparency then
		part.Transparency = props.Transparency
	end
	return part
end

local function addSign(parent, text, offset)
	local sign = makePart({
		Name = "Sign",
		Parent = parent,
		Size = Vector3.new(8, 3, 0.4),
		CFrame = parent:GetPivot() * CFrame.new(0, 5 + (offset or 0), -parent.Size.Z / 2 - 1),
		Color = Color3.fromRGB(30, 32, 40),
		Material = Enum.Material.Neon,
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

local function buildZone(folder, zoneConfig)
	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = zoneConfig.id
	zoneFolder.Parent = folder

	local platform = makePart({
		Name = "Platform",
		Parent = zoneFolder,
		Size = Vector3.new(zoneConfig.size.X, 1, zoneConfig.size.Z),
		CFrame = CFrame.new(zoneConfig.position + Vector3.new(0, 0.5, 0)),
		Color = zoneConfig.color,
		Material = Enum.Material.Neon,
	})
	platform.Transparency = 0.35

	local trigger = makePart({
		Name = "Trigger",
		Parent = zoneFolder,
		Size = Vector3.new(zoneConfig.size.X - 2, zoneConfig.size.Y, zoneConfig.size.Z - 2),
		CFrame = CFrame.new(zoneConfig.position + Vector3.new(0, zoneConfig.size.Y / 2, 0)),
		Transparency = 1,
		CanCollide = false,
	})
	trigger:SetAttribute("ZoneId", zoneConfig.id)
	trigger:SetAttribute("ZoneAction", zoneConfig.action)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = zoneConfig.label
	prompt.ActionText = "Interagieren"
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 0
	prompt.Parent = trigger

	addSign(platform, zoneConfig.label)

	return zoneFolder
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	local floor = makePart({
		Name = "Floor",
		Parent = hub,
		Size = HubConfig.HUB_SIZE,
		CFrame = CFrame.new(0, 0, 0),
		Color = Color3.fromRGB(35, 38, 48),
		Material = Enum.Material.Slate,
	})

	local halfX = HubConfig.HUB_SIZE.X / 2
	local halfZ = HubConfig.HUB_SIZE.Z / 2
	local wallY = HubConfig.WALL_HEIGHT / 2 + 0.5
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = hub

	local wallDefs = {
		{ Vector3.new(0, wallY, -halfZ), Vector3.new(HubConfig.HUB_SIZE.X, HubConfig.WALL_HEIGHT, 2) },
		{ Vector3.new(0, wallY, halfZ), Vector3.new(HubConfig.HUB_SIZE.X, HubConfig.WALL_HEIGHT, 2) },
		{ Vector3.new(-halfX, wallY, 0), Vector3.new(2, HubConfig.WALL_HEIGHT, HubConfig.HUB_SIZE.Z) },
		{ Vector3.new(halfX, wallY, 0), Vector3.new(2, HubConfig.WALL_HEIGHT, HubConfig.HUB_SIZE.Z) },
	}
	for i, def in wallDefs do
		makePart({
			Name = "Wall" .. i,
			Parent = walls,
			Size = def[2],
			CFrame = CFrame.new(def[1]),
			Color = Color3.fromRGB(55, 58, 70),
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Parent = hub

	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = hub
	for _, zoneConfig in HubConfig.ZONES do
		buildZone(zones, zoneConfig)
	end

	local centerRing = makePart({
		Name = "CenterRing",
		Parent = hub,
		Size = Vector3.new(16, 0.4, 16),
		CFrame = CFrame.new(0, 0.7, 0),
		Color = Color3.fromRGB(120, 90, 255),
		Material = Enum.Material.Neon,
	})
	centerRing.Transparency = 0.5

	return hub
end

return HubWorldBuilder
