local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local arenaBusy = false
local pendingMatch = nil
local fillTimers = {}
local onMatchReady = nil
local onQueueUpdate = nil
local canStartMatch = nil

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isPlayerInQueue(player)
	return playerQueue[player] ~= nil
end

local function removeFromQueueList(player, modeId)
	local queue = queues[modeId]
	for i, p in queue do
		if p == player then
			table.remove(queue, i)
			return
		end
	end
end

local function cancelFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
end

local function buildQueuePayload(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	local names = {}
	for _, player in queue do
		if player.Parent then
			table.insert(names, player.Name)
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = names,
		count = #names,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		arenaBusy = arenaBusy,
		pending = arenaBusy and #names >= mode.minPlayers,
	}
end

local function broadcastQueue(modeId)
	if onQueueUpdate then
		local payload = buildQueuePayload(modeId)
		for _, player in queues[modeId] do
			if player.Parent then
				onQueueUpdate(player, payload)
			end
		end
	end
end

local function tryStartMatch(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]

	local active = {}
	for _, player in queue do
		if player.Parent then
			table.insert(active, player)
		end
	end

	if #active < mode.minPlayers then
		return
	end

	local matchPlayers = {}
	for i = 1, math.min(#active, mode.maxPlayers) do
		table.insert(matchPlayers, active[i])
	end

	for _, player in matchPlayers do
		removeFromQueueList(player, modeId)
		playerQueue[player] = nil
	end

	cancelFillTimer(modeId)
	broadcastQueue(modeId)

	local blocked = arenaBusy or (canStartMatch and not canStartMatch())
	if blocked then
		pendingMatch = {
			modeId = modeId,
			players = matchPlayers,
		}
		for _, player in matchPlayers do
			if player.Parent and onQueueUpdate then
				onQueueUpdate(player, {
					modeId = modeId,
					modeLabel = mode.label,
					players = {},
					count = 0,
					minPlayers = mode.minPlayers,
					maxPlayers = mode.maxPlayers,
					arenaBusy = true,
					pending = true,
				})
			end
		end
		return
	end

	if onMatchReady then
		onMatchReady(matchPlayers, modeId)
	end
end

local function scheduleFillTimeout(modeId)
	local mode = getMode(modeId)
	if mode.fillTimeout <= 0 then
		return
	end

	cancelFillTimer(modeId)
	local token = {}
	fillTimers[modeId] = token

	task.delay(mode.fillTimeout, function()
		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil

		local queue = queues[modeId]
		if #queue >= mode.minPlayers and #queue < mode.maxPlayers then
			tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.setCallbacks(callbacks)
	onMatchReady = callbacks.onMatchReady
	onQueueUpdate = callbacks.onQueueUpdate
	canStartMatch = callbacks.canStartMatch
end

function MatchmakingService.joinQueue(player, modeId)
	if not getMode(modeId) then
		return false, "invalid_mode"
	end
	if arenaBusy and isPlayerInQueue(player) then
		return false, "already_queued"
	end

	MatchmakingService.leaveQueue(player)

	local queue = queues[modeId]
	table.insert(queue, player)
	playerQueue[player] = modeId
	broadcastQueue(modeId)

	local mode = getMode(modeId)
	if #queue >= mode.maxPlayers then
		tryStartMatch(modeId)
	elseif #queue >= mode.minPlayers then
		if mode.fillTimeout <= 0 or #queue == mode.minPlayers then
			tryStartMatch(modeId)
		else
			scheduleFillTimeout(modeId)
		end
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueueList(player, modeId)
	playerQueue[player] = nil
	cancelFillTimer(modeId)
	broadcastQueue(modeId)
end

function MatchmakingService.getPlayerQueue(player)
	return playerQueue[player]
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy and pendingMatch then
		local match = pendingMatch
		pendingMatch = nil
		if onMatchReady then
			onMatchReady(match.players, match.modeId)
		end
	end
end

function MatchmakingService.confirmMatchStarted()
	arenaBusy = true
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)

	if pendingMatch then
		for i, p in pendingMatch.players do
			if p == player then
				table.remove(pendingMatch.players, i)
				break
			end
		end
		if #pendingMatch.players < getMode(pendingMatch.modeId).minPlayers then
			for _, p in pendingMatch.players do
				if p.Parent and onQueueUpdate then
					onQueueUpdate(p, {
						modeId = pendingMatch.modeId,
						pending = false,
						arenaBusy = arenaBusy,
						cancelled = true,
					})
				end
			end
			pendingMatch = nil
		end
	end
end

return MatchmakingService
