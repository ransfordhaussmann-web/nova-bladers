local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local startingToken = 0
local running = false

local function getQueueList(modeId)
	return queues[modeId]
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local list = queues[entry.modeId]
	for i, p in list do
		if p == player then
			table.remove(list, i)
			break
		end
	end
	playerQueue[player] = nil
end

local function countValidPlayers(list)
	local count = 0
	for _, player in list do
		if player.Parent then
			count += 1
		end
	end
	return count
end

local function getValidPlayers(list, maxCount)
	local result = {}
	for _, player in list do
		if player.Parent and #result < maxCount then
			table.insert(result, player)
		end
	end
	return result
end

local function pruneQueues()
	for modeId, list in queues do
		for i = #list, 1, -1 do
			if not list[i].Parent then
				local removed = list[i]
				table.remove(list, i)
				playerQueue[removed] = nil
			end
		end
	end
end

local function buildQueuePayload(player, mode, status, extra)
	local list = getQueueList(mode.id)
	local count = countValidPlayers(list)
	return {
		inQueue = true,
		mode = mode.id,
		modeLabel = mode.label,
		players = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		secondsLeft = extra and extra.secondsLeft,
	}
end

local function sendQueueUpdate(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueueUpdate(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local list = getQueueList(modeId)
	local status = MatchStateService.isArenaBusy()
		and MatchmakingConfig.STATUS.PENDING
		or MatchmakingConfig.STATUS.WAITING

	if fillTimers[modeId] then
		status = MatchmakingConfig.STATUS.FILLING
	end

	local count = countValidPlayers(list)
	local secondsLeft
	if fillTimers[modeId] then
		secondsLeft = math.max(0, math.ceil(fillTimers[modeId].endsAt - os.clock()))
	end

	for _, player in list do
		if player.Parent then
			sendQueueUpdate(player, buildQueuePayload(player, mode, status, { secondsLeft = secondsLeft }))
		end
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end
end

local function clearQueue(modeId)
	queues[modeId] = {}
	for player, entry in playerQueue do
		if entry.modeId == modeId then
			playerQueue[player] = nil
		end
	end
	clearFillTimer(modeId)
end

local function leaveQueue(player)
	local entry = playerQueue[player]
	if not entry then
		sendQueueUpdate(player, { inQueue = false })
		return
	end

	local modeId = entry.modeId
	removeFromQueue(player)
	sendQueueUpdate(player, { inQueue = false })
	broadcastQueueUpdate(modeId)

	local mode = MatchModes.get(modeId)
	local list = getQueueList(modeId)
	if mode and countValidPlayers(list) < mode.minPlayers then
		clearFillTimer(modeId)
	end
end

local function markPlayersStarting(players, mode)
	for _, player in players do
		sendQueueUpdate(player, buildQueuePayload(player, mode, MatchmakingConfig.STATUS.STARTING))
	end
end

local function launchMatch(modeId, players)
	clearQueue(modeId)
	startingToken += 1
	local token = startingToken
	local mode = MatchModes.get(modeId)

	markPlayersStarting(players, mode)

	task.delay(MatchmakingConfig.STARTING_DELAY, function()
		if token ~= startingToken then
			return
		end

		for _, player in players do
			playerQueue[player] = nil
			sendQueueUpdate(player, { inQueue = false })
		end

		if MatchReady then
			MatchReady:Fire({
				players = players,
				mode = modeId,
			})
		end
	end)
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	pruneQueues()
	local mode = MatchModes.get(modeId)
	local list = getQueueList(modeId)
	local count = countValidPlayers(list)

	if count < mode.minPlayers then
		broadcastQueueUpdate(modeId)
		return
	end

	if modeId == "ffa" and fillTimers[modeId] then
		if count >= mode.maxPlayers or os.clock() >= fillTimers[modeId].endsAt then
			clearFillTimer(modeId)
			local players = getValidPlayers(list, mode.maxPlayers)
			launchMatch(modeId, players)
		else
			broadcastQueueUpdate(modeId)
		end
		return
	end

	if count >= mode.maxPlayers or (mode.fillTimeout == nil and count >= mode.minPlayers) then
		local players = getValidPlayers(list, mode.maxPlayers)
		launchMatch(modeId, players)
		return
	end

	broadcastQueueUpdate(modeId)
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout or fillTimers[modeId] then
		return
	end

	local timer = { cancelled = false, endsAt = os.clock() + mode.fillTimeout }
	fillTimers[modeId] = timer

	task.delay(mode.fillTimeout, function()
		if timer.cancelled or fillTimers[modeId] ~= timer then
			return
		end
		fillTimers[modeId] = nil
		tryStartMatch(modeId)
	end)
end

local function onQueueChanged(modeId)
	pruneQueues()
	local mode = MatchModes.get(modeId)
	local list = getQueueList(modeId)
	local count = countValidPlayers(list)

	if count < mode.minPlayers then
		clearFillTimer(modeId)
		broadcastQueueUpdate(modeId)
		return
	end

	if modeId == "ffa" and count >= mode.minPlayers and not fillTimers[modeId] then
		startFillTimer(modeId)
	end

	tryStartMatch(modeId)
end

local function joinQueue(player, modeId)
	if playerQueue[player] then
		leaveQueue(player)
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = { modeId = modeId }

	local status = MatchStateService.isArenaBusy()
		and MatchmakingConfig.STATUS.PENDING
		or MatchmakingConfig.STATUS.WAITING
	sendQueueUpdate(player, buildQueuePayload(player, mode, status))
	broadcastQueueUpdate(modeId)
	onQueueChanged(modeId)
	return true
end

local function joinQuickMatch(player)
	local count = #Players:GetPlayers()
	local mode = MatchModes.resolveQuickMatch(count)
	return joinQueue(player, mode.id)
end

local function processPendingQueues()
	for modeId, _ in queues do
		local mode = MatchModes.get(modeId)
		if mode and countValidPlayers(getQueueList(modeId)) >= mode.minPlayers then
			tryStartMatch(modeId)
		else
			broadcastQueueUpdate(modeId)
		end
	end
end

function MatchmakingService.start()
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	running = true

	MatchStateService.onArenaFree(processPendingQueues)

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, payload)
		if typeof(payload) ~= "table" then
			payload = {}
		end

		local modeId = payload.modeId
		if modeId == "quick" or modeId == nil then
			joinQuickMatch(player)
		else
			joinQueue(player, modeId)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local entry = playerQueue[player]
		if entry then
			removeFromQueue(player)
			broadcastQueueUpdate(entry.modeId)
		end
	end)
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

function MatchmakingService.joinQueue(player, modeId)
	return joinQueue(player, modeId)
end

function MatchmakingService.joinQuickMatch(player)
	return joinQuickMatch(player)
end

function MatchmakingService.isInQueue(player)
	return playerQueue[player] ~= nil
end

return MatchmakingService
