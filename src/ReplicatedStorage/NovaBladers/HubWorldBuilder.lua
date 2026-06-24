local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Color = props.color or Color3.fromRGB(60, 65, 80)
	part.Size = props.size
	part.CFrame = props.cframe
	part.Name = props.name or "Part"
	part.Transparency = props.transparency or 0
	part.Parent = props.parent
	return part
end

local function createSign(parent, text, position, color)
	local sign = makePart({
		parent = parent,
		name = "Sign",
		size = Vector3.new(8, 3, 0.4),
		cframe = CFrame.new(position),
		color = color,
		material = Enum.Material.Neon,
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

	return sign
end

function HubWorldBuilder.buildLeaderboardBoard(parent, entries)
	local board = makePart({
		parent = parent,
		name = "LeaderboardBoard",
		size = Vector3.new(12, 8, 0.5),
		cframe = CFrame.new(35, 7, -6) * CFrame.Angles(0, math.rad(-90), 0),
		color = Color3.fromRGB(30, 32, 45),
		material = Enum.Material.Slate,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = HubConfig.LEADERBOARD_BOARD_SIZE
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 48)
	title.BackgroundTransparency = 1
	title.Text = "🏆 Ruhmeshalle — Top Spieler"
	title.TextColor3 = Color3.fromRGB(255, 220, 80)
	title.TextSize = 28
	title.Font = Enum.Font.GothamBold
	title.Parent = gui

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.fromOffset(0, 52)
	list.Size = UDim2.new(1, 0, 1, -52)
	list.BackgroundTransparency = 1
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextColor3 = Color3.fromRGB(230, 230, 240)
	list.TextSize = 22
	list.Font = Enum.Font.Gotham
	list.Text = ""
	list.Parent = gui

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt.", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	list.Text = table.concat(lines, "\n")

	return board
end

function HubWorldBuilder.updateLeaderboardBoard(hubFolder, entries)
	local board = hubFolder:FindFirstChild("LeaderboardBoard", true)
	if not board then return end
	local gui = board:FindFirstChildOfClass("SurfaceGui")
	if not gui then return end
	local list = gui:FindFirstChild("List")
	if not list then return end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt.", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	list.Text = table.concat(lines, "\n")
end

function HubWorldBuilder.build(leaderboardEntries)
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local floorY = HubConfig.FLOOR_Y
	local floor = makePart({
		parent = hub,
		name = "Floor",
		size = HubConfig.FLOOR_SIZE,
		cframe = CFrame.new(0, floorY - HubConfig.FLOOR_SIZE.Y / 2, 0),
		color = Color3.fromRGB(45, 50, 65),
		material = Enum.Material.Concrete,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.CFrame = CFrame.new(HubConfig.SPAWN)
	spawn.Parent = hub

	local wallHeight = 12
	local wallThickness = 2
	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallY = floorY + wallHeight / 2

	local walls = {
		{ Vector3.new(0, wallY, halfZ + wallThickness / 2), Vector3.new(HubConfig.FLOOR_SIZE.X + 4, wallHeight, wallThickness) },
		{ Vector3.new(0, wallY, -halfZ - wallThickness / 2), Vector3.new(HubConfig.FLOOR_SIZE.X + 4, wallHeight, wallThickness) },
		{ Vector3.new(halfX + wallThickness / 2, wallY, 0), Vector3.new(wallThickness, wallHeight, HubConfig.FLOOR_SIZE.Z + 4) },
		{ Vector3.new(-halfX - wallThickness / 2, wallY, 0), Vector3.new(wallThickness, wallHeight, HubConfig.FLOOR_SIZE.Z + 4) },
	}
	for i, wall in walls do
		makePart({
			parent = hub,
			name = "Wall" .. i,
			size = wall[2],
			cframe = CFrame.new(wall[1]),
			color = Color3.fromRGB(35, 38, 50),
			material = Enum.Material.Brick,
		})
	end

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zonePart = makePart({
			parent = zonesFolder,
			name = zone.id,
			size = zone.size,
			cframe = CFrame.new(zone.position),
			color = zone.color,
			material = Enum.Material.Neon,
			transparency = 0.35,
			canCollide = false,
		})
		zonePart:SetAttribute("ZoneId", zone.id)
		zonePart:SetAttribute("ZoneName", zone.name)
		zonePart:SetAttribute("ZoneHint", zone.hint)
		zonePart:SetAttribute("ZoneAction", zone.action)

		createSign(hub, zone.name, zone.position + Vector3.new(0, zone.size.Y / 2 + 2.5, 0), zone.color)
	end

	HubWorldBuilder.buildLeaderboardBoard(hub, leaderboardEntries or {})

	local light = Instance.new("PointLight")
	light.Brightness = 0.6
	light.Range = 40
	light.Parent = floor

	return hub
end

return HubWorldBuilder
