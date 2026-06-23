local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local Remotes = NovaBladers:WaitForChild("Remotes")
local LobbyReady = Remotes:WaitForChild("LobbyReady")
local RequestLobbyData = Remotes:FindFirstChild("RequestLobbyData")

local hubRoot = HubWorldBuilder.build()
local playersInHub = {}

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
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = true,
	}
end

local function sendLobbyReady(player)
	LobbyReady:FireClient(player, buildLobbyPayload(player))
end

local function teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end
	rootPart.CFrame = HubWorldBuilder.getSpawnCFrame()
	playersInHub[player] = true
	sendLobbyReady(player)
end

Players.PlayerAdded:Connect(function(player)
	PlayerDataManager.load(player)
	player.CharacterAdded:Connect(function()
		task.defer(teleportToHub, player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	playersInHub[player] = nil
	PlayerDataManager.save(player)
end)

if RequestLobbyData then
	RequestLobbyData.OnServerEvent:Connect(function(player)
		sendLobbyReady(player)
	end)
end

for _, player in Players:GetPlayers() do
	PlayerDataManager.load(player)
	if player.Character then
		teleportToHub(player)
	end
end

return {
	sendLobbyReady = sendLobbyReady,
	teleportToHub = teleportToHub,
	isInHub = function(player)
		return playersInHub[player] == true
	end,
}
