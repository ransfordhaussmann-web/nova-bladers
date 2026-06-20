local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubFolder
local zoneCooldowns = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function findArenaSpawn()
	for _, folderName in HubConfig.ARENA_FOLDER_NAMES do
		local arena = workspace:FindFirstChild(folderName)
		if arena then
			for _, spawnName in HubConfig.ARENA_SPAWN_NAMES do
				local spawn = arena:FindFirstChild(spawnName, true)
				if spawn and spawn:IsA("BasePart") then
					return spawn
				end
			end
		end
	end

	local fallback = workspace:FindFirstChild("ArenaSpawn", true)
	if fallback and fallback:IsA("BasePart") then
		return fallback
	end
	return nil
end

local function teleportCharacter(player, position, lookAt)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local cf = CFrame.new(position)
	if lookAt then
		cf = CFrame.lookAt(position, lookAt)
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	character:PivotTo(cf)
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
		inHub = true,
	}
end

local function refreshHallBoard()
	if not hubFolder then
		return
	end
	HubWorldBuilder.buildHallBoard(hubFolder, LeaderboardManager.getTop(5))
end

local function sendToHub(player)
	local spawnPart = hubFolder and hubFolder:FindFirstChild("HubSpawn")
	local pos = spawnPart and spawnPart.Position + Vector3.new(0, 3, 0) or HubConfig.SPAWN_POSITION
	teleportCharacter(player, pos)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
	refreshHallBoard()
end

function HubWorldManager.enterArena(player)
	if zoneCooldowns[player] and tick() - zoneCooldowns[player] < HubConfig.ZONE_COOLDOWN then
		return
	end
	zoneCooldowns[player] = tick()

	local spawnPart = findArenaSpawn()
	if spawnPart then
		teleportCharacter(player, spawnPart.Position + Vector3.new(0, 3, 0))
	else
		warn("[NovaBladers] Kein Arena-Spawn gefunden — HubSpawn als Fallback")
		sendToHub(player)
	end
end

function HubWorldManager.openBeySelect(player)
	if zoneCooldowns[player] and tick() - zoneCooldowns[player] < HubConfig.ZONE_COOLDOWN then
		return
	end
	zoneCooldowns[player] = tick()
	remotes.OpenBeySelect:FireClient(player)
end

function HubWorldManager.returnToHub(player)
	zoneCooldowns[player] = nil
	sendToHub(player)
end

local function onPlayerReady(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		sendToHub(player)
	end)

	if player.Character then
		sendToHub(player)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubFolder = HubWorldBuilder.build()
	refreshHallBoard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	Players.PlayerAdded:Connect(onPlayerReady)
	Players.PlayerRemoving:Connect(function(player)
		zoneCooldowns[player] = nil
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerReady, player)
	end
end

return HubWorldManager
