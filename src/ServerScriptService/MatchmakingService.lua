local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(script.Parent.GameMatchState)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local fillTimers = {}
local remotes
local matchReadyBindable
local callbacks = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerMode[player] = nil

	if fillTimers[modeId] then
		fillTimers[modeId] = nil
	end
end

local function countQueue(modeId)
	return #queues[modeId]
end

local function buildQueuePayload(player, modeId, status)
	local config = getModeConfig(modeId)
	local queued = countQueue(modeId)
	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = config.label,
		queued = queued,
		needed = config.minPlayers,
		max = config.maxPlayers,
		status = status,
	}
end

local function broadcastQueueUpdates(modeId)
	local config = getModeConfig(modeId)
	local queued = countQueue(modeId)
	local status = "waiting"
	if queued >= config.minPlayers and GameMatchState.isBusy() then
		status = "pending_arena"
	end

	for _, player in queues[modeId] do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, status))
		end
	end
end

local function fireQueueLeft(player)
	remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

local function takePlayers(modeId, count)
	local taken = {}
	local queue = queues[modeId]
	while #taken < count and #queue > 0 do
		local player = table.remove(queue, 1)
		if player.Parent then
			playerMode[player] = nil
			table.insert(taken, player)
		end
	end
	return taken
end

local function startMatch(modeId, players)
	GameMatchState.setBusy(true)
	fillTimers[modeId] = nil

	for _, player in players do
		if callbacks.onMatchStarting then
			callbacks.onMatchStarting(player)
		end
		remotes.QueueUpdate:FireClient(player, {
			inQueue = true,
			modeId = modeId,
			modeLabel = getModeConfig(modeId).label,
			status = "starting",
		})
	end

	matchReadyBindable:Fire({
		mode = modeId,
		players = players,
	})
end

local function tryStartMode(modeId)
	if GameMatchState.isBusy() then
		return
	end

	local config = getModeConfig(modeId)
	local queued = countQueue(modeId)
	if queued < config.minPlayers then
		return
	end

	local playerCount = math.min(queued, config.maxPlayers)
	startMatch(modeId, takePlayers(modeId, playerCount))
end

local function tryAllModes()
	for modeId in MatchmakingConfig.MODES do
		tryStartMode(modeId)
	end
end

local function scheduleFillTimer(modeId)
	local config = getModeConfig(modeId)
	if not config.fillTimeout then
		tryStartMode(modeId)
		return
	end

	if fillTimers[modeId] then
		return
	end

	local token = {}
	fillTimers[modeId] = token

	task.delay(config.fillTimeout, function()
		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		tryStartMode(modeId)
	end)
end

local function evaluateMode(modeId)
	local config = getModeConfig(modeId)
	local queued = countQueue(modeId)

	if queued < config.minPlayers then
		fillTimers[modeId] = nil
		broadcastQueueUpdates(modeId)
		return
	end

	if config.fillTimeout then
		if queued >= config.maxPlayers then
			tryStartMode(modeId)
		else
			scheduleFillTimer(modeId)
			broadcastQueueUpdates(modeId)
		end
	else
		tryStartMode(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false
	end
	if GameMatchState.isBusy() and playerMode[player] then
		return false
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	if callbacks.onQueueJoin then
		callbacks.onQueueJoin(player, modeId)
	end

	evaluateMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		return
	end

	local modeId = playerMode[player]
	removeFromQueue(player)

	if callbacks.onQueueLeave then
		callbacks.onQueueLeave(player)
	end

	fireQueueLeft(player)
	evaluateMode(modeId)
end

function MatchmakingService.isInQueue(player)
	return playerMode[player] ~= nil
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.onArenaFree()
	GameMatchState.setBusy(false)
	tryAllModes()
end

function MatchmakingService.start(remotesFolder, bindablesFolder, newCallbacks)
	remotes = remotesFolder
	matchReadyBindable = bindablesFolder.MatchReady
	callbacks = newCallbacks or {}

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	bindablesFolder.ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK)
			if not GameMatchState.isBusy() then
				tryAllModes()
			else
				for modeId in MatchmakingConfig.MODES do
					if countQueue(modeId) >= getModeConfig(modeId).minPlayers then
						broadcastQueueUpdates(modeId)
					end
				end
			end
		end
	end)
end

return MatchmakingService
