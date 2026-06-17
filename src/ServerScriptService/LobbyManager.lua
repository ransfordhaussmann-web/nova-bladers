local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldManager = require(script.Parent.HubWorldManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local LobbyManager = {}

local function getRemotes()
	return ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("Remotes")
end

local function modeLabelForPlayerCount(count: number)
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

function LobbyManager.buildLobbyPayload()
	local playerCount = #Players:GetPlayers()
	local leaderboard = LeaderboardManager.getTop(5)
	return {
		wins = 0,
		losses = 0,
		rank = 0,
		modeLabel = modeLabelForPlayerCount(playerCount),
		leaderboard = leaderboard,
	}
end

function LobbyManager.sendLobbyReady(player: Player, showPanel: boolean?)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	local payload = LobbyManager.buildLobbyPayload()
	payload.wins = data.Wins
	payload.losses = data.Losses
	payload.rank = rankPoints
	payload.showPanel = showPanel == true

	getRemotes().LobbyReady:FireClient(player, payload)
end

function LobbyManager.onEnterArena(player: Player)
	if HubWorldManager.isInArena(player) then
		return
	end
	if HubWorldManager.sendToArena(player) then
		getRemotes().EnterArena:FireClient(player)
	end
end

function LobbyManager.onZoneAction(player: Player, action: string, _zoneConfig)
	if HubWorldManager.isInArena(player) then
		return
	end

	if action == "enterArena" then
		LobbyManager.onEnterArena(player)
	elseif action == "openBeySelect" then
		getRemotes().OpenBeySelect:FireClient(player)
	elseif action == "openStats" then
		LobbyManager.sendLobbyReady(player, true)
	end
end

function LobbyManager.init()
	HubWorldManager.init(function(player, action, zoneConfig)
		LobbyManager.onZoneAction(player, action, zoneConfig)
	end)

	getRemotes().EnterArena.OnServerEvent:Connect(function(player)
		LobbyManager.onEnterArena(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		HubWorldManager.onPlayerAdded(player, function()
			LobbyManager.sendLobbyReady(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		HubWorldManager.onPlayerRemoving(player)
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		PlayerDataManager.load(player)
		HubWorldManager.onPlayerAdded(player, function()
			LobbyManager.sendLobbyReady(player)
		end)
	end
end

return LobbyManager
