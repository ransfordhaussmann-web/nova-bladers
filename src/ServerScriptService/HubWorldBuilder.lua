local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HubConfig = require(ReplicatedStorage:WaitForChild("NovaBladers").HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.CFrame = CFrame.new(props.position)
	part.Color = props.color or Color3.fromRGB(200, 200, 200)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function addPrompt(part, zone)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = zone.label
	prompt.ObjectText = "Nova Hub"
	prompt.HoldDuration = zone.promptHold or 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("HubAction", zone.promptAction)
	prompt:SetAttribute("ZoneId", zone.id)
	prompt.Parent = part
	return prompt
end

local function addBillboard(part, title)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HubLabel"
	gui.Size = UDim2.fromOffset(220, 60)
	gui.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 2, 0)
	gui.AlwaysOnTop = true
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
	label.TextColor3 = Color3.fromRGB(240, 240, 255)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.Text = title
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	return gui
end

local function addSurfaceDisplay(part, title)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "HubDisplay"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = part

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 48)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 22
	titleLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
	titleLabel.Text = title
	titleLabel.Parent = frame

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Size = UDim2.new(1, -16, 1, -56)
	body.Position = UDim2.fromOffset(8, 52)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Gotham
	body.TextSize = 16
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextColor3 = Color3.fromRGB(220, 225, 240)
	body.Text = "Lade…"
	body.TextWrapped = true
	body.Parent = frame

	return body
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.ROOT_NAME)
	if existing then
		return existing
	end

	local root = Instance.new("Folder")
	root.Name = HubConfig.ROOT_NAME
	root.Parent = workspace

	local floorCfg = HubConfig.FLOOR
	makePart({
		name = "Floor",
		parent = root,
		size = floorCfg.size,
		position = floorCfg.position,
		color = floorCfg.color,
		material = floorCfg.material,
	})

	local halfX = floorCfg.size.X / 2
	local halfZ = floorCfg.size.Z / 2
	local rim = HubConfig.RIM
	local walls = {
		{ Vector3.new(0, rim.height / 2 + 0.5, halfZ + rim.thickness / 2), Vector3.new(floorCfg.size.X + rim.thickness * 2, rim.height, rim.thickness) },
		{ Vector3.new(0, rim.height / 2 + 0.5, -halfZ - rim.thickness / 2), Vector3.new(floorCfg.size.X + rim.thickness * 2, rim.height, rim.thickness) },
		{ Vector3.new(halfX + rim.thickness / 2, rim.height / 2 + 0.5, 0), Vector3.new(rim.thickness, rim.height, floorCfg.size.Z) },
		{ Vector3.new(-halfX - rim.thickness / 2, rim.height / 2 + 0.5, 0), Vector3.new(rim.thickness, rim.height, floorCfg.size.Z) },
	}
	for i, spec in walls do
		makePart({
			name = "Rim_" .. i,
			parent = root,
			size = spec[2],
			position = spec[1],
			color = rim.color,
			material = Enum.Material.Metal,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN - Vector3.new(0, 2.5, 0)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.Parent = root

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = root

	for _, zone in HubConfig.ZONES do
		local part = makePart({
			name = zone.id,
			parent = zonesFolder,
			size = zone.size,
			position = zone.position,
			color = zone.color,
			material = zone.id == "TrainingPad" and Enum.Material.Neon or Enum.Material.SmoothPlastic,
			canCollide = zone.id ~= "TrainingPad",
		})
		part.Transparency = zone.id == "TrainingPad" and 0.25 or 0.1

		addPrompt(part, zone)
		addBillboard(part, zone.label)

		if zone.id == "Leaderboard" then
			addSurfaceDisplay(part, "🏆 Top Spieler")
		elseif zone.id == "StatsTerminal" then
			addSurfaceDisplay(part, "Deine Stats")
		end
	end

	-- Center marker
	makePart({
		name = "CenterLogo",
		parent = root,
		size = Vector3.new(8, 0.2, 8),
		position = Vector3.new(0, 1.05, 0),
		color = Color3.fromRGB(100, 120, 200),
		material = Enum.Material.Neon,
	})

	local sign = makePart({
		name = "WelcomeSign",
		parent = root,
		size = Vector3.new(16, 6, 1),
		position = Vector3.new(0, 5, -32),
		color = Color3.fromRGB(45, 50, 70),
	})
	addBillboard(sign, "Nova Bladers Hub")
	sign:FindFirstChild("HubLabel").StudsOffset = Vector3.new(0, 4, 0)

	return root
end

return HubWorldBuilder
