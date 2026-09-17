local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local MatchReadyBindable

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local queueJoinedAt = {}
local fillTimers = {}
local pendingMatch = nil
local started = false

local function getQueue(modeId)
	return queues[modeId]
end

local function countValidPlayers(modeId)
	local queue = getQueue(modeId)
	local count = 0
	for i = #queue, 1, -1 do
		local player = queue[i]
		if player.Parent then
			count += 1
		else
			table.remove(queue, i)
			playerQueue[player] = nil
			queueJoinedAt[player] = nil
		end
	end
	return count
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	local queue = getQueue(modeId)
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil
	queueJoinedAt[player] = nil
	return modeId
end

local function isPlayerPending(player)
	if not pendingMatch then
		return false
	end
	for _, pendingPlayer in pendingMatch.players do
		if pendingPlayer == player then
			return true
		end
	end
	return false
end

local function buildQueuePayload(modeId, player, status)
	local mode = MatchModes.get(modeId)
	local count = countValidPlayers(modeId)
	if pendingMatch and pendingMatch.modeId == modeId then
		count += #pendingMatch.players
	end
	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		playersWaiting = count,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 6,
		status = status or "waiting",
		inQueue = playerQueue[player] == modeId or isPlayerPending(player),
		arenaBusy = not MatchStateService.isArenaAvailable(),
	}
end

local function notifyPendingPlayers()
	if not pendingMatch then
		return
	end
	for _, player in pendingMatch.players do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(
				player,
				buildQueuePayload(pendingMatch.modeId, player, "pending")
			)
		end
	end
end

local function broadcastQueueUpdate(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if player.Parent then
			local status = "waiting"
			if pendingMatch and pendingMatch.modeId == modeId then
				status = "pending"
			end
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player, status))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function clearFillTimer(modeId)
	local timer = fillTimers[modeId]
	if timer then
		task.cancel(timer)
		fillTimers[modeId] = nil
	end
end

local function popPlayersForMatch(modeId, count)
	local queue = getQueue(modeId)
	local picked = {}
	local i = 1
	while #picked < count and i <= #queue do
		local player = queue[i]
		if player.Parent then
			table.insert(picked, player)
			table.remove(queue, i)
			playerQueue[player] = nil
			queueJoinedAt[player] = nil
		else
			table.remove(queue, i)
			playerQueue[player] = nil
			queueJoinedAt[player] = nil
		end
	end
	return picked
end

local function tryLaunchMatch(modeId, playerList)
	if #playerList == 0 then
		return false
	end

	if not MatchStateService.isArenaAvailable() then
		pendingMatch = {
			modeId = modeId,
			players = playerList,
		}
		notifyPendingPlayers()
		return false
	end

	clearFillTimer(modeId)
	pendingMatch = nil
	MatchReadyBindable:Fire(modeId, playerList)
	return true
end

local function evaluateQueue(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local count = countValidPlayers(modeId)
	if count == 0 then
		clearFillTimer(modeId)
		return
	end

	if count >= mode.maxPlayers then
		local players = popPlayersForMatch(modeId, mode.maxPlayers)
		tryLaunchMatch(modeId, players)
		broadcastQueueUpdate(modeId)
		return
	end

	if count >= mode.minPlayers then
		local players = popPlayersForMatch(modeId, count)
		tryLaunchMatch(modeId, players)
		broadcastQueueUpdate(modeId)
		return
	end

	if mode.fillTimeout and count >= (mode.fillMinPlayers or mode.minPlayers) then
		if not fillTimers[modeId] then
			fillTimers[modeId] = task.delay(mode.fillTimeout, function()
				fillTimers[modeId] = nil
				local currentCount = countValidPlayers(modeId)
				if currentCount >= (mode.fillMinPlayers or mode.minPlayers) then
					local players = popPlayersForMatch(modeId, currentCount)
					tryLaunchMatch(modeId, players)
				end
				broadcastQueueUpdate(modeId)
			end)
		end
	end
end

local function evaluateAllQueues()
	for modeId in queues do
		evaluateQueue(modeId)
	end
end

local function processPendingMatch()
	if not pendingMatch then
		return
	end
	if not MatchStateService.isArenaAvailable() then
		return
	end

	local match = pendingMatch
	pendingMatch = nil
	MatchReadyBindable:Fire(match.modeId, match.players)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return false, "invalid_mode"
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "unknown_mode"
	end

	if playerQueue[player] == modeId then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player, "waiting"))
		return true
	end

	removeFromQueue(player)

	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId
	queueJoinedAt[player] = os.clock()

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player, "waiting"))
	broadcastQueueUpdate(modeId)
	evaluateQueue(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local removedFromPending = false
	if pendingMatch then
		local nextPending = {}
		for _, pendingPlayer in pendingMatch.players do
			if pendingPlayer == player then
				removedFromPending = true
			elseif pendingPlayer.Parent then
				table.insert(nextPending, pendingPlayer)
			end
		end
		if removedFromPending then
			if #nextPending == 0 then
				pendingMatch = nil
			else
				pendingMatch.players = nextPending
			end
		end
	end

	local modeId = removeFromQueue(player)
	if not modeId and not removedFromPending then
		return false
	end

	if modeId then
		clearFillTimer(modeId)
		broadcastQueueUpdate(modeId)
		evaluateQueue(modeId)
	end

	Remotes.QueueUpdate:FireClient(player, {
		inQueue = false,
		status = "idle",
		modeId = modeId,
	})
	broadcastAllQueues()
	return true
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setMatchActive(false)
	task.defer(function()
		processPendingMatch()
		evaluateAllQueues()
		broadcastAllQueues()
	end)
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	local remotes, bindables = RemotesSetup.ensure()
	Remotes = remotes
	MatchReadyBindable = bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local modeId = removeFromQueue(player)
		if modeId then
			clearFillTimer(modeId)
			broadcastQueueUpdate(modeId)
			evaluateQueue(modeId)
		end
	end)

	MatchStateService.onArenaFree(function()
		processPendingMatch()
		evaluateAllQueues()
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
			evaluateAllQueues()
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
