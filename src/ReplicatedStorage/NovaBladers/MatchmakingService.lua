local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(script.Parent.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local starting = false

local remotes = nil
local matchReadyBindable = nil
local onPlayerEnterArena = nil

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function getQueueNames(modeId)
	local list = {}
	for _, player in queues[modeId] do
		if player.Parent then
			table.insert(list, player.Name)
		end
	end
	return list
end

local function pruneQueue(modeId)
	local queue = queues[modeId]
	local i = 1
	while i <= #queue do
		if not queue[i].Parent or playerQueue[queue[i]] ~= modeId then
			table.remove(queue, i)
		else
			i += 1
		end
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end
end

local function getFillSecondsLeft(modeId)
	local timer = fillTimers[modeId]
	if not timer or timer.cancelled then
		return nil
	end
	return math.max(0, math.ceil(timer.endsAt - os.clock()))
end

local function buildQueuePayload(modeId, player)
	local config = getModeConfig(modeId)
	pruneQueue(modeId)
	local count = #queues[modeId]
	local status = "waiting"

	if MatchStateService.isArenaBusy() then
		status = "pending"
	elseif count >= config.maxPlayers then
		status = "starting"
	elseif modeId == "ffa" and count >= config.minPlayers then
		status = "filling"
	end

	return {
		mode = modeId,
		modeLabel = config.label,
		players = getQueueNames(modeId),
		count = count,
		needed = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = status,
		secondsLeft = status == "filling" and getFillSecondsLeft(modeId) or nil,
		inQueue = player ~= nil,
	}
end

local function broadcastQueue(modeId)
	if not remotes then
		return
	end
	pruneQueue(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in MatchmakingConfig.MODES do
		broadcastQueue(modeId)
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	if modeId == "ffa" and #queues[modeId] < MatchmakingConfig.MODES.ffa.minPlayers then
		clearFillTimer(modeId)
	end

	broadcastQueue(modeId)
end

local function startFillTimer(modeId)
	clearFillTimer(modeId)
	local config = getModeConfig(modeId)
	local token = { cancelled = false }
	fillTimers[modeId] = {
		cancelled = false,
		endsAt = os.clock() + config.fillTimeout,
	}
	fillTimers[modeId] = fillTimers[modeId]
	local timerRef = fillTimers[modeId]

	task.spawn(function()
		local elapsed = 0
		while elapsed < config.fillTimeout do
			if timerRef.cancelled or fillTimers[modeId] ~= timerRef then
				return
			end
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			elapsed += MatchmakingConfig.QUEUE_UPDATE_INTERVAL
			broadcastQueue(modeId)
		end
		if not timerRef.cancelled and fillTimers[modeId] == timerRef then
			MatchmakingService.tryStartMatch(modeId)
		end
	end)
end

local function canStartMode(modeId)
	local config = getModeConfig(modeId)
	pruneQueue(modeId)
	local count = #queues[modeId]

	if count < config.minPlayers then
		return false
	end
	if count >= config.maxPlayers then
		return true
	end
	if modeId == "ffa" then
		return fillTimers[modeId] ~= nil and getFillSecondsLeft(modeId) == 0
	end
	return count >= config.minPlayers
end

local function popPlayersForMatch(modeId)
	local config = getModeConfig(modeId)
	pruneQueue(modeId)
	local count = math.min(#queues[modeId], config.maxPlayers)
	local matchPlayers = {}
	for _ = 1, count do
		local player = table.remove(queues[modeId], 1)
		if player then
			playerQueue[player] = nil
			table.insert(matchPlayers, player)
		end
	end
	clearFillTimer(modeId)
	return matchPlayers
end

function MatchmakingService.tryStartMatch(modeId)
	if starting or MatchStateService.isArenaBusy() then
		return false
	end
	if not isValidMode(modeId) or not canStartMode(modeId) then
		return false
	end

	local matchPlayers = popPlayersForMatch(modeId)
	if #matchPlayers == 0 then
		return false
	end

	starting = true
	broadcastAllQueues()

	if onPlayerEnterArena then
		for _, player in matchPlayers do
			onPlayerEnterArena(player)
		end
	end

	if matchReadyBindable then
		matchReadyBindable:Fire(matchPlayers)
	end

	starting = false
	broadcastAllQueues()
	return true
end

function MatchmakingService.tryStartNextMatch()
	if MatchStateService.isArenaBusy() then
		return
	end

	for _, modeId in { "training", "pvp", "ffa" } do
		if canStartMode(modeId) then
			if MatchmakingService.tryStartMatch(modeId) then
				return
			end
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false, "invalid_mode"
	end
	if playerQueue[player] then
		if playerQueue[player] == modeId then
			return true
		end
		removeFromQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	local config = getModeConfig(modeId)
	if modeId == "ffa" and #queues[modeId] >= config.minPlayers and not fillTimers[modeId] then
		startFillTimer(modeId)
	end

	broadcastQueue(modeId)

	if not MatchStateService.isArenaBusy() then
		if modeId ~= "ffa" and #queues[modeId] >= config.minPlayers then
			MatchmakingService.tryStartMatch(modeId)
		elseif modeId == "ffa" and #queues[modeId] >= config.maxPlayers then
			MatchmakingService.tryStartMatch(modeId)
		end
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
	if remotes then
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.init(options)
	remotes = options.remotes
	matchReadyBindable = options.matchReadyBindable
	onPlayerEnterArena = options.onPlayerEnterArena

	MatchStateService.onMatchEnd(function()
		task.defer(MatchmakingService.tryStartNextMatch)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
