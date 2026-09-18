local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local fillTokens = {}

local function getQueueSize(modeId)
	return #queues[modeId]
end

local function getQueueNames(modeId)
	local names = {}
	for _, player in queues[modeId] do
		if player.Parent then
			table.insert(names, player.DisplayName)
		end
	end
	return names
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, p in queue do
		if p == player then
			table.remove(queue, i)
			break
		end
	end
	playerQueue[player] = nil
end

local function buildStatus(player, modeId)
	local mode = MatchModes.get(modeId)
	local queueSize = getQueueSize(modeId)
	local pending = MatchStateService.isBusy()
	local status = "waiting"

	if pending then
		status = "pending"
	elseif modeId == "training" and queueSize >= mode.minPlayers then
		status = "ready"
	elseif modeId == "pvp" and queueSize >= mode.minPlayers then
		status = "ready"
	elseif modeId == "ffa" and queueSize >= mode.minPlayers then
		status = fillTimers[modeId] and "filling" or "ready"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		queueSize = queueSize,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		pending = pending,
		players = getQueueNames(modeId),
		fillTimeout = mode.fillTimeout,
	}
end

local function broadcastQueue(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildStatus(player, modeId))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	fillTimers[modeId] = nil
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]
	fillTimers[modeId] = true
	broadcastQueue(modeId)

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		MatchmakingService.tryStartMatch(modeId, true)
	end)
end

local function popPlayers(modeId, count)
	local popped = {}
	local queue = queues[modeId]
	while #popped < count and #queue > 0 do
		local player = table.remove(queue, 1)
		if player.Parent then
			playerQueue[player] = nil
			table.insert(popped, player)
		end
	end
	return popped
end

function MatchmakingService.tryStartMatch(modeId, forceStart)
	if MatchStateService.isBusy() then
		broadcastQueue(modeId)
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queueSize = getQueueSize(modeId)
	if queueSize < mode.minPlayers then
		return
	end

	if modeId == "ffa" and not forceStart then
		if queueSize >= mode.maxPlayers then
			cancelFillTimer(modeId)
		elseif fillTimers[modeId] then
			return
		elseif queueSize >= mode.minPlayers then
			startFillTimer(modeId)
			return
		end
	end

	cancelFillTimer(modeId)

	local count = math.min(queueSize, mode.maxPlayers)
	local matched = popPlayers(modeId, count)
	if #matched < mode.minPlayers then
		for _, player in matched do
			table.insert(queues[modeId], player)
			playerQueue[player] = modeId
		end
		return
	end

	MatchStateService.setBusy(true)
	MatchReady:Fire(modeId, matched)
	broadcastAllQueues()
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.get(modeId) then
		return
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	Remotes.QueueUpdate:FireClient(player, buildStatus(player, modeId))
	MatchmakingService.tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueue(player)

	if modeId == "ffa" and getQueueSize(modeId) < MatchModes.get(modeId).minPlayers then
		cancelFillTimer(modeId)
	end

	broadcastQueue(modeId)
	Remotes.QueueUpdate:FireClient(player, { status = "idle" })
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setBusy(false)
	task.defer(function()
		for modeId in queues do
			MatchmakingService.tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
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
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
