local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldManager = require(script.Parent.HubWorldManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local Remotes = ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("Remotes")

local function modeLabelFor(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = modeLabelFor(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
		hubMode = true,
	}
end

local function sendPlayerToHub(player)
	local payload = buildLobbyPayload(player)
	HubWorldManager.returnToHub(player, payload)
end

HubWorldManager.buildHubWorld()

local function enterArena(player)
	HubWorldManager.sendToArena(player)
end

HubWorldManager.setupZoneHandlers(
	enterArena,
	function(player)
		local openBey = Remotes:FindFirstChild("OpenBeySelect")
		if openBey then
			openBey:FireClient(player)
		end
	end,
	function(player)
		local payload = buildLobbyPayload(player)
		Remotes.LobbyReady:FireClient(player, payload)
	end
)

Remotes.EnterArena.OnServerEvent:Connect(function(player)
	if HubWorldManager.isInArena(player) then return end
	enterArena(player)
end)

Players.PlayerAdded:Connect(function(player)
	PlayerDataManager.load(player)
	player.CharacterAdded:Connect(function()
		task.defer(function()
			if HubWorldManager.isInHub(player) then
				sendPlayerToHub(player)
			end
		end)
	end)
	if player.Character then
		task.defer(sendPlayerToHub, player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerDataManager.save(player)
	HubWorldManager.clearPlayer(player)
end)

for _, player in Players:GetPlayers() do
	PlayerDataManager.load(player)
	if player.Character then
		sendPlayerToHub(player)
	end
end
