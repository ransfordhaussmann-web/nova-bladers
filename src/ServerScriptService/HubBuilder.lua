local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color or Color3.fromRGB(45, 50, 65)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Name = props.Name or "Part"
	part.Transparency = props.Transparency or 0
	part.Parent = props.Parent
	return part
end

local function addNeonRing(parent, position, radius, color)
	local ring = makePart({
		Name = "NeonRing",
		Parent = parent,
		Size = Vector3.new(radius * 2, 0.3, radius * 2),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, 0),
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	ring.Shape = Enum.PartType.Cylinder
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	return ring
end

local function addModePad(parent, hubOrigin, padConfig)
	local pos = hubOrigin + padConfig.offset + Vector3.new(0, 0.6, 0)
	local pad = makePart({
		Name = "ModePad_" .. padConfig.id,
		Parent = parent,
		Size = Vector3.new(12, 0.4, 12),
		CFrame = CFrame.new(pos),
		Color = padConfig.color,
		Material = Enum.Material.Neon,
	})
	pad.Transparency = 0.35
	pad:SetAttribute("BaseColor", padConfig.color)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(160, 64)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = pad

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 16
	label.Text = padConfig.label .. "\n" .. padConfig.desc
	label.Parent = billboard

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "JoinQueuePrompt"
	prompt.ActionText = "Warteschlange"
	prompt.ObjectText = padConfig.label
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad

	return {
		part = pad,
		config = padConfig,
		prompt = prompt,
		setActive = function(active)
			pad.Transparency = active and 0.1 or 0.35
			pad.Color = active and padConfig.color or Color3.fromRGB(60, 65, 80)
		end,
	}
end

function HubBuilder.build()
	local existing = workspace:FindFirstChild("Hub")
	if existing then
		existing:Destroy()
	end

	local hubFolder = Instance.new("Folder")
	hubFolder.Name = "Hub"
	hubFolder.Parent = workspace

	local origin = Vector3.new(0, HubConfig.SPAWN_Y, 0)
	local half = HubConfig.HUB_SIZE / 2

	-- Main walkable floor
	makePart({
		Name = "Floor",
		Parent = hubFolder,
		Size = Vector3.new(HubConfig.HUB_SIZE, HubConfig.FLOOR_HEIGHT, HubConfig.HUB_SIZE),
		CFrame = CFrame.new(origin - Vector3.new(0, HubConfig.FLOOR_HEIGHT / 2, 0)),
		Color = Color3.fromRGB(35, 40, 52),
		Material = Enum.Material.Slate,
	})

	-- Decorative center plaza
	addNeonRing(hubFolder, origin + Vector3.new(0, 0.2, 0), 8, Color3.fromRGB(80, 160, 255))

	-- Low boundary walls (open sky hub)
	local wallHeight = 6
	local wallThickness = 2
	local wallY = origin.Y + wallHeight / 2
	for _, spec in {
		{ name = "WallNorth", size = Vector3.new(HubConfig.HUB_SIZE, wallHeight, wallThickness), pos = origin + Vector3.new(0, wallHeight / 2, half) },
		{ name = "WallSouth", size = Vector3.new(HubConfig.HUB_SIZE, wallHeight, wallThickness), pos = origin + Vector3.new(0, wallHeight / 2, -half) },
		{ name = "WallEast", size = Vector3.new(wallThickness, wallHeight, HubConfig.HUB_SIZE), pos = origin + Vector3.new(half, wallHeight / 2, 0) },
		{ name = "WallWest", size = Vector3.new(wallThickness, wallHeight, HubConfig.HUB_SIZE), pos = origin + Vector3.new(-half, wallHeight / 2, 0) },
	} do
		makePart({
			Name = spec.name,
			Parent = hubFolder,
			Size = spec.size,
			CFrame = CFrame.new(spec.pos),
			Color = Color3.fromRGB(28, 32, 42),
			Material = Enum.Material.Concrete,
		})
	end

	-- Arena portal (walk up and interact)
	local portalPos = origin + Vector3.new(0, HubConfig.PORTAL_SIZE.Y / 2 + 0.5, HubConfig.PORTAL_OFFSET)
	local portalFrame = makePart({
		Name = "ArenaPortal",
		Parent = hubFolder,
		Size = HubConfig.PORTAL_SIZE,
		CFrame = CFrame.new(portalPos),
		Color = Color3.fromRGB(60, 120, 255),
		Material = Enum.Material.Neon,
	})
	portalFrame.Transparency = 0.25

	local portalGlow = makePart({
		Name = "PortalGlow",
		Parent = portalFrame,
		Size = Vector3.new(HubConfig.PORTAL_SIZE.X - 2, HubConfig.PORTAL_SIZE.Y - 2, 0.5),
		CFrame = portalFrame.CFrame,
		Color = Color3.fromRGB(140, 200, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	portalGlow.Transparency = 0.4

	local portalPrompt = Instance.new("ProximityPrompt")
	portalPrompt.Name = "EnterArenaPrompt"
	portalPrompt.ActionText = "Arena betreten"
	portalPrompt.ObjectText = "Nova Arena"
	portalPrompt.KeyboardKeyCode = Enum.KeyCode.E
	portalPrompt.HoldDuration = 0
	portalPrompt.MaxActivationDistance = 14
	portalPrompt.RequiresLineOfSight = false
	portalPrompt.Parent = portalFrame

	local portalBillboard = Instance.new("BillboardGui")
	portalBillboard.Size = UDim2.fromOffset(200, 48)
	portalBillboard.StudsOffset = Vector3.new(0, HubConfig.PORTAL_SIZE.Y / 2 + 2, 0)
	portalBillboard.Parent = portalFrame

	local portalLabel = Instance.new("TextLabel")
	portalLabel.Size = UDim2.fromScale(1, 1)
	portalLabel.BackgroundTransparency = 1
	portalLabel.Font = Enum.Font.GothamBold
	portalLabel.TextSize = 20
	portalLabel.TextColor3 = Color3.fromRGB(180, 220, 255)
	portalLabel.TextStrokeTransparency = 0.4
	portalLabel.Text = "⬡ Arena Portal"
	portalLabel.Parent = portalBillboard

	-- Mode pads around the hub
	local modePads = {}
	for _, padConfig in pairs(HubConfig.MODE_PADS) do
		table.insert(modePads, addModePad(hubFolder, origin, padConfig))
	end

	-- Leaderboard pillar
	local lbPos = origin + HubConfig.LEADERBOARD_OFFSET + Vector3.new(0, 4, 0)
	local lbPillar = makePart({
		Name = "LeaderboardPillar",
		Parent = hubFolder,
		Size = Vector3.new(6, 8, 1.5),
		CFrame = CFrame.new(lbPos),
		Color = Color3.fromRGB(50, 55, 70),
		Material = Enum.Material.Metal,
	})

	local lbSurface = Instance.new("SurfaceGui")
	lbSurface.Name = "LeaderboardDisplay"
	lbSurface.Face = Enum.NormalId.Front
	lbSurface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	lbSurface.PixelsPerStud = 40
	lbSurface.Parent = lbPillar

	local lbText = Instance.new("TextLabel")
	lbText.Name = "BoardText"
	lbText.Size = UDim2.fromScale(1, 1)
	lbText.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	lbText.BackgroundTransparency = 0.15
	lbText.Font = Enum.Font.GothamMedium
	lbText.TextSize = 14
	lbText.TextColor3 = Color3.fromRGB(220, 220, 230)
	lbText.TextXAlignment = Enum.TextXAlignment.Left
	lbText.TextYAlignment = Enum.TextYAlignment.Top
	lbText.Text = "🏆 Top Spieler\nLade..."
	lbText.Parent = lbSurface

	-- Spawn location for default character spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(origin + HubConfig.RETURN_SPAWN_OFFSET + Vector3.new(0, 0.5, 0))
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hubFolder

	-- Ambient hub lighting accents
	for i = 1, 4 do
		local angle = (i - 1) * (math.pi / 2)
		local lightPos = origin + Vector3.new(math.cos(angle) * (half - 6), 10, math.sin(angle) * (half - 6))
		local lightPart = makePart({
			Name = "HubLight_" .. i,
			Parent = hubFolder,
			Size = Vector3.new(2, 1, 2),
			CFrame = CFrame.new(lightPos),
			Color = Color3.fromRGB(100, 160, 255),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		local light = Instance.new("PointLight")
		light.Brightness = 1.2
		light.Range = 28
		light.Color = Color3.fromRGB(120, 170, 255)
		light.Parent = lightPart
	end

	return {
		folder = hubFolder,
		origin = origin,
		spawnCFrame = spawn.CFrame + Vector3.new(0, 3, 0),
		portalPrompt = portalPrompt,
		modePads = modePads,
		leaderboardText = lbText,
	}
end

return HubBuilder
