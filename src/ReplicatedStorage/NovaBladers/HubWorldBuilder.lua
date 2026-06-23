local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.CanQuery = props.canQuery ~= false
	part.CanTouch = props.canTouch ~= false
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or Color3.fromRGB(45, 48, 58)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Transparency = props.transparency or 0
	part.Name = props.name
	part.Parent = props.parent
	return part
end

local function addSign(parent, text, offset)
	local sign = makePart({
		name = "Sign",
		size = Vector3.new(8, 3, 0.4),
		cframe = parent.CFrame * CFrame.new(0, parent.Size.Y / 2 + 2.5, 0) * CFrame.new(offset or Vector3.zero),
		color = Color3.fromRGB(30, 32, 40),
		material = Enum.Material.Neon,
		parent = parent.Parent,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Text = text
	label.Parent = gui
end

local function buildLeaderboardBoard(parent, zonePart)
	local board = makePart({
		name = "LeaderboardBoard",
		size = Vector3.new(10, 7, 0.5),
		cframe = zonePart.CFrame * CFrame.new(0, 4, -zonePart.Size.Z / 2 - 0.5),
		color = Color3.fromRGB(25, 28, 38),
		material = Enum.Material.Slate,
		parent = parent,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Name = "LeaderboardGui"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(400, 280)
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 210, 80)
	title.TextScaled = true
	title.Text = "🏆 Nova-Liga"
	title.Parent = gui

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Position = UDim2.fromOffset(0, 44)
	body.Size = UDim2.new(1, 0, 1, -44)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Gotham
	body.TextColor3 = Color3.new(1, 1, 1)
	body.TextSize = 18
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Text = "Lade Rangliste…"
	body.Parent = gui

	return board
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		return existing
	end

	local hub = Instance.new("Model")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local floorY = HubConfig.SPAWN.Y - 3
	local floor = makePart({
		name = "Floor",
		size = HubConfig.FLOOR_SIZE,
		cframe = CFrame.new(0, floorY, 0),
		color = Color3.fromRGB(38, 42, 52),
		material = Enum.Material.Concrete,
		parent = hub,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallY = floorY + wallH / 2

	local walls = {
		{ Vector3.new(0, wallY, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 1) },
		{ Vector3.new(0, wallY, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 1) },
		{ Vector3.new(-halfX, wallY, 0), Vector3.new(1, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(halfX, wallY, 0), Vector3.new(1, wallH, HubConfig.FLOOR_SIZE.Z) },
	}
	for i, spec in walls do
		makePart({
			name = "Wall" .. i,
			size = spec[2],
			cframe = CFrame.new(spec[1]),
			color = Color3.fromRGB(55, 60, 72),
			material = Enum.Material.Brick,
			parent = hub,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	local zoneParts = {}
	for _, zone in HubConfig.ZONES do
		local platform = makePart({
			name = zone.id,
			size = zone.size,
			cframe = CFrame.new(zone.position.X, floorY + zone.size.Y / 2, zone.position.Z),
			color = zone.color,
			material = Enum.Material.Neon,
			transparency = 0.35,
			parent = zonesFolder,
		})
		platform:SetAttribute("ZoneId", zone.id)
		platform:SetAttribute("ZoneAction", zone.action or "")

		local trigger = makePart({
			name = zone.id .. "Trigger",
			size = zone.size + Vector3.new(2, 6, 2),
			cframe = CFrame.new(zone.position.X, floorY + 4, zone.position.Z),
			canCollide = false,
			transparency = 1,
			parent = zonesFolder,
		})
		trigger:SetAttribute("ZoneId", zone.id)

		addSign(platform, zone.name)
		zoneParts[zone.id] = { platform = platform, trigger = trigger }

		if zone.id == "HallOfFame" then
			buildLeaderboardBoard(hub, platform)
		end
	end

	-- Ambient hub lighting accent
	local light = Instance.new("PointLight")
	light.Brightness = 0.6
	light.Range = 40
	light.Color = Color3.fromRGB(120, 160, 255)
	light.Parent = floor

	hub:SetAttribute("Built", true)
	return hub, zoneParts
end

return HubWorldBuilder
