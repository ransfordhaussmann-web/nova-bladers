local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldManager = {}

local hubModel = nil
local arenaPlayers = {}
local enterArenaCallbacks = {}

local function getCharacterRoot(player)
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function teleportPlayer(player, position)
	local root = getCharacterRoot(player)
	if not root then
		return
	end
	root.CFrame = CFrame.new(position)
end

local function createSign(parent, text, offset)
	local sign = Instance.new("Part")
	sign.Name = "Sign"
	sign.Size = Vector3.new(8, 3, 0.5)
	sign.Anchored = true
	sign.CanCollide = false
	sign.Material = Enum.Material.SmoothPlastic
	sign.Color = Color3.fromRGB(30, 35, 45)
	sign.CFrame = parent.CFrame * CFrame.new(0, 4, 0)
	sign.Parent = parent.Parent

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(200, 60)
	billboard.StudsOffset = offset or Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(240, 245, 255)
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard
end

local function buildZone(hub, zoneName, zoneConfig)
	local zone = Instance.new("Model")
	zone.Name = zoneName
	zone.Parent = hub

	local pad = Instance.new("Part")
	pad.Name = "Pad"
	pad.Size = zoneConfig.size
	pad.Position = zoneConfig.position
	pad.Anchored = true
	pad.Material = Enum.Material.Neon
	pad.Color = zoneConfig.color
	pad.Transparency = 0.45
	pad.Parent = zone

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zoneConfig.actionText
	prompt.ObjectText = zoneConfig.label
	prompt.MaxActivationDistance = 12
	prompt.HoldDuration = 0
	prompt.Parent = pad

	createSign(pad, zoneConfig.signText)

	if zoneName == "StatsBoard" then
		local display = Instance.new("Part")
		display.Name = "StatsBoardDisplay"
		display.Size = Vector3.new(14, 9, 1)
		display.Anchored = true
		display.CanCollide = false
		display.Material = Enum.Material.SmoothPlastic
		display.Color = Color3.fromRGB(25, 28, 38)
		display.CFrame = CFrame.new(zoneConfig.position + Vector3.new(0, 6, -6))
			* CFrame.Angles(0, math.rad(90), 0)
		display.Parent = zone

		local surface = Instance.new("SurfaceGui")
		surface.Name = "BoardGui"
		surface.Face = Enum.NormalId.Front
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 40
		surface.Parent = display

		local statsLabel = Instance.new("TextLabel")
		statsLabel.Name = "StatsText"
		statsLabel.Size = UDim2.fromScale(1, 0.45)
		statsLabel.BackgroundTransparency = 1
		statsLabel.Font = Enum.Font.GothamMedium
		statsLabel.TextColor3 = Color3.fromRGB(230, 235, 245)
		statsLabel.TextScaled = true
		statsLabel.Text = "Deine Stats laden…"
		statsLabel.TextXAlignment = Enum.TextXAlignment.Left
		statsLabel.TextYAlignment = Enum.TextYAlignment.Top
		statsLabel.Parent = surface

		local boardLabel = Instance.new("TextLabel")
		boardLabel.Name = "LeaderboardText"
		boardLabel.Size = UDim2.new(1, 0, 0.55, 0)
		boardLabel.Position = UDim2.fromScale(0, 0.45)
		boardLabel.BackgroundTransparency = 1
		boardLabel.Font = Enum.Font.Gotham
		boardLabel.TextColor3 = Color3.fromRGB(255, 215, 90)
		boardLabel.TextScaled = true
		boardLabel.Text = "🏆 Top Spieler"
		boardLabel.TextXAlignment = Enum.TextXAlignment.Left
		boardLabel.TextYAlignment = Enum.TextYAlignment.Top
		boardLabel.Parent = surface
	end

	return zone
end

