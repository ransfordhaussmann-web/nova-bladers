local Players = game:GetService("Players")
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
local fillTimers = {}
local pendingStarts = {}
local leaveHubForArena
local getPlayerPhase

local function getQueueList(modeId)
	return queues[modeId]
end

local function countValidPlayers(queue)
	local count = 0
	for _, player in queue do
		if player.Parent then
			count += 1
		end
	end
	return count
end

local function pruneQueue(modeId)
	local queue = getQueueList(modeId)
	local cleaned = {}
	for _, player in queue do
		if player.Parent and playerQueue[player] == modeId then
			table.insert(cleaned, player)
		elseif playerQueue[player] == modeId then
			playerQueue[player] = nil
		end
	end
	queues[modeId] = cleaned
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	pruneQueue(modeId)
	local queue = getQueueList(modeId)
	local names = {}
	for _, queuedPlayer in queue do
		table.insert(names, queuedPlayer.DisplayName)
	end

	local count = #names
	local status = "waiting"
	if pendingStarts[modeId] then
		status = "pending"
	elseif modeId == "ffa" and fillTimers[modeId] then
		status = "filling"
	end

	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		count = count,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		players = names,
		status = status,
		fillTimeout = modeId == "ffa" and MatchmakingConfig.FFA_FILL_TIMEOUT or nil,
		inQueue = player ~= nil,
	}
end

local function broadcastQueue(modeId)
	pruneQueue(modeId)
	local queue = getQueueList(modeId)
	local seen = {}
	for _, player in queue do
		if player.Parent and not seen[player] then
			seen[player] = true
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
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

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end
	pruneQueue(modeId)
	local count = countValidPlayers(getQueueList(modeId))
	return count >= mode.minPlayers and count <= mode.maxPlayers
end

local function takePlayersForMatch(modeId)
	pruneQueue(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueueList(modeId)
	local taken = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		local player = queue[i]
		if player.Parent then
			table.insert(taken, player)
		end
	end

	queues[modeId] = {}
	clearFillTimer(modeId)
	pendingStarts[modeId] = nil

	for _, player in taken do
		playerQueue[player] = nil
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end

	broadcastAllQueues()
	return taken
end

local function getDefaultModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function launchMatch(modeId)
	if not canStartMode(modeId) then
		return
	end
	if MatchStateService.isArenaBusy() then
		pendingStarts[modeId] = true
		broadcastQueue(modeId)
		return
	end

	pendingStarts[modeId] = nil
	local players = takePlayersForMatch(modeId)
	if #players == 0 then
		return
	end

	for _, player in players do
		if leaveHubForArena then
			leaveHubForArena(player)
		end
	end

	MatchReady:Fire({
		mode = modeId,
		players = players,
	})
end

local function scheduleFillTimer(modeId)
	if fillTimers[modeId] then
		return
	end
	fillTimers[modeId] = task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		fillTimers[modeId] = nil
		launchMatch(modeId)
	end)
end

local function evaluateMode(modeId)
	if not MatchModes.get(modeId) then
		return
	end
	pruneQueue(modeId)
	local mode = MatchModes.get(modeId)
	local count = countValidPlayers(getQueueList(modeId))

	if count < mode.minPlayers then
		clearFillTimer(modeId)
		pendingStarts[modeId] = nil
		broadcastQueue(modeId)
		return
	end

	if modeId == "ffa" then
		if count >= mode.maxPlayers then
			clearFillTimer(modeId)
			launchMatch(modeId)
			return
		end
		scheduleFillTimer(modeId)
		broadcastQueue(modeId)
		return
	end

	launchMatch(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		modeId = getDefaultModeId()
	end
	local mode = MatchModes.get(modeId)
	if getPlayerPhase and getPlayerPhase(player) == "arena" then
		return false, "in_match"
	end
	local existingMode = playerQueue[player]
	if existingMode and existingMode ~= modeId then
		MatchmakingService.leaveQueue(player)
	end

	playerQueue[player] = modeId
	queues[modeId] = getQueueList(modeId)
	local alreadyQueued = false
	for _, queuedPlayer in queues[modeId] do
		if queuedPlayer == player then
			alreadyQueued = true
			break
		end
	end
	if not alreadyQueued then
		table.insert(queues[modeId], player)
	end

	broadcastQueue(modeId)
	evaluateMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	playerQueue[player] = nil
	local queue = getQueueList(modeId)
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end

	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	evaluateMode(modeId)
end

function MatchmakingService.getQueueMode(player)
	return playerQueue[player]
end

function MatchmakingService.start(handlers)
	leaveHubForArena = handlers.leaveHubForArena
	getPlayerPhase = handlers.getPlayerPhase

	local bindables
	Remotes, bindables = RemotesSetup.ensure()
	MatchReady = bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaIdle(function()
		for modeId in queues do
			if pendingStarts[modeId] or canStartMode(modeId) then
				task.defer(function()
					evaluateMode(modeId)
				end)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
