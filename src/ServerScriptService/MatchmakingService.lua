local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local Bindables
local getPlayerPhase
local leaveHubForArena

local queues = {}
local playerQueue = {}
local fillTokens = {}
local initialized = false

local STATUS = {
	WAITING = "waiting",
	FILLING = "filling",
	PENDING = "pending",
}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = { players = {} }
	end
	return queues[modeId]
end

local function getMode(modeId)
	return MatchModes.get(modeId) or MatchModes.training
end

local function isPlayerAvailable(player)
	return player.Parent and getPlayerPhase(player) == "hub"
end

local function pruneQueue(modeId)
	local queue = getQueue(modeId)
	local kept = {}
	for _, player in queue.players do
		if isPlayerAvailable(player) and playerQueue[player] and playerQueue[player].modeId == modeId then
			table.insert(kept, player)
		elseif playerQueue[player] and playerQueue[player].modeId == modeId then
			playerQueue[player] = nil
		end
	end
	queue.players = kept
end

local function buildQueuePayload(player)
	local entry = playerQueue[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = getMode(entry.modeId)
	local queue = getQueue(entry.modeId)
	local fillTimeLeft

	if entry.status == STATUS.FILLING and queue.fillDeadline then
		fillTimeLeft = math.max(0, math.ceil(queue.fillDeadline - os.clock()))
	end

	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode.label,
		status = entry.status,
		players = #queue.players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillTimeLeft = fillTimeLeft,
	}
end

local function sendQueueUpdate(player)
	if Remotes and Remotes.QueueUpdate then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastQueue(modeId)
	pruneQueue(modeId)
	local queue = getQueue(modeId)
	for _, player in queue.players do
		sendQueueUpdate(player)
	end
end

local function setQueueStatus(modeId, status)
	local queue = getQueue(modeId)
	for _, player in queue.players do
		if playerQueue[player] then
			playerQueue[player].status = status
		end
	end
	broadcastQueue(modeId)
end

local function clearFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local queue = getQueue(modeId)
	queue.fillDeadline = nil
end

local function removeFromQueue(player, silent)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	playerQueue[player] = nil

	local queue = getQueue(modeId)
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, i)
			break
		end
	end

	if #queue.players < getMode(modeId).minPlayers then
		clearFillTimer(modeId)
		setQueueStatus(modeId, STATUS.WAITING)
	end

	if not silent then
		sendQueueUpdate(player)
		broadcastQueue(modeId)
	end
end

local function takePlayers(modeId, count)
	pruneQueue(modeId)
	local queue = getQueue(modeId)
	local taken = {}
	local limit = math.min(count, #queue.players)

	for _ = 1, limit do
		local player = table.remove(queue.players, 1)
		if player then
			table.insert(taken, player)
			playerQueue[player] = nil
		end
	end

	clearFillTimer(modeId)
	return taken
end

local function launchMatch(modeId, players)
	if #players == 0 then
		return
	end

	MatchStateService.setBusy(true)
	for _, player in players do
		leaveHubForArena(player)
		sendQueueUpdate(player)
	end

	Bindables.MatchReady:Fire(players, modeId)
end

local function tryStartMatch(modeId)
	if MatchStateService.isBusy() then
		setQueueStatus(modeId, STATUS.PENDING)
		return
	end

	pruneQueue(modeId)
	local mode = getMode(modeId)
	local queue = getQueue(modeId)
	local count = #queue.players

	if count < mode.minPlayers then
		setQueueStatus(modeId, STATUS.WAITING)
		return
	end

	if count >= mode.maxPlayers then
		launchMatch(modeId, takePlayers(modeId, mode.maxPlayers))
		return
	end

	if mode.fillTimeout then
		if not queue.fillDeadline then
			queue.fillDeadline = os.clock() + mode.fillTimeout
			setQueueStatus(modeId, STATUS.FILLING)
			fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
			local token = fillTokens[modeId]

			task.delay(mode.fillTimeout, function()
				if fillTokens[modeId] ~= token then
					return
				end
				if MatchStateService.isBusy() then
					setQueueStatus(modeId, STATUS.PENDING)
					return
				end
				pruneQueue(modeId)
				local ready = takePlayers(modeId, getMode(modeId).maxPlayers)
				if #ready >= getMode(modeId).minPlayers then
					launchMatch(modeId, ready)
				end
			end)
		end
		return
	end

	launchMatch(modeId, takePlayers(modeId, mode.maxPlayers))
end

local MODE_ORDER = { "training", "pvp", "ffa" }

local function processAllQueues()
	for _, modeId in MODE_ORDER do
		local mode = getMode(modeId)
		pruneQueue(modeId)
		if #getQueue(modeId).players >= mode.minPlayers then
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not initialized then
		return
	end
	if not isPlayerAvailable(player) then
		return
	end

	local mode = getMode(modeId)
	if not mode then
		return
	end

	removeFromQueue(player, true)

	local queue = getQueue(mode.id)
	table.insert(queue.players, player)
	playerQueue[player] = {
		modeId = mode.id,
		status = STATUS.WAITING,
	}

	sendQueueUpdate(player)
	broadcastQueue(mode.id)
	tryStartMatch(mode.id)
end

function MatchmakingService.leaveQueue(player)
	if not initialized then
		return
	end
	removeFromQueue(player, false)
end

function MatchmakingService.init(deps)
	Remotes = deps.remotes
	Bindables = deps.bindables
	getPlayerPhase = deps.getPlayerPhase
	leaveHubForArena = deps.leaveHubForArena

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchModes.training.id
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchStateService.setBusy(false)
		task.delay(MatchmakingConfig.PENDING_RETRY_DELAY, processAllQueues)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player, true)
	end)

	task.spawn(function()
		while initialized do
			for _, modeId in MODE_ORDER do
				local queue = getQueue(modeId)
				if queue.fillDeadline then
					broadcastQueue(modeId)
				end
			end
			task.wait(MatchmakingConfig.QUEUE_TICK)
		end
	end)

	initialized = true
	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
