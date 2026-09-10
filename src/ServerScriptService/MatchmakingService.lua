local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTasks = {}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function cancelFillTask(modeId)
	local taskToken = fillTasks[modeId]
	if taskToken then
		fillTasks[modeId] = nil
	end
end

local function buildQueuePayload(modeId, player)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueue(modeId)
	local names = {}
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			table.insert(names, queuedPlayer.Name)
		end
	end

	local status = "waiting"
	if MatchStateService.isBusy() then
		status = "pending"
	elseif mode.fillTimeout and #queue >= mode.minPlayers and #queue < mode.maxPlayers then
		status = "filling"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = names,
		count = #names,
		required = mode.minPlayers,
		max = mode.maxPlayers,
		status = status,
		inQueue = playerQueue[player] == modeId,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function removeFromQueue(player, silent)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	playerQueue[player] = nil
	local queue = getQueue(modeId)
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	if not silent then
		broadcastQueueUpdate(modeId)
	end
	return modeId
end

local function popPlayers(modeId, count)
	local queue = getQueue(modeId)
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(picked, player)
		end
	end
	broadcastQueueUpdate(modeId)
	return picked
end

local function canStartMode(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return false
	end
	if MatchStateService.isBusy() then
		return false
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return false
	end
	if #queue >= mode.maxPlayers then
		return true
	end
	if mode.fillTimeout and #queue >= mode.minPlayers then
		return fillTasks[modeId] == nil
	end
	return #queue >= mode.minPlayers
end

local function startMatchForMode(modeId)
	if not canStartMode(modeId) then
		return false
	end

	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueue(modeId)
	local takeCount = math.min(#queue, mode.maxPlayers)
	local players = popPlayers(modeId, takeCount)
	if #players < mode.minPlayers then
		for _, player in players do
			MatchmakingService.joinQueue(player, modeId)
		end
		return false
	end

	cancelFillTask(modeId)
	MatchStateService.setBusy(true)

	for _, player in players do
		Remotes.QueueUpdate:FireClient(player, {
			modeId = modeId,
			modeLabel = mode.label,
			status = "starting",
			inQueue = false,
		})
	end

	Bindables.MatchReady:Fire({
		mode = modeId,
		players = players,
	})

	return true
end

local function scheduleFillTimeout(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	cancelFillTask(modeId)
	local token = {}
	fillTasks[modeId] = token

	task.delay(mode.fillTimeout, function()
		if fillTasks[modeId] ~= token then
			return
		end
		fillTasks[modeId] = nil
		startMatchForMode(modeId)
	end)
end

local function tryStartQueues()
	for modeId in MatchmakingConfig.MODES do
		local mode = MatchmakingConfig.getMode(modeId)
		local queue = getQueue(modeId)

		if #queue >= mode.maxPlayers then
			startMatchForMode(modeId)
		elseif mode.fillTimeout and #queue >= mode.minPlayers and not fillTasks[modeId] then
			scheduleFillTimeout(modeId)
			broadcastQueueUpdate(modeId)
		elseif canStartMode(modeId) then
			startMatchForMode(modeId)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not player or not player.Parent then
		return false
	end

	modeId = modeId or MatchmakingConfig.DEFAULT_MODE
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return false
	end

	removeFromQueue(player, true)
	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId

	broadcastQueueUpdate(modeId)
	tryStartQueues()
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromQueue(player)
	if not modeId then
		return false
	end

	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueue(modeId)
	if mode.fillTimeout and #queue < mode.minPlayers then
		cancelFillTask(modeId)
	end

	tryStartQueues()
	return true
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setBusy(false)
	tryStartQueues()
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player, true)
end

function MatchmakingService.getActiveModeId()
	return MatchmakingConfig.resolveModeFromPlayerCount(#Players:GetPlayers())
end

return MatchmakingService
