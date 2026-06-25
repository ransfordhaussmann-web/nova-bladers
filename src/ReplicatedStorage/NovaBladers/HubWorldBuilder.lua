local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Color = props.color or Color3.new(1, 1, 1)
	part.Size = props.size
	part.CFrame = props.cframe
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function addZoneLabel(parent, zone)
	local anchor = Instance.new("Part")
	anchor.Name = "SignAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(zone.position + Vector3.new(0, zone.size.Y * 0.5 + 3, 0))
	anchor.Parent = parent

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, 0, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.Text = zone.name
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local floorSize = HubConfig.HUB_FLOOR_SIZE
	local floorY = HubConfig.SPAWN_POSITION.Y - 3.5

	makePart({
		name = "Floor",
		parent = hub,
		size = floorSize,
		cframe = CFrame.new(0, floorY, 0),
		color = HubConfig.FLOOR_COLOR,
		material = Enum.Material.Slate,
	})

	local halfX = floorSize.X * 0.5
	local halfZ = floorSize.Z * 0.5
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS
	local wallY = floorY + wallH * 0.5

	local walls = {
		{ size = Vector3.new(floorSize.X + wallT * 2, wallH, wallT), pos = Vector3.new(0, wallY, -halfZ - wallT * 0.5) },
		{ size = Vector3.new(floorSize.X + wallT * 2, wallH, wallT), pos = Vector3.new(0, wallY, halfZ + wallT * 0.5) },
		{ size = Vector3.new(wallT, wallH, floorSize.Z), pos = Vector3.new(-halfX - wallT * 0.5, wallY, 0) },
		{ size = Vector3.new(wallT, wallH, floorSize.Z), pos = Vector3.new(halfX + wallT * 0.5, wallY, 0) },
	}

	for i, wall in walls do
		makePart({
			name = "Wall" .. i,
			parent = hub,
			size = wall.size,
			cframe = CFrame.new(wall.pos),
			color = HubConfig.WALL_COLOR,
			material = Enum.Material.Concrete,
		})
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in pairs(HubConfig.ZONES) do
		local zonePart = makePart({
			name = zone.id,
			parent = zonesFolder,
			size = zone.size,
			cframe = CFrame.new(zone.position + Vector3.new(0, floorY + zone.size.Y * 0.5, 0)),
			color = zone.color,
			material = Enum.Material.Neon,
		})
		zonePart.Transparency = 0.55

		local pad = makePart({
			name = zone.id .. "Pad",
			parent = zonesFolder,
			size = Vector3.new(zone.size.X - 2, 0.4, zone.size.Z - 2),
			cframe = CFrame.new(zone.position + Vector3.new(0, floorY + 0.2, 0)),
			color = zone.color,
			material = Enum.Material.SmoothPlastic,
		})
		pad.Transparency = 0.25

		addZoneLabel(zonesFolder, {
			name = zone.name,
			position = zone.position + Vector3.new(0, floorY, 0),
			size = zone.size,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	spawn.Neutral = true
	spawn.Parent = hub

	return hub
end

return HubWorldBuilder
