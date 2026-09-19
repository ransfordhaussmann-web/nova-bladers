local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local Bindables
local getPhase
local onMatchStarting

local queues = {}
local playerToMode = {}
local pendingMatch = nil
local fillTokens = {}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = { players = {} }
	end
	return queues[modeId]
end

local function getMode(modeId)
	return MatchModes[modeId]
end

local function isValidPlayer(player)
	return player and player.Parent and getPhase(player) == "hub"
end

local function indexOfPlayer(list, player)
	for i, queued in list do
		if queued == player then
			return i
		end
	end
	return nil
end

local function clearFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function buildQueuePayload(player, modeId, status)
	local queue = getQueue(modeId)
	local mode = getMode(modeId)
	local position = indexOfPlayer(queue.players, player) or 0
	local fillSecondsLeft = nil

	if queue.fillDeadline then
		fillSecondsLeft = math.max(0, math.ceil(queue.fillDeadline - os.clock()))
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		playersInQueue = #queue.players,
		playersNeeded = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status or "waiting",
		fillSecondsLeft = fillSecondsLeft,
	}
end

local function sendQueueUpdate(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueueUpdate(modeId, status)
	local queue = getQueue(modeId)
	for _, player in queue.players do
		sendQueueUpdate(player, buildQueuePayload(player, modeId, status))
	end
end

local function removePlayerFromQueue(player, silent)
	local modeId = playerToMode[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	local index = indexOfPlayer(queue.players, player)
	if index then
		table.remove(queue.players, index)
	end
	playerToMode[player] = nil

	if #queue.players < getMode(modeId).minPlayers then
		queue.fillDeadline = nil
		clearFillTimer(modeId)
	end

	if not silent then
		sendQueueUpdate(player, { inQueue = false })
		broadcastQueueUpdate(modeId)
	end
end

local function takePlayersFromQueue(modeId, count)
	local queue = getQueue(modeId)
	local taken = {}
	for _ = 1, math.min(count, #queue.players) do
		local player = table.remove(queue.players, 1)
		if player then
			playerToMode[player] = nil
			table.insert(taken, player)
		end
	end

	queue.fillDeadline = nil
	clearFillTimer(modeId)
	return taken
end

local function launchMatch(modeId, players)
	if #players == 0 then
		return
	end

	MatchStateService.setArenaBusy(true)

	for _, player in players do
		sendQueueUpdate(player, { inQueue = false, status = "starting" })
	end

	if onMatchStarting then
		onMatchStarting(players, modeId)
	end

	task.delay(MatchmakingConfig.START_DELAY, function()
		if Bindables.MatchReady then
			Bindables.MatchReady:Fire(players, modeId)
		end
	end)
end

local function tryStartQueue(modeId)
	local mode = getMode(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	local count = #queue.players
	if count < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		pendingMatch = {
			modeId = modeId,
			players = table.clone(queue.players),
		}
		broadcastQueueUpdate(modeId, "pending")
		return
	end

	local playerCount = math.min(count, mode.maxPlayers)
	launchMatch(modeId, takePlayersFromQueue(modeId, playerCount))
end

local function startFillTimer(modeId)
	local mode = getMode(modeId)
	if not mode or not mode.fillTimeout then
		tryStartQueue(modeId)
		return
	end

	local queue = getQueue(modeId)
	if queue.fillDeadline then
		return
	end

	queue.fillDeadline = os.clock() + mode.fillTimeout
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	broadcastQueueUpdate(modeId)

	task.spawn(function()
		while queue.fillDeadline and os.clock() < queue.fillDeadline do
			if fillTokens[modeId] ~= token then
				return
			end
			broadcastQueueUpdate(modeId)
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
		end

		if fillTokens[modeId] ~= token then
			return
		end

		if #queue.players >= mode.minPlayers then
			tryStartQueue(modeId)
		end
	end)
end

local function evaluateQueue(modeId)
	local mode = getMode(modeId)
	local queue = getQueue(modeId)
	local count = #queue.players

	if count >= mode.maxPlayers then
		tryStartQueue(modeId)
		return
	end

	if mode.id == "training" and count >= 1 then
		tryStartQueue(modeId)
		return
	end

	if mode.id == "pvp" and count >= 2 then
		tryStartQueue(modeId)
		return
	end

	if mode.id == "ffa" and count >= mode.minPlayers then
		startFillTimer(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidPlayer(player) then
		return false, "not_in_hub"
	end

	local mode = getMode(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if MatchStateService.isArenaBusy() and playerToMode[player] == modeId then
		return true
	end

	if playerToMode[player] then
		removePlayerFromQueue(player, true)
	end

	local queue = getQueue(modeId)
	if #queue.players >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue.players, player)
	playerToMode[player] = modeId
	broadcastQueueUpdate(modeId)
	evaluateQueue(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerToMode[player] then
		sendQueueUpdate(player, { inQueue = false })
		return
	end
	removePlayerFromQueue(player)
end

function MatchmakingService.getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)

	if pendingMatch then
		local pending = pendingMatch
		pendingMatch = nil

		local mode = getMode(pending.modeId)
		local validPlayers = {}
		for _, player in pending.players do
			removePlayerFromQueue(player, true)
			if isValidPlayer(player) then
				table.insert(validPlayers, player)
			end
		end

		if mode and #validPlayers >= mode.minPlayers then
			launchMatch(pending.modeId, validPlayers)
			return
		end
	end

	for modeId in MatchModes do
		evaluateQueue(modeId)
	end
end

function MatchmakingService.init(options)
	Remotes = options.remotes
	Bindables = options.bindables
	getPhase = options.getPhase
	onMatchStarting = options.onMatchStarting

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getRecommendedModeId()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removePlayerFromQueue(player, true)
	end)
end

return MatchmakingService
