--[[
	MatchmakingService — per-mode queues with FFA fill timeout and arena-busy pending.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerEntry = {}
local arenaBusy = false
local onMatchReady = nil
local onQueueUpdate = nil

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			fillToken = 0,
			fillDeadline = nil,
		}
	end
	return queues[modeId]
end

local function isPlayerValid(player)
	return player and player.Parent ~= nil
end

local function removeFromQueueList(queue, player)
	for i, p in queue.players do
		if p == player then
			table.remove(queue.players, i)
			return true
		end
	end
	return false
end

local function countValidPlayers(queue)
	local count = 0
	for i = #queue.players, 1, -1 do
		if not isPlayerValid(queue.players[i]) then
			table.remove(queue.players, i)
		else
			count += 1
		end
	end
	return count
end

local function buildQueuePayload(player, modeId, status)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueue(modeId)
	local waiting = countValidPlayers(queue)

	local fillTimeLeft = nil
	if queue.fillDeadline then
		fillTimeLeft = math.max(0, math.ceil(queue.fillDeadline - os.clock()))
	end

	local statusText
	if status == "pending" then
		statusText = MatchmakingConfig.PENDING_STATUS_TEXT
	elseif modeId == "training" then
		statusText = "Starte Training..."
	elseif modeId == "pvp" then
		statusText = waiting >= mode.minPlayers
			and "Gegner gefunden — Start..."
			or string.format("Warte auf Gegner (%d/%d)", waiting, mode.maxPlayers)
	elseif modeId == "ffa" then
		if waiting < mode.minPlayers then
			statusText = string.format("Warte auf Spieler (%d/%d)", waiting, mode.minPlayers)
		elseif fillTimeLeft and fillTimeLeft > 0 then
			statusText = string.format("Lobby füllt sich (%d/%d) — %ds", waiting, mode.maxPlayers, fillTimeLeft)
		else
			statusText = string.format("Starte FFA (%d Spieler)", waiting)
		end
	else
		statusText = "In Warteschlange..."
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		waiting = waiting,
		required = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		statusText = statusText,
		fillTimeLeft = fillTimeLeft,
	}
end

local function notifyPlayer(player, payload)
	if onQueueUpdate and isPlayerValid(player) then
		onQueueUpdate(player, payload)
	end
end

local function notifyQueue(modeId)
	local queue = getQueue(modeId)
	for _, player in queue.players do
		if isPlayerValid(player) and playerEntry[player] then
			notifyPlayer(player, buildQueuePayload(player, modeId, playerEntry[player].status))
		end
	end
end

local function cancelFillTimer(queue)
	queue.fillToken += 1
	queue.fillDeadline = nil
end

local function startFillTimer(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode.fillTimeout then
		return
	end

	local queue = getQueue(modeId)
	if queue.fillDeadline then
		return
	end

	queue.fillToken += 1
	local token = queue.fillToken
	queue.fillDeadline = os.clock() + mode.fillTimeout

	task.delay(mode.fillTimeout, function()
		if token ~= queue.fillToken then
			return
		end
		queue.fillDeadline = nil
		MatchmakingService.processQueues()
	end)
end

local function takePlayersFromQueue(modeId, count)
	local queue = getQueue(modeId)
	local taken = {}
	local remaining = {}

	for _, player in queue.players do
		if isPlayerValid(player) and #taken < count then
			table.insert(taken, player)
		elseif isPlayerValid(player) then
			table.insert(remaining, player)
		end
	end

	queue.players = remaining
	cancelFillTimer(queue)
	return taken
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy then
		MatchmakingService.processQueues()
	end
end

function MatchmakingService.setCallbacks(callbacks)
	onMatchReady = callbacks.onMatchReady
	onQueueUpdate = callbacks.onQueueUpdate
end

function MatchmakingService.getPlayerMode(player)
	local entry = playerEntry[player]
	return entry and entry.modeId
end

function MatchmakingService.isInQueue(player)
	return playerEntry[player] ~= nil
end

function MatchmakingService.leaveQueue(player)
	local entry = playerEntry[player]
	if not entry then
		notifyPlayer(player, { inQueue = false })
		return
	end

	local queue = getQueue(entry.modeId)
	removeFromQueueList(queue, player)
	playerEntry[player] = nil

	if countValidPlayers(queue) < MatchmakingConfig.getMode(entry.modeId).minPlayers then
		cancelFillTimer(queue)
	end

	notifyPlayer(player, { inQueue = false })
	notifyQueue(entry.modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if not isPlayerValid(player) then
		return
	end

	if not MatchmakingConfig.MODES[modeId] then
		modeId = "training"
	end

	if playerEntry[player] then
		MatchmakingService.leaveQueue(player)
	end

	local queue = getQueue(modeId)
	table.insert(queue.players, player)
	playerEntry[player] = {
		modeId = modeId,
		status = "waiting",
	}

	notifyPlayer(player, buildQueuePayload(player, modeId, "waiting"))
	notifyQueue(modeId)
	MatchmakingService.processQueues()
end

function MatchmakingService.markPlayersMatched(players)
	for _, player in players do
		playerEntry[player] = nil
		notifyPlayer(player, { inQueue = false })
	end
end

local function canStartMode(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local waiting = countValidPlayers(getQueue(modeId))
	if waiting < mode.minPlayers then
		return false
	end
	if waiting >= mode.maxPlayers then
		return true
	end
	local queue = getQueue(modeId)
	if mode.fillTimeout and queue.fillDeadline then
		return os.clock() >= queue.fillDeadline
	end
	if mode.fillTimeout and not queue.fillDeadline then
		return false
	end
	return waiting >= mode.minPlayers
end

function MatchmakingService.processQueues()
	if not onMatchReady then
		return
	end

	if arenaBusy then
		for modeId in MatchmakingConfig.MODES do
			local queue = getQueue(modeId)
			local waiting = countValidPlayers(queue)
			if waiting == 0 then
				cancelFillTimer(queue)
				continue
			end

			local status = if canStartMode(modeId) then "pending" else "waiting"
			for _, player in queue.players do
				if playerEntry[player] then
					playerEntry[player].status = status
					notifyPlayer(player, buildQueuePayload(player, modeId, status))
				end
			end
		end
		return
	end

	local priority = { "training", "pvp", "ffa" }
	for _, modeId in priority do
		local mode = MatchmakingConfig.getMode(modeId)
		local queue = getQueue(modeId)
		local waiting = countValidPlayers(queue)

		if waiting == 0 then
			cancelFillTimer(queue)
			continue
		end

		if waiting >= mode.maxPlayers then
			local players = takePlayersFromQueue(modeId, mode.maxPlayers)
			if #players > 0 then
				onMatchReady(players, modeId)
				notifyQueue(modeId)
				return
			end
		end

		if waiting >= mode.minPlayers then
			if mode.fillTimeout then
				if not queue.fillDeadline then
					startFillTimer(modeId)
				end
				if queue.fillDeadline and os.clock() >= queue.fillDeadline then
					local players = takePlayersFromQueue(modeId, math.min(waiting, mode.maxPlayers))
					if #players > 0 then
						onMatchReady(players, modeId)
						notifyQueue(modeId)
						return
					end
				end
			else
				local players = takePlayersFromQueue(modeId, mode.maxPlayers)
				if #players > 0 then
					onMatchReady(players, modeId)
					notifyQueue(modeId)
					return
				end
			end
		end
	end
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

return MatchmakingService
