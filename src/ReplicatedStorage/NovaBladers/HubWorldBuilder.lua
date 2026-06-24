local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.Size = props.size
	part.Position = props.position
	part.Color = props.color or Color3.fromRGB(60, 65, 80)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Name = props.name or "Part"
	part.Parent = props.parent
	return part
end

local function addSign(parent, zone)
	local sign = makePart({
		name = zone.id .. "Sign",
		parent = parent,
		size = Vector3.new(6, 3, 0.4),
		position = zone.position + Vector3.new(0, zone.size.Y * 0.5 + 2.5, 0),
		color = zone.color,
		canCollide = false,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = zone.label
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	local backGui = gui:Clone()
	backGui.Face = Enum.NormalId.Back
	backGui.Parent = sign
end

local function addZoneTrigger(parent, zone)
	local trigger = makePart({
		name = zone.id .. "Zone",
		parent = parent,
		size = zone.size,
		position = zone.position,
		color = zone.color,
		canCollide = false,
	})
	trigger.Transparency = 0.75
	trigger:SetAttribute("ZoneId", zone.id)
	trigger:SetAttribute("ZoneAction", zone.action)
	trigger:SetAttribute("ZoneHint", zone.hint)
	trigger:SetAttribute("ZoneLabel", zone.label)
	return trigger
end

function HubWorldBuilder.createLeaderboardBoard(parent, entries)
	local board = parent:FindFirstChild("LeaderboardBoard")
	if not board then
		board = makePart({
			name = "LeaderboardBoard",
			parent = parent,
			size = Vector3.new(10, 7, 0.5),
			position = HubConfig.ZONES.HallOfFame.position + Vector3.new(0, 4, -6),
			color = Color3.fromRGB(35, 35, 45),
			canCollide = true,
		})
	end

	local gui = board:FindFirstChildOfClass("SurfaceGui")
	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Parent = board
	end

	local frame = gui:FindFirstChild("Frame")
	if not frame then
		frame = Instance.new("Frame")
		frame.Name = "Frame"
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
		frame.BorderSizePixel = 0
		frame.Parent = gui

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, 0, 0, 48)
		title.BackgroundTransparency = 1
		title.Text = "🏆 Ruhmeshalle"
		title.TextColor3 = Color3.fromRGB(255, 210, 80)
		title.TextScaled = true
		title.Font = Enum.Font.GothamBold
		title.Parent = frame

		local list = Instance.new("TextLabel")
		list.Name = "List"
		list.Position = UDim2.new(0, 8, 0, 52)
		list.Size = UDim2.new(1, -16, 1, -60)
		list.BackgroundTransparency = 1
		list.TextXAlignment = Enum.TextXAlignment.Left
		list.TextYAlignment = Enum.TextYAlignment.Top
		list.TextColor3 = Color3.new(1, 1, 1)
		list.TextSize = 22
		list.Font = Enum.Font.Gotham
		list.TextWrapped = true
		list.Parent = frame
	end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	frame.List.Text = table.concat(lines, "\n")
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER
	hub.Parent = workspace

	local floorY = HubConfig.SPAWN.Y - 3
	makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		position = Vector3.new(0, floorY, 0),
		color = Color3.fromRGB(45, 50, 65),
		material = Enum.Material.Slate,
	})

	local halfX = HubConfig.FLOOR_SIZE.X * 0.5
	local halfZ = HubConfig.FLOOR_SIZE.Z * 0.5
	local wallH = HubConfig.WALL_HEIGHT
	local wallY = floorY + wallH * 0.5

	for _, wall in {
		{ name = "WallNorth", pos = Vector3.new(0, wallY, -halfZ), size = Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 1) },
		{ name = "WallSouth", pos = Vector3.new(0, wallY, halfZ), size = Vector3.new(HubConfig.FLOOR_SIZE.X, wallH, 1) },
		{ name = "WallWest", pos = Vector3.new(-halfX, wallY, 0), size = Vector3.new(1, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ name = "WallEast", pos = Vector3.new(halfX, wallY, 0), size = Vector3.new(1, wallH, HubConfig.FLOOR_SIZE.Z) },
	} do
		makePart({
			name = wall.name,
			parent = hub,
			size = wall.size,
			position = wall.pos,
			color = Color3.fromRGB(55, 60, 75),
			material = Enum.Material.Concrete,
		})
	end

	local spawn = makePart({
		name = "HubSpawn",
		parent = hub,
		size = Vector3.new(4, 0.2, 4),
		position = HubConfig.SPAWN - Vector3.new(0, 3.4, 0),
		color = Color3.fromRGB(100, 180, 255),
		canCollide = false,
	})
	spawn.Transparency = 0.5

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		addZoneTrigger(zonesFolder, zone)
		addSign(zonesFolder, zone)
	end

	HubWorldBuilder.createLeaderboardBoard(hub, {})

	return hub
end

return HubWorldBuilder
