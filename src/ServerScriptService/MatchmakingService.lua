local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local MatchReady
local Bindables

local queues = {}
local playerQueue = {}
local fillTokens = {}
local fillUpdateTokens = {}

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			fillDeadline = nil,
		}
	end
	return queues[modeId]
end

local function removeFromQueueList(queue, player)
	for index, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, index)
			return true
		end
	end
	return false
end

local function getQueueStatus(modeId, queue)
	local mode = MatchModes.get(modeId)
	if not mode then
		return MatchmakingConfig.STATUS.WAITING
	end

	local count = #queue.players
	if count < mode.minPlayers then
		return MatchmakingConfig.STATUS.WAITING
	end

	if MatchStateService.isBusy() then
		return MatchmakingConfig.STATUS.PENDING
	end

	if mode.fillTimeout and count < mode.maxPlayers and queue.fillDeadline and os.clock() < queue.fillDeadline then
		return MatchmakingConfig.STATUS.WAITING
	end

	return MatchmakingConfig.STATUS.STARTING
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local queue = ensureQueue(modeId)
	local status = getQueueStatus(modeId, queue)
	local fillSecondsLeft = nil

	if queue.fillDeadline then
		fillSecondsLeft = math.max(0, math.ceil(queue.fillDeadline - os.clock()))
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		status = status,
		queued = #queue.players,
		needed = mode.minPlayers,
		max = mode.maxPlayers,
		fillSecondsLeft = fillSecondsLeft,
		arenaBusy = MatchStateService.isBusy(),
	}
end

local function sendQueueUpdate(player)
	if player.Parent and Remotes.QueueUpdate then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastQueueUpdates(modeId)
	local queue = ensureQueue(modeId)
	for _, player in queue.players do
		sendQueueUpdate(player)
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	fillUpdateTokens[modeId] = (fillUpdateTokens[modeId] or 0) + 1
	local queue = ensureQueue(modeId)
	queue.fillDeadline = nil
end

local function scheduleFillUpdates(modeId, token)
	task.spawn(function()
		while fillUpdateTokens[modeId] == token do
			local queue = ensureQueue(modeId)
			if not queue.fillDeadline then
				break
			end
			broadcastQueueUpdates(modeId)
			task.wait(1)
		end
	end)
end

local function scheduleFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	local queue = ensureQueue(modeId)
	if queue.fillDeadline then
		return
	end

	queue.fillDeadline = os.clock() + mode.fillTimeout
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	fillUpdateTokens[modeId] = (fillUpdateTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]
	scheduleFillUpdates(modeId, fillUpdateTokens[modeId])

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		MatchmakingService.tryStartMatch(modeId)
	end)
end

local function takeReadyPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = ensureQueue(modeId)
	local readyPlayers = {}

	for index = 1, math.min(#queue.players, mode.maxPlayers) do
		table.insert(readyPlayers, queue.players[index])
	end

	for _, player in readyPlayers do
		removeFromQueueList(queue, player)
		playerQueue[player] = nil
	end

	cancelFillTimer(modeId)
	return readyPlayers
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = ensureQueue(modeId)
	local count = #queue.players

	if count < mode.minPlayers then
		broadcastQueueUpdates(modeId)
		return
	end

	if count < mode.maxPlayers and mode.fillTimeout then
		scheduleFillTimer(modeId)
		if queue.fillDeadline and os.clock() < queue.fillDeadline then
			broadcastQueueUpdates(modeId)
			return
		end
	end

	if MatchStateService.isBusy() then
		broadcastQueueUpdates(modeId)
		return
	end

	local readyPlayers = takeReadyPlayers(modeId)
	if #readyPlayers == 0 then
		return
	end

	MatchStateService.setBusy(true)

	for _, player in readyPlayers do
		HubService.enterArenaForMatch(player)
		sendQueueUpdate(player)
	end

	MatchReady:Fire(readyPlayers, modeId)
	broadcastQueueUpdates(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end
	if playerQueue[player] == modeId then
		sendQueueUpdate(player)
		return
	end

	MatchmakingService.leaveQueue(player, true)

	playerQueue[player] = modeId
	local queue = ensureQueue(modeId)
	table.insert(queue.players, player)

	broadcastQueueUpdates(modeId)
	MatchmakingService.tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player, silent)
	local modeId = playerQueue[player]
	if not modeId then
		if not silent then
			sendQueueUpdate(player)
		end
		return
	end

	local queue = ensureQueue(modeId)
	removeFromQueueList(queue, player)
	playerQueue[player] = nil

	local mode = MatchModes.get(modeId)
	if mode and #queue.players < mode.minPlayers then
		cancelFillTimer(modeId)
	end

	if not silent then
		sendQueueUpdate(player)
	end
	broadcastQueueUpdates(modeId)
end

function MatchmakingService.init()
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player, true)
	end)

	MatchStateService.onArenaFree(function()
		for _, modeId in MatchModes.ALL do
			MatchmakingService.tryStartMatch(modeId)
		end
	end)
end

return MatchmakingService
