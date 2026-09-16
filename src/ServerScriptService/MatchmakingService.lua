local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {}
local playerMode = {}
local fillTimers = {}
local pendingMatch = nil
local started = false

for _, mode in MatchModes.getAll() do
	queues[mode.id] = {}
end

local function getQueueCount(modeId)
	return #queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for index, queuedPlayer in ipairs(queue) do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	playerMode[player] = nil
end

local function buildQueuePayload(player)
	local modeId = playerMode[player]
	if not modeId then
		return nil
	end

	local mode = MatchModes.get(modeId)
	local count = getQueueCount(modeId)
	local pending = pendingMatch ~= nil and pendingMatch.modeId == modeId
	local status = "waiting"

	if pending then
		status = "pending"
	elseif modeId == "ffa" and count >= mode.minPlayers and fillTimers[modeId] then
		status = "filling"
	elseif count >= mode.maxPlayers then
		status = "ready"
	elseif count >= mode.minPlayers then
		status = "ready"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		arenaBusy = MatchStateService.isBusy(),
	}
end

local function broadcastQueueUpdate(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			local payload = buildQueuePayload(player)
			if payload then
				Remotes.QueueUpdate:FireClient(player, payload)
			end
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function canStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local count = getQueueCount(modeId)
	if count < mode.minPlayers then
		return false
	end
	if count >= mode.maxPlayers then
		return true
	end
	if modeId == "ffa" and fillTimers[modeId] then
		return true
	end
	if modeId ~= "ffa" and count >= mode.minPlayers then
		return true
	end
	return false
end

local function takePlayersForMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local count = math.min(#queue, mode.maxPlayers)
	local matchPlayers = {}

	for index = 1, count do
		local player = queue[index]
		table.insert(matchPlayers, player)
	end

	for _, player in matchPlayers do
		removeFromQueue(player)
	end

	clearFillTimer(modeId)
	return matchPlayers
end

local function launchMatch(modeId, matchPlayers)
	pendingMatch = nil
	broadcastAllQueues()

	local activePlayers = {}
	for _, queuedPlayer in matchPlayers do
		if queuedPlayer.Parent then
			table.insert(activePlayers, queuedPlayer)
		end
	end

	if #activePlayers == 0 then
		return
	end

	Bindables.MatchReady:Fire({
		modeId = modeId,
		players = activePlayers,
	})
end

local function tryStartMatch(modeId)
	if not canStartMatch(modeId) then
		broadcastQueueUpdate(modeId)
		return
	end

	local matchPlayers = takePlayersForMatch(modeId)
	if #matchPlayers == 0 then
		return
	end

	if MatchStateService.isBusy() then
		pendingMatch = {
			modeId = modeId,
			players = matchPlayers,
		}
		broadcastAllQueues()
		MatchStateService.whenIdle(function()
			if pendingMatch and pendingMatch.modeId == modeId then
				local ready = pendingMatch
				pendingMatch = nil
				launchMatch(ready.modeId, ready.players)
			end
		end)
		return
	end

	launchMatch(modeId, matchPlayers)
end

local function maybeStartFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if modeId ~= "ffa" then
		return
	end

	local count = getQueueCount(modeId)
	if count < mode.minPlayers or count >= mode.maxPlayers then
		clearFillTimer(modeId)
		return
	end

	if fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		fillTimers[modeId] = nil
		tryStartMatch(modeId)
	end)
	broadcastQueueUpdate(modeId)
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
		return
	end
	if playerMode[player] == modeId then
		return
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	local payload = buildQueuePayload(player)
	if payload then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
	broadcastQueueUpdate(modeId)

	tryStartMatch(modeId)
	maybeStartFillTimer(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	removeFromQueue(player)
	clearFillTimer(modeId)
	broadcastQueueUpdate(modeId)
	Remotes.QueueUpdate:FireClient(player, { status = "left" })
end

function MatchmakingService.isQueued(player)
	return playerMode[player] ~= nil
end

function MatchmakingService.getQueuedMode(player)
	return playerMode[player]
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

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

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
