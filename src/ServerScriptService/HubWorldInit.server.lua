local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldManager = require(script.Parent.HubWorldManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function modeLabelForPlayerCount(count)
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
		modeLabel = modeLabelForPlayerCount(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = true,
	}
end

local function refreshLobby(player)
	if HubWorldManager.isInArena(player) then
		return
	end
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

HubWorldManager.init()

local function onPlayerJoined(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
	HubWorldManager.onPlayerAdded(player, buildLobbyPayload)
end

Players.PlayerAdded:Connect(onPlayerJoined)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerJoined, player)
end

Players.PlayerRemoving:Connect(function(player)
	PlayerDataManager.save(player)
end)

remotes.EnterArena.OnServerEvent:Connect(function(player)
	if HubWorldManager.isInArena(player) then
		return
	end
	HubWorldManager.sendToArena(player)
end)

remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
	if HubWorldManager.isInArena(player) then
		return
	end
	remotes.OpenBeySelect:FireClient(player)
end)

local refreshLobbyRemote = remotes:FindFirstChild("RefreshLobby")
if refreshLobbyRemote then
	refreshLobbyRemote.OnServerEvent:Connect(function(player)
		if HubWorldManager.isInArena(player) then
			return
		end
		local payload = buildLobbyPayload(player)
		payload.forceShow = true
		remotes.LobbyReady:FireClient(player, payload)
	end)
end

if remotes:FindFirstChild("ReturnToHub") then
	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
		refreshLobby(player)
	end)
end

_G.NovaBladersReturnToHub = function(player)
	HubWorldManager.returnToHub(player)
	refreshLobby(player)
end
