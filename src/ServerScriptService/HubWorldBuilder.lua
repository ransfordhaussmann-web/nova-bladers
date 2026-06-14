local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Color = props.Color or Color3.new(1, 1, 1)
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Name = props.Name or "Part"
	part.Transparency = props.Transparency or 0
	part.Parent = props.Parent
	return part
end

local function addNeonTrim(parent, cframe, size, color)
	local trim = makePart({
		Name = "NeonTrim",
		Parent = parent,
		Size = size,
		CFrame = cframe,
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	return trim
end

local function addBillboard(parent, text, color)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(200, 50)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 20
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.5
	label.Text = text
	label.Parent = gui
end

local function addProximityPrompt(parent, actionText, objectText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

function HubWorldBuilder.getOrigin()
	return HubConfig.ORIGIN
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local origin = HubConfig.ORIGIN
	local floorY = origin.Y + HubConfig.FLOOR_HEIGHT / 2

	makePart({
		Name = "Floor",
		Parent = hub,
		Size = Vector3.new(HubConfig.FLOOR_SIZE.X, HubConfig.FLOOR_HEIGHT, HubConfig.FLOOR_SIZE.Y),
		CFrame = CFrame.new(origin.X, floorY, origin.Z),
		Color = HubConfig.COLORS.Floor,
		Material = Enum.Material.Slate,
	})

	local accentSize = HubConfig.FLOOR_SIZE - Vector2.new(12, 12)
	makePart({
		Name = "FloorAccent",
		Parent = hub,
		Size = Vector3.new(accentSize.X, 0.2, accentSize.Y),
		CFrame = CFrame.new(origin.X, floorY + 0.6, origin.Z),
		Color = HubConfig.COLORS.FloorAccent,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Y / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallY = floorY + wallH / 2

	local walls = {
		{ Vector3.new(halfX * 2 + 2, wallH, 2), Vector3.new(origin.X, wallY, origin.Z - halfZ - 1) },
		{ Vector3.new(halfX * 2 + 2, wallH, 2), Vector3.new(origin.X, wallY, origin.Z + halfZ + 1) },
		{ Vector3.new(2, wallH, halfZ * 2 + 2), Vector3.new(origin.X - halfX - 1, wallY, origin.Z) },
		{ Vector3.new(2, wallH, halfZ * 2 + 2), Vector3.new(origin.X + halfX + 1, wallY, origin.Z) },
	}

	local wallsFolder = Instance.new("Folder")
	wallsFolder.Name = "Walls"
	wallsFolder.Parent = hub

	for i, wall in walls do
		makePart({
			Name = "Wall" .. i,
			Parent = wallsFolder,
			Size = wall[1],
			CFrame = CFrame.new(wall[2]),
			Color = HubConfig.COLORS.Wall,
			Material = Enum.Material.Concrete,
		})
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for zoneId, zone in HubConfig.ZONES do
		local zonePos = origin + zone.offset
		local zonePart = makePart({
			Name = zoneId,
			Parent = zonesFolder,
			Size = zone.size,
			CFrame = CFrame.new(zonePos.X, floorY + zone.size.Y / 2, zonePos.Z),
			Color = HubConfig.COLORS.Neon,
			Transparency = 0.85,
			CanCollide = false,
		})
		zonePart:SetAttribute("HubZone", zoneId)
		addBillboard(zonePart, zone.label, HubConfig.COLORS.Neon)
		addProximityPrompt(zonePart, zone.prompt, zone.label)
	end

	local portalZone = zonesFolder:FindFirstChild("ArenaPortal")
	if portalZone then
		local portalFrame = makePart({
			Name = "PortalFrame",
			Parent = portalZone,
			Size = Vector3.new(12, 10, 1.5),
			CFrame = portalZone.CFrame * CFrame.new(0, 0, -2),
			Color = HubConfig.COLORS.Portal,
			Material = Enum.Material.Metal,
		})
		addNeonTrim(
			portalZone,
			portalFrame.CFrame * CFrame.new(0, 0, -0.8),
			Vector3.new(8, 8, 0.3),
			HubConfig.COLORS.Portal
		)

		local portalLight = Instance.new("PointLight")
		portalLight.Color = HubConfig.COLORS.Portal
		portalLight.Brightness = 2
		portalLight.Range = 24
		portalLight.Parent = portalZone
	end

	local boothZone = zonesFolder:FindFirstChild("BeyBooth")
	if boothZone then
		makePart({
			Name = "BoothBase",
			Parent = boothZone,
			Size = Vector3.new(8, 6, 8),
			CFrame = boothZone.CFrame,
			Color = HubConfig.COLORS.Booth,
			Material = Enum.Material.Wood,
		})
	end

	local kioskZone = zonesFolder:FindFirstChild("StatsKiosk")
	if kioskZone then
		makePart({
			Name = "KioskScreen",
			Parent = kioskZone,
			Size = Vector3.new(6, 5, 1),
			CFrame = kioskZone.CFrame * CFrame.new(0, 1, 2.5),
			Color = HubConfig.COLORS.Kiosk,
			Material = Enum.Material.Glass,
			Transparency = 0.3,
		})
	end

	local boardZone = zonesFolder:FindFirstChild("Leaderboard")
	if boardZone then
		makePart({
			Name = "BoardScreen",
			Parent = boardZone,
			Size = Vector3.new(8, 10, 0.8),
			CFrame = boardZone.CFrame,
			Color = HubConfig.COLORS.Board,
			Material = Enum.Material.SmoothPlastic,
		})
	end

	for _, offset in {
		Vector3.new(-20, 0, -20),
		Vector3.new(20, 0, -20),
		Vector3.new(-20, 0, 20),
		Vector3.new(20, 0, 20),
	} do
		local pillarPos = origin + offset
		makePart({
			Name = "Pillar",
			Parent = hub,
			Size = Vector3.new(2, 10, 2),
			CFrame = CFrame.new(pillarPos.X, floorY + 5, pillarPos.Z),
			Color = HubConfig.COLORS.Wall,
			Material = Enum.Material.Marble,
		})
		addNeonTrim(
			hub,
			CFrame.new(pillarPos.X, floorY + 10.5, pillarPos.Z),
			Vector3.new(2.4, 0.4, 2.4),
			HubConfig.COLORS.Neon
		)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(origin + HubConfig.SPAWN_OFFSET)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	local arenaSpawn = Instance.new("Part")
	arenaSpawn.Name = "ArenaSpawn"
	arenaSpawn.Size = Vector3.new(4, 1, 4)
	arenaSpawn.Anchored = true
	arenaSpawn.CanCollide = false
	arenaSpawn.Transparency = 1
	arenaSpawn.CFrame = CFrame.new(origin + HubConfig.ARENA_SPAWN_OFFSET)
	arenaSpawn.Parent = hub

	Lighting.Ambient = HubConfig.AMBIENT
	Lighting.OutdoorAmbient = HubConfig.OUTDOOR_AMBIENT
	Lighting.FogColor = HubConfig.FOG_COLOR
	Lighting.FogStart = HubConfig.FOG_START
	Lighting.FogEnd = HubConfig.FOG_END

	return hub
end

return HubWorldBuilder
