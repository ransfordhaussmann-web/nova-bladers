local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, Bindables
local HubService

local queues = {}
local playerQueue = {}
local fillTimers = {}
local fillDeadline = {}
local pendingLaunch = {}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function isValidMode(modeId)
	return MatchModes.get(modeId) ~= nil
end

local function getModeLabel(modeId)
	local mode = MatchModes.get(modeId)
	return mode and mode.label or modeId
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local queue = getQueue(entry.modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return { inQueue = false }
	end

	local queue = getQueue(modeId)
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local pending = pendingLaunch[modeId] == true
	local fillTimeLeft = nil
	if fillDeadline[modeId] then
		fillTimeLeft = math.max(0, math.ceil(fillDeadline[modeId] - os.clock()))
	end

	return {
		inQueue = position > 0,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queued = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = pending and MatchStateService.isArenaBusy(),
		fillTimeLeft = fillTimeLeft,
	}
end

local function sendQueueUpdate(player)
	local entry = playerQueue[player]
	if not entry then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, entry.modeId))
end

local function broadcastQueueUpdate(modeId)
	local queue = getQueue(modeId)
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			sendQueueUpdate(queuedPlayer)
		end
	end
end

local function cancelFillTimer(modeId)
	fillTimers[modeId] = nil
	fillDeadline[modeId] = nil
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
	return picked
end

local function launchMatch(modeId, players)
	if #players == 0 then
		return
	end

	pendingLaunch[modeId] = false
	cancelFillTimer(modeId)
	MatchStateService.setArenaBusy(true)

	for _, player in players do
		if HubService and HubService.getPhase(player) ~= "arena" then
			Remotes.QueueUpdate:FireClient(player, { inQueue = false, launching = true })
		end
	end

	Bindables.MatchReady:Fire({
		players = players,
		modeId = modeId,
	})
end

local function tryStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		pendingLaunch[modeId] = false
		cancelFillTimer(modeId)
		broadcastQueueUpdate(modeId)
		return
	end

	if MatchStateService.isArenaBusy() then
		pendingLaunch[modeId] = true
		broadcastQueueUpdate(modeId)
		return
	end

	if mode.id == "ffa" and #queue < mode.maxPlayers then
		if not fillTimers[modeId] then
			fillDeadline[modeId] = os.clock() + mode.fillTimeout
			fillTimers[modeId] = true
			task.delay(mode.fillTimeout, function()
				fillTimers[modeId] = nil
				fillDeadline[modeId] = nil
				if MatchStateService.isArenaBusy() then
					pendingLaunch[modeId] = true
					broadcastQueueUpdate(modeId)
					return
				end
				local currentQueue = getQueue(modeId)
				if #currentQueue >= mode.minPlayers then
					local players = popPlayers(modeId, math.min(#currentQueue, mode.maxPlayers))
					launchMatch(modeId, players)
					broadcastQueueUpdate(modeId)
					MatchmakingService.processAllQueues()
				end
			end)
			broadcastQueueUpdate(modeId)
		end
		return
	end

	local players = popPlayers(modeId, mode.maxPlayers)
	launchMatch(modeId, players)
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.processAllQueues()
	for _, mode in MatchModes.all() do
		tryStartMode(mode.id)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false, "invalid_mode"
	end
	if MatchStateService.isArenaBusy() and playerQueue[player] then
		-- allow re-join to switch modes while waiting
	end
	if HubService and HubService.getPhase(player) == "arena" then
		return false, "in_match"
	end

	removeFromQueue(player)
	table.insert(getQueue(modeId), player)
	playerQueue[player] = { modeId = modeId, joinedAt = os.clock() }

	sendQueueUpdate(player)
	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		sendQueueUpdate(player)
		return
	end

	local modeId = playerQueue[player].modeId
	removeFromQueue(player)

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if mode and #queue < mode.minPlayers then
		pendingLaunch[modeId] = false
		cancelFillTimer(modeId)
	end

	sendQueueUpdate(player)
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	for modeId in queues do
		pendingLaunch[modeId] = false
	end
	task.defer(MatchmakingService.processAllQueues)
end

function MatchmakingService.getPlayerMode(player)
	local entry = playerQueue[player]
	return entry and entry.modeId
end

function MatchmakingService.init(deps)
	Remotes, Bindables = RemotesSetup.ensure()
	HubService = deps.hubService

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
