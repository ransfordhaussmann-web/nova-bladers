local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldManager = require(script.Parent.NovaBladers.HubWorldManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local RemotesSetup = require(script.Parent.NovaBladers.RemotesSetup)

local remotes

local function modeLabelFor(count)
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

local function buildLobbyPayload(player, showPanel)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = modeLabelFor(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = player:GetAttribute("InHub") ~= false,
		showPanel = showPanel == true,
	}
end

local function sendLobbyReady(player, showPanel)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, showPanel))
end

local function onKiosk(player)
	if HubWorldManager.isInArena(player) then
		return
	end
	sendLobbyReady(player, true)
end

local function onArena(player)
	if HubWorldManager.isInArena(player) then
		return
	end
	HubWorldManager.sendToArena(player)
end

local function onBeySelect(player)
	if HubWorldManager.isInArena(player) then
		return
	end
	remotes.OpenBeySelect:FireClient(player)
end

local function onEnterArena(player)
	if HubWorldManager.isInArena(player) then
		return
	end
	HubWorldManager.sendToArena(player)
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
	HubWorldManager.onPlayerAdded(player)
	task.defer(sendLobbyReady, player)
end

local function onPlayerRemoving(player)
	PlayerDataManager.save(player)
	HubWorldManager.onPlayerRemoving(player)
end

remotes = RemotesSetup.ensure()
HubWorldManager.init(onKiosk, onArena, onBeySelect)

remotes.EnterArena.OnServerEvent:Connect(onEnterArena)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

return {
	sendLobbyReady = sendLobbyReady,
	returnToHub = HubWorldManager.returnToHub,
}
