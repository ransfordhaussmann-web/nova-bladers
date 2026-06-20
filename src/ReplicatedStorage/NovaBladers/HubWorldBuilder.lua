local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Color = props.Color or Color3.fromRGB(55, 58, 68)
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Name = props.Name or "Part"
	part.Parent = props.Parent
	return part
end

local function makeSign(parent, text, position, color)
	local sign = makePart({
		Name = "Sign",
		Parent = parent,
		Size = Vector3.new(10, 4, 0.4),
		CFrame = CFrame.new(position + Vector3.new(0, 5, 0)),
		Color = color,
		Material = Enum.Material.Neon,
	})
	sign.CanCollide = false

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

	return sign
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER
	hub.Parent = workspace

	local floorY = HubConfig.SPAWN.Y - 2.5
	local floorCenter = Vector3.new(HubConfig.SPAWN.X, floorY, HubConfig.SPAWN.Z)

	makePart({
		Name = "Floor",
		Parent = hub,
		Size = HubConfig.FLOOR_SIZE,
		CFrame = CFrame.new(floorCenter),
		Color = Color3.fromRGB(42, 44, 52),
		Material = Enum.Material.Slate,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS

	local walls = {
		{ Vector3.new(0, wallH / 2 + floorY, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT) },
		{ Vector3.new(0, wallH / 2 + floorY, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT) },
		{ Vector3.new(-halfX, wallH / 2 + floorY, 0), Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(halfX, wallH / 2 + floorY, 0), Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
	}
	for i, wall in walls do
		makePart({
			Name = "Wall" .. i,
			Parent = hub,
			Size = wall[2],
			CFrame = CFrame.new(wall[1]),
			Color = Color3.fromRGB(30, 32, 38),
		})
	end

	local spawn = makePart({
		Name = "HubSpawn",
		Parent = hub,
		Size = Vector3.new(8, 1, 8),
		CFrame = CFrame.new(HubConfig.SPAWN + Vector3.new(0, -1.5, 0)),
		Color = Color3.fromRGB(90, 95, 110),
		Material = Enum.Material.Metal,
	})
	spawn:SetAttribute("IsHubSpawn", true)

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zonePart = makePart({
			Name = zone.id,
			Parent = zonesFolder,
			Size = zone.size,
			CFrame = CFrame.new(zone.position),
			Color = zone.color,
			Material = Enum.Material.Neon,
		})
		zonePart.Transparency = 0.35
		zonePart.CanCollide = false
		zonePart:SetAttribute("ZoneId", zone.id)
		zonePart:SetAttribute("Action", zone.action)
		zonePart:SetAttribute("Prompt", zone.prompt)

		local promptPart = makePart({
			Name = zone.id .. "Prompt",
			Parent = zonesFolder,
			Size = Vector3.new(zone.size.X, 6, zone.size.Z),
			CFrame = CFrame.new(zone.position + Vector3.new(0, 3, 0)),
			Color = zone.color,
		})
		promptPart.Transparency = 1
		promptPart.CanCollide = false
		promptPart:SetAttribute("ZoneId", zone.id)
		promptPart:SetAttribute("Action", zone.action)
		promptPart:SetAttribute("Prompt", zone.prompt)

		makeSign(hub, zone.name .. "\n[E]", zone.position, zone.color)
	end

	local light = Instance.new("PointLight")
	light.Brightness = 1.2
	light.Range = 80
	light.Parent = spawn

	return hub
end

return HubWorldBuilder
