local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local HubWorldManager = {}

local remotes
local playerDataManager
local leaderboardManager
local playersInArena = {}
local hubFolder

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function findArenaSpawn()
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if not arena then
		return nil
	end
	local spawn = arena:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawn then
		return spawn
	end
	local floor = arena:FindFirstChild("Floor", true)
	if floor and floor:IsA("BasePart") then
		return floor.Position + HubConfig.ARENA_SPAWN_OFFSET
	end
	return arena:GetPivot().Position + HubConfig.ARENA_SPAWN_OFFSET
end

local function getHubSpawnCFrame()
	local spawnPart = hubFolder and hubFolder:FindFirstChild("HubSpawn")
	if spawnPart and spawnPart:IsA("BasePart") then
		return spawnPart.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubConfig.HUB_CENTER + HubConfig.SPAWN_OFFSET)
end

local function teleportCharacter(player, targetCFrame)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = targetCFrame
	end
end

local function createSign(parent, text)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = parent
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.Text = text
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	return billboard
end

local function createZone(parent, zoneId, zoneConfig, onTriggered)
	local zone = Instance.new("Part")
	zone.Name = zoneId
	zone.Size = zoneConfig.size
	zone.Position = HubConfig.HUB_CENTER + zoneConfig.position
	zone.Anchored = true
	zone.CanCollide = true
	zone.Material = Enum.Material.Neon
	zone.Color = zoneConfig.color
	zone.Transparency = 0.25
	zone.Parent = parent

	createSign(zone, zoneConfig.name)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zoneConfig.actionText
	prompt.ObjectText = zoneConfig.objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = zone

	prompt.Triggered:Connect(onTriggered)
	return zone
end

local function buildHubWorld()
	if workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME) then
		hubFolder = workspace[HubConfig.HUB_FOLDER_NAME]
		return hubFolder
	end

	hubFolder = Instance.new("Folder")
	hubFolder.Name = HubConfig.HUB_FOLDER_NAME
	hubFolder.Parent = workspace

	local floor = Instance.new("Part")
	floor.Name = "HubFloor"
	floor.Size = HubConfig.HUB_SIZE
	floor.Position = HubConfig.HUB_CENTER
	floor.Anchored = true
	floor.Material = Enum.Material.Slate
	floor.Color = Color3.fromRGB(55, 58, 68)
	floor.Parent = hubFolder

	local spawn = Instance.new("Part")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.HUB_CENTER + HubConfig.SPAWN_OFFSET
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = hubFolder

	createSign(floor, "Nova Bladers Hub")

	return hubFolder
end

function HubWorldManager.pushLobbyState(player)
	if not playerDataManager or not remotes then
		return
	end

	local data = playerDataManager.get(player)
	local rankPoints = playerDataManager.getRankPoints(data)
	local leaderboard = leaderboardManager and leaderboardManager.getTop(5) or {}
	local activeCount = #Players:GetPlayers() - #playersInArena

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(math.max(1, activeCount)),
		leaderboard = leaderboard,
		inHub = not playersInArena[player],
	})
end

function HubWorldManager.isInArena(player)
	return playersInArena[player] == true
end

function HubWorldManager.sendToArena(player)
	local target = findArenaSpawn()
	if not target then
		warn("[HubWorldManager] Arena-Ordner nicht gefunden:", HubConfig.ARENA_FOLDER_NAME)
		return false
	end

	playersInArena[player] = true
	local cframe = typeof(target) == "CFrame" and target or CFrame.new(target)
	teleportCharacter(player, cframe)

	if remotes then
		remotes.HubState:FireClient(player, { inArena = true })
	end
	return true
end

function HubWorldManager.returnToHub(player)
	playersInArena[player] = nil
	teleportCharacter(player, getHubSpawnCFrame())

	if remotes then
		remotes.HubState:FireClient(player, { inArena = false })
	end
	HubWorldManager.pushLobbyState(player)
end

function HubWorldManager.onPlayerAdded(player)
	player.CharacterAdded:Connect(function()
		task.defer(function()
			if HubWorldManager.isInArena(player) then
				return
			end
			teleportCharacter(player, getHubSpawnCFrame())
			HubWorldManager.pushLobbyState(player)
			if remotes then
				remotes.HubState:FireClient(player, { inArena = false })
			end
		end)
	end)

	if player.Character then
		teleportCharacter(player, getHubSpawnCFrame())
	end
	HubWorldManager.pushLobbyState(player)
end

function HubWorldManager.onPlayerRemoving(player)
	playersInArena[player] = nil
end

function HubWorldManager.init(deps)
	playerDataManager = deps.playerDataManager
	leaderboardManager = deps.leaderboardManager
	remotes = RemotesSetup.getRemotes()

	buildHubWorld()

	local function ensureZone(zoneId, zoneConfig, onTriggered)
		if hubFolder:FindFirstChild(zoneId) then
			return
		end
		createZone(hubFolder, zoneId, zoneConfig, onTriggered)
	end

	ensureZone("ArenaGate", HubConfig.ZONES.ArenaGate, function(player)
		HubWorldManager.sendToArena(player)
	end)

	ensureZone("BeyShop", HubConfig.ZONES.BeyShop, function(player)
		remotes.OpenBeySelect:FireClient(player)
	end)

	ensureZone("StatsBoard", HubConfig.ZONES.StatsBoard, function(player)
		local data = playerDataManager.get(player)
		local rankPoints = playerDataManager.getRankPoints(data)
		local leaderboard = leaderboardManager and leaderboardManager.getTop(5) or {}
		remotes.RefreshHubStats:FireClient(player, {
			wins = data.Wins,
			losses = data.Losses,
			rank = rankPoints,
			leaderboard = leaderboard,
		})
	end)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.sendToArena(player)
	end)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(HubWorldManager.onPlayerRemoving)
end

return HubWorldManager
