local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color or Color3.fromRGB(40, 44, 58)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Transparency = props.Transparency or 0
	part.Name = props.Name or "Part"
	part.Parent = props.Parent
	return part
end

local function addBillboard(parent, title, subtitle)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ZoneLabel"
	gui.Size = UDim2.fromOffset(200, 70)
	gui.StudsOffset = Vector3.new(0, parent.Size.Y * 0.5 + 3, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextScaled = true
	titleLabel.Text = title
	titleLabel.Parent = gui

	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subLabel.Position = UDim2.fromScale(0, 0.55)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
	subLabel.TextScaled = true
	subLabel.Text = subtitle
	subLabel.Parent = gui
end

local function addPrompt(part, promptText, actionId)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = promptText
	prompt.ObjectText = part.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("HubAction", actionId)
	prompt.Parent = part
	return prompt
end

function HubWorldBuilder.build(parent)
	local existing = parent:FindFirstChild(HubConfig.HUB_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Model")
	hub.Name = HubConfig.HUB_NAME
	hub.Parent = parent

	local floorSize = HubConfig.FLOOR_SIZE
	local halfX = floorSize.X * 0.5
	local halfZ = floorSize.Z * 0.5
	local wallH = HubConfig.WALL_HEIGHT

	local floor = makePart({
		Name = "Floor",
		Size = floorSize,
		CFrame = CFrame.new(0, -floorSize.Y * 0.5, 0),
		Color = Color3.fromRGB(28, 32, 44),
		Material = Enum.Material.Slate,
		Parent = hub,
	})
	floor:SetAttribute("HubFloor", true)

	local wallThickness = 2
	local walls = {
		{ name = "WallNorth", size = Vector3.new(floorSize.X + wallThickness, wallH, wallThickness), pos = Vector3.new(0, wallH * 0.5, -halfZ) },
		{ name = "WallSouth", size = Vector3.new(floorSize.X + wallThickness, wallH, wallThickness), pos = Vector3.new(0, wallH * 0.5, halfZ) },
		{ name = "WallWest", size = Vector3.new(wallThickness, wallH, floorSize.Z), pos = Vector3.new(-halfX, wallH * 0.5, 0) },
		{ name = "WallEast", size = Vector3.new(wallThickness, wallH, floorSize.Z), pos = Vector3.new(halfX, wallH * 0.5, 0) },
	}
	for _, wall in walls do
		makePart({
			Name = wall.name,
			Size = wall.size,
			CFrame = CFrame.new(wall.pos),
			Color = Color3.fromRGB(50, 56, 72),
			Material = Enum.Material.Metal,
			Parent = hub,
		})
	end

	local spawn = makePart({
		Name = "HubSpawn",
		Size = Vector3.new(6, 1, 6),
		CFrame = CFrame.new(HubConfig.SPAWN_OFFSET),
		Color = Color3.fromRGB(100, 180, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
		Parent = hub,
	})

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zonePart = makePart({
			Name = zone.name,
			Size = zone.size,
			CFrame = CFrame.new(zone.position + Vector3.new(0, zone.size.Y * 0.5, 0)),
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.25,
			CanCollide = true,
			Parent = zonesFolder,
		})
		zonePart:SetAttribute("HubZoneId", zone.id)
		zonePart:SetAttribute("HubAction", zone.action)
		addBillboard(zonePart, zone.name, zone.subtitle)
		addPrompt(zonePart, zone.promptText, zone.action)
	end

	local light = Instance.new("PointLight")
	light.Brightness = 1.2
	light.Range = 40
	light.Color = Color3.fromRGB(140, 180, 255)
	light.Parent = spawn

	hub.PrimaryPart = floor
	return hub
end

function HubWorldBuilder.getSpawnCFrame(hub)
	local spawn = hub:FindFirstChild("HubSpawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubConfig.SPAWN_OFFSET + Vector3.new(0, 3, 0))
end

return HubWorldBuilder
