local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local remotes = nil
local matchReadyEvent = nil
local onMatchStart = nil

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function buildQueuePayload(player, modeId, status)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueue(modeId)
	local count = #queue

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		players = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status or (MatchStateService.isArenaBusy() and "pending" or "waiting"),
		position = table.find(queue, player) or count,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = getQueue(modeId)
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent and remotes then
			local status = MatchStateService.isArenaBusy() and "pending" or "waiting"
			remotes.QueueUpdate:FireClient(queuedPlayer, buildQueuePayload(queuedPlayer, modeId, status))
		end
	end
end

local function fireQueueLeft(player)
	if remotes and player.Parent then
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function startMatch(modeId, playerList)
	for _, player in playerList do
		removeFromQueue(player)
	end

	if onMatchStart then
		onMatchStart(playerList, modeId)
	end

	if matchReadyEvent then
		matchReadyEvent:Fire(playerList, modeId)
	end
end

local function tryStartMatch(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	local queue = getQueue(modeId)
	local count = #queue
	if count < mode.minPlayers then
		return
	end

	local playerList = {}
	for i = 1, math.min(count, mode.maxPlayers) do
		table.insert(playerList, queue[i])
	end

	MatchStateService.setArenaBusy(true)
	startMatch(modeId, playerList)
end

local function scheduleFillTimeout(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
	end

	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		local queue = getQueue(modeId)
		if #queue >= mode.minPlayers and #queue < mode.maxPlayers then
			tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.init(remotesFolder, bindables, matchStartCallback)
	remotes = remotesFolder
	matchReadyEvent = bindables.MatchReady
	onMatchStart = matchStartCallback

	bindables.MatchEnded.Event:Connect(function()
		MatchStateService.setArenaBusy(false)
		for modeId in MatchmakingConfig.MODES do
			tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchmakingConfig.getMode(modeId) then
		return false
	end

	if playerQueue[player] then
		if playerQueue[player] == modeId then
			return true
		end
		MatchmakingService.leaveQueue(player)
	end

	local queue = getQueue(modeId)
	if #queue >= MatchmakingConfig.getMode(modeId).maxPlayers then
		return false
	end

	table.insert(queue, player)
	playerQueue[player] = modeId

	local status = MatchStateService.isArenaBusy() and "pending" or "waiting"
	if remotes then
		remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, status))
	end
	broadcastQueueUpdate(modeId)

	local mode = MatchmakingConfig.getMode(modeId)
	if #queue >= mode.minPlayers then
		if modeId == "ffa" and #queue < mode.maxPlayers then
			scheduleFillTimeout(modeId)
		else
			tryStartMatch(modeId)
		end
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueue(player)
	fireQueueLeft(player)
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getQueueMode(player)
	return playerQueue[player]
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

return MatchmakingService
