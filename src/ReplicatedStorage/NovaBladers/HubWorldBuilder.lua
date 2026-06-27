local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function createPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color or Color3.fromRGB(60, 65, 75)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Transparency = props.Transparency or 0
	part.Name = props.Name or "Part"
	part.Parent = props.Parent
	return part
end

local function createSign(parent, zone)
	local anchor = createPart({
		Name = zone.id .. "Sign",
		Parent = parent,
		Size = Vector3.new(0.4, 6, 4),
		CFrame = CFrame.new(zone.position + Vector3.new(0, 5, -zone.size.Z * 0.5 - 2)),
		Color = zone.color,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(220, 70)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = anchor

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
	hint.TextColor3 = Color3.fromRGB(210, 210, 220)
	hint.TextScaled = true
	hint.Text = zone.hint
	hint.Parent = billboard
end

local function createZonePad(parent, zone)
	local pad = createPart({
		Name = zone.id .. "Pad",
		Parent = parent,
		Size = Vector3.new(zone.size.X, 0.4, zone.size.Z),
		CFrame = CFrame.new(zone.position + Vector3.new(0, 0.3, 0)),
		Color = zone.color,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
	})
	pad:SetAttribute("ZoneId", zone.id)
	pad:SetAttribute("ZoneAction", zone.action)

	local light = Instance.new("PointLight")
	light.Color = zone.color
	light.Brightness = 1.2
	light.Range = 14
	light.Parent = pad

	return pad
end

function HubWorldBuilder.build(workspace)
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Model")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local origin = HubConfig.ORIGIN

	createPart({
		Name = "Floor",
		Parent = hub,
		Size = HubConfig.FLOOR_SIZE,
		CFrame = CFrame.new(origin + Vector3.new(0, -0.5, 0)),
		Color = Color3.fromRGB(42, 48, 58),
		Material = Enum.Material.Slate,
	})

	createPart({
		Name = "CenterPlaza",
		Parent = hub,
		Size = Vector3.new(36, 0.3, 36),
		CFrame = CFrame.new(origin + Vector3.new(0, 0.05, 0)),
		Color = Color3.fromRGB(55, 62, 78),
		Material = Enum.Material.Marble,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(origin + HubConfig.SPAWN_OFFSET)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(90, 160, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Parent = hub

	for _, zone in HubConfig.ZONES do
		createZonePad(hub, zone)
		createSign(hub, zone)
	end

	local rimHeight = 4
	local half = HubConfig.FLOOR_SIZE.X * 0.5
	local rimPositions = {
		{ pos = Vector3.new(0, rimHeight * 0.5, half), size = Vector3.new(HubConfig.FLOOR_SIZE.X, rimHeight, 2) },
		{ pos = Vector3.new(0, rimHeight * 0.5, -half), size = Vector3.new(HubConfig.FLOOR_SIZE.X, rimHeight, 2) },
		{ pos = Vector3.new(half, rimHeight * 0.5, 0), size = Vector3.new(2, rimHeight, HubConfig.FLOOR_SIZE.Z) },
		{ pos = Vector3.new(-half, rimHeight * 0.5, 0), size = Vector3.new(2, rimHeight, HubConfig.FLOOR_SIZE.Z) },
	}
	for index, rim in rimPositions do
		createPart({
			Name = "Rim" .. index,
			Parent = hub,
			Size = rim.size,
			CFrame = CFrame.new(origin + rim.pos),
			Color = Color3.fromRGB(30, 34, 42),
			Material = Enum.Material.Concrete,
		})
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local trigger = Instance.new("Part")
		trigger.Name = zone.id .. "Trigger"
		trigger.Anchored = true
		trigger.CanCollide = false
		trigger.Transparency = 1
		trigger.Size = Vector3.new(zone.size.X + 4, 8, zone.size.Z + 4)
		trigger.CFrame = CFrame.new(zone.position + Vector3.new(0, 4, 0))
		trigger:SetAttribute("ZoneId", zone.id)
		trigger:SetAttribute("ZoneAction", zone.action)
		trigger.Parent = zonesFolder
	end

	return hub
end

return HubWorldBuilder
