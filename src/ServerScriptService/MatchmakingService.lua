local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerMode = {}
local fillDeadlines = {}
local pendingStarts = {}
local lockedModes = {}
local started = false

local function initQueues()
	for _, mode in MatchModes.all() do
		queues[mode.id] = {}
	end
end

local function getQueueSize(modeId)
	return #(queues[modeId] or {})
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return nil
	end

	local queue = queues[modeId]
	if queue then
		for i, queuedPlayer in queue do
			if queuedPlayer == player then
				table.remove(queue, i)
				break
			end
		end
	end

	playerMode[player] = nil
	fillDeadlines[modeId] = nil
	return modeId
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local queue = queues[modeId] or {}
	local names = {}
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			table.insert(names, queuedPlayer.DisplayName)
		end
	end

	local status = "waiting"
	if MatchStateService.isArenaBusy() then
		status = "pending"
	elseif #queue >= mode.minPlayers then
		status = "ready"
	end

	local deadline = fillDeadlines[modeId]
	local secondsLeft = nil
	if deadline and mode.fillTimeout > 0 then
		secondsLeft = math.max(0, math.ceil(deadline - os.clock()))
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = names,
		count = #names,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		secondsLeft = secondsLeft,
		inQueue = player ~= nil,
	}
end

local function broadcastQueueUpdate(modeId)
	local payload = buildQueuePayload(modeId)
	if not payload then
		return
	end

	for _, queuedPlayer in queues[modeId] or {} do
		if queuedPlayer.Parent then
			local personal = table.clone(payload)
			personal.inQueue = true
			Remotes.QueueUpdate:FireClient(queuedPlayer, personal)
		end
	end
end

local function clearQueue(modeId)
	queues[modeId] = {}
	fillDeadlines[modeId] = nil
end

local function takeMatchPlayers(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return {}
	end

	local queue = queues[modeId] or {}
	local count = math.min(#queue, mode.maxPlayers)
	local matchPlayers = {}
	for i = 1, count do
		local queuedPlayer = queue[i]
		if queuedPlayer and queuedPlayer.Parent then
			table.insert(matchPlayers, queuedPlayer)
		end
	end
	return matchPlayers
end

function MatchmakingService.markPending(modeId)
	pendingStarts[modeId] = true
	lockedModes[modeId] = nil
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.confirmStart(modeId, matchPlayers)
	lockedModes[modeId] = nil
	for _, matchPlayer in matchPlayers do
		removeFromQueue(matchPlayer)
	end
	if getQueueSize(modeId) == 0 then
		fillDeadlines[modeId] = nil
	end
	pendingStarts[modeId] = nil
end

local function fireMatchReady(modeId, matchPlayers)
	if #matchPlayers == 0 then
		return
	end

	Bindables.MatchReady:Fire({
		mode = modeId,
		players = matchPlayers,
	})
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if MatchStateService.isArenaBusy() then
		pendingStarts[modeId] = true
		broadcastQueueUpdate(modeId)
		return
	end

	if lockedModes[modeId] then
		return
	end

	local queue = queues[modeId] or {}
	if #queue < mode.minPlayers then
		return
	end

	if #queue >= mode.maxPlayers then
		local matchPlayers = takeMatchPlayers(modeId)
		lockedModes[modeId] = true
		fireMatchReady(modeId, matchPlayers)
		return
	end

	local deadline = fillDeadlines[modeId]
	if deadline and os.clock() >= deadline and #queue >= mode.minPlayers then
		local matchPlayers = takeMatchPlayers(modeId)
		lockedModes[modeId] = true
		fireMatchReady(modeId, matchPlayers)
		return
	end

	if #queue >= mode.minPlayers and mode.fillTimeout <= 0 then
		local matchPlayers = takeMatchPlayers(modeId)
		lockedModes[modeId] = true
		fireMatchReady(modeId, matchPlayers)
	end
end

local function scheduleFillDeadline(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or mode.fillTimeout <= 0 then
		fillDeadlines[modeId] = nil
		return
	end

	if fillDeadlines[modeId] then
		return
	end

	fillDeadlines[modeId] = os.clock() + mode.fillTimeout
	task.delay(mode.fillTimeout, function()
		tryStartMatch(modeId)
	end)
end

function MatchmakingService.getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false, "invalid_mode"
	end

	if MatchStateService.isArenaBusy() and playerMode[player] then
		-- allow re-join while pending
	end

	removeFromQueue(player)

	local queue = queues[modeId]
	table.insert(queue, player)
	playerMode[player] = modeId

	scheduleFillDeadline(modeId)
	broadcastQueueUpdate(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromQueue(player)
	if modeId then
		Remotes.QueueUpdate:FireClient(player, {
			modeId = modeId,
			inQueue = false,
			status = "left",
		})
		broadcastQueueUpdate(modeId)
	end
end

function MatchmakingService.leaveAllQueues(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.processPendingQueues()
	if MatchStateService.isArenaBusy() then
		return
	end

	for modeId, isPending in pendingStarts do
		if isPending then
			pendingStarts[modeId] = nil
			tryStartMatch(modeId)
		end
	end

	for _, mode in MatchModes.all() do
		if getQueueSize(mode.id) >= mode.minPlayers then
			tryStartMatch(mode.id)
		end
	end
end

function MatchmakingService.onArenaFree()
	MatchStateService.setArenaBusy(false)
	MatchmakingService.processPendingQueues()
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getRecommendedModeId()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaFree(function()
		MatchmakingService.processPendingQueues()
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			for modeId in queues do
				if getQueueSize(modeId) > 0 then
					broadcastQueueUpdate(modeId)
					tryStartMatch(modeId)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
