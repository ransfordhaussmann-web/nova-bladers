local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local arenaBusy = false
local pendingMatch = nil

local remotes = nil
local matchReadyBindable = nil
local hubGetPhase = nil

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			fillStartedAt = nil,
		}
	end
	return queues[modeId]
end

local function isPlayerValid(player)
	return player and player.Parent and hubGetPhase and hubGetPhase(player) == "hub"
end

local function pruneQueue(modeId)
	local queue = getQueue(modeId)
	local alive = {}
	for _, player in queue.players do
		if isPlayerValid(player) then
			table.insert(alive, player)
		else
			playerQueue[player] = nil
		end
	end
	queue.players = alive
	if #alive == 0 then
		queue.fillStartedAt = nil
	end
end

local function buildUpdatePayload(player, modeId, status)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueue(modeId)
	pruneQueue(modeId)

	local fillTimeLeft = nil
	if mode.fillTimeout and queue.fillStartedAt then
		fillTimeLeft = math.max(0, mode.fillTimeout - (os.clock() - queue.fillStartedAt))
	end

	return {
		inQueue = true,
		mode = modeId,
		modeLabel = mode.label,
		playersInQueue = #queue.players,
		playersNeeded = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status or "waiting",
		fillTimeLeft = fillTimeLeft,
	}
end

local function broadcastQueueUpdate(modeId, status)
	pruneQueue(modeId)
	local queue = getQueue(modeId)
	for _, player in queue.players do
		if remotes and remotes.QueueUpdate then
			remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player, modeId, status))
		end
	end
end

local function clearPlayerFromQueues(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	local nextPlayers = {}
	for _, queued in queue.players do
		if queued ~= player then
			table.insert(nextPlayers, queued)
		end
	end
	queue.players = nextPlayers
	if #nextPlayers == 0 then
		queue.fillStartedAt = nil
	end
	playerQueue[player] = nil

	if remotes and remotes.QueueUpdate then
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
	broadcastQueueUpdate(modeId)
end

local function canStartMatch(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueue(modeId)
	pruneQueue(modeId)

	if #queue.players < mode.minPlayers then
		return false
	end

	if #queue.players >= mode.maxPlayers then
		return true
	end

	if mode.fillTimeout and queue.fillStartedAt then
		return os.clock() - queue.fillStartedAt >= mode.fillTimeout
	end

	return #queue.players >= mode.minPlayers and not mode.fillTimeout
end

local function takeMatchPlayers(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueue(modeId)
	pruneQueue(modeId)

	local count = math.min(#queue.players, mode.maxPlayers)
	local matchPlayers = {}
	for i = 1, count do
		table.insert(matchPlayers, queue.players[i])
	end

	for _, player in matchPlayers do
		clearPlayerFromQueues(player)
	end

	queue.fillStartedAt = nil
	return matchPlayers
end

local function startPendingMatch()
	if not pendingMatch or arenaBusy then
		return
	end

	local players = pendingMatch.players
	local modeId = pendingMatch.modeId
	pendingMatch = nil

	for _, player in players do
		if remotes and remotes.QueueUpdate then
			remotes.QueueUpdate:FireClient(player, {
				inQueue = true,
				mode = modeId,
				modeLabel = MatchmakingConfig.getMode(modeId).label,
				status = "starting",
			})
		end
	end

	if matchReadyBindable then
		matchReadyBindable:Fire({
			players = players,
			mode = modeId,
		})
	end
end

local function tryFormMatch(modeId)
	if arenaBusy or pendingMatch then
		return
	end

	if not canStartMatch(modeId) then
		return
	end

	local players = takeMatchPlayers(modeId)
	if #players == 0 then
		return
	end

	if arenaBusy then
		pendingMatch = { players = players, modeId = modeId }
		for _, player in players do
			if remotes and remotes.QueueUpdate then
				remotes.QueueUpdate:FireClient(player, {
					inQueue = true,
					mode = modeId,
					modeLabel = MatchmakingConfig.getMode(modeId).label,
					playersInQueue = #players,
					status = "pending",
				})
			end
		end
		return
	end

	pendingMatch = { players = players, modeId = modeId }
	startPendingMatch()
end

local function tickQueues()
	for modeId, mode in MatchmakingConfig.MODES do
		local queue = getQueue(modeId)
		pruneQueue(modeId)

		if #queue.players >= mode.minPlayers and mode.fillTimeout and not queue.fillStartedAt then
			queue.fillStartedAt = os.clock()
			broadcastQueueUpdate(modeId)
		end

		tryFormMatch(modeId)
	end
end

function MatchmakingService.init(options)
	remotes = options.remotes
	matchReadyBindable = options.matchReadyBindable
	hubGetPhase = options.getPhase
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy then
		startPendingMatch()
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchmakingConfig.getMode(modeId) then
		return false, "invalid_mode"
	end
	if not isPlayerValid(player) then
		return false, "not_in_hub"
	end
	if playerQueue[player] then
		return false, "already_queued"
	end

	local queue = getQueue(modeId)
	table.insert(queue.players, player)
	playerQueue[player] = modeId

	local mode = MatchmakingConfig.getMode(modeId)
	if #queue.players >= mode.minPlayers and mode.fillTimeout then
		queue.fillStartedAt = os.clock()
	end

	broadcastQueueUpdate(modeId)
	tryFormMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end
	clearPlayerFromQueues(player)
	return true
end

function MatchmakingService.getRecommendedMode()
	local hubPlayers = 0
	for _, player in Players:GetPlayers() do
		if isPlayerValid(player) and not playerQueue[player] then
			hubPlayers += 1
		end
	end
	for _, modeId in playerQueue do
		hubPlayers += 1
	end
	return MatchmakingConfig.getRecommendedMode(hubPlayers)
end

function MatchmakingService.startTickLoop()
	task.spawn(function()
		while true do
			tickQueues()
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
		end
	end)
end

function MatchmakingService.onPlayerRemoving(player)
	clearPlayerFromQueues(player)
end

return MatchmakingService
