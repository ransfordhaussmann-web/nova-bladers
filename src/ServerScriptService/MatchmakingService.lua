local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {}
local playerEntry = {}
local fillTokens = {}
local pendingStarts = {}

local remotes
local bindables
local hubCallbacks = {}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function queueCount(modeId)
	return #queues[modeId]
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	playerEntry[player] = nil

	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end
end

local function buildUpdatePayload(modeId, player)
	local mode = getMode(modeId)
	local count = queueCount(modeId)
	local status = "waiting"

	if MatchStateService.isBusy() and count >= mode.minPlayers then
		status = "pending"
	elseif count >= mode.maxPlayers then
		status = "full"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		inQueue = playerEntry[player] ~= nil,
	}
end

local function broadcastQueue(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, buildUpdatePayload(modeId, player))
		end
	end
end

local function leaveArenaPhase(player)
	if hubCallbacks.leaveQueuePhase then
		hubCallbacks.leaveQueuePhase(player)
	end
end

local function enterArenaPhase(player)
	if hubCallbacks.enterArenaPhase then
		hubCallbacks.enterArenaPhase(player)
	end
end

local function clearQueue(modeId)
	for _, player in queues[modeId] do
		playerEntry[player] = nil
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, {
				modeId = modeId,
				inQueue = false,
				status = "left",
			})
		end
	end
	queues[modeId] = {}
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function startMatch(modeId, playerList)
	clearQueue(modeId)
	pendingStarts[modeId] = nil

	for _, player in playerList do
		enterArenaPhase(player)
	end

	bindables.MatchReady:Fire({
		modeId = modeId,
		players = playerList,
	})
end

local function tryStartMatch(modeId)
	local mode = getMode(modeId)
	if not mode then
		return
	end

	local count = queueCount(modeId)
	if count < mode.minPlayers then
		return
	end

	if MatchStateService.isBusy() then
		pendingStarts[modeId] = true
		broadcastQueue(modeId)
		return
	end

	local playerList = {}
	for i = 1, math.min(count, mode.maxPlayers) do
		table.insert(playerList, queues[modeId][i])
	end

	startMatch(modeId, playerList)
end

local function scheduleFillTimeout(modeId)
	local mode = getMode(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if token ~= fillTokens[modeId] then
			return
		end
		if queueCount(modeId) >= mode.minPlayers then
			tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.init(deps)
	remotes = deps.remotes
	bindables = deps.bindables
	hubCallbacks = deps.hubCallbacks or {}

	MatchStateService.onIdle(function()
		for modeId, pending in pendingStarts do
			if pending and queueCount(modeId) >= getMode(modeId).minPlayers then
				tryStartMatch(modeId)
			end
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingConfig.DEFAULT_MODE
	end

	local mode = getMode(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerEntry[player] then
		MatchmakingService.leaveQueue(player)
	end

	if queueCount(modeId) >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queues[modeId], player)
	playerEntry[player] = {
		modeId = modeId,
		joinedAt = os.clock(),
	}

	remotes.QueueUpdate:FireClient(player, buildUpdatePayload(modeId, player))
	broadcastQueue(modeId)

	if queueCount(modeId) >= mode.minPlayers then
		if mode.minPlayers == mode.maxPlayers or queueCount(modeId) >= mode.maxPlayers then
			tryStartMatch(modeId)
		elseif mode.fillTimeout <= 0 then
			tryStartMatch(modeId)
		else
			scheduleFillTimeout(modeId)
		end
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	removeFromQueue(player)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	pendingStarts[modeId] = nil

	leaveArenaPhase(player)
	remotes.QueueUpdate:FireClient(player, {
		modeId = modeId,
		inQueue = false,
		status = "left",
	})
	broadcastQueue(modeId)
end

function MatchmakingService.handlePlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.getSuggestedMode(playerCount)
	if playerCount >= 3 then
		return "ffa"
	elseif playerCount == 2 then
		return "pvp"
	end
	return "training"
end

return MatchmakingService
