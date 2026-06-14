local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubWorldManager = require(ServerScriptService.HubWorldManager)
local PlayerDataManager = require(ServerScriptService.PlayerDataManager)
local LeaderboardManager = require(ServerScriptService.LeaderboardManager)

RemotesSetup.init()
HubWorldManager.init()

local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	else
		return string.format("Modus: FFA (%d Spieler)", playerCount)
	end
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
	}
end

local function sendLobbyReady(player)
	Remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

local function onPlayerReady(player)
	PlayerDataManager.load(player)

	local function onCharacter()
		task.wait(0.3)
		sendLobbyReady(player)
	end

	if player.Character then
		onCharacter()
	end
	player.CharacterAdded:Connect(onCharacter)
end

for _, player in Players:GetPlayers() do
	onPlayerReady(player)
end
Players.PlayerAdded:Connect(onPlayerReady)

Players.PlayerRemoving:Connect(function(player)
	PlayerDataManager.save(player)
end)

Remotes.EnterArena.OnServerEvent:Connect(function(player)
	HubWorldManager.requestEnterArena(player)
end)

Remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
	Remotes.OpenBeySelect:FireClient(player)
end)
