--[[
	MatchmakingService — queue state and match-start logic for Training / PvP / FFA.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerEntry = {}
local arenaBusy = false
local fillTimers = {}

local onQueueUpdateCallbacks = {}
local onMatchReadyCallbacks = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			order = {},
			fillStartedAt = nil,
		}
	end
	return queues[modeId]
end

local function cancelFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
	return token
end

local function getQueueCount(modeId)
	local queue = queues[modeId]
	return queue and #queue.order or 0
end

local function buildPlayerStatus(player)
	local entry = playerEntry[player]
	if not entry then
		return nil
	end

	local mode = getModeConfig(entry.modeId)
	local count = getQueueCount(entry.modeId)

	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode.label,
		status = entry.status,
		queueCount = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillTimeout = mode.fillTimeout,
		fillRemaining = entry.fillRemaining,
		arenaBusy = arenaBusy,
	}
end

local function notifyQueueUpdate(player, payload)
	local data = payload or buildPlayerStatus(player)
	if not data then
		return
	end
	for _, callback in onQueueUpdateCallbacks do
		callback(player, data)
	end
end

local function notifyAllQueued()
	for queuedPlayer in playerEntry do
		if queuedPlayer.Parent then
			notifyQueueUpdate(queuedPlayer)
		end
	end
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local queue = queues[entry.modeId]
	if queue then
		for i, queuedPlayer in queue.order do
			if queuedPlayer == player then
				table.remove(queue.order, i)
				break
			end
		end

		if #queue.order < getModeConfig(entry.modeId).minPlayers then
			queue.fillStartedAt = nil
			cancelFillTimer(entry.modeId)
		end

		if #queue.order == 0 then
			queues[entry.modeId] = nil
		end
	end

	playerEntry[player] = nil
end

local function popPlayers(modeId, count)
	local queue = ensureQueue(modeId)
	local picked = {}
	for _ = 1, math.min(count, #queue.order) do
		local player = table.remove(queue.order, 1)
		if player and player.Parent then
			table.insert(picked, player)
			playerEntry[player] = nil
		end
	end

	queue.fillStartedAt = nil
	cancelFillTimer(modeId)
	if #queue.order == 0 then
		queues[modeId] = nil
	end

	return picked
end

local function fireMatchReady(modeId, playerList)
	arenaBusy = true
	cancelFillTimer(modeId)

	local payload = {
		mode = modeId,
		players = playerList,
	}

	for _, callback in onMatchReadyCallbacks do
		callback(payload)
	end

	notifyAllQueued()
end

local function tryStartMatch(modeId)
	if arenaBusy then
		return false
	end

	local mode = getModeConfig(modeId)
	local queue = ensureQueue(modeId)
	local count = #queue.order

	if count < mode.minPlayers then
		return false
	end

	if count >= mode.maxPlayers then
		local players = popPlayers(modeId, mode.maxPlayers)
		if #players >= mode.minPlayers then
			fireMatchReady(modeId, players)
			return true
		end
		return false
	end

	if mode.fillTimeout and queue.fillStartedAt then
		local elapsed = os.clock() - queue.fillStartedAt
		if elapsed >= mode.fillTimeout then
			local players = popPlayers(modeId, count)
			if #players >= mode.minPlayers then
				fireMatchReady(modeId, players)
				return true
			end
		end
		return false
	end

	if not mode.fillTimeout and count >= mode.minPlayers then
		local players = popPlayers(modeId, mode.minPlayers)
		if #players >= mode.minPlayers then
			fireMatchReady(modeId, players)
			return true
		end
	end

	return false
end

local function scheduleFillTimer(modeId)
	local mode = getModeConfig(modeId)
	if not mode.fillTimeout then
		return
	end

	local queue = ensureQueue(modeId)
	if #queue.order < mode.minPlayers then
		return
	end

	if not queue.fillStartedAt then
		queue.fillStartedAt = os.clock()
	end

	local token = {}
	fillTimers[modeId] = token

	task.spawn(function()
		while fillTimers[modeId] == token do
			local entry = queues[modeId]
			if not entry or #entry.order < mode.minPlayers then
				break
			end

			local remaining = mode.fillTimeout - (os.clock() - entry.fillStartedAt)
			for player, data in playerEntry do
				if data.modeId == modeId then
					data.fillRemaining = math.max(0, math.ceil(remaining))
					data.status = arenaBusy and "pending" or "waiting"
					notifyQueueUpdate(player)
				end
			end

			if remaining <= 0 then
				tryStartMatch(modeId)
				break
			end

			task.wait(0.25)
		end

		if fillTimers[modeId] == token then
			fillTimers[modeId] = nil
		end
	end)
end

local function refreshEntryStatus(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	if arenaBusy then
		entry.status = "pending"
	else
		entry.status = "waiting"
	end
end

function MatchmakingService.onQueueUpdate(callback)
	table.insert(onQueueUpdateCallbacks, callback)
end

function MatchmakingService.onMatchReady(callback)
	table.insert(onMatchReadyCallbacks, callback)
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	for player in playerEntry do
		refreshEntryStatus(player)
		notifyQueueUpdate(player)
	end

	if not busy then
		for modeId in MatchmakingConfig.MODES do
			tryStartMatch(modeId)
			scheduleFillTimer(modeId)
		end
	end
end

function MatchmakingService.getPlayerStatus(player)
	return buildPlayerStatus(player)
end

function MatchmakingService.leave(player)
	if not playerEntry[player] then
		return false
	end

	removeFromQueue(player)
	notifyQueueUpdate(player, { inQueue = false })
	notifyAllQueued()
	return true
end

function MatchmakingService.join(player, modeId)
	if not isValidMode(modeId) then
		return false, "invalid_mode"
	end

	if playerEntry[player] then
		MatchmakingService.leave(player)
	end

	local queue = ensureQueue(modeId)
	if #queue.order >= getModeConfig(modeId).maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue.order, player)
	playerEntry[player] = {
		modeId = modeId,
		status = arenaBusy and "pending" or "waiting",
		fillRemaining = nil,
	}

	notifyQueueUpdate(player)
	notifyAllQueued()

	if not arenaBusy then
		if tryStartMatch(modeId) then
			return true
		end
		scheduleFillTimer(modeId)
	end

	return true
end

function MatchmakingService.resolveAutoMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.resolvePortalMode()
	if MatchmakingConfig.PORTAL_MODE == "auto" then
		return MatchmakingService.resolveAutoMode()
	end
	return MatchmakingConfig.DEFAULT_MODE
end

Players.PlayerRemoving:Connect(function(player)
	if playerEntry[player] then
		removeFromQueue(player)
		notifyAllQueued()
	end
end)

return MatchmakingService
