local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color or Color3.new(1, 1, 1)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Name = props.Name or "Part"
	part.Transparency = props.Transparency or 0
	part.Parent = props.Parent
	return part
end

local function addZoneLabel(zonePart, zone)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 60)
	billboard.StudsOffset = Vector3.new(0, zone.size.Y * 0.5 + 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = zonePart

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.55, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.Text = zone.label
	title.Parent = billboard

	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(1, 0, 0.45, 0)
	hint.Position = UDim2.fromScale(0, 0.55)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextColor3 = Color3.fromRGB(200, 210, 230)
	hint.TextScaled = true
	hint.Text = zone.hint
	hint.Parent = billboard
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Model")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local origin = HubConfig.ORIGIN
	local floorSize = HubConfig.FLOOR_SIZE

	makePart({
		Name = "Floor",
		Parent = hub,
		Size = floorSize,
		CFrame = CFrame.new(origin),
		Color = HubConfig.COLORS.Floor,
		Material = Enum.Material.Slate,
	})

	local halfX = floorSize.X * 0.5
	local halfZ = floorSize.Z * 0.5
	local wallH = HubConfig.WALL_HEIGHT

	local walls = {
		{ Vector3.new(0, 0, halfZ), Vector3.new(floorSize.X, wallH, 2) },
		{ Vector3.new(0, 0, -halfZ), Vector3.new(floorSize.X, wallH, 2) },
		{ Vector3.new(halfX, 0, 0), Vector3.new(2, wallH, floorSize.Z) },
		{ Vector3.new(-halfX, 0, 0), Vector3.new(2, wallH, floorSize.Z) },
	}

	for index, wall in walls do
		makePart({
			Name = "Wall" .. index,
			Parent = hub,
			Size = wall[2],
			CFrame = CFrame.new(origin + wall[1] + Vector3.new(0, wallH * 0.5 - floorSize.Y * 0.5, 0)),
			Color = HubConfig.COLORS.Wall,
			Material = Enum.Material.Concrete,
		})
	end

	local spawnPos = origin + HubConfig.SPAWN_OFFSET
	local spawn = makePart({
		Name = "HubSpawn",
		Parent = hub,
		Size = Vector3.new(10, 1, 10),
		CFrame = CFrame.new(spawnPos),
		Color = HubConfig.COLORS.SpawnPad,
		Material = Enum.Material.Neon,
	})
	spawn.Transparency = 0.35

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zonePos = origin + zone.position + Vector3.new(0, zone.size.Y * 0.5, 0)
		local zonePart = makePart({
			Name = zone.id,
			Parent = zonesFolder,
			Size = zone.size,
			CFrame = CFrame.new(zonePos),
			Color = zone.color,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		zonePart.Transparency = 0.55
		zonePart:SetAttribute("ZoneId", zone.id)
		zonePart:SetAttribute("Action", zone.action)
		addZoneLabel(zonePart, zone)
	end

	hub.PrimaryPart = spawn
	return hub
end

return HubWorldBuilder
