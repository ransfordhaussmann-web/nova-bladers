local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local remotes
local matchReadyEvent
local callbacks = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local started = false

local function getQueue(modeId)
	return queues[modeId]
end

local function isPlayerValid(player)
	return player and player.Parent ~= nil
end

local function removeFromQueueList(queue, player)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			return true
		end
	end
	return false
end

local function clearPlayerQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	removeFromQueueList(getQueue(entry.modeId), player)
	playerQueue[player] = nil
end

local function buildQueuePayload(player)
	local entry = playerQueue[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = MatchModes.get(entry.modeId)
	local queue = getQueue(entry.modeId)
	local status = "waiting"
	if MatchStateService.isBusy() then
		status = "pending"
	end

	local payload = {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode.label,
		status = status,
		playersInQueue = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
	}

	if entry.modeId == "ffa" and fillTimers.ffa then
		payload.fillTimeLeft = math.max(0, math.ceil(fillTimers.ffa.endsAt - os.clock()))
	end

	return payload
end

local function broadcastQueueUpdate(player)
	if not remotes or not isPlayerValid(player) then
		return
	end
	remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
end

local function broadcastQueueUpdates()
	for player in playerQueue do
		if isPlayerValid(player) then
			broadcastQueueUpdate(player)
		end
	end
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue

	if mode.instant then
		return count >= mode.minPlayers
	end

	if count >= mode.maxPlayers then
		return true
	end

	if count >= mode.minPlayers then
		if modeId == "ffa" and fillTimers.ffa then
			return os.clock() >= fillTimers.ffa.endsAt
		end
		if modeId ~= "ffa" then
			return true
		end
	end

	return false
end

local function startFillTimer(modeId)
	if modeId ~= "ffa" or fillTimers.ffa then
		return
	end

	fillTimers.ffa = {
		endsAt = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT,
	}
end

local function clearFillTimer(modeId)
	if modeId == "ffa" then
		fillTimers.ffa = nil
	end
end

local function takePlayersForMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = math.min(#queue, mode.maxPlayers)
	local roster = {}

	for i = 1, count do
		local player = queue[1]
		table.remove(queue, 1)
		if isPlayerValid(player) then
			table.insert(roster, player)
			playerQueue[player] = nil
		end
	end

	clearFillTimer(modeId)
	return roster
end

local function fireMatchReady(modeId, roster)
	if #roster == 0 then
		return
	end

	if callbacks.preparePlayersForMatch then
		callbacks.preparePlayersForMatch(roster, modeId)
	end

	matchReadyEvent:Fire({
		mode = modeId,
		players = roster,
	})
end

local function tryStartNextMatch()
	if MatchStateService.isBusy() then
		return
	end

	for _, mode in MatchModes.all() do
		local modeId = mode.id
		if canStartMode(modeId) then
			local roster = takePlayersForMatch(modeId)
			if #roster > 0 then
				fireMatchReady(modeId, roster)
				broadcastQueueUpdates()
				return
			end
		end
	end
end

function MatchmakingService.onArenaFree()
	MatchStateService.setBusy(false)
	broadcastQueueUpdates()
	tryStartNextMatch()
end

function MatchmakingService.joinQueue(player, modeId)
	if not started or not isPlayerValid(player) then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if callbacks.getPlayerPhase and callbacks.getPlayerPhase(player) ~= "hub" then
		return
	end

	clearPlayerQueue(player)

	local queue = getQueue(modeId)
	table.insert(queue, player)
	playerQueue[player] = { modeId = modeId }

	if modeId == "ffa" and #queue >= mode.minPlayers then
		startFillTimer(modeId)
	end

	broadcastQueueUpdate(player)
	broadcastQueueUpdates()
	tryStartNextMatch()
end

function MatchmakingService.leaveQueue(player)
	if not started or not playerQueue[player] then
		return
	end

	local modeId = playerQueue[player].modeId
	clearPlayerQueue(player)

	local queue = getQueue(modeId)
	if modeId == "ffa" and #queue < MatchModes.ffa.minPlayers then
		clearFillTimer(modeId)
	end

	broadcastQueueUpdate(player)
	broadcastQueueUpdates()
end

function MatchmakingService.getRecommendedMode()
	return MatchModes.recommendForPlayerCount(#Players:GetPlayers()).id
end

function MatchmakingService.start(remoteFolder, bindables, newCallbacks)
	if started then
		return
	end

	remotes = remoteFolder
	matchReadyEvent = bindables.MatchReady
	callbacks = newCallbacks or {}
	started = true

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getRecommendedMode()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while started do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			for modeId, timer in fillTimers do
				if timer and os.clock() >= timer.endsAt then
					tryStartNextMatch()
				end
			end
			broadcastQueueUpdates()
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
