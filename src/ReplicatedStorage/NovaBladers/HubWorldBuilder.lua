local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Color = props.color or Color3.fromRGB(60, 65, 80)
	part.Size = props.size
	part.CFrame = props.cframe
	part.Name = props.name
	part.Parent = props.parent
	return part
end

local function addBillboard(parent, title, subtitle)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 60)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 18
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.Text = title
	titleLabel.Parent = gui

	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subLabel.Position = UDim2.fromScale(0, 0.55)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextSize = 14
	subLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
	subLabel.Text = subtitle
	subLabel.Parent = gui
end

local function addProximityPrompt(part, actionText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = part.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

function HubWorldBuilder.build(workspace)
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	local floorSize = HubConfig.FLOOR_SIZE
	makePart({
		name = "Floor",
		parent = hub,
		size = floorSize,
		cframe = CFrame.new(0, -0.5, 0),
		color = Color3.fromRGB(45, 50, 65),
		material = Enum.Material.Slate,
	})

	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallDefs = {
		{ name = "WallNorth", size = Vector3.new(floorSize.X, wallH, 2), pos = Vector3.new(0, wallH / 2, -halfZ) },
		{ name = "WallSouth", size = Vector3.new(floorSize.X, wallH, 2), pos = Vector3.new(0, wallH / 2, halfZ) },
		{ name = "WallWest", size = Vector3.new(2, wallH, floorSize.Z), pos = Vector3.new(-halfX, wallH / 2, 0) },
		{ name = "WallEast", size = Vector3.new(2, wallH, floorSize.Z), pos = Vector3.new(halfX, wallH / 2, 0) },
	}
	for _, def in wallDefs do
		makePart({
			name = def.name,
			parent = hub,
			size = def.size,
			cframe = CFrame.new(def.pos),
			color = Color3.fromRGB(35, 38, 50),
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 0.5
	spawn.Color = Color3.fromRGB(100, 180, 255)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for zoneId, zone in HubConfig.ZONES do
		local zonePart = makePart({
			name = zone.displayName,
			parent = zonesFolder,
			size = zone.size,
			cframe = CFrame.new(zone.position + Vector3.new(0, zone.size.Y / 2, 0)),
			color = zone.color,
			material = Enum.Material.Neon,
		})
		zonePart.Transparency = 0.35
		zonePart:SetAttribute("ZoneId", zone.id)
		zonePart:SetAttribute("ZoneAction", zone.action)
		addBillboard(zonePart, zone.displayName, zone.hint)
		addProximityPrompt(zonePart, zone.hint)
	end

	return hub
end

return HubWorldBuilder
