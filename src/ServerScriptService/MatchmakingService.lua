local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerMode = {}
local fillTimers = {}
local pendingMatch = nil
local callbacks = {}

local function initQueues()
	for _, mode in MatchModes.all() do
		queues[mode.id] = {}
	end
end

local function getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function resolveModeId(modeId)
	if modeId and MatchModes.get(modeId) then
		return modeId
	end
	return getRecommendedModeId()
end

local function queueCount(modeId)
	local queue = queues[modeId]
	if not queue then
		return 0
	end
	local count = 0
	for player in queue do
		if player.Parent then
			count += 1
		end
	end
	return count
end

local function orderedPlayers(modeId)
	local list = {}
	for player in queues[modeId] or {} do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function buildQueuePayload(player, modeId, status)
	local mode = MatchModes.get(modeId)
	if not mode then
		return { inQueue = false }
	end

	local players = orderedPlayers(modeId)
	local position = 0
	for i, queued in players do
		if queued == player then
			position = i
			break
		end
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		queued = #players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		position = position,
		status = status or "waiting",
	}
end

local function broadcastQueue(modeId, status)
	for player in queues[modeId] or {} do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, status))
		end
	end
end

local function clearFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
end

local function removeFromAllQueues(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	if queue then
		queue[player] = nil
	end
	playerMode[player] = nil
	clearFillTimer(modeId)

	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
	broadcastQueue(modeId, "waiting")
end

local function takePlayers(modeId, count)
	local taken = {}
	local queue = queues[modeId]
	if not queue then
		return taken
	end

	for player in queue do
		if player.Parent and #taken < count then
			queue[player] = nil
			playerMode[player] = nil
			table.insert(taken, player)
		end
	end

	clearFillTimer(modeId)
	broadcastQueue(modeId, "waiting")
	return taken
end

local function launchMatch(modeId, players)
	if #players == 0 then
		return
	end

	if MatchStateService.isArenaBusy() then
		pendingMatch = { modeId = modeId, players = players }
		for _, player in players do
			if player.Parent then
				Remotes.QueueUpdate:FireClient(player, {
					inQueue = true,
					modeId = modeId,
					modeLabel = MatchModes.get(modeId).label,
					queued = #players,
					status = "pending",
				})
			end
		end
		return
	end

	for _, player in players do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, {
				inQueue = true,
				modeId = modeId,
				modeLabel = MatchModes.get(modeId).label,
				queued = #players,
				status = "starting",
			})
		end
	end

	if callbacks.onMatchReady then
		callbacks.onMatchReady(players, modeId)
	end
end

local function tryStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local players = orderedPlayers(modeId)
	if #players < mode.minPlayers then
		return
	end

	if mode.fillTimeout and #players < mode.maxPlayers then
		if not fillTimers[modeId] then
			local token = {}
			fillTimers[modeId] = token
			task.delay(mode.fillTimeout, function()
				if fillTimers[modeId] ~= token then
					return
				end
				fillTimers[modeId] = nil
				local ready = orderedPlayers(modeId)
				if #ready >= mode.minPlayers then
					local count = math.min(#ready, mode.maxPlayers)
					launchMatch(modeId, takePlayers(modeId, count))
				end
			end)
		end
		return
	end

	local count = math.min(#players, mode.maxPlayers)
	launchMatch(modeId, takePlayers(modeId, count))
end

local function tryStartAllModes()
	for _, mode in MatchModes.all() do
		tryStartMode(mode.id)
	end
end

function MatchmakingService.join(player, modeId)
	if not player or not player.Parent then
		return
	end

	modeId = resolveModeId(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if callbacks.getPlayerPhase and callbacks.getPlayerPhase(player) == "arena" then
		return
	end

	removeFromAllQueues(player)

	local queue = queues[modeId]
	queue[player] = true
	playerMode[player] = modeId

	if callbacks.onPlayerQueued then
		callbacks.onPlayerQueued(player, modeId)
	end

	broadcastQueue(modeId, "waiting")
	tryStartMode(modeId)
end

function MatchmakingService.leave(player)
	removeFromAllQueues(player)
	if callbacks.onPlayerLeftQueue then
		callbacks.onPlayerLeftQueue(player)
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.notifyArenaFreed()
	MatchStateService.setArenaBusy(false)

	if pendingMatch then
		local match = pendingMatch
		pendingMatch = nil
		launchMatch(match.modeId, match.players)
		return
	end

	tryStartAllModes()
end

function MatchmakingService.getRecommendedModeId()
	return getRecommendedModeId()
end

function MatchmakingService.start(opts)
	Remotes, Bindables = RemotesSetup.ensure()
	callbacks = opts or {}
	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.join(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leave(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromAllQueues(player)
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
