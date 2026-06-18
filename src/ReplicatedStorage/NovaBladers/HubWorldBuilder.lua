local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.fromRGB(60, 65, 80)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function addBillboard(parent, title, subtitle, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 80)
	gui.StudsOffset = Vector3.new(0, 6, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 20
	titleLabel.TextColor3 = color
	titleLabel.Text = title
	titleLabel.Parent = gui

	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subLabel.Position = UDim2.fromScale(0, 0.55)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextSize = 14
	subLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
	subLabel.Text = subtitle
	subLabel.Parent = gui
end

local function buildZone(folder, zoneDef, origin)
	local pad = makePart({
		name = zoneDef.id,
		parent = folder,
		size = zoneDef.size,
		cframe = CFrame.new(origin + zoneDef.offset),
		color = zoneDef.color,
		material = Enum.Material.Neon,
	})
	pad.Transparency = 0.35
	pad:SetAttribute("ZoneId", zoneDef.id)
	pad:SetAttribute("RemoteName", zoneDef.remote)

	local ring = makePart({
		name = zoneDef.id .. "Ring",
		parent = folder,
		size = Vector3.new(zoneDef.size.X + 2, 0.4, zoneDef.size.Z + 2),
		cframe = CFrame.new(origin + zoneDef.offset + Vector3.new(0, 0.3, 0)),
		color = zoneDef.color,
		material = Enum.Material.Metal,
	})
	ring.Transparency = 0.2

	addBillboard(pad, zoneDef.label, zoneDef.hint, zoneDef.color)
	return pad
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		return existing
	end

	local origin = HubConfig.HUB_ORIGIN
	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local floor = makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		cframe = CFrame.new(origin + Vector3.new(0, -HubConfig.FLOOR_SIZE.Y / 2, 0)),
		color = Color3.fromRGB(35, 38, 48),
		material = Enum.Material.Slate,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local t = HubConfig.WALL_THICKNESS
	local wallColor = Color3.fromRGB(50, 55, 70)

	local walls = {
		{ size = Vector3.new(HubConfig.FLOOR_SIZE.X + t * 2, wallH, t), offset = Vector3.new(0, wallH / 2, halfZ + t / 2) },
		{ size = Vector3.new(HubConfig.FLOOR_SIZE.X + t * 2, wallH, t), offset = Vector3.new(0, wallH / 2, -halfZ - t / 2) },
		{ size = Vector3.new(t, wallH, HubConfig.FLOOR_SIZE.Z), offset = Vector3.new(halfX + t / 2, wallH / 2, 0) },
		{ size = Vector3.new(t, wallH, HubConfig.FLOOR_SIZE.Z), offset = Vector3.new(-halfX - t / 2, wallH / 2, 0) },
	}
	for i, spec in walls do
		makePart({
			name = "Wall" .. i,
			parent = hub,
			size = spec.size,
			cframe = CFrame.new(origin + spec.offset),
			color = wallColor,
			material = Enum.Material.Concrete,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(origin + HubConfig.SPAWN_OFFSET)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zoneDef in HubConfig.ZONES do
		buildZone(zonesFolder, zoneDef, origin)
	end

	local centerPillar = makePart({
		name = "CenterPillar",
		parent = hub,
		size = Vector3.new(4, 10, 4),
		cframe = CFrame.new(origin + Vector3.new(0, 5, 0)),
		color = Color3.fromRGB(90, 100, 140),
		material = Enum.Material.Marble,
	})
	addBillboard(centerPillar, "Nova Bladers", "Wähle eine Zone", Color3.fromRGB(180, 200, 255))

	hub:SetAttribute("Built", true)
	return hub
end

return HubWorldBuilder
