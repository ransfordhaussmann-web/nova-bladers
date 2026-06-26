local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local Remotes = NovaBladers:WaitForChild("Remotes")

local HubWorldManager = {}
local inArena = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = PlayerDataManager.getRankPoints(data),
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
	}
end

function HubWorldManager.ensureHub()
	return HubWorldBuilder.build(workspace)
end

function HubWorldManager.teleportToHub(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	inArena[player] = nil
end

function HubWorldManager.sendLobbyReady(player)
	Remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.enterHub(player)
	HubWorldManager.teleportToHub(player)
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.enterArena(player)
	inArena[player] = true
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(HubConfig.ARENA_TELEPORT)
	end
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.enterHub(player)
end

function HubWorldManager.isInArena(player)
	return inArena[player] == true
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(PlayerDataManager.get(player)))

	local function onCharacter(character)
		if inArena[player] then
			return
		end
		task.defer(function()
			HubWorldManager.teleportToHub(player)
		end)
	end

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end

	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.onPlayerRemoving(player)
	PlayerDataManager.save(player)
	inArena[player] = nil
end

function HubWorldManager.onMatchResult(player, won)
	PlayerDataManager.recordMatch(player, won)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
	PlayerDataManager.persist(player)
end

function HubWorldManager.init()
	HubWorldManager.ensureHub()

	Remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	Players.PlayerAdded:Connect(HubWorldManager.onPlayerAdded)
	Players.PlayerRemoving:Connect(HubWorldManager.onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(HubWorldManager.onPlayerAdded, player)
	end
end

return HubWorldManager
