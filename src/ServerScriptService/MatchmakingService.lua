local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local arenaBusy = false
local deps = nil

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function buildQueuePayload(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	local count = queue and #queue.players or 0
	local status = "open"
	if arenaBusy then
		status = "pending"
	elseif count >= mode.minPlayers and mode.fillTimeout > 0 and queue.fillDeadline then
		status = "filling"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillSecondsLeft = queue and queue.fillSecondsLeft or nil,
	}
end

local function notifyPlayer(player, payload)
	if player.Parent and deps and deps.remotes then
		deps.remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function notifyQueue(modeId)
	local payload = buildQueuePayload(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end
	for _, queuedPlayer in queue.players do
		if queuedPlayer.Parent then
			notifyPlayer(queuedPlayer, payload)
		end
	end
end

local function removeFromQueue(player, silent)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	local queue = queues[modeId]
	playerQueue[player] = nil

	if queue then
		for index, queuedPlayer in queue.players do
			if queuedPlayer == player then
				table.remove(queue.players, index)
				break
			end
		end

		if queue.fillTask then
			task.cancel(queue.fillTask)
			queue.fillTask = nil
		end
		queue.fillDeadline = nil
		queue.fillSecondsLeft = nil

		if not silent then
			notifyQueue(modeId)
		end
	end

	return modeId
end

local function pullPlayers(modeId, amount)
	local queue = queues[modeId]
	local pulled = {}
	for _ = 1, amount do
		local nextPlayer = table.remove(queue.players, 1)
		if not nextPlayer then
			break
		end
		playerQueue[nextPlayer] = nil
		table.insert(pulled, nextPlayer)
	end
	return pulled
end

local function startMatch(modeId, players)
	arenaBusy = true
	if deps and deps.hubService then
		for _, player in players do
			deps.hubService.setPlayerPhase(player, "arena")
		end
	end
	if deps and deps.bindables then
		deps.bindables.MatchReady:Fire(players, modeId)
	end
	for _, modeKey in MatchmakingConfig.MODE_ORDER do
		notifyQueue(modeKey)
	end
end

local function tryStartQueue(modeId)
	if arenaBusy then
		notifyQueue(modeId)
		return
	end

	local mode = getMode(modeId)
	local queue = queues[modeId]
	if not queue or #queue.players < mode.minPlayers then
		return
	end

	if mode.maxPlayers == mode.minPlayers or #queue.players >= mode.maxPlayers then
		if queue.fillTask then
			task.cancel(queue.fillTask)
			queue.fillTask = nil
		end
		queue.fillDeadline = nil
		queue.fillSecondsLeft = nil

		local players = pullPlayers(modeId, mode.maxPlayers)
		if #players >= mode.minPlayers then
			startMatch(modeId, players)
		end
		return
	end

	if mode.fillTimeout <= 0 then
		local players = pullPlayers(modeId, mode.maxPlayers)
		if #players >= mode.minPlayers then
			startMatch(modeId, players)
		end
		return
	end

	if queue.fillTask then
		return
	end

	queue.fillDeadline = os.clock() + mode.fillTimeout
	queue.fillSecondsLeft = mode.fillTimeout
	notifyQueue(modeId)

	queue.fillTask = task.spawn(function()
		while queue.fillDeadline do
			local remaining = math.ceil(queue.fillDeadline - os.clock())
			queue.fillSecondsLeft = math.max(0, remaining)
			notifyQueue(modeId)
			if remaining <= 0 then
				break
			end
			task.wait(1)
		end

		queue.fillTask = nil
		queue.fillDeadline = nil
		queue.fillSecondsLeft = nil

		if arenaBusy or #queue.players < mode.minPlayers then
			notifyQueue(modeId)
			return
		end

		local players = pullPlayers(modeId, mode.maxPlayers)
		if #players >= mode.minPlayers then
			startMatch(modeId, players)
		else
			for _, leftover in players do
				table.insert(queue.players, 1, leftover)
				playerQueue[leftover] = modeId
			end
			notifyQueue(modeId)
		end
	end)
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = { players = {} }
	end
	return queues[modeId]
end

function MatchmakingService.init(newDeps)
	deps = newDeps
	for _, modeId in MatchmakingConfig.MODE_ORDER do
		ensureQueue(modeId)
	end
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	for _, modeId in MatchmakingConfig.MODE_ORDER do
		notifyQueue(modeId)
	end
	if not busy then
		for _, modeId in MatchmakingConfig.MODE_ORDER do
			tryStartQueue(modeId)
		end
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.getRecommendedModeId(playerCount)
	if playerCount >= 3 then
		return "ffa"
	elseif playerCount == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.joinQueue(player, modeId)
	if not getMode(modeId) then
		return false, "Unbekannter Modus"
	end
	if playerQueue[player] then
		return false, "Du bist bereits in der Warteschlange"
	end

	local queue = ensureQueue(modeId)
	if #queue.players >= getMode(modeId).maxPlayers then
		return false, "Warteschlange voll"
	end

	table.insert(queue.players, player)
	playerQueue[player] = modeId

	if deps and deps.hubService then
		deps.hubService.setPlayerPhase(player, "queue")
	end

	notifyPlayer(player, buildQueuePayload(modeId))
	notifyQueue(modeId)
	tryStartQueue(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromQueue(player)
	if not modeId then
		return false
	end

	if deps and deps.hubService then
		deps.hubService.setPlayerPhase(player, "hub")
	end

	notifyPlayer(player, {
		modeId = modeId,
		status = "left",
	})
	return true
end

function MatchmakingService.onPlayerRemoving(player)
	local modeId = removeFromQueue(player, true)
	if modeId then
		notifyQueue(modeId)
	end
end

function MatchmakingService.getQueuePayload(modeId)
	return buildQueuePayload(modeId)
end

return MatchmakingService