local function buildHubWorld()
	if workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME) then
		return workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	end

	local hub = Instance.new("Model")
	hub.Name = HubConfig.HUB_FOLDER_NAME

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = HubConfig.FLOOR_SIZE
	floor.Position = HubConfig.HUB_CENTER
	floor.Anchored = true
	floor.Material = Enum.Material.Slate
	floor.Color = Color3.fromRGB(42, 48, 62)
	floor.Parent = hub

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = HubConfig.HUB_SPAWN
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = hub

	local titleSign = Instance.new("Part")
	titleSign.Name = "HubTitle"
	titleSign.Size = Vector3.new(1, 1, 1)
	titleSign.Anchored = true
	titleSign.CanCollide = false
	titleSign.Transparency = 1
	titleSign.Position = HubConfig.HUB_SPAWN + Vector3.new(0, 6, -8)
	titleSign.Parent = hub

	local titleGui = Instance.new("BillboardGui")
	titleGui.Size = UDim2.fromOffset(320, 80)
	titleGui.AlwaysOnTop = true
	titleGui.Parent = titleSign

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.fromScale(1, 1)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextColor3 = Color3.fromRGB(120, 180, 255)
	titleLabel.TextScaled = true
	titleLabel.Text = "NOVA BLADERS"
	titleLabel.Parent = titleGui

	for zoneName, zoneConfig in HubConfig.ZONES do
		buildZone(hub, zoneName, zoneConfig)
	end

	local wallHeight = 6
	local wallThickness = 2
	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallPositions = {
		Vector3.new(0, wallHeight / 2, -halfZ),
		Vector3.new(0, wallHeight / 2, halfZ),
		Vector3.new(-halfX, wallHeight / 2, 0),
		Vector3.new(halfX, wallHeight / 2, 0),
	}
	local wallSizes = {
		Vector3.new(HubConfig.FLOOR_SIZE.X + wallThickness, wallHeight, wallThickness),
		Vector3.new(HubConfig.FLOOR_SIZE.X + wallThickness, wallHeight, wallThickness),
		Vector3.new(wallThickness, wallHeight, HubConfig.FLOOR_SIZE.Z + wallThickness),
		Vector3.new(wallThickness, wallHeight, HubConfig.FLOOR_SIZE.Z + wallThickness),
	}

	for index, position in wallPositions do
		local wall = Instance.new("Part")
		wall.Name = "BoundaryWall"
		wall.Size = wallSizes[index]
		wall.Position = HubConfig.HUB_CENTER + position
		wall.Anchored = true
		wall.Material = Enum.Material.Concrete
		wall.Color = Color3.fromRGB(55, 60, 75)
		wall.Parent = hub
	end

	hub.Parent = workspace
	return hub
end

local function resolveArenaSpawn()
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if not arena then
		return HubConfig.ARENA_FALLBACK_SPAWN
	end

	local arenaSpawn = arena:FindFirstChild("Spawn", true)
		or arena:FindFirstChildWhichIsA("SpawnLocation", true)
	if arenaSpawn and arenaSpawn:IsA("BasePart") then
		return arenaSpawn.Position + Vector3.new(0, 3, 0)
	end

	local bowl = arena:FindFirstChild("Bowl", true)
	if bowl and bowl:IsA("BasePart") then
		return bowl.Position + Vector3.new(0, 6, 0)
	end

	return HubConfig.ARENA_FALLBACK_SPAWN
end

function HubWorldManager.getHubModel()
	return hubModel
end

function HubWorldManager.isInArena(player)
	return arenaPlayers[player] == true
end

function HubWorldManager.onEnterArena(callback)
	table.insert(enterArenaCallbacks, callback)
end

function HubWorldManager.sendToArena(player)
	arenaPlayers[player] = true
	teleportPlayer(player, resolveArenaSpawn())
end

function HubWorldManager.returnToHub(player)
	arenaPlayers[player] = nil
	teleportPlayer(player, HubConfig.HUB_SPAWN)
end

function HubWorldManager.requestEnterArena(player)
	if HubWorldManager.isInArena(player) then
		return
	end

	if #enterArenaCallbacks > 0 then
		for _, callback in enterArenaCallbacks do
			callback(player)
		end
	else
		HubWorldManager.sendToArena(player)
	end
end

function HubWorldManager.onPlayerAdded(player)
	player.CharacterAdded:Connect(function()
		if not HubWorldManager.isInArena(player) then
			task.defer(function()
				HubWorldManager.returnToHub(player)
			end)
		end
	end)
end

function HubWorldManager.init()
	hubModel = buildHubWorld()

	local nova = ReplicatedStorage:FindFirstChild("NovaBladers")
	if nova and not nova:FindFirstChild("Use3DHub") then
		local flag = Instance.new("BoolValue")
		flag.Name = "Use3DHub"
		flag.Value = true
		flag.Parent = nova
	end

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
end

return HubWorldManager
