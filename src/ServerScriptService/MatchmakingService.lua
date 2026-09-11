local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local fillTokens = {}
local fillTimerActive = {}
local arenaBusyChecker = nil
local hubCallbacks = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function isArenaBusy()
	return arenaBusyChecker and arenaBusyChecker() or false
end

local function removePlayerFromQueues(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end

	playerMode[player] = nil
end

local function getQueuePosition(player)
	local modeId = playerMode[player]
	if not modeId then
		return nil
	end

	for index, queuedPlayer in queues[modeId] do
		if queuedPlayer == player then
			return index, #queues[modeId], modeId
		end
	end

	return nil
end

local function getValidQueue(modeId)
	local valid = {}
	for _, player in queues[modeId] do
		if player.Parent and hubCallbacks.getPhase(player) == "hub" then
			table.insert(valid, player)
		end
	end
	return valid
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	fillTimerActive[modeId] = false
end

local function sendQueueUpdate(player)
	if not player.Parent then
		return
	end

	local position, total, modeId = getQueuePosition(player)
	if not position then
		Remotes.QueueUpdate:FireClient(player, { joined = false })
		return
	end

	local config = getModeConfig(modeId)
	local status = "waiting"
	if isArenaBusy() then
		status = "pending"
	elseif modeId == "ffa" and total >= config.minPlayers and fillTimerActive[modeId] then
		status = "filling"
	end

	Remotes.QueueUpdate:FireClient(player, {
		joined = true,
		modeId = modeId,
		modeLabel = config.label,
		position = position,
		total = total,
		status = status,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
	})
end

local function broadcastQueueUpdates(modeId)
	for _, player in queues[modeId] do
		sendQueueUpdate(player)
	end
end

local function broadcastAllQueueUpdates()
	for _, modeId in MatchmakingConfig.MODE_ORDER do
		broadcastQueueUpdates(modeId)
	end
end

local function startFillTimer(modeId)
	local config = getModeConfig(modeId)
	if not config.fillTimeout or fillTimerActive[modeId] then
		return
	end

	fillTimerActive[modeId] = true
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(config.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		fillTimerActive[modeId] = false
		MatchmakingService.tryStartMode(modeId, true)
	end)
end

function MatchmakingService.registerHubCallbacks(callbacks)
	hubCallbacks = callbacks
end

function MatchmakingService.setArenaBusyChecker(checker)
	arenaBusyChecker = checker
end

function MatchmakingService.getQueueCounts()
	local counts = {}
	for modeId, queue in queues do
		counts[modeId] = #getValidQueue(modeId)
	end
	return counts
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		return
	end

	local modeId = playerMode[player]
	removePlayerFromQueues(player)

	local config = getModeConfig(modeId)
	if config and #getValidQueue(modeId) < config.minPlayers then
		cancelFillTimer(modeId)
	end

	Remotes.QueueUpdate:FireClient(player, { joined = false })
	broadcastQueueUpdates(modeId)
	if hubCallbacks.onQueueChanged then
		hubCallbacks.onQueueChanged()
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return
	end
	if hubCallbacks.getPhase(player) ~= "hub" then
		return
	end
	if isArenaBusy() and not playerMode[player] then
		-- Allow re-join while already queued; new joins while arena is busy become pending.
	end

	if playerMode[player] == modeId then
		sendQueueUpdate(player)
		return
	end

	MatchmakingService.leaveQueue(player)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	sendQueueUpdate(player)
	broadcastQueueUpdates(modeId)
	if hubCallbacks.onQueueChanged then
		hubCallbacks.onQueueChanged()
	end
	MatchmakingService.tryStartMode(modeId)
end

function MatchmakingService.tryStartMode(modeId, forceStart)
	if isArenaBusy() then
		broadcastQueueUpdates(modeId)
		return
	end

	local config = getModeConfig(modeId)
	if not config then
		return
	end

	local valid = getValidQueue(modeId)
	if #valid < config.minPlayers then
		return
	end

	if modeId == "ffa" and not forceStart and #valid < config.maxPlayers then
		startFillTimer(modeId)
		broadcastQueueUpdates(modeId)
		return
	end

	local matchPlayers = {}
	local count = math.min(#valid, config.maxPlayers)
	for i = 1, count do
		table.insert(matchPlayers, valid[i])
	end

	for _, player in matchPlayers do
		removePlayerFromQueues(player)
		if hubCallbacks.onMatchStarting then
			hubCallbacks.onMatchStarting(player)
		end
	end

	cancelFillTimer(modeId)
	broadcastQueueUpdates(modeId)
	Bindables.MatchReady:Fire(matchPlayers, modeId)
end

function MatchmakingService.tryStartMatches()
	if isArenaBusy() then
		broadcastAllQueueUpdates()
		return
	end

	for _, modeId in MatchmakingConfig.MODE_ORDER do
		MatchmakingService.tryStartMode(modeId)
		if isArenaBusy() then
			break
		end
	end
end

function MatchmakingService.onMatchEnded()
	broadcastAllQueueUpdates()
	MatchmakingService.tryStartMatches()
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

return MatchmakingService
