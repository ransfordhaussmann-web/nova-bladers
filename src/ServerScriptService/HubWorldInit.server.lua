local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local HubWorldManager = require(script.Parent.HubWorldManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local Remotes = require(ReplicatedStorage.NovaBladers.RemotesSetup)

if not ServerScriptService:FindFirstChild("ArenaEntryRequested") then
	local entryEvent = Instance.new("BindableEvent")
	entryEvent.Name = "ArenaEntryRequested"
	entryEvent.Parent = ServerScriptService
end

HubWorldManager.build()

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function sendLobbyReady(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)

	Remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
		inHub = true,
	})
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		if HubWorldManager.isInArena(player) then
			return
		end
		HubWorldManager.teleportToHub(player)
		sendLobbyReady(player)
	end)

	if player.Character then
		HubWorldManager.teleportToHub(player)
	end
	sendLobbyReady(player)
end

Remotes.EnterArena.OnServerEvent:Connect(function(player)
	if HubWorldManager.isInArena(player) then
		return
	end
	HubWorldManager.sendToArena(player)
end)

Remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
	if HubWorldManager.isInArena(player) then
		return
	end
	Remotes.OpenBeySelect:FireClient(player)
end)

Remotes.ReturnToHub.OnServerEvent:Connect(function(player)
	HubWorldManager.returnToHub(player)
	sendLobbyReady(player)
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	HubWorldManager.onPlayerRemoving(player)
	PlayerDataManager.save(player)
end)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
