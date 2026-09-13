local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(script.Parent.GameMatchState)

local MatchmakingService = {}

local queues = {}
local playerEntry = {}
local fillTokens = {}
local remotes
local bindables
local callbacks = {}

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function initQueues()
	for modeId in MatchmakingConfig.MODES do
		queues[modeId] = {}
	end
end

local function queueCount(modeId)
	return #(queues[modeId] or {})
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	playerEntry[player] = nil

	local queue = queues[modeId]
	if not queue then
		return
	end

	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	if queueCount(modeId) < (getMode(modeId) and getMode(modeId).minPlayers or 999) then
		cancelFillTimer(modeId)
	end
end

local function buildPlayerPayload(player)
	local entry = playerEntry[player]
	if not entry then
		return nil
	end

	local mode = getMode(entry.modeId)
	if not mode then
		return nil
	end

	local count = queueCount(entry.modeId)
	local status = "searching"
	if GameMatchState.isBusy() and count >= mode.minPlayers then
		status = "pending"
	end

	return {
		modeId = entry.modeId,
		modeLabel = mode.label,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		inQueue = true,
	}
end

local function broadcastQueue(player)
	if not remotes or not remotes.QueueUpdate then
		return
	end

	local payload = buildPlayerPayload(player)
	if payload then
		remotes.QueueUpdate:FireClient(player, payload)
	else
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function broadcastQueueForMode(modeId)
	for player, entry in playerEntry do
		if entry.modeId == modeId and player.Parent then
			broadcastQueue(player)
		end
	end
end

local function popPlayers(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	if not queue or not mode then
		return {}
	end

	local take = math.min(#queue, mode.maxPlayers)
	local picked = {}
	for index = 1, take do
		table.insert(picked, queue[index])
	end

	for index = take, 1, -1 do
		local player = table.remove(queue, index)
		playerEntry[player] = nil
	end

	cancelFillTimer(modeId)
	return picked
end

local function startMatch(modeId)
	local mode = getMode(modeId)
	if not mode then
		return
	end

	if queueCount(modeId) < mode.minPlayers then
		return
	end

	if GameMatchState.isBusy() then
		broadcastQueueForMode(modeId)
		return
	end

	local players = popPlayers(modeId)
	if #players < mode.minPlayers then
		for _, player in players do
			MatchmakingService.joinQueue(player, modeId)
		end
		return
	end

	GameMatchState.setBusy(true)

	for _, player in players do
		remotes.QueueUpdate:FireClient(player, { inQueue = false, starting = true, modeLabel = mode.label })
	end

	if callbacks.onMatchStarting then
		callbacks.onMatchStarting(players, modeId)
	end

	if bindables and bindables.MatchReady then
		bindables.MatchReady:Fire(players, modeId)
	end
end

local function scheduleFillTimer(modeId)
	local mode = getMode(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	cancelFillTimer(modeId)
	local token = fillTokens[modeId] or 0
	fillTokens[modeId] = token

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		startMatch(modeId)
	end)
end

local function evaluateQueue(modeId)
	local mode = getMode(modeId)
	if not mode then
		return
	end

	local count = queueCount(modeId)
	if count < mode.minPlayers then
		return
	end

	broadcastQueueForMode(modeId)

	if modeId == "training" or modeId == "pvp" then
		startMatch(modeId)
	elseif modeId == "ffa" then
		if count >= mode.maxPlayers then
			startMatch(modeId)
		else
			scheduleFillTimer(modeId)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not getMode(modeId) then
		return
	end

	if playerEntry[player] and playerEntry[player].modeId == modeId then
		broadcastQueue(player)
		return
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerEntry[player] = { modeId = modeId, joinedAt = os.clock() }

	broadcastQueueForMode(modeId)
	evaluateQueue(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerEntry[player] then
		return
	end

	local modeId = playerEntry[player].modeId
	removeFromQueue(player)
	broadcastQueue(player)
	broadcastQueueForMode(modeId)
end

function MatchmakingService.onArenaFree()
	GameMatchState.setBusy(false)

	for modeId in MatchmakingConfig.MODES do
		evaluateQueue(modeId)
	end
end

function MatchmakingService.start(remoteFolder, bindableFolder, newCallbacks)
	remotes = remoteFolder
	bindables = bindableFolder
	callbacks = newCallbacks or {}

	initQueues()

	if remotes.QueueLeave then
		remotes.QueueLeave.OnServerEvent:Connect(function(player)
			MatchmakingService.leaveQueue(player)
		end)
	end

	if bindables and bindables.ArenaFree then
		bindables.ArenaFree.Event:Connect(function()
			MatchmakingService.onArenaFree()
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
