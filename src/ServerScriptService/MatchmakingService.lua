--[[
	MatchmakingService — per-mode queues with fill timeout and pending state when arena is busy.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimerTokens = {}
local callbacks = {}
local remotes = nil

local function getQueue(modeId)
	return queues[modeId]
end

local function findQueueIndex(modeId, player)
	local queue = getQueue(modeId)
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			return index
		end
	end
	return nil
end

local function buildQueuePayload(player)
	local info = playerQueue[player]
	if not info then
		return nil
	end

	local mode = MatchModes.get(info.modeId)
	local queue = getQueue(info.modeId)
	local count = #queue
	local position = findQueueIndex(info.modeId, player) or count
	local status = "waiting"

	if count >= mode.minPlayers then
		if MatchStateService.isBusy() then
			status = "pending"
		elseif mode.fillTimeout and count < mode.maxPlayers then
			status = "filling"
		else
			status = "ready"
		end
	end

	return {
		modeId = info.modeId,
		modeLabel = mode.label,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		position = position,
		status = status,
		arenaBusy = MatchStateService.isBusy(),
	}
end

local function sendQueueUpdate(player)
	if not remotes or not player.Parent then
		return
	end
	local payload = buildQueuePayload(player)
	if payload then
		remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueueUpdates()
	for player in playerQueue do
		sendQueueUpdate(player)
	end
end

local function removeFromQueue(player)
	local info = playerQueue[player]
	if not info then
		return
	end

	local index = findQueueIndex(info.modeId, player)
	if index then
		table.remove(getQueue(info.modeId), index)
	end
	playerQueue[player] = nil
end

local function takePlayersFromQueue(modeId, count)
	local queue = getQueue(modeId)
	local taken = {}
	local amount = math.min(count, #queue)

	for _ = 1, amount do
		local player = table.remove(queue, 1)
		if player then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end

	return taken
end

local function launchMatch(modeId)
	if MatchStateService.isBusy() then
		return false
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return false
	end

	local playerCount = math.min(#queue, mode.maxPlayers)
	local matchedPlayers = takePlayersFromQueue(modeId, playerCount)
	if #matchedPlayers < mode.minPlayers then
		for _, player in matchedPlayers do
			table.insert(queue, player)
			playerQueue[player] = { modeId = modeId, joinedAt = os.clock() }
		end
		return false
	end

	MatchStateService.setBusy(true)
	fillTimerTokens[modeId] = nil

	if callbacks.onMatchReady then
		callbacks.onMatchReady(modeId, matchedPlayers)
	end

	broadcastQueueUpdates()
	return true
end

function MatchmakingService.cancelMatchStart(modeId, players)
	MatchStateService.setBusy(false)

	if typeof(modeId) == "string" and typeof(players) == "table" then
		for _, player in players do
			if player.Parent and not playerQueue[player] then
				table.insert(getQueue(modeId), player)
				playerQueue[player] = {
					modeId = modeId,
					joinedAt = os.clock(),
				}
			end
		end
	end

	broadcastQueueUpdates()
	evaluateAllQueues()
end

local function scheduleFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode.fillTimeout then
		launchMatch(modeId)
		return
	end

	fillTimerTokens[modeId] = (fillTimerTokens[modeId] or 0) + 1
	local token = fillTimerTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if fillTimerTokens[modeId] ~= token then
			return
		end
		launchMatch(modeId)
	end)
end

local function evaluateQueue(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue

	if count < mode.minPlayers then
		return
	end

	if count >= mode.maxPlayers then
		launchMatch(modeId)
		return
	end

	if mode.fillTimeout then
		if count == mode.minPlayers and not fillTimerTokens[modeId] then
			scheduleFillTimer(modeId)
		end
		if MatchStateService.isBusy() then
			broadcastQueueUpdates()
			return
		end
		return
	end

	launchMatch(modeId)
end

local function evaluateAllQueues()
	for _, mode in MatchModes.all() do
		evaluateQueue(mode.id)
	end
end

function MatchmakingService.init(options)
	callbacks = options or {}
	remotes = callbacks.remotes
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return false
	end
	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(getQueue(modeId), player)
	playerQueue[player] = {
		modeId = modeId,
		joinedAt = os.clock(),
	}

	if callbacks.onPlayerQueued then
		callbacks.onPlayerQueued(player, modeId)
	end

	sendQueueUpdate(player)
	evaluateQueue(modeId)
	broadcastQueueUpdates()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end

	local modeId = playerQueue[player].modeId
	removeFromQueue(player)

	local queue = getQueue(modeId)
	if #queue < MatchModes.get(modeId).minPlayers then
		fillTimerTokens[modeId] = nil
	end

	if callbacks.onPlayerLeftQueue then
		callbacks.onPlayerLeftQueue(player)
	end

	broadcastQueueUpdates()
	return true
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getQueueMode(player)
	local info = playerQueue[player]
	return info and info.modeId
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setBusy(false)
	task.defer(evaluateAllQueues)
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

return MatchmakingService
