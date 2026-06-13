local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(script.Parent.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.Parent.LeaderboardManager)

local HubWorldManager = {}

local hubFolder
local hubSpawn
local arenaGatePortal
local playerInArena = {}
local remotes

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "Modus: FFA"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: Training"
end

local function findArenaSpawn()
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if not arena then
		return nil
	end
	return arena:FindFirstChild(HubConfig.ARENA_SPAWN_NAME, true)
end

local function teleportCharacter(player, targetCFrame)
	local character = player.Character
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	root.CFrame = targetCFrame + Vector3.new(0, 3, 0)
	return true
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = not HubWorldManager.isInArena(player),
	}
end

function HubWorldManager.isInArena(player)
	return playerInArena[player] == true
end

function HubWorldManager.sendLobbyReady(player)
	if not remotes then
		return
	end
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.returnToHub(player)
	playerInArena[player] = false
	player:SetAttribute("InHub", true)

	local spawnCFrame = hubSpawn and hubSpawn.CFrame or CFrame.new(HubConfig.HUB_SPAWN)
	teleportCharacter(player, spawnCFrame)
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.sendToArena(player)
	HubWorldManager.enterArena(player)
end

function HubWorldManager.enterArena(player)
	local arenaSpawn = findArenaSpawn()
	if not arenaSpawn then
		warn("[HubWorldManager] Arena spawn not found — is Workspace.Arena present?")
		return false
	end

	playerInArena[player] = true
	player:SetAttribute("InHub", false)
	teleportCharacter(player, arenaSpawn.CFrame)

	if remotes then
		remotes.OpenBeySelect:FireClient(player)
	end
	return true
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	playerInArena[player] = false
	player:SetAttribute("InHub", true)

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if HubWorldManager.isInArena(player) then
				local arenaSpawn = findArenaSpawn()
				if arenaSpawn then
					teleportCharacter(player, arenaSpawn.CFrame)
				end
			else
				HubWorldManager.returnToHub(player)
			end
		end)
	end)

	if player.Character then
		HubWorldManager.returnToHub(player)
	else
		HubWorldManager.sendLobbyReady(player)
	end
end

function HubWorldManager.onPlayerRemoving(player)
	playerInArena[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init(remoteFolder)
	remotes = remoteFolder
	hubFolder, hubSpawn, arenaGatePortal = HubWorldBuilder.build()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(HubWorldManager.onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		HubWorldManager.onPlayerAdded(player)
	end
end

return HubWorldManager
