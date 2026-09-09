local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local STATUS = {
	WAITING = "waiting",
	PENDING = "pending",
}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerEntry = {}
local remotes
local startMatchCallback

local function countQueue(modeId)
	return #queues[modeId]
end

local function buildPayload(player, entry)
	local mode = MatchmakingConfig.getMode(entry.modeId)
	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode and mode.label or entry.modeId,
		status = entry.status,
		queuedCount = countQueue(entry.modeId),
		requiredCount = mode and mode.minPlayers or 1,
	}
end

local function sendUpdate(player)
	if not remotes or not player.Parent then
		return
	end
	local entry = playerEntry[player]
	if entry then
		remotes.QueueUpdate:FireClient(player, buildPayload(player, entry))
	else
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function broadcastModeUpdates(modeId)
	for _, queuedPlayer in queues[modeId] do
		sendUpdate(queuedPlayer)
	end
end

local function removeFromQueueList(player, modeId)
	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			return
		end
	end
end

local function setEntryStatus(player, status)
	local entry = playerEntry[player]
	if entry then
		entry.status = status
		sendUpdate(player)
	end
end

local function refreshPendingStatuses()
	for modeId, queue in queues do
		local mode = MatchmakingConfig.getMode(modeId)
		if mode and #queue >= mode.minPlayers and MatchStateService.isBusy() then
			for index = 1, math.min(#queue, mode.minPlayers) do
				setEntryStatus(queue[index], STATUS.PENDING)
			end
			for index = mode.minPlayers + 1, #queue do
				setEntryStatus(queue[index], STATUS.WAITING)
			end
		end
	end
end

function MatchmakingService.configure(options)
	remotes = options.remotes
	startMatchCallback = options.onStartMatch
end

function MatchmakingService.leaveQueue(player)
	local entry = playerEntry[player]
	if not entry then
		sendUpdate(player)
		return
	end

	removeFromQueueList(player, entry.modeId)
	playerEntry[player] = nil
	sendUpdate(player)
	broadcastModeUpdates(entry.modeId)
	MatchmakingService.tryStartAll()
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchmakingConfig.isValidMode(modeId) then
		return false
	end
	if playerEntry[player] then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId], player)
	playerEntry[player] = {
		modeId = modeId,
		status = STATUS.WAITING,
	}

	sendUpdate(player)
	broadcastModeUpdates(modeId)
	MatchmakingService.tryStartMode(modeId)
	return true
end

function MatchmakingService.isQueued(player)
	return playerEntry[player] ~= nil
end

function MatchmakingService.getQueueMode(player)
	local entry = playerEntry[player]
	return entry and entry.modeId or nil
end

function MatchmakingService.tryStartAll()
	for modeId in MatchmakingConfig.MODES do
		MatchmakingService.tryStartMode(modeId)
	end
end

function MatchmakingService.tryStartMode(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = queues[modeId]
	if not mode or #queue < mode.minPlayers then
		return
	end

	if MatchStateService.isBusy() then
		refreshPendingStatuses()
		return
	end

	local players = {}
	for _ = 1, mode.minPlayers do
		table.insert(players, table.remove(queue, 1))
	end

	if modeId == "ffa" then
		while #queue > 0 and #players < mode.maxPlayers do
			table.insert(players, table.remove(queue, 1))
		end
	end

	for _, queuedPlayer in players do
		playerEntry[queuedPlayer] = nil
	end

	broadcastModeUpdates(modeId)
	task.delay(MatchmakingConfig.START_DELAY, function()
		if MatchStateService.isBusy() then
			for index = #players, 1, -1 do
				local queuedPlayer = players[index]
				if queuedPlayer.Parent then
					table.insert(queues[modeId], 1, queuedPlayer)
					playerEntry[queuedPlayer] = {
						modeId = modeId,
						status = STATUS.PENDING,
					}
				else
					table.remove(players, index)
				end
			end
			broadcastModeUpdates(modeId)
			return
		end

		local activePlayers = {}
		for _, queuedPlayer in players do
			if queuedPlayer.Parent then
				table.insert(activePlayers, queuedPlayer)
			end
		end

		if #activePlayers < mode.minPlayers then
			for _, queuedPlayer in activePlayers do
				table.insert(queues[modeId], queuedPlayer)
				playerEntry[queuedPlayer] = {
					modeId = modeId,
					status = STATUS.WAITING,
				}
			end
			broadcastModeUpdates(modeId)
			MatchmakingService.tryStartMode(modeId)
			return
		end

		if startMatchCallback then
			startMatchCallback(activePlayers, modeId)
		end
	end)
end

function MatchmakingService.onArenaIdle()
	refreshPendingStatuses()
	MatchmakingService.tryStartAll()
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

return MatchmakingService
