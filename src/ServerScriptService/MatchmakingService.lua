local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local arenaBusy = false
local remotes = nil
local onMatchReady = nil

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			fillDeadline = nil,
			fillToken = 0,
		}
	end
	return queues[modeId]
end

local function countPlayers(queue)
	return #queue.players
end

local function removeFromQueueList(queue, player)
	for i, p in queue.players do
		if p == player then
			table.remove(queue.players, i)
			return true
		end
	end
	return false
end

local function buildUpdatePayload(player, modeId, status)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueue(modeId)
	local count = countPlayers(queue)
	return {
		status = status,
		modeId = modeId,
		modeLabel = mode.label,
		players = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		arenaBusy = arenaBusy,
	}
end

local function broadcastQueueUpdate(modeId)
	if not remotes then
		return
	end
	local queue = getQueue(modeId)
	for _, player in queue.players do
		if player.Parent then
			local status = arenaBusy and "pending" or "waiting"
			remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player, modeId, status))
		end
	end
end

local function cancelFillTimer(queue)
	queue.fillDeadline = nil
	queue.fillToken += 1
end

local function canStartMode(mode, count)
	if count < mode.minPlayers or count > mode.maxPlayers then
		return false
	end
	if mode.instant then
		return count >= mode.minPlayers
	end
	if count >= mode.maxPlayers then
		return true
	end
	if mode.fillTimeout then
		local queue = getQueue(mode.id)
		if queue.fillDeadline and os.clock() >= queue.fillDeadline then
			return count >= mode.minPlayers
		end
	end
	return false
end

local function startFillTimer(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if mode.instant or not mode.fillTimeout then
		return
	end

	local queue = getQueue(modeId)
	if queue.fillDeadline then
		return
	end

	queue.fillToken += 1
	local token = queue.fillToken
	queue.fillDeadline = os.clock() + mode.fillTimeout

	task.delay(mode.fillTimeout, function()
		if token ~= queue.fillToken then
			return
		end
		MatchmakingService.tryStartMatch(modeId)
	end)
end

function MatchmakingService.setRemotes(remoteFolder)
	remotes = remoteFolder
end

function MatchmakingService.setMatchReadyCallback(callback)
	onMatchReady = callback
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	for modeId, _ in MatchmakingConfig.MODES do
		broadcastQueueUpdate(modeId)
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = getQueue(modeId)
	removeFromQueueList(queue, player)

	if countPlayers(queue) < MatchmakingConfig.getMode(modeId).minPlayers then
		cancelFillTimer(queue)
	end

	if remotes and player.Parent then
		remotes.QueueUpdate:FireClient(player, {
			status = "idle",
			modeId = nil,
		})
	end

	broadcastQueueUpdate(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if arenaBusy then
		-- Still allow joining; players wait in pending state until arena frees.
	end

	if not MatchmakingConfig.MODES[modeId] then
		modeId = MatchmakingConfig.DEFAULT_MODE
	end

	if playerQueue[player] == modeId then
		return
	end

	MatchmakingService.leaveQueue(player)

	local queue = getQueue(modeId)
	if countPlayers(queue) >= MatchmakingConfig.getMode(modeId).maxPlayers then
		if remotes then
			remotes.QueueUpdate:FireClient(player, {
				status = "full",
				modeId = modeId,
				modeLabel = MatchmakingConfig.getMode(modeId).label,
			})
		end
		return
	end

	table.insert(queue.players, player)
	playerQueue[player] = modeId

	local status = arenaBusy and "pending" or "waiting"
	if remotes then
		remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player, modeId, status))
	end
	broadcastQueueUpdate(modeId)

	startFillTimer(modeId)
	MatchmakingService.tryStartMatch(modeId)
end

function MatchmakingService.tryStartMatch(modeId)
	if arenaBusy then
		return
	end

	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueue(modeId)
	local count = countPlayers(queue)

	if not canStartMode(mode, count) then
		return
	end

	local matchPlayers = {}
	for i = 1, math.min(count, mode.maxPlayers) do
		table.insert(matchPlayers, queue.players[i])
	end

	if #matchPlayers < mode.minPlayers then
		return
	end

	cancelFillTimer(queue)

	for _, p in matchPlayers do
		playerQueue[p] = nil
		removeFromQueueList(queue, p)
		if remotes and p.Parent then
			remotes.QueueUpdate:FireClient(p, {
				status = "starting",
				modeId = modeId,
				modeLabel = mode.label,
			})
		end
	end

	arenaBusy = true
	broadcastQueueUpdate(modeId)

	if onMatchReady then
		onMatchReady(matchPlayers, modeId)
	end
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.onMatchEnded()
	arenaBusy = false
	for modeId, _ in MatchmakingConfig.MODES do
		broadcastQueueUpdate(modeId)
		MatchmakingService.tryStartMatch(modeId)
	end
end

return MatchmakingService
