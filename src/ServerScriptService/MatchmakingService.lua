local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchFlowState = require(script.Parent.MatchFlowState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local pendingStarts = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function countValidPlayers(list)
	local count = 0
	for _, player in list do
		if player.Parent then
			count += 1
		end
	end
	return count
end

local function compactQueue(modeId)
	local queue = queues[modeId]
	local compact = {}
	for _, player in queue do
		if player.Parent and playerQueue[player] == modeId then
			table.insert(compact, player)
		end
	end
	queues[modeId] = compact
	return compact
end

local function buildQueuePayload(player, modeId)
	local config = getModeConfig(modeId)
	local queue = compactQueue(modeId)
	local inQueue = countValidPlayers(queue)
	local status = "waiting"

	if MatchFlowState.isArenaBusy() then
		status = "pending"
	elseif config.minPlayers == 1 and inQueue >= 1 then
		status = "ready"
	elseif inQueue >= config.maxPlayers then
		status = "ready"
	elseif inQueue >= config.minPlayers and config.fillTimeout > 0 and fillTimers[modeId] then
		status = "filling"
	end

	return {
		modeId = modeId,
		modeLabel = config.label,
		inQueue = inQueue,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = status,
		arenaBusy = MatchFlowState.isArenaBusy(),
	}
end

local function broadcastQueue(modeId)
	local payload = buildQueuePayload(nil, modeId)
	for _, player in compactQueue(modeId) do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
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

	local config = getModeConfig(modeId)
	if config and config.fillTimeout > 0 then
		local remaining = countValidPlayers(compactQueue(modeId))
		if remaining < config.minPlayers then
			clearFillTimer(modeId)
		end
	end

	broadcastQueue(modeId)
end

local function startMatch(modeId, playerList)
	clearFillTimer(modeId)
	MatchFlowState.setArenaBusy(true)

	for _, player in playerList do
		removeFromQueue(player)
	end

	for _, player in playerList do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, {
				modeId = modeId,
				status = "starting",
				modeLabel = getModeConfig(modeId).label,
			})
		end
	end

	Bindables.MatchReady:Fire(playerList, modeId)
end

local function tryStartMatch(modeId)
	if MatchFlowState.isArenaBusy() then
		broadcastQueue(modeId)
		return
	end

	local config = getModeConfig(modeId)
	local queue = compactQueue(modeId)
	local inQueue = #queue

	if inQueue < config.minPlayers then
		broadcastQueue(modeId)
		return
	end

	if inQueue >= config.maxPlayers then
		local players = {}
		for i = 1, config.maxPlayers do
			table.insert(players, queue[i])
		end
		startMatch(modeId, players)
		return
	end

	if config.minPlayers == 1 and inQueue >= 1 then
		startMatch(modeId, { queue[1] })
		return
	end

	if config.minPlayers > 1 and inQueue >= config.minPlayers and config.fillTimeout == 0 then
		local players = {}
		for i = 1, config.minPlayers do
			table.insert(players, queue[i])
		end
		startMatch(modeId, players)
		return
	end

	if config.fillTimeout > 0 and inQueue >= config.minPlayers and not fillTimers[modeId] then
		fillTimers[modeId] = task.delay(config.fillTimeout, function()
			fillTimers[modeId] = nil
			if MatchFlowState.isArenaBusy() then
				return
			end
			local current = compactQueue(modeId)
			if #current >= config.minPlayers then
				startMatch(modeId, current)
			end
		end)
	end

	broadcastQueue(modeId)
end

local function processPendingStarts()
	if MatchFlowState.isArenaBusy() then
		return
	end

	for modeId in MatchmakingConfig.MODES do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		modeId = MatchmakingConfig.DEFAULT_MODE
	end

	if playerQueue[player] then
		if playerQueue[player] == modeId then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
			return
		end
		removeFromQueue(player)
	end

	if MatchFlowState.isArenaBusy() then
		table.insert(queues[modeId], player)
		playerQueue[player] = modeId
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
		return
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastQueue(modeId)
	tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { status = "idle" })
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onMatchEnded()
	MatchFlowState.setArenaBusy(false)
	task.defer(processPendingStarts)
end

function MatchmakingService.init(handlers)
	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = nil
		end
		if handlers and handlers.onJoinQueue then
			handlers.onJoinQueue(player, modeId)
		else
			MatchmakingService.joinQueue(player, modeId)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
		if handlers and handlers.onLeaveQueue then
			handlers.onLeaveQueue(player)
		end
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
