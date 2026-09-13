local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(ReplicatedStorage.NovaBladers.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes
local MatchReady
local ArenaFree

local queues = {}
local playerEntry = {}
local fillTimers = {}
local started = false

local function initQueues()
	for _, mode in MatchModes.all() do
		queues[mode.id] = {}
	end
end

local function getQueueSize(modeId)
	return #(queues[modeId] or {})
end

local function buildUpdatePayload(player, modeId, status)
	local mode = MatchModes.get(modeId)
	local queueSize = getQueueSize(modeId)
	return {
		status = status,
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		queueSize = queueSize,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		arenaBusy = GameMatchState.isBusy(),
	}
end

local function sendUpdate(player, modeId, status)
	if not player.Parent then
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player, modeId, status))
end

local function broadcastQueue(modeId)
	for _, entry in queues[modeId] or {} do
		local status = if GameMatchState.isBusy() then "pending" else "queued"
		sendUpdate(entry.player, modeId, status)
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	local queue = queues[modeId]
	if queue then
		for i, queued in queue do
			if queued.player == player then
				table.remove(queue, i)
				break
			end
		end
	end

	playerEntry[player] = nil
	sendUpdate(player, modeId, "left")
	broadcastQueue(modeId)

	local mode = MatchModes.get(modeId)
	if mode and getQueueSize(modeId) < mode.minPlayers then
		clearFillTimer(modeId)
	end
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for i = 1, math.min(count, #queue) do
		local entry = table.remove(queue, 1)
		if entry and entry.player.Parent then
			table.insert(picked, entry.player)
			playerEntry[entry.player] = nil
		end
	end
	return picked
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queueSize = getQueueSize(modeId)
	if queueSize < mode.minPlayers then
		return
	end

	if GameMatchState.isBusy() then
		broadcastQueue(modeId)
		return
	end

	local playerCount = math.min(queueSize, mode.maxPlayers)
	local matched = popPlayers(modeId, playerCount)
	if #matched < mode.minPlayers then
		for _, player in matched do
			MatchmakingService.joinQueue(player, modeId)
		end
		return
	end

	clearFillTimer(modeId)
	GameMatchState.setBusy(true)

	for _, player in matched do
		sendUpdate(player, modeId, "matchFound")
	end

	MatchReady:Fire(matched, modeId)
end

local function scheduleFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout or fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		if getQueueSize(modeId) >= mode.minPlayers then
			tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.get(modeId) then
		modeId = MatchmakingConfig.DEFAULT_MODE
	end

	if playerEntry[player] then
		removeFromQueue(player)
	end

	table.insert(queues[modeId], { player = player })
	playerEntry[player] = { modeId = modeId }

	local status = if GameMatchState.isBusy() then "pending" else "queued"
	sendUpdate(player, modeId, status)
	broadcastQueue(modeId)

	local mode = MatchModes.get(modeId)
	if getQueueSize(modeId) >= mode.maxPlayers then
		tryStartMatch(modeId)
	elseif getQueueSize(modeId) >= mode.minPlayers and not mode.fillTimeout then
		tryStartMatch(modeId)
	elseif getQueueSize(modeId) >= mode.minPlayers and mode.fillTimeout then
		scheduleFillTimer(modeId)
	end
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player)
end

function MatchmakingService.isQueued(player)
	return playerEntry[player] ~= nil
end

function MatchmakingService.getQueuedMode(player)
	local entry = playerEntry[player]
	return entry and entry.modeId
end

function MatchmakingService.onArenaFree()
	GameMatchState.setBusy(false)

	for modeId in queues do
		local mode = MatchModes.get(modeId)
		if mode and getQueueSize(modeId) >= mode.minPlayers then
			if mode.fillTimeout and not fillTimers[modeId] then
				scheduleFillTimer(modeId)
			elseif not mode.fillTimeout then
				tryStartMatch(modeId)
			end
		else
			broadcastQueue(modeId)
		end
	end
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	local bindables
	Remotes, bindables = RemotesSetup.ensure()
	MatchReady = bindables.MatchReady
	ArenaFree = bindables.ArenaFree

	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingConfig.DEFAULT_MODE
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
