local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local arenaBusy = false
local fillTokens = {}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function countQueue(modeId)
	return #queues[modeId]
end

local function buildQueuePayload(modeId, player)
	local config = getModeConfig(modeId)
	local status = MatchmakingConfig.QUEUE_STATUS.Waiting
	if arenaBusy then
		status = MatchmakingConfig.QUEUE_STATUS.Pending
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = config.label,
		players = countQueue(modeId),
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = status,
		arenaBusy = arenaBusy,
	}
end

local function broadcastQueueUpdate(modeId)
	local payload = {
		modeId = modeId,
		players = countQueue(modeId),
		minPlayers = getModeConfig(modeId).minPlayers,
		maxPlayers = getModeConfig(modeId).maxPlayers,
		arenaBusy = arenaBusy,
	}

	for _, player in queues[modeId] do
		if player.Parent then
			local personal = buildQueuePayload(modeId, player)
			Remotes.QueueUpdate:FireClient(player, personal)
		end
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function startFillTimer(modeId)
	local config = getModeConfig(modeId)
	if config.fillTimeout <= 0 then
		return
	end

	cancelFillTimer(modeId)
	local token = fillTokens[modeId] or 0

	task.delay(config.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		if countQueue(modeId) >= config.minPlayers then
			MatchmakingService.tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

local function removeFromQueue(player, notifyClient)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil
	cancelFillTimer(modeId)

	if notifyClient then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
	broadcastQueueUpdate(modeId)
	return modeId
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player, true)
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	local queue = queues[modeId]
	local config = getModeConfig(modeId)
	if #queue >= config.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerQueue[player] = modeId

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
	broadcastQueueUpdate(modeId)

	if countQueue(modeId) >= config.maxPlayers then
		MatchmakingService.tryStartMatch(modeId)
	elseif countQueue(modeId) >= config.minPlayers and config.fillTimeout > 0 then
		startFillTimer(modeId)
	elseif countQueue(modeId) >= config.minPlayers and config.fillTimeout <= 0 then
		MatchmakingService.tryStartMatch(modeId)
	end

	return true
end

function MatchmakingService.tryStartMatch(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]

	if #queue < config.minPlayers then
		return false
	end

	if arenaBusy then
		for _, player in queue do
			if player.Parent then
				Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
			end
		end
		return false
	end

	cancelFillTimer(modeId)

	local matchPlayers = {}
	for i = 1, math.min(#queue, config.maxPlayers) do
		table.insert(matchPlayers, queue[i])
	end

	for _, player in matchPlayers do
		removeFromQueue(player, false)
	end

	arenaBusy = true
	for _, player in matchPlayers do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, {
				inQueue = true,
				modeId = modeId,
				modeLabel = config.label,
				status = MatchmakingConfig.QUEUE_STATUS.Starting,
				players = #matchPlayers,
				minPlayers = config.minPlayers,
				maxPlayers = config.maxPlayers,
			})
		end
	end

	Bindables.MatchReady:Fire({
		mode = modeId,
		players = matchPlayers,
	})

	return true
end

function MatchmakingService.onMatchEnded()
	arenaBusy = false
	for modeId in queues do
		broadcastQueueUpdate(modeId)
		local config = getModeConfig(modeId)
		if countQueue(modeId) >= config.minPlayers then
			MatchmakingService.tryStartMatch(modeId)
		end
	end
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

return MatchmakingService
