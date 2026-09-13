local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local pendingMatches = {}
local ffaFillToken = 0
local callbacks = {}

local Remotes, Bindables

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function getActiveModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	end
	if count == 2 then
		return "pvp"
	end
	return "training"
end

local function ensureQueues()
	for modeId in MatchmakingConfig.MODES do
		if not queues[modeId] then
			queues[modeId] = {}
		end
	end
end

local function removePlayerFromQueues(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	if queue then
		for i, queuedPlayer in queue do
			if queuedPlayer == player then
				table.remove(queue, i)
				break
			end
		end
	end

	playerQueue[player] = nil
end

local function buildQueuePayload(player, modeId, status)
	local config = getModeConfig(modeId)
	local queue = queues[modeId] or {}
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = config.label,
		position = position,
		queued = #queue,
		needed = config.minPlayers,
		status = status or "waiting",
	}
end

local function sendQueueUpdate(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueueUpdates(modeId, status)
	local queue = queues[modeId] or {}
	for _, player in queue do
		sendQueueUpdate(player, buildQueuePayload(player, modeId, status))
	end
end

local function sendNotInQueue(player)
	sendQueueUpdate(player, { inQueue = false })
end

local function takePlayersFromQueue(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end
	return taken
end

local function startMatch(modeId, players)
	if #players == 0 then
		return
	end

	GameMatchState.setArenaBusy(true)

	for _, player in players do
		sendNotInQueue(player)
		if callbacks.onMatchStarting then
			callbacks.onMatchStarting(player, modeId)
		end
	end

	Bindables.MatchReady:Fire(players, modeId)
end

local function tryStartPending()
	if GameMatchState.isArenaBusy() or #pendingMatches == 0 then
		return
	end

	local nextMatch = table.remove(pendingMatches, 1)
	startMatch(nextMatch.modeId, nextMatch.players)
	tryStartPending()
end

local function queueMatch(modeId, players)
	if GameMatchState.isArenaBusy() then
		table.insert(pendingMatches, { modeId = modeId, players = players })
		for _, player in players do
			sendQueueUpdate(player, buildQueuePayload(player, modeId, "pending"))
		end
		return
	end

	startMatch(modeId, players)
end

local function cancelFfaFill()
	ffaFillToken += 1
end

local function scheduleFfaFill()
	cancelFfaFill()
	ffaFillToken += 1
	local token = ffaFillToken
	local timeout = MatchmakingConfig.MODES.ffa.fillTimeout

	task.delay(timeout, function()
		if token ~= ffaFillToken then
			return
		end

		local queue = queues.ffa
		local config = MatchmakingConfig.MODES.ffa
		if #queue < config.minPlayers then
			return
		end

		local players = takePlayersFromQueue("ffa", config.maxPlayers)
		cancelFfaFill()
		queueMatch("ffa", players)
		broadcastQueueUpdates("ffa")
	end)
end

local function evaluateMode(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	if not config or #queue < config.minPlayers then
		return
	end

	if modeId == "ffa" then
		if #queue >= config.maxPlayers then
			cancelFfaFill()
			local players = takePlayersFromQueue("ffa", config.maxPlayers)
			queueMatch("ffa", players)
			broadcastQueueUpdates("ffa")
		else
			scheduleFfaFill()
		end
		return
	end

	local players = takePlayersFromQueue(modeId, config.maxPlayers)
	queueMatch(modeId, players)
	broadcastQueueUpdates(modeId)
end

local function evaluateAllModes()
	for modeId in MatchmakingConfig.MODES do
		evaluateMode(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not player or not player.Parent then
		return
	end

	modeId = modeId or getActiveModeId()
	if not getModeConfig(modeId) then
		modeId = getActiveModeId()
	end

	removePlayerFromQueues(player)

	local queue = queues[modeId]
	table.insert(queue, player)
	playerQueue[player] = modeId

	sendQueueUpdate(player, buildQueuePayload(player, modeId))
	broadcastQueueUpdates(modeId)
	evaluateMode(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		sendNotInQueue(player)
		return
	end

	local modeId = playerQueue[player]
	removePlayerFromQueues(player)

	if modeId == "ffa" then
		cancelFfaFill()
	end

	sendNotInQueue(player)
	broadcastQueueUpdates(modeId)
end

function MatchmakingService.getActiveModeId()
	return getActiveModeId()
end

function MatchmakingService.onArenaFree()
	GameMatchState.setArenaBusy(false)
	tryStartPending()
	evaluateAllModes()
end

function MatchmakingService.start(hubCallbacks)
	callbacks = hubCallbacks or {}
	ensureQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = nil
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)

		for i = #pendingMatches, 1, -1 do
			local match = pendingMatches[i]
			local stillValid = {}
			for _, queuedPlayer in match.players do
				if queuedPlayer ~= player and queuedPlayer.Parent then
					table.insert(stillValid, queuedPlayer)
				end
			end
			if #stillValid == 0 then
				table.remove(pendingMatches, i)
			else
				match.players = stillValid
			end
		end
	end)

	Bindables.ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)
end

function MatchmakingService.init(remotes, bindables)
	Remotes = remotes
	Bindables = bindables
end

return MatchmakingService
