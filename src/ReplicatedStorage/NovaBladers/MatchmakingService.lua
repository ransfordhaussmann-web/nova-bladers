local Players = game:GetService("Players")

local MatchmakingConfig = require(script.Parent.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {}
local playerEntry = {}
local onReadyCallback = nil
local onUpdateCallback = nil

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {
		players = {},
		fillDeadline = nil,
	}
end

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function countValid(players)
	local n = 0
	for _, player in players do
		if player.Parent then
			n += 1
		end
	end
	return n
end

local function compactPlayers(players)
	local valid = {}
	for _, player in players do
		if player.Parent then
			table.insert(valid, player)
		end
	end
	return valid
end

local function buildQueueSnapshot(modeId)
	local queue = queues[modeId]
	local config = getModeConfig(modeId)
	local players = compactPlayers(queue.players)
	queue.players = players

	return {
		mode = modeId,
		label = config.label,
		count = #players,
		needed = config.minPlayers,
		max = config.maxPlayers,
		fillDeadline = queue.fillDeadline,
	}
end

local function broadcastQueueUpdate()
	if not onUpdateCallback then
		return
	end

	local seen = {}
	for modeId in queues do
		local snapshot = buildQueueSnapshot(modeId)
		for _, player in queues[modeId].players do
			if player.Parent and not seen[player] then
				seen[player] = true
				local entry = playerEntry[player]
				onUpdateCallback(player, {
					status = entry and entry.status or "idle",
					queue = snapshot,
					arenaBusy = MatchStateService.isBusy(),
				})
			end
		end
	end
end

local function removeFromAllQueues(player)
	for modeId, queue in queues do
		for i, queued in queue.players do
			if queued == player then
				table.remove(queue.players, i)
				break
			end
		end
		if #queue.players == 0 then
			queue.fillDeadline = nil
		end
	end
end

local function setPlayerStatus(player, modeId, status)
	playerEntry[player] = {
		mode = modeId,
		status = status,
	}
end

local function clearPlayer(player)
	playerEntry[player] = nil
end

local function notifyPlayer(player, payload)
	if onUpdateCallback and player.Parent then
		onUpdateCallback(player, payload)
	end
end

local function leaveHubPhase(player, leaveHubFn)
	if leaveHubFn then
		leaveHubFn(player)
	end
end

local function tryStartMatch(modeId, leaveHubFn)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local players = compactPlayers(queue.players)
	queue.players = players

	if #players < config.minPlayers then
		return false
	end

	if MatchStateService.isBusy() then
		for _, player in players do
			setPlayerStatus(player, modeId, "pending")
			notifyPlayer(player, {
				status = "pending",
				queue = buildQueueSnapshot(modeId),
				arenaBusy = true,
			})
		end
		return false
	end

	local matchPlayers = {}
	for i = 1, math.min(#players, config.maxPlayers) do
		table.insert(matchPlayers, players[i])
	end

	queue.players = {}
	queue.fillDeadline = nil

	for _, player in matchPlayers do
		clearPlayer(player)
		leaveHubPhase(player, leaveHubFn)
	end

	MatchStateService.setBusy(true)

	if onReadyCallback then
		onReadyCallback(matchPlayers, modeId)
	end

	broadcastQueueUpdate()
	return true
end

local function evaluateQueue(modeId, leaveHubFn)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local players = compactPlayers(queue.players)
	queue.players = players

	if #players == 0 then
		queue.fillDeadline = nil
		return
	end

	for _, player in players do
		setPlayerStatus(player, modeId, "waiting")
	end

	if #players >= config.maxPlayers then
		tryStartMatch(modeId, leaveHubFn)
		return
	end

	if #players >= config.minPlayers then
		if config.fillTimeout <= 0 then
			tryStartMatch(modeId, leaveHubFn)
			return
		end

		if not queue.fillDeadline then
			queue.fillDeadline = os.clock() + config.fillTimeout
		elseif os.clock() >= queue.fillDeadline then
			tryStartMatch(modeId, leaveHubFn)
			return
		end
	end

	broadcastQueueUpdate()
end

function MatchmakingService.setCallbacks(readyFn, updateFn)
	onReadyCallback = readyFn
	onUpdateCallback = updateFn
end

function MatchmakingService.joinQueue(player, modeId, leaveHubFn)
	if typeof(modeId) ~= "string" or not getModeConfig(modeId) then
		modeId = MatchmakingConfig.DEFAULT_MODE
	end

	if playerEntry[player] and playerEntry[player].status == "pending" then
		return false, "pending"
	end

	removeFromAllQueues(player)
	local queue = queues[modeId]
	table.insert(queue.players, player)
	setPlayerStatus(player, modeId, "waiting")

	evaluateQueue(modeId, leaveHubFn)
	return true
end

function MatchmakingService.leaveQueue(player)
	removeFromAllQueues(player)
	clearPlayer(player)
	notifyPlayer(player, {
		status = "idle",
		queue = nil,
		arenaBusy = MatchStateService.isBusy(),
	})
	broadcastQueueUpdate()
end

function MatchmakingService.onMatchEnded(leaveHubFn)
	MatchStateService.setBusy(false)

	for modeId in queues do
		evaluateQueue(modeId, leaveHubFn)
	end
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromAllQueues(player)
	clearPlayer(player)
	broadcastQueueUpdate()
end

function MatchmakingService.getPlayerStatus(player)
	local entry = playerEntry[player]
	if not entry then
		return "idle"
	end
	return entry.status
end

function MatchmakingService.tick(leaveHubFn)
	for modeId in queues do
		evaluateQueue(modeId, leaveHubFn)
	end
end

function MatchmakingService.resolveDefaultMode(playerCount)
	if playerCount >= 3 then
		return "ffa"
	elseif playerCount == 2 then
		return "pvp"
	end
	return "training"
end

return MatchmakingService
