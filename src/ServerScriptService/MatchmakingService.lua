local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerQueue = {}
local fillTimers = {}
local fillStartedAt = {}
local deps = {}

local function getMode(modeId)
	return MatchModes[modeId]
end

local function queueSize(modeId)
	local queue = queues[modeId]
	if not queue then
		return 0
	end
	return #queue
end

local function playerInQueue(player)
	return playerQueue[player] ~= nil
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	local mode = getMode(modeId)
	if mode and queueSize(modeId) < mode.minPlayers then
		fillStartedAt[modeId] = nil
	end
end

local function buildQueuePayload(modeId, player)
	local mode = getMode(modeId)
	if not mode then
		return { inQueue = false }
	end

	local count = queueSize(modeId)
	local status = "waiting"
	if MatchStateService.isBusy() then
		status = "pending"
	elseif mode.fillTimeout and count >= mode.minPlayers then
		status = "filling"
	end

	local fillSecondsLeft = nil
	if status == "filling" and fillStartedAt[modeId] then
		local elapsed = os.clock() - fillStartedAt[modeId]
		fillSecondsLeft = math.max(0, math.ceil(mode.fillTimeout - elapsed))
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		players = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillSecondsLeft = fillSecondsLeft,
		isYou = player ~= nil,
	}
end

local function broadcastQueueUpdate(modeId)
	local payload = buildQueuePayload(modeId)
	for _, queuedPlayer in queues[modeId] do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, payload)
		end
	end
end

local function clearQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function leaveHubForMatch(player)
	if deps.leaveHubForArena then
		deps.leaveHubForArena(player)
	end
end

local function popPlayersForMatch(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local nextPlayer = table.remove(queue, 1)
		if nextPlayer and nextPlayer.Parent then
			playerQueue[nextPlayer] = nil
			table.insert(picked, nextPlayer)
		end
	end
	fillStartedAt[modeId] = nil
	return picked
end

local function startMatch(modeId, playerList)
	for _, player in playerList do
		leaveHubForMatch(player)
		clearQueueUpdate(player)
	end

	Bindables.MatchReady:Fire({
		mode = modeId,
		players = playerList,
	})

	broadcastQueueUpdate(modeId)
end

local function canStartMode(modeId)
	local mode = getMode(modeId)
	if not mode then
		return false, 0
	end

	local count = queueSize(modeId)
	if count < mode.minPlayers then
		return false, 0
	end

	if count >= mode.maxPlayers then
		return true, mode.maxPlayers
	end

	if mode.fillTimeout and fillStartedAt[modeId] then
		local elapsed = os.clock() - fillStartedAt[modeId]
		if elapsed >= mode.fillTimeout then
			return true, count
		end
	end

	if not mode.fillTimeout and count >= mode.minPlayers then
		return true, count
	end

	return false, 0
end

local function tryStartQueue(modeId)
	if MatchStateService.isBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	local ready, playerCount = canStartMode(modeId)
	if not ready or playerCount <= 0 then
		broadcastQueueUpdate(modeId)
		return
	end

	local players = popPlayersForMatch(modeId, playerCount)
	if #players == 0 then
		return
	end

	startMatch(modeId, players)
end

local function tryStartAllQueues()
	for modeId in MatchModes do
		tryStartQueue(modeId)
	end
end

local function ensureFillTimer(modeId)
	local mode = getMode(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	if queueSize(modeId) < mode.minPlayers then
		fillStartedAt[modeId] = nil
		return
	end

	if not fillStartedAt[modeId] then
		fillStartedAt[modeId] = os.clock()
	end

	if fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = task.delay(mode.fillTimeout + 0.05, function()
		fillTimers[modeId] = nil
		tryStartQueue(modeId)
	end)
end

local function joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end

	local mode = getMode(modeId)
	if not mode then
		return
	end

	if deps.getPhase and deps.getPhase(player) == "arena" then
		return
	end

	if playerInQueue(player) then
		removeFromQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	ensureFillTimer(modeId)
	tryStartQueue(modeId)
	broadcastQueueUpdate(modeId)
end

local function leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		clearQueueUpdate(player)
		return
	end

	removeFromQueue(player)
	clearQueueUpdate(player)
	broadcastQueueUpdate(modeId)
end

local function joinQuickMatch(player)
	local modeId = "training"
	if deps.getQuickMatchModeId then
		modeId = deps.getQuickMatchModeId()
	end
	joinQueue(player, modeId)
end

function MatchmakingService.init(hubDeps)
	deps = hubDeps
	Remotes, Bindables = RemotesSetup.ensure()

	for modeId in MatchModes do
		queues[modeId] = {}
	end

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if modeId == "quick" then
			joinQuickMatch(player)
		else
			joinQueue(player, modeId)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		leaveQueue(player)
	end)

	MatchStateService.onArenaFree(function()
		task.delay(MatchmakingConfig.ARENA_BUSY_RETRY_DELAY, tryStartAllQueues)
	end)

	if hubDeps.hub and hubDeps.hub.modePads then
		for _, pad in hubDeps.hub.modePads do
			if pad.prompt then
				pad.prompt.Triggered:Connect(function(player)
					joinQueue(player, pad.config.id)
				end)
			end
		end
	end

	if hubDeps.hub and hubDeps.hub.portalPrompt then
		hubDeps.hub.portalPrompt.Triggered:Connect(function(player)
			joinQuickMatch(player)
		end)
	end

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			for modeId in MatchModes do
				if queueSize(modeId) > 0 then
					broadcastQueueUpdate(modeId)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue ready")
end

function MatchmakingService.joinQuickMatch(player)
	joinQuickMatch(player)
end

return MatchmakingService
