local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function createPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Name = props.Name or "Part"
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color or Color3.fromRGB(60, 65, 80)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Transparency = props.Transparency or 0
	part.CanCollide = props.CanCollide ~= false
	part.Parent = props.Parent
	return part
end

local function createSign(parent, text, offset)
	local anchor = createPart({
		Name = "SignAnchor",
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = parent.CFrame * CFrame.new(0, parent.Size.Y / 2 + 3, 0),
		Transparency = 1,
		CanCollide = false,
		Parent = parent,
	})

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneSign"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = offset or Vector3.new(0, 0, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	label.TextColor3 = Color3.fromRGB(240, 240, 255)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.Text = text
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	return anchor
end

local function createZone(folder, zoneConfig)
	local zone = createPart({
		Name = zoneConfig.id,
		Size = zoneConfig.size,
		CFrame = CFrame.new(zoneConfig.position + Vector3.new(0, zoneConfig.size.Y / 2, 0)),
		Color = zoneConfig.color,
		Transparency = 0.65,
		CanCollide = false,
		Material = Enum.Material.Neon,
		Parent = folder,
	})

	zone:SetAttribute("ZoneId", zoneConfig.id)
	zone:SetAttribute("Hint", zoneConfig.hint)

	createSign(zone, zoneConfig.name)

	if zoneConfig.action and zoneConfig.promptText then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ZonePrompt"
		prompt.ActionText = zoneConfig.promptText
		prompt.ObjectText = zoneConfig.name
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt:SetAttribute("Action", zoneConfig.action)
		prompt.Parent = zone
	end

	return zone
end

local function createLeaderboardBoard(parent, zonePart)
	local board = createPart({
		Name = "LeaderboardBoard",
		Size = Vector3.new(12, 8, 0.5),
		CFrame = zonePart.CFrame * CFrame.new(0, 2, -zonePart.Size.Z / 2 - 1),
		Color = Color3.fromRGB(30, 32, 45),
		Material = Enum.Material.Slate,
		Parent = parent,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "BoardGui"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 50)
	title.BackgroundTransparency = 1
	title.Text = "🏆 Ruhmeshalle"
	title.TextColor3 = Color3.fromRGB(255, 220, 100)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 28
	title.Parent = surface

	local list = Instance.new("TextLabel")
	list.Name = "Entries"
	list.Position = UDim2.fromOffset(0, 50)
	list.Size = UDim2.new(1, 0, 1, -50)
	list.BackgroundTransparency = 1
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextColor3 = Color3.fromRGB(230, 230, 240)
	list.Font = Enum.Font.Gotham
	list.TextSize = 22
	list.Text = "Lade Rangliste…"
	list.Parent = surface

	return board
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local floorSize = HubConfig.FLOOR_SIZE
	local halfX = floorSize.X / 2
	local halfZ = floorSize.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS

	createPart({
		Name = "Floor",
		Size = floorSize,
		CFrame = CFrame.new(0, 0, 0),
		Color = Color3.fromRGB(45, 50, 65),
		Material = Enum.Material.Concrete,
		Parent = hub,
	})

	local wallColor = Color3.fromRGB(55, 60, 78)
	createPart({
		Name = "WallNorth",
		Size = Vector3.new(floorSize.X + wallT * 2, wallH, wallT),
		CFrame = CFrame.new(0, wallH / 2, -halfZ - wallT / 2),
		Color = wallColor,
		Parent = hub,
	})
	createPart({
		Name = "WallSouth",
		Size = Vector3.new(floorSize.X + wallT * 2, wallH, wallT),
		CFrame = CFrame.new(0, wallH / 2, halfZ + wallT / 2),
		Color = wallColor,
		Parent = hub,
	})
	createPart({
		Name = "WallWest",
		Size = Vector3.new(wallT, wallH, floorSize.Z),
		CFrame = CFrame.new(-halfX - wallT / 2, wallH / 2, 0),
		Color = wallColor,
		Parent = hub,
	})
	createPart({
		Name = "WallEast",
		Size = Vector3.new(wallT, wallH, floorSize.Z),
		CFrame = CFrame.new(halfX + wallT / 2, wallH / 2, 0),
		Color = wallColor,
		Parent = hub,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.CanCollide = false
	spawn.Transparency = 0.5
	spawn.Color = Color3.fromRGB(100, 200, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	local zones = {}
	local leaderboardBoard = nil

	for _, zoneConfig in HubConfig.ZONES do
		local zone = createZone(zonesFolder, zoneConfig)
		zones[zoneConfig.id] = zone
		if zoneConfig.id == "HallOfFame" then
			leaderboardBoard = createLeaderboardBoard(hub, zone)
		end
	end

	return {
		hub = hub,
		spawn = spawn,
		zones = zones,
		leaderboardBoard = leaderboardBoard,
	}
end

function HubWorldBuilder.updateLeaderboardBoard(board, entries)
	if not board then
		return
	end

	local gui = board:FindFirstChild("BoardGui")
	if not gui then
		return
	end

	local list = gui:FindFirstChild("Entries")
	if not list then
		return
	end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		list.Text = "Noch keine Einträge"
	else
		list.Text = table.concat(lines, "\n")
	end
end

return HubWorldBuilder
