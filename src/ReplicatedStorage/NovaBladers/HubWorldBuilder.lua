local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldBuilder = {}

local function setPartDefaults(part)
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function createLabel(parent, text, size, position, color)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(200, 60)
	billboard.StudsOffset = position
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = size
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Text = text
	label.Parent = billboard

	return billboard
end

function HubWorldBuilder.findArenaSpawn()
	for _, folderName in HubConfig.ARENA_FOLDER_NAMES do
		local folder = workspace:FindFirstChild(folderName)
		if folder then
			for _, spawnName in HubConfig.ARENA_SPAWN_NAMES do
				local spawn = folder:FindFirstChild(spawnName, true)
				if spawn and spawn:IsA("BasePart") then
					return spawn
				end
			end
			local bowl = folder:FindFirstChild("Bowl") or folder:FindFirstChild("Floor")
			if bowl and bowl:IsA("BasePart") then
				return bowl
			end
		end
	end
	return nil
end

function HubWorldBuilder.updateLeaderboardBoard(boardPart, entries)
	local surface = boardPart:FindFirstChild("LeaderboardSurface")
	if not surface then return end

	local frame = surface:FindFirstChild("Frame")
	if not frame then return end

	local title = frame:FindFirstChild("Title")
	local list = frame:FindFirstChild("List")
	if not title or not list then return end

	title.Text = "🏆 Ruhmeshalle"
	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s — %d Pkt", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	list.Text = table.concat(lines, "\n")
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		return existing
	end

	local hub = Instance.new("Model")
	hub.Name = "NovaHub"

	local origin = HubConfig.HUB_ORIGIN

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = HubConfig.FLOOR_SIZE
	floor.Position = origin + Vector3.new(0, -HubConfig.FLOOR_SIZE.Y / 2, 0)
	floor.Color = Color3.fromRGB(35, 38, 48)
	floor.Material = Enum.Material.Slate
	setPartDefaults(floor)
	floor.Parent = hub

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallThickness = 2
	local wallY = origin.Y + HubConfig.WALL_HEIGHT / 2

	local wallDefs = {
		{ Vector3.new(0, 0, -halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X + 4, HubConfig.WALL_HEIGHT, wallThickness) },
		{ Vector3.new(0, 0, halfZ), Vector3.new(HubConfig.FLOOR_SIZE.X + 4, HubConfig.WALL_HEIGHT, wallThickness) },
		{ Vector3.new(-halfX, 0, 0), Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z + 4) },
		{ Vector3.new(halfX, 0, 0), Vector3.new(wallThickness, HubConfig.WALL_HEIGHT, HubConfig.FLOOR_SIZE.Z + 4) },
	}

	for index, def in wallDefs do
		local wall = Instance.new("Part")
		wall.Name = "Wall" .. index
		wall.Size = def[2]
		wall.Position = origin + def[1] + Vector3.new(0, wallY - origin.Y, 0)
		wall.Color = Color3.fromRGB(50, 55, 68)
		wall.Material = Enum.Material.Concrete
		setPartDefaults(wall)
		wall.Parent = hub
	end

	local spawn = Instance.new("Part")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Anchored = true
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zonePart = Instance.new("Part")
		zonePart.Name = zone.id
		zonePart.Size = zone.size
		zonePart.Position = zone.position
		zonePart.Color = zone.color
		zonePart.Material = Enum.Material.Neon
		zonePart.Transparency = 0.35
		setPartDefaults(zonePart)
		zonePart.CanCollide = false
		zonePart.Parent = zonesFolder

		createLabel(zonePart, zone.label, 22, Vector3.new(0, zone.size.Y / 2 + 2, 0), zone.color)
		createLabel(zonePart, zone.subtitle, 14, Vector3.new(0, zone.size.Y / 2 - 0.5, 0), Color3.fromRGB(220, 220, 220))

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ZonePrompt"
		prompt.ActionText = zone.hint
		prompt.ObjectText = zone.label
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("ZoneId", zone.id)
		prompt:SetAttribute("ZoneAction", zone.action)
		prompt.Parent = zonePart

		if zone.id == "HallOfFame" then
			local board = Instance.new("Part")
			board.Name = "LeaderboardBoard"
			board.Size = Vector3.new(12, 8, 0.5)
			board.Position = zone.position + Vector3.new(0, 5, zone.size.Z / 2 + 1)
			board.Color = Color3.fromRGB(25, 28, 36)
			board.Material = Enum.Material.SmoothPlastic
			setPartDefaults(board)
			board.Parent = zonesFolder

			local surface = Instance.new("SurfaceGui")
			surface.Name = "LeaderboardSurface"
			surface.Face = Enum.NormalId.Front
			surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStuds
			surface.PixelsPerStuds = 40
			surface.Parent = board

			local frame = Instance.new("Frame")
			frame.Name = "Frame"
			frame.Size = UDim2.fromScale(1, 1)
			frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
			frame.BorderSizePixel = 0
			frame.Parent = surface

			local title = Instance.new("TextLabel")
			title.Name = "Title"
			title.Size = UDim2.new(1, 0, 0, 36)
			title.BackgroundTransparency = 1
			title.Font = Enum.Font.GothamBold
			title.TextSize = 22
			title.TextColor3 = Color3.fromRGB(255, 220, 100)
			title.Text = "🏆 Ruhmeshalle"
			title.Parent = frame

			local list = Instance.new("TextLabel")
			list.Name = "List"
			list.Size = UDim2.new(1, -12, 1, -44)
			list.Position = UDim2.fromOffset(6, 40)
			list.BackgroundTransparency = 1
			list.Font = Enum.Font.Gotham
			list.TextSize = 16
			list.TextXAlignment = Enum.TextXAlignment.Left
			list.TextYAlignment = Enum.TextYAlignment.Top
			list.TextColor3 = Color3.fromRGB(230, 230, 240)
			list.Text = "Lade…"
			list.TextWrapped = true
			list.Parent = frame
		end
	end

	hub.Parent = workspace
	return hub
end

return HubWorldBuilder
