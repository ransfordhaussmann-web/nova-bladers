local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local pendingStarts = {}
local hubCallbacks = {}

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

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local pending = pendingStarts[modeId] == true

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		queued = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = pending,
		arenaBusy = MatchStateService.isBusy(),
	}
end

local function broadcastQueueUpdate()
	for _, player in Players:GetPlayers() do
		if playerQueue[player] and player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
		end
	end
end

local function leaveHubForQueuedPlayers(playerList)
	for _, player in playerList do
		if hubCallbacks.leaveHubForArena and player.Parent then
			hubCallbacks.leaveHubForArena(player)
		end
	end
end

local function popPlayers(modeId, count)
	local queue = getQueue(modeId)
	local picked = {}
	for i = 1, math.min(count, #queue) do
		table.insert(picked, queue[1])
		playerQueue[queue[1]] = nil
		table.remove(queue, 1)
	end
	return picked
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if MatchStateService.isBusy() then
		pendingStarts[modeId] = true
		broadcastQueueUpdate()
		return
	end

	pendingStarts[modeId] = false
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end

	local playerCount = math.min(#queue, mode.maxPlayers)
	local players = popPlayers(modeId, playerCount)

	if #players == 0 then
		return
	end

	leaveHubForQueuedPlayers(players)
	MatchReady:Fire(players, modeId)
	broadcastQueueUpdate()
end

local function scheduleFillTimeout(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
	end

	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		tryStartMatch(modeId)
	end)
end

local function onPlayerJoinedQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	removeFromQueue(player)
	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId

	broadcastQueueUpdate()

	if modeId == "training" and #getQueue(modeId) >= 1 then
		tryStartMatch(modeId)
	elseif modeId == "pvp" and #getQueue(modeId) >= mode.maxPlayers then
		tryStartMatch(modeId)
	elseif modeId == "ffa" then
		if #getQueue(modeId) >= mode.maxPlayers then
			tryStartMatch(modeId)
		elseif #getQueue(modeId) >= mode.minPlayers then
			scheduleFillTimeout(modeId)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return
	end
	if hubCallbacks.getPhase and hubCallbacks.getPhase(player) ~= "hub" then
		return
	end
	onPlayerJoinedQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

function MatchmakingService.getSuggestedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.init(callbacks)
	hubCallbacks = callbacks or {}

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaFree(function()
		for _, mode in MatchModes.all() do
			local modeId = mode.id
			if pendingStarts[modeId] or #getQueue(modeId) >= mode.minPlayers then
				tryStartMatch(modeId)
			end
		end
	end)
end

return MatchmakingService
