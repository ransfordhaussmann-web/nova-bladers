local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}
local playerQueue = {}
local arenaBusy = false
local ffaFillToken = 0
local ffaFillActive = false

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function queueCount(modeId)
	return #queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local list = queues[modeId]
	for i, queued in list do
		if queued == player then
			table.remove(list, i)
			break
		end
	end
	playerQueue[player] = nil
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = getModeConfig(modeId)
	local count = queueCount(modeId)
	local status = "waiting"
	if count >= mode.minPlayers then
		status = arenaBusy and "pending" or "ready"
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		players = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		arenaBusy = arenaBusy,
	}
end

local function sendQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastQueueUpdates()
	for _, player in Players:GetPlayers() do
		if playerQueue[player] then
			sendQueueUpdate(player)
		end
	end
end

local function popPlayers(modeId, count)
	local list = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #list) do
		local player = table.remove(list, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(picked, player)
		end
	end
	return picked
end

local function startMatch(modeId, playerList)
	arenaBusy = true
	ffaFillToken += 1
	ffaFillActive = false
	HubService.enterArenaForMatch(playerList)

	for _, player in playerList do
		sendQueueUpdate(player)
	end
	broadcastQueueUpdates()

	Bindables.MatchReady:Fire({
		mode = modeId,
		players = playerList,
	})
end

local function tryStartMode(modeId)
	if arenaBusy then
		return
	end

	local mode = getModeConfig(modeId)
	if not mode then
		return
	end

	local count = queueCount(modeId)
	if count < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		return
	end

	local players = popPlayers(modeId, mode.maxPlayers)
	if #players >= mode.minPlayers then
		startMatch(modeId, players)
	end
end

local function tryStartFfa()
	if arenaBusy then
		return
	end

	local mode = getModeConfig("ffa")
	local count = queueCount("ffa")
	if count < mode.minPlayers then
		return
	end

	if count >= mode.maxPlayers then
		local players = popPlayers("ffa", mode.maxPlayers)
		if #players >= mode.minPlayers then
			startMatch("ffa", players)
		end
		return
	end

	if ffaFillActive then
		return
	end

	ffaFillActive = true
	ffaFillToken += 1
	local token = ffaFillToken
	broadcastQueueUpdates()

	task.delay(mode.fillTimeout, function()
		ffaFillActive = false
		if token ~= ffaFillToken or arenaBusy then
			return
		end

		local readyCount = queueCount("ffa")
		if readyCount < mode.minPlayers then
			return
		end

		local players = popPlayers("ffa", mode.maxPlayers)
		if #players >= mode.minPlayers then
			startMatch("ffa", players)
		end
	end)
end

local function tryStartMatches()
	if arenaBusy then
		broadcastQueueUpdates()
		return
	end

	tryStartMode("training")
	if arenaBusy then
		return
	end

	tryStartMode("pvp")
	if arenaBusy then
		return
	end

	tryStartFfa()
	if not arenaBusy then
		broadcastQueueUpdates()
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not getModeConfig(modeId) then
		modeId = getRecommendedModeId()
	end

	if HubService.getPhase(player) == "arena" then
		return false
	end

	if playerQueue[player] == modeId then
		sendQueueUpdate(player)
		return true
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	sendQueueUpdate(player)
	broadcastQueueUpdates()
	tryStartMatches()
	return true
end

function MatchmakingService.joinRecommended(player)
	return MatchmakingService.joinQueue(player, getRecommendedModeId())
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		sendQueueUpdate(player)
		return
	end

	removeFromQueue(player)
	sendQueueUpdate(player)
	broadcastQueueUpdates()
end

function MatchmakingService.onMatchEnded()
	arenaBusy = false
	tryStartMatches()
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.getRecommendedModeId()
	return getRecommendedModeId()
end

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Remotes.EnterArena.OnServerEvent:Connect(function(player)
	MatchmakingService.joinRecommended(player)
end)

Players.PlayerRemoving:Connect(function(player)
	removeFromQueue(player)
	task.defer(broadcastQueueUpdates)
end)

return MatchmakingService
