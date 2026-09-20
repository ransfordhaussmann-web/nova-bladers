--[[
	MatchmakingService — per-mode queues with FFA fill timeout and arena-pending state.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local remotes
local bindables
local onMatchStarting
local getSuggestedMode

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local fillDeadlines = {}
local startingMatch = false
local started = false

local function getQueue(modeId)
	return queues[modeId]
end

local function isValidMode(modeId)
	return MatchModes.get(modeId) ~= nil
end

local function removeFromQueueList(queue, player)
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			return true
		end
	end
	return false
end

local function clearFillTimer(modeId)
	fillTimers[modeId] = nil
	fillDeadlines[modeId] = nil
end

local function queueContains(queue, player)
	for _, queuedPlayer in queue do
		if queuedPlayer == player then
			return true
		end
	end
	return false
end

local function getPlayerMode(player)
	local entry = playerQueue[player]
	if entry then
		return entry.modeId
	end
	return nil
end

local function buildStatus(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue
	local arenaBusy = MatchStateService.isBusy()

	local status = "waiting"
	if arenaBusy and count > 0 then
		status = "pending"
	end

	local playersNeeded = mode.minPlayers
	local fillTimeRemaining = nil
	if mode.fillTimeout and count >= mode.minPlayers and fillDeadlines[modeId] then
		fillTimeRemaining = math.max(0, fillDeadlines[modeId] - os.clock())
		if fillTimeRemaining <= 0 then
			status = arenaBusy and "pending" or "starting"
		end
	elseif count >= mode.maxPlayers then
		status = arenaBusy and "pending" or "starting"
	elseif count >= mode.minPlayers and not mode.fillTimeout then
		status = arenaBusy and "pending" or "starting"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		modeDesc = mode.desc,
		playersInQueue = count,
		playersNeeded = playersNeeded,
		maxPlayers = mode.maxPlayers,
		fillTimeRemaining = fillTimeRemaining,
		arenaBusy = arenaBusy,
		status = status,
	}
end

local function broadcastQueueUpdate()
	if not remotes then
		return
	end

	for _, player in Players:GetPlayers() do
		local modeId = getPlayerMode(player)
		if modeId then
			local payload = buildStatus(modeId)
			payload.inQueue = true
			remotes.QueueUpdate:FireClient(player, payload)
		else
			remotes.QueueUpdate:FireClient(player, { inQueue = false })
		end
	end
end

local function isQueueReady(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue

	if count < mode.minPlayers then
		return false
	end
	if count >= mode.maxPlayers then
		return true
	end
	if mode.fillTimeout then
		local deadline = fillDeadlines[modeId]
		return deadline ~= nil and os.clock() >= deadline
	end
	return count >= mode.minPlayers
end

local function takePlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = math.min(#queue, mode.maxPlayers)
	local matchPlayers = {}

	for _ = 1, count do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(matchPlayers, player)
			playerQueue[player] = nil
		end
	end

	clearFillTimer(modeId)
	return matchPlayers
end

local function maybeStartFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode.fillTimeout then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		clearFillTimer(modeId)
		return
	end

	if fillTimers[modeId] then
		return
	end

	local timeout = mode.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT
	fillDeadlines[modeId] = os.clock() + timeout
	fillTimers[modeId] = true

	task.delay(timeout, function()
		fillTimers[modeId] = nil
		broadcastQueueUpdate()
		MatchmakingService.processQueues()
	end)
end

local function startMatch(modeId, matchPlayers)
	if #matchPlayers == 0 then
		return
	end

	if onMatchStarting then
		onMatchStarting(matchPlayers, modeId)
	end

	if bindables and bindables.MatchReady then
		bindables.MatchReady:Fire(matchPlayers, modeId)
	end

	broadcastQueueUpdate()
end

function MatchmakingService.processQueues()
	if MatchStateService.isBusy() or startingMatch then
		broadcastQueueUpdate()
		return
	end

	local readyModes = {}
	for modeId in queues do
		if isQueueReady(modeId) then
			table.insert(readyModes, modeId)
		end
	end

	table.sort(readyModes, function(a, b)
		local qa = getQueue(a)
		local qb = getQueue(b)
		return #qa > #qb
	end)

	for _, modeId in readyModes do
		if MatchStateService.isBusy() then
			break
		end
		local matchPlayers = takePlayers(modeId)
		if #matchPlayers > 0 then
			startingMatch = true
			task.delay(MatchmakingConfig.START_DELAY, function()
				startingMatch = false
				if not MatchStateService.isBusy() then
					startMatch(modeId, matchPlayers)
				else
					for _, player in matchPlayers do
						if player.Parent then
							MatchmakingService.joinQueue(player, modeId)
						end
					end
				end
				MatchmakingService.processQueues()
			end)
			break
		end
	end

	broadcastQueueUpdate()
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false, "invalid_mode"
	end

	MatchmakingService.leaveQueue(player)

	local queue = getQueue(modeId)
	if queueContains(queue, player) then
		return false, "already_queued"
	end

	table.insert(queue, player)
	playerQueue[player] = {
		modeId = modeId,
		joinedAt = os.clock(),
	}

	maybeStartFillTimer(modeId)
	broadcastQueueUpdate()
	MatchmakingService.processQueues()
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = getPlayerMode(player)
	if not modeId then
		return false
	end

	removeFromQueueList(getQueue(modeId), player)
	playerQueue[player] = nil

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if mode.fillTimeout and #queue < mode.minPlayers then
		clearFillTimer(modeId)
	end

	broadcastQueueUpdate()
	return true
end

function MatchmakingService.getQueueStatus(modeId)
	if not isValidMode(modeId) then
		return nil
	end
	return buildStatus(modeId)
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.init(options)
	if started then
		return
	end
	started = true

	remotes = options.remotes
	bindables = options.bindables
	onMatchStarting = options.onMatchStarting
	getSuggestedMode = options.getSuggestedMode

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or modeId == "" then
			modeId = getSuggestedMode and getSuggestedMode() or "training"
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	if bindables.MatchEnded then
		bindables.MatchEnded.Event:Connect(function()
			task.defer(MatchmakingService.processQueues)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
