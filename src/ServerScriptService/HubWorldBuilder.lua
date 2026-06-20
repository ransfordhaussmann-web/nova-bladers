local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local BeyCatalog = require(ReplicatedStorage.NovaBladers.BeyCatalog)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color or Color3.fromRGB(55, 60, 75)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Name = props.Name
	part.Transparency = props.Transparency or 0
	part.Parent = props.Parent
	return part
end

local function addBillboard(parent, title, subtitle)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ZoneLabel"
	gui.Size = UDim2.fromOffset(200, 80)
	gui.StudsOffset = Vector3.new(0, 6, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.5, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextScaled = true
	titleLabel.Text = title
	titleLabel.Parent = gui

	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, 0, 0.5, 0)
	subLabel.Position = UDim2.fromScale(0, 0.5)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
	subLabel.TextScaled = true
	subLabel.Text = subtitle
	subLabel.Parent = gui
end

local function addProximityPrompt(parent, actionText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = "Nova Hub"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

local function buildWalls(root, floorSize, wallHeight)
	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local y = wallHeight / 2 + 0.5

	local walls = {
		{ Size = Vector3.new(floorSize.X, wallHeight, 2), Pos = Vector3.new(0, y, -halfZ) },
		{ Size = Vector3.new(floorSize.X, wallHeight, 2), Pos = Vector3.new(0, y, halfZ) },
		{ Size = Vector3.new(2, wallHeight, floorSize.Z), Pos = Vector3.new(-halfX, y, 0) },
		{ Size = Vector3.new(2, wallHeight, floorSize.Z), Pos = Vector3.new(halfX, y, 0) },
	}

	local wallsFolder = Instance.new("Folder")
	wallsFolder.Name = "Walls"
	wallsFolder.Parent = root

	for i, wall in walls do
		makePart({
			Name = "Wall" .. i,
			Parent = wallsFolder,
			Size = wall.Size,
			CFrame = CFrame.new(wall.Pos),
			Color = Color3.fromRGB(40, 45, 58),
			Material = Enum.Material.Concrete,
		})
	end
end

local function buildBeyPedestals(root)
	local folder = Instance.new("Folder")
	folder.Name = "BeyShowcase"
	folder.Parent = root

	local count = #BeyCatalog
	local radius = 16
	for i, bey in ipairs(BeyCatalog) do
		local angle = (i - 1) / count * math.pi * 2
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius + 8

		local pedestal = makePart({
			Name = bey.id .. "Pedestal",
			Parent = folder,
			Size = Vector3.new(4, 1, 4),
			CFrame = CFrame.new(x, 1.5, z),
			Color = Color3.fromRGB(35, 38, 48),
			Material = Enum.Material.Metal,
		})

		local glow = makePart({
			Name = bey.id .. "Glow",
			Parent = folder,
			Size = Vector3.new(2.5, 0.3, 2.5),
			CFrame = CFrame.new(x, 2.2, z),
			Color = bey.color,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})

		local light = Instance.new("PointLight")
		light.Color = bey.color
		light.Brightness = 1.2
		light.Range = 10
		light.Parent = glow

		addBillboard(pedestal, bey.name, bey.special)
	end
end

local function buildZone(root, zoneDef)
	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = zoneDef.id
	zoneFolder.Parent = root

	local platform = makePart({
		Name = "Platform",
		Parent = zoneFolder,
		Size = zoneDef.size,
		CFrame = CFrame.new(zoneDef.position),
		Color = zoneDef.color,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
	})

	local trigger = makePart({
		Name = "Trigger",
		Parent = zoneFolder,
		Size = zoneDef.size + Vector3.new(2, 4, 2),
		CFrame = CFrame.new(zoneDef.position + Vector3.new(0, 2, 0)),
		Transparency = 1,
		CanCollide = false,
	})
	trigger:SetAttribute("HubZone", zoneDef.action)

	local prompt = addProximityPrompt(trigger, zoneDef.label)
	prompt:SetAttribute("HubAction", zoneDef.action)

	addBillboard(platform, zoneDef.label, zoneDef.hint)

	zoneFolder:SetAttribute("HubAction", zoneDef.action)
	return zoneFolder
end

function HubWorldBuilder.build()
	local existing = Workspace:FindFirstChild(HubConfig.ROOT_NAME)
	if existing then
		return existing
	end

	local root = Instance.new("Folder")
	root.Name = HubConfig.ROOT_NAME
	root.Parent = Workspace

	makePart({
		Name = "Floor",
		Parent = root,
		Size = HubConfig.FLOOR_SIZE,
		CFrame = CFrame.new(0, 0, 0),
		Color = Color3.fromRGB(30, 32, 42),
		Material = Enum.Material.Slate,
	})

	buildWalls(root, HubConfig.FLOOR_SIZE, HubConfig.WALL_HEIGHT)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = root

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = root

	for _, zoneDef in HubConfig.ZONES do
		buildZone(zonesFolder, zoneDef)
	end

	buildBeyPedestals(root)

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 80
	light.Parent = root:FindFirstChild("Floor")

	return root
end

function HubWorldBuilder.getSpawnCFrame()
	return CFrame.new(HubConfig.SPAWN + Vector3.new(0, 3, 0))
end

function HubWorldBuilder.findArenaSpawn()
	local arena = Workspace:FindFirstChild(HubConfig.ARENA_FOLDER)
	if not arena then return nil end

	for _, name in HubConfig.ARENA_SPAWN_NAMES do
		local spawn = arena:FindFirstChild(name, true)
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end

	local bowl = arena:FindFirstChild("Bowl") or arena:FindFirstChild("Floor")
	if bowl and bowl:IsA("BasePart") then
		return bowl.CFrame + Vector3.new(0, bowl.Size.Y / 2 + 4, 0)
	end

	return nil
end

return HubWorldBuilder
