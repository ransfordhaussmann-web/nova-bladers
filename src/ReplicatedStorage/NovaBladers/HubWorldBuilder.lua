local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	return part
end

local function createSign(parent, text, cframe, color)
	local sign = makePart({
		Name = "Sign",
		Size = Vector3.new(8, 2, 0.3),
		CFrame = cframe,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})

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

	sign.Parent = parent
	return sign
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"

	local floorY = HubConfig.SPAWN_CFRAME.Position.Y - 3
	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		CFrame = CFrame.new(0, floorY, 0),
		Color = HubConfig.COLORS.FLOOR,
		Material = Enum.Material.Slate,
	})
	floor.Parent = hub

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS
	local wallY = floorY + wallH / 2

	local wallDefs = {
		{ Vector3.new(halfX * 2 + wallT * 2, wallH, wallT), CFrame.new(0, wallY, halfZ + wallT / 2) },
		{ Vector3.new(halfX * 2 + wallT * 2, wallH, wallT), CFrame.new(0, wallY, -halfZ - wallT / 2) },
		{ Vector3.new(wallT, wallH, halfZ * 2), CFrame.new(halfX + wallT / 2, wallY, 0) },
		{ Vector3.new(wallT, wallH, halfZ * 2), CFrame.new(-halfX - wallT / 2, wallY, 0) },
	}

	for i, def in wallDefs do
		local wall = makePart({
			Name = "Wall" .. i,
			Size = def[1],
			CFrame = def[2],
			Color = HubConfig.COLORS.WALL,
			Material = Enum.Material.Concrete,
		})
		wall.Parent = hub
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = HubConfig.SPAWN_CFRAME
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zonePart = makePart({
			Name = zone.id,
			Size = zone.size,
			CFrame = zone.cframe,
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.55,
			CanCollide = false,
			CanTouch = true,
		})
		zonePart:SetAttribute("ZoneId", zone.id)
		zonePart:SetAttribute("ZoneAction", zone.action)
		zonePart.Parent = zonesFolder

		local signCFrame = zone.cframe * CFrame.new(0, zone.size.Y / 2 + 1.5, -zone.size.Z / 2 - 0.5)
		createSign(zonesFolder, zone.name, signCFrame, zone.color)
	end

	local lbCfg = HubConfig.LEADERBOARD
	local board = makePart({
		Name = "LeaderboardBoard",
		Size = lbCfg.size,
		CFrame = lbCfg.cframe,
		Color = HubConfig.COLORS.WALL,
		Material = Enum.Material.SmoothPlastic,
	})
	board.Parent = hub

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 50)
	title.BackgroundColor3 = HubConfig.COLORS.ACCENT
	title.Text = "🏆 Ruhmeshalle"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.Parent = surface

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Size = UDim2.new(1, -16, 1, -58)
	list.Position = UDim2.fromOffset(8, 54)
	list.BackgroundTransparency = 1
	list.Text = "Lade Rangliste..."
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextScaled = false
	list.TextSize = 28
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Font = Enum.Font.Gotham
	list.Parent = surface

	hub.Parent = workspace
	return hub
end

function HubWorldBuilder.getLeaderboardBoard(hub)
	local board = hub:FindFirstChild("LeaderboardBoard")
	if not board then return nil end
	local gui = board:FindFirstChildOfClass("SurfaceGui")
	if not gui then return nil end
	return gui:FindFirstChild("List")
end

return HubWorldBuilder
