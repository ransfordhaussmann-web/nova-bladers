local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(script.Parent.GameMatchState)

local MatchmakingService = {}

local queues = {}
local playerMode = {}
local fillTimers = {}
local pendingModes = {}
local remotes = nil
local bindables = nil
local getActiveModeId = nil
local leaveHubForArena = nil

local function initQueues()
	for modeId in pairs(MatchmakingConfig.MODES) do
		queues[modeId] = {}
	end
end

local function getQueueList(modeId)
	local list = {}
	for _, player in queues[modeId] do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function getPlayerNameList(modeId)
	local names = {}
	for _, player in getQueueList(modeId) do
		table.insert(names, player.DisplayName)
	end
	return names
end

local function buildUpdatePayload(modeId, status)
	local mode = MatchmakingConfig.getMode(modeId)
	local count = #getQueueList(modeId)
	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		count = count,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		status = status or "waiting",
		players = getPlayerNameList(modeId),
		arenaBusy = GameMatchState.isBusy(),
	}
end

local function fireQueueUpdate(modeId, status)
	local payload = buildUpdatePayload(modeId, status)
	for _, player in getQueueList(modeId) do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queued in ipairs(queue) do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	playerMode[player] = nil
	clearFillTimer(modeId)

	if #getQueueList(modeId) == 0 then
		pendingModes[modeId] = nil
	end

	fireQueueUpdate(modeId, "waiting")
end

local function canStartMode(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return false
	end

	local count = #getQueueList(modeId)
	if count < mode.minPlayers then
		return false
	end
	if count >= mode.maxPlayers then
		return true
	end
	if mode.fillTimeout <= 0 then
		return true
	end
	return false
end

local function popPlayersForMatch(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueueList(modeId)
	local take = math.min(#queue, mode.maxPlayers)
	local matchPlayers = {}

	for i = 1, take do
		local player = queue[i]
		table.insert(matchPlayers, player)
		playerMode[player] = nil
	end

	queues[modeId] = {}
	for i = take + 1, #queue do
		table.insert(queues[modeId], queue[i])
	end

	clearFillTimer(modeId)
	pendingModes[modeId] = nil
	return matchPlayers
end

local function startMatch(modeId)
	if GameMatchState.isBusy() then
		pendingModes[modeId] = true
		fireQueueUpdate(modeId, "pending")
		return
	end

	local matchPlayers = popPlayersForMatch(modeId)
	if #matchPlayers == 0 then
		return
	end

	for _, player in matchPlayers do
		if leaveHubForArena then
			leaveHubForArena(player)
		end
	end

	fireQueueUpdate(modeId, "starting")
	bindables.MatchReady:Fire(matchPlayers, modeId)
end

local function scheduleFillTimer(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode or mode.fillTimeout <= 0 or fillTimers[modeId] then
		return
	end

	local count = #getQueueList(modeId)
	if count < mode.minPlayers then
		return
	end

	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		if canStartMode(modeId) or #getQueueList(modeId) >= mode.minPlayers then
			startMatch(modeId)
		end
	end)
end

local function tryStartMode(modeId)
	if canStartMode(modeId) then
		startMatch(modeId)
		return
	end

	local mode = MatchmakingConfig.getMode(modeId)
	local count = #getQueueList(modeId)
	if mode and count >= mode.minPlayers then
		scheduleFillTimer(modeId)
	end
end

local function onArenaFree()
	for modeId in pairs(MatchmakingConfig.MODES) do
		if pendingModes[modeId] or canStartMode(modeId) then
			tryStartMode(modeId)
		else
			fireQueueUpdate(modeId, "waiting")
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchmakingConfig.getMode(modeId) then
		modeId = getActiveModeId and getActiveModeId() or "training"
	end

	if playerMode[player] == modeId then
		local status = GameMatchState.isBusy() and "pending" or "waiting"
		remotes.QueueUpdate:FireClient(player, buildUpdatePayload(modeId, status))
		return
	end

	MatchmakingService.leaveQueue(player)

	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	local status = GameMatchState.isBusy() and "pending" or "waiting"
	fireQueueUpdate(modeId, status)
	tryStartMode(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end
	removeFromQueue(player)
	remotes.QueueUpdate:FireClient(player, {
		modeId = nil,
		status = "left",
	})
end

function MatchmakingService.isQueued(player)
	return playerMode[player] ~= nil
end

function MatchmakingService.start(options)
	remotes = options.remotes
	bindables = options.bindables
	getActiveModeId = options.getActiveModeId
	leaveHubForArena = options.leaveHubForArena

	initQueues()

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	bindables.ArenaFree.Event:Connect(onArenaFree)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
