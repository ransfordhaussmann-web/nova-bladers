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
local fillTokens = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil
	return modeId
end

local function buildPlayerPayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = config.label,
		count = #queue,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		arenaBusy = arenaBusy,
		pending = arenaBusy,
	}
end

local function sendQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildPlayerPayload(player))
	end
end

local function broadcastQueueUpdate(modeId)
	for _, player in queues[modeId] do
		sendQueueUpdate(player)
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = nil
end

local function clearQueue(modeId)
	for _, player in queues[modeId] do
		playerQueue[player] = nil
		sendQueueUpdate(player)
	end
	queues[modeId] = {}
	cancelFillTimer(modeId)
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end

	if not busy then
		for modeId in MatchmakingConfig.MODES do
			MatchmakingService.tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromQueue(player)
	if not modeId then
		return
	end

	local config = getModeConfig(modeId)
	if config and #queues[modeId] < config.minPlayers then
		cancelFillTimer(modeId)
	end

	sendQueueUpdate(player)
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false
	end
	if HubService.getPhase(player) ~= "hub" then
		return false
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	sendQueueUpdate(player)
	broadcastQueueUpdate(modeId)
	MatchmakingService.tryStartMatch(modeId)
	return true
end

function MatchmakingService.popPlayers(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local count = math.min(#queue, config.maxPlayers)
	local players = {}

	for _ = 1, count do
		local nextPlayer = table.remove(queue, 1)
		if nextPlayer then
			playerQueue[nextPlayer] = nil
			table.insert(players, nextPlayer)
		end
	end

	cancelFillTimer(modeId)
	broadcastQueueUpdate(modeId)
	return players
end

function MatchmakingService.tryStartMatch(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	if not config or #queue < config.minPlayers or arenaBusy then
		return
	end

	if #queue >= config.maxPlayers then
		cancelFillTimer(modeId)
		local players = MatchmakingService.popPlayers(modeId)
		if #players > 0 then
			MatchmakingService.launchMatch(modeId, players)
		end
		return
	end

	if modeId == "ffa" and config.fillTimeout then
		if fillTokens[modeId] then
			return
		end

		fillTokens[modeId] = {}
		local token = fillTokens[modeId]
		task.delay(config.fillTimeout, function()
			if fillTokens[modeId] ~= token or arenaBusy then
				return
			end
			fillTokens[modeId] = nil

			if #queues[modeId] >= config.minPlayers then
				local players = MatchmakingService.popPlayers(modeId)
				if #players > 0 then
					MatchmakingService.launchMatch(modeId, players)
				end
			end
		end)
		return
	end

	local players = MatchmakingService.popPlayers(modeId)
	if #players > 0 then
		MatchmakingService.launchMatch(modeId, players)
	end
end

function MatchmakingService.launchMatch(modeId, players)
	arenaBusy = true
	for modeKey in queues do
		broadcastQueueUpdate(modeKey)
	end

	for _, player in players do
		if HubService.leaveHubForArena then
			HubService.leaveHubForArena(player)
		end
	end

	Bindables.MatchReady:Fire({
		mode = modeId,
		players = players,
	})
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

Bindables.MatchStarted.Event:Connect(function()
	MatchmakingService.setArenaBusy(true)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.setArenaBusy(false)
end)

return MatchmakingService
