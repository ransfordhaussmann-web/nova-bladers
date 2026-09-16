local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerEntry = {}
local fillTimers = {}
local fillDeadlines = {}
local pendingStarts = {}

local function getSuggestedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function resolveModeId(modeId)
	if modeId == MatchmakingConfig.AUTO_MODE_ID then
		return getSuggestedModeId()
	end
	if MatchModes.get(modeId) then
		return modeId
	end
	return getSuggestedModeId()
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local queue = queues[entry.modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	playerEntry[player] = nil
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local deadline = fillDeadlines[modeId]
	local secondsLeft = nil
	if deadline then
		secondsLeft = math.max(0, math.ceil(deadline - os.clock()))
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		queued = #queue,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = MatchStateService.isBusy() and "pending" or "waiting",
		fillSecondsLeft = secondsLeft,
		inQueue = playerEntry[player] ~= nil,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = queues[modeId]
	for _, player in queue do
		if player.Parent then
			QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function clearFillTimer(modeId)
	fillTimers[modeId] = nil
	fillDeadlines[modeId] = nil
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerEntry[player] = nil
			table.insert(picked, player)
		end
	end
	return picked
end

local function launchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	clearFillTimer(modeId)
	pendingStarts[modeId] = nil
	MatchStateService.setBusy(true)

	for _, player in playerList do
		QueueUpdate:FireClient(player, {
			modeId = modeId,
			modeLabel = MatchModes.get(modeId).label,
			status = "starting",
			queued = 0,
			needed = MatchModes.get(modeId).minPlayers,
			maxPlayers = MatchModes.get(modeId).maxPlayers,
			inQueue = false,
		})
	end

	MatchReady:Fire(playerList, modeId)
end

local function tryStartMatch(modeId, forceStart)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return
	end

	if MatchStateService.isBusy() then
		pendingStarts[modeId] = true
		broadcastQueueUpdate(modeId)
		return
	end

	if #queue >= mode.maxPlayers then
		launchMatch(modeId, popPlayers(modeId, mode.maxPlayers))
		return
	end

	if mode.fillTimeout > 0 and not forceStart then
		if not fillTimers[modeId] and #queue >= mode.minPlayers then
			fillDeadlines[modeId] = os.clock() + mode.fillTimeout
			fillTimers[modeId] = task.delay(mode.fillTimeout, function()
				fillTimers[modeId] = nil
				fillDeadlines[modeId] = nil
				if #queues[modeId] >= mode.minPlayers then
					tryStartMatch(modeId, true)
				end
			end)
			broadcastQueueUpdate(modeId)
		end
		return
	end

	launchMatch(modeId, popPlayers(modeId, math.min(#queue, mode.maxPlayers)))
end

local function joinQueue(player, requestedModeId)
	if playerEntry[player] then
		return
	end

	local modeId = resolveModeId(requestedModeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = queues[modeId]
	if #queue >= mode.maxPlayers then
		return
	end

	table.insert(queue, player)
	playerEntry[player] = {
		modeId = modeId,
		joinedAt = os.clock(),
	}

	broadcastQueueUpdate(modeId)
	tryStartMatch(modeId)
end

local function leaveQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	removeFromQueue(player)

	local mode = MatchModes.get(modeId)
	if mode and #queues[modeId] < mode.minPlayers then
		if fillTimers[modeId] then
			task.cancel(fillTimers[modeId])
			clearFillTimer(modeId)
		end
	end

	broadcastQueueUpdate(modeId)
	QueueUpdate:FireClient(player, {
		status = "left",
		inQueue = false,
	})
end

function MatchmakingService.join(player, modeId)
	joinQueue(player, modeId or MatchmakingConfig.AUTO_MODE_ID)
end

function MatchmakingService.leave(player)
	leaveQueue(player)
end

function MatchmakingService.getSuggestedModeId()
	return getSuggestedModeId()
end

function MatchmakingService.start()
	QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingConfig.AUTO_MODE_ID
		end
		joinQueue(player, modeId)
	end)

	QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		leaveQueue(player)
	end)

	MatchStateService.onArenaIdle(function()
		for modeId, pending in pairs(pendingStarts) do
			if pending then
				pendingStarts[modeId] = nil
				tryStartMatch(modeId)
			end
		end

		for modeId in pairs(queues) do
			if #queues[modeId] > 0 then
				tryStartMatch(modeId)
			end
		end
	end)
end

return MatchmakingService
