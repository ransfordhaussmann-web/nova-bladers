local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {}
local playerQueue = {}
local pendingMatch = nil
local pendingPlayers = {}
local started = false

local function getAutoModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function resolveModeId(modeId)
	if modeId == "auto" or modeId == nil then
		return getAutoModeId()
	end
	if MatchModes[modeId] then
		return modeId
	end
	return getAutoModeId()
end

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			fillDeadline = nil,
		}
	end
	return queues[modeId]
end

local function sanitizeQueue(queue)
	local valid = {}
	for _, player in queue.players do
		if player.Parent and playerQueue[player] then
			table.insert(valid, player)
		end
	end
	queue.players = valid
	return valid
end

local function buildQueuePayload(player, modeId, status)
	local mode = MatchModes[modeId]
	local queue = getQueue(modeId)
	local players = sanitizeQueue(queue)
	local fillSecondsLeft = nil
	if queue.fillDeadline then
		fillSecondsLeft = math.max(0, math.ceil(queue.fillDeadline - os.clock()))
	end

	return {
		status = status,
		modeId = modeId,
		modeLabel = mode.label,
		players = #players,
		required = mode.minPlayers,
		max = mode.maxPlayers,
		pending = MatchStateService.isBusy(),
		fillSecondsLeft = fillSecondsLeft,
		inQueue = playerQueue[player] == modeId,
	}
end

local function broadcastQueueUpdate()
	for _, player in Players:GetPlayers() do
		local modeId = playerQueue[player]
		if modeId then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, "waiting"))
		elseif pendingPlayers[player] then
			local pendingModeId = pendingPlayers[player]
			local mode = MatchModes[pendingModeId]
			Remotes.QueueUpdate:FireClient(player, {
				status = "pending",
				modeId = pendingModeId,
				modeLabel = mode.label,
				players = mode.minPlayers,
				required = mode.minPlayers,
				max = mode.maxPlayers,
				pending = true,
				inQueue = true,
			})
		end
	end
end

local function removePlayerFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = getQueue(modeId)
	for i, queued in queue.players do
		if queued == player then
			table.remove(queue.players, i)
			break
		end
	end

	if #queue.players < MatchModes[modeId].minPlayers then
		queue.fillDeadline = nil
	end

	broadcastQueueUpdate()
end

local function takePlayersForMatch(modeId)
	local mode = MatchModes[modeId]
	local queue = getQueue(modeId)
	local players = sanitizeQueue(queue)
	local matchPlayers = {}

	for i = 1, math.min(#players, mode.maxPlayers) do
		table.insert(matchPlayers, players[i])
	end

	queue.players = {}
	queue.fillDeadline = nil

	for _, player in matchPlayers do
		playerQueue[player] = nil
	end

	broadcastQueueUpdate()
	return matchPlayers
end

local function clearPendingPlayers(matchPlayers)
	for _, player in matchPlayers do
		pendingPlayers[player] = nil
	end
end

local function launchMatch(matchPlayers, modeId)
	if #matchPlayers == 0 then
		return
	end

	clearPendingPlayers(matchPlayers)
	MatchReady:Fire({
		players = matchPlayers,
		modeId = modeId,
	})
end

local function tryLaunchPending()
	if pendingMatch and not MatchStateService.isBusy() then
		local match = pendingMatch
		pendingMatch = nil
		launchMatch(match.players, match.modeId)
	end
end

local function queueMatch(matchPlayers, modeId)
	if MatchStateService.isBusy() then
		pendingMatch = {
			players = matchPlayers,
			modeId = modeId,
		}
		local mode = MatchModes[modeId]
		for _, player in matchPlayers do
			pendingPlayers[player] = modeId
			if player.Parent then
				Remotes.QueueUpdate:FireClient(player, {
					status = "pending",
					modeId = modeId,
					modeLabel = mode.label,
					players = #matchPlayers,
					required = mode.minPlayers,
					max = mode.maxPlayers,
					pending = true,
					inQueue = true,
				})
			end
		end
		return
	end

	launchMatch(matchPlayers, modeId)
end

local function tryStartMatch(modeId)
	local mode = MatchModes[modeId]
	local queue = getQueue(modeId)
	local players = sanitizeQueue(queue)

	if #players < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		if #players >= mode.maxPlayers then
			queueMatch(takePlayersForMatch(modeId), modeId)
			return
		end

		if not queue.fillDeadline then
			queue.fillDeadline = os.clock() + mode.fillTimeout
			broadcastQueueUpdate()
			return
		end

		if os.clock() < queue.fillDeadline then
			return
		end
	end

	queueMatch(takePlayersForMatch(modeId), modeId)
end

local function joinQueue(player, modeId)
	modeId = resolveModeId(modeId)

	if playerQueue[player] == modeId then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, "waiting"))
		return
	end

	removePlayerFromQueue(player)

	playerQueue[player] = modeId
	local queue = getQueue(modeId)
	table.insert(queue.players, player)

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, "waiting"))
	tryStartMatch(modeId)
	broadcastQueueUpdate()
end

local function tickQueues()
	for modeId in MatchModes do
		local queue = getQueue(modeId)
		if queue.fillDeadline and os.clock() >= queue.fillDeadline then
			tryStartMatch(modeId)
		end
	end
	tryLaunchPending()
end

function MatchmakingService.joinQueue(player, modeId)
	joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	removePlayerFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { status = "idle" })
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.start(onMatchReady)
	local remotes, bindables = RemotesSetup.ensure()
	Remotes = remotes
	MatchReady = bindables.MatchReady

	if onMatchReady then
		MatchReady.Event:Connect(onMatchReady)
	end

	if started then
		return
	end
	started = true

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = "auto"
		end
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removePlayerFromQueue(player)
		pendingPlayers[player] = nil
	end)

	MatchStateService.onArenaFree(function()
		tryLaunchPending()
		for modeId in MatchModes do
			tryStartMatch(modeId)
		end
	end)

	task.spawn(function()
		while true do
			tickQueues()
			task.wait(MatchmakingConfig.QUEUE_TICK)
		end
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
