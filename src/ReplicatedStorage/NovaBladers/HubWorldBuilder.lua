local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Color = props.color or Color3.fromRGB(50, 55, 70)
	part.Size = props.size
	part.CFrame = CFrame.new(props.position)
	part.Name = props.name
	part.Parent = props.parent
	return part
end

local function makeSign(parent, text, position, color)
	local sign = makePart({
		name = "Sign",
		parent = parent,
		size = Vector3.new(8, 3, 0.4),
		position = position + Vector3.new(0, 5, 0),
		color = color,
		canCollide = false,
	})
	sign.Material = Enum.Material.Neon

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 60)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.Parent = billboard
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER
	hub.Parent = workspace

	makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		position = HubConfig.FLOOR_POSITION,
		color = Color3.fromRGB(35, 40, 55),
		material = Enum.Material.Slate,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local t = HubConfig.WALL_THICKNESS
	local y = HubConfig.FLOOR_POSITION.Y + wallH / 2

	local walls = {
		{ "WallNorth", Vector3.new(0, y, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X + t * 2, wallH, t) },
		{ "WallSouth", Vector3.new(0, y, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X + t * 2, wallH, t) },
		{ "WallWest", Vector3.new(-halfX, y, 0), Vector3.new(t, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ "WallEast", Vector3.new(halfX, y, 0), Vector3.new(t, wallH, HubConfig.FLOOR_SIZE.Z) },
	}
	for _, wall in walls do
		makePart({
			name = wall[1],
			parent = hub,
			size = wall[3],
			position = wall[2],
			color = Color3.fromRGB(25, 28, 38),
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = HubConfig.SPAWN_NAME
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = Vector3.new(0, HubConfig.FLOOR_POSITION.Y + 1, 0)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zonePart = makePart({
			name = zone.id,
			parent = zonesFolder,
			size = zone.size,
			position = zone.position + Vector3.new(0, zone.size.Y / 2, 0),
			color = zone.color,
			canCollide = false,
		})
		zonePart.Transparency = 0.55
		zonePart.Material = Enum.Material.Neon

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = zone.hint
		prompt.ObjectText = zone.name
		prompt.KeyboardKeyCode = HubConfig.PROMPT_KEY
		prompt.MaxActivationDistance = HubConfig.INTERACT_RANGE
		prompt.HoldDuration = 0
		prompt.Parent = zonePart

		local attr = Instance.new("StringValue")
		attr.Name = "Action"
		attr.Value = zone.action
		attr.Parent = zonePart

		makeSign(hub, zone.name, zone.position, zone.color)
	end

	return hub
end

return HubWorldBuilder
