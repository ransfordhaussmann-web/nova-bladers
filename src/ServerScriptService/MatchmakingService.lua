local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local ffaFillToken = 0
local started = false

local callbacks = {
	setPlayerPhase = nil,
	getPlayerPhase = nil,
}

local function getMode(modeId)
	return MatchModes.get(modeId)
end

local function queueCount(modeId)
	return #queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end
	return modeId
end

local function canJoinQueue(player)
	local phase = callbacks.getPlayerPhase and callbacks.getPlayerPhase(player)
	return phase == "hub" or phase == "queue"
end

local function buildQueuePayload(modeId, player)
	local mode = getMode(modeId)
	local count = queueCount(modeId)
	local status = "waiting"

	if MatchStateService.isBusy() and count >= mode.minPlayers then
		status = "pending"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = count,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		inQueue = playerQueue[player] == modeId,
	}
end

local function broadcastQueueUpdate(modeId)
	for _, queuedPlayer in queues[modeId] do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, buildQueuePayload(modeId, queuedPlayer))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function takePlayers(modeId, count)
	local taken = {}
	local queue = queues[modeId]
	while #taken < count and #queue > 0 do
		local player = table.remove(queue, 1)
		if player.Parent and canJoinQueue(player) then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end
	return taken
end

local function beginMatch(players)
	if #players == 0 then
		return
	end

	MatchStateService.setBusy(true)

	for _, player in players do
		if callbacks.setPlayerPhase then
			callbacks.setPlayerPhase(player, "arena")
		end
	end

	MatchReady:Fire(players)
end

local function tryStartTraining()
	local mode = MatchModes.Training
	if queueCount(mode.id) < mode.minPlayers then
		return false
	end
	if MatchStateService.isBusy() then
		broadcastQueueUpdate(mode.id)
		return false
	end

	local players = takePlayers(mode.id, mode.maxPlayers)
	if #players < mode.minPlayers then
		for _, player in players do
			table.insert(queues[mode.id], player)
			playerQueue[player] = mode.id
		end
		return false
	end

	task.delay(MatchmakingConfig.TRAINING_START_DELAY, function()
		beginMatch(players)
	end)
	return true
end

local function tryStartPvP()
	local mode = MatchModes.PvP
	if queueCount(mode.id) < mode.minPlayers then
		return false
	end
	if MatchStateService.isBusy() then
		broadcastQueueUpdate(mode.id)
		return false
	end

	local players = takePlayers(mode.id, mode.maxPlayers)
	if #players < mode.minPlayers then
		for _, player in players do
			table.insert(queues[mode.id], player)
			playerQueue[player] = mode.id
		end
		return false
	end

	task.delay(MatchmakingConfig.PVP_START_DELAY, function()
		beginMatch(players)
	end)
	return true
end

local function tryStartFFA()
	local mode = MatchModes.FFA
	local count = queueCount(mode.id)
	if count < mode.minPlayers then
		return false
	end
	if MatchStateService.isBusy() then
		broadcastQueueUpdate(mode.id)
		return false
	end

	local takeCount = math.min(count, mode.maxPlayers)
	local players = takePlayers(mode.id, takeCount)
	if #players < mode.minPlayers then
		for _, player in players do
			table.insert(queues[mode.id], player)
			playerQueue[player] = mode.id
		end
		return false
	end

	ffaFillToken += 1
	task.delay(MatchmakingConfig.FFA_START_DELAY, function()
		beginMatch(players)
	end)
	return true
end

local function scheduleFFAFill()
	local mode = MatchModes.FFA
	if queueCount(mode.id) < mode.minPlayers then
		return
	end

	ffaFillToken += 1
	local token = ffaFillToken

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= ffaFillToken then
			return
		end
		tryStartFFA()
	end)
end

local function tryStartMode(modeId)
	if modeId == "training" then
		return tryStartTraining()
	elseif modeId == "pvp" then
		return tryStartPvP()
	elseif modeId == "ffa" then
		return tryStartFFA()
	end
	return false
end

local function tryStartAllModes()
	for _, mode in MatchModes.all() do
		if tryStartMode(mode.id) then
			return
		end
	end
end

function MatchmakingService.configure(handlers)
	callbacks.setPlayerPhase = handlers.setPlayerPhase
	callbacks.getPlayerPhase = handlers.getPlayerPhase
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not getMode(modeId) then
		return false
	end
	if not canJoinQueue(player) then
		return false
	end

	local previousMode = removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	if callbacks.setPlayerPhase then
		callbacks.setPlayerPhase(player, "queue")
	end

	if previousMode and previousMode ~= modeId then
		broadcastQueueUpdate(previousMode)
	end
	broadcastQueueUpdate(modeId)

	if modeId == "ffa" then
		local count = queueCount(modeId)
		if count >= MatchModes.FFA.maxPlayers then
			ffaFillToken += 1
			tryStartFFA()
		elseif count == MatchModes.FFA.minPlayers then
			scheduleFFAFill()
		end
	else
		tryStartMode(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromQueue(player)
	if not modeId then
		return false
	end

	if modeId == "ffa" then
		ffaFillToken += 1
	end

	if callbacks.setPlayerPhase then
		callbacks.setPlayerPhase(player, "hub")
	end

	Remotes.QueueUpdate:FireClient(player, {
		modeId = modeId,
		inQueue = false,
		status = "left",
	})
	broadcastQueueUpdate(modeId)
	return true
end

function MatchmakingService.onPlayerRemoving(player)
	local modeId = removeFromQueue(player)
	if modeId then
		if modeId == "ffa" then
			ffaFillToken += 1
		end
		broadcastQueueUpdate(modeId)
	end
end

function MatchmakingService.onArenaFree()
	broadcastAllQueues()
	tryStartAllModes()
end

function MatchmakingService.getQueueForPlayer(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end
	return buildQueuePayload(modeId, player)
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	local _, Bindables = RemotesSetup.ensure()
	Remotes = ReplicatedStorage.NovaBladers.Remotes
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
