local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local Bindables

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerEntry = {}
local fillTimers = {}
local fillTokens = {}

local function isValidPlayer(player)
	return player and player.Parent == Players
end

local function countActive(queue)
	local n = 0
	for _, player in queue do
		if isValidPlayer(player) then
			n += 1
		end
	end
	return n
end

local function compactQueue(modeId)
	local queue = queues[modeId]
	local compacted = {}
	for _, player in queue do
		if isValidPlayer(player) then
			table.insert(compacted, player)
		else
			playerEntry[player] = nil
		end
	end
	queues[modeId] = compacted
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local queue = queues[entry.modeId]
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end
	playerEntry[player] = nil
end

local function getQueueStatus(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end
	compactQueue(modeId)
	return {
		modeId = modeId,
		label = mode.label,
		count = countActive(queues[modeId]),
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
	}
end

local function buildPlayerUpdate(player)
	local entry = playerEntry[player]
	if not entry then
		return { inQueue = false }
	end

	local status = getQueueStatus(entry.modeId)
	local position = 0
	for i, queued in queues[entry.modeId] do
		if queued == player then
			position = i
			break
		end
	end

	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = status and status.label or entry.modeId,
		status = entry.status,
		position = position,
		queueCount = status and status.count or 0,
		minPlayers = status and status.minPlayers or 1,
		maxPlayers = status and status.maxPlayers or 1,
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function sendQueueUpdate(player)
	if not isValidPlayer(player) then
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildPlayerUpdate(player))
end

local function broadcastQueueUpdates()
	for player in playerEntry do
		if isValidPlayer(player) then
			sendQueueUpdate(player)
		end
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	fillTimers[modeId] = nil
end

local function takePlayers(modeId, count)
	compactQueue(modeId)
	local taken = {}
	local queue = queues[modeId]
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if isValidPlayer(player) then
			table.insert(taken, player)
			playerEntry[player] = nil
		end
	end
	return taken
end

local hubCallbacks

local function startMatch(modeId, players)
	if #players == 0 then
		return
	end

	cancelFillTimer(modeId)
	MatchStateService.setArenaBusy(true)

	for _, player in players do
		sendQueueUpdate(player)
	end
	broadcastQueueUpdates()

	local payload = {
		modeId = modeId,
		players = players,
	}

	if hubCallbacks and hubCallbacks.onMatchStarting then
		hubCallbacks.onMatchStarting(payload)
	end

	Bindables.MatchReady:Fire(payload)
end

local function shouldStartImmediately(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	compactQueue(modeId)
	local count = countActive(queues[modeId])
	if count < mode.minPlayers then
		return false
	end
	if count >= mode.maxPlayers then
		return true
	end
	if mode.fillTimeout == nil then
		return count >= mode.minPlayers
	end
	return false
end

local function scheduleFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout or fillTimers[modeId] then
		return
	end

	compactQueue(modeId)
	if countActive(queues[modeId]) < mode.minPlayers then
		return
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]
	fillTimers[modeId] = token

	task.delay(mode.fillTimeout, function()
		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil

		if MatchStateService.isArenaBusy() then
			return
		end

		compactQueue(modeId)
		local count = countActive(queues[modeId])
		if count >= mode.minPlayers then
			local players = takePlayers(modeId, math.min(count, mode.maxPlayers))
			startMatch(modeId, players)
		end
	end)
end

local function tryLaunchQueue(modeId)
	if MatchStateService.isArenaBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	compactQueue(modeId)
	local count = countActive(queues[modeId])

	if count >= mode.maxPlayers then
		local players = takePlayers(modeId, mode.maxPlayers)
		startMatch(modeId, players)
		return
	end

	if shouldStartImmediately(modeId) then
		local players = takePlayers(modeId, count)
		startMatch(modeId, players)
		return
	end

	if mode.fillTimeout and count >= mode.minPlayers then
		scheduleFillTimer(modeId)
	end
end

local function tryAllQueues()
	for modeId in queues do
		tryLaunchQueue(modeId)
	end
end

local function refreshEntryStatuses()
	local busy = MatchStateService.isArenaBusy()
	for player, entry in playerEntry do
		if not isValidPlayer(player) then
			playerEntry[player] = nil
		else
			entry.status = busy and "pending" or "waiting"
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidPlayer(player) then
		return false, "invalid_player"
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerEntry[player] then
		MatchmakingService.leaveQueue(player)
	end

	local status = if MatchStateService.isArenaBusy() then "pending" else "waiting"
	table.insert(queues[modeId], player)
	playerEntry[player] = {
		modeId = modeId,
		status = status,
	}

	sendQueueUpdate(player)
	broadcastQueueUpdates()

	if not MatchStateService.isArenaBusy() then
		tryLaunchQueue(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerEntry[player] then
		return false
	end

	local modeId = playerEntry[player].modeId
	removeFromQueue(player)

	compactQueue(modeId)
	if fillTimers[modeId] and countActive(queues[modeId]) < (MatchModes.get(modeId) and MatchModes.get(modeId).minPlayers or 2) then
		cancelFillTimer(modeId)
	end

	sendQueueUpdate(player)
	broadcastQueueUpdates()
	return true
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	refreshEntryStatuses()
	broadcastQueueUpdates()
	tryAllQueues()
end

function MatchmakingService.init(callbacks)
	Remotes, Bindables = RemotesSetup.ensure()
	hubCallbacks = callbacks

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			broadcastQueueUpdates()
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
