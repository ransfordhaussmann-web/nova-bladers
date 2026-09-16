local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local Bindables

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local fillTimers = {}
local fillDeadline = {}

local function removeFromQueue(player, modeId)
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

	if #queues[modeId] == 0 then
		fillTimers[modeId] = nil
		fillDeadline[modeId] = nil
	end
end

local function clearPlayerFromQueues(player)
	local modeId = playerMode[player]
	if modeId then
		removeFromQueue(player, modeId)
		playerMode[player] = nil
	end
end

local function getQueueStatus(modeId)
	local queue = queues[modeId]
	local mode = MatchModes.get(modeId)
	if not mode then
		return "waiting"
	end

	if MatchStateService.isBusy() then
		return "pending"
	end

	if #queue >= mode.minPlayers then
		return "ready"
	end

	if mode.fillTimeout > 0 and fillDeadline[modeId] and os.clock() >= fillDeadline[modeId] then
		return "ready"
	end

	return "waiting"
end

local function buildQueuePayload(player, modeId)
	local queue = queues[modeId]
	local mode = MatchModes.get(modeId)
	if not mode then
		return { inQueue = false }
	end

	local position = 0
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			position = index
			break
		end
	end

	local fillSecondsLeft = nil
	if fillDeadline[modeId] then
		fillSecondsLeft = math.max(0, math.ceil(fillDeadline[modeId] - os.clock()))
	end

	return {
		inQueue = position > 0,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		total = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = getQueueStatus(modeId),
		arenaBusy = MatchStateService.isBusy(),
		fillSecondsLeft = fillSecondsLeft,
	}
end

local function broadcastQueue(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function popPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if not mode or #queue == 0 then
		return nil
	end

	local count = math.min(#queue, mode.maxPlayers)
	if count < mode.minPlayers then
		if mode.fillTimeout <= 0 or not fillDeadline[modeId] or os.clock() < fillDeadline[modeId] then
			return nil
		end
		if count < mode.minPlayers then
			return nil
		end
	end

	local players = {}
	for _ = 1, count do
		local nextPlayer = table.remove(queue, 1)
		if nextPlayer and nextPlayer.Parent then
			table.insert(players, nextPlayer)
			playerMode[nextPlayer] = nil
		end
	end

	fillTimers[modeId] = nil
	fillDeadline[modeId] = nil
	broadcastQueue(modeId)
	return players
end

local function tryStartMode(modeId)
	if MatchStateService.isBusy() then
		broadcastQueue(modeId)
		return
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if not mode or #queue < mode.minPlayers then
		if mode and mode.fillTimeout > 0 and fillDeadline[modeId] and os.clock() >= fillDeadline[modeId] and #queue >= mode.minPlayers then
			-- fall through
		else
			return
		end
	end

	local players = popPlayers(modeId)
	if not players or #players == 0 then
		return
	end

	Bindables.MatchReady:Fire(players, modeId)
end

local function tryStartAllModes()
	for modeId in queues do
		tryStartMode(modeId)
		if MatchStateService.isBusy() then
			break
		end
	end
end

local function scheduleFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end

	if fillTimers[modeId] then
		return
	end

	fillDeadline[modeId] = os.clock() + mode.fillTimeout
	fillTimers[modeId] = true

	task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		if #queues[modeId] >= mode.minPlayers then
			tryStartMode(modeId)
		else
			broadcastQueue(modeId)
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false, "invalid_mode"
	end

	if playerMode[player] == modeId then
		return true
	end

	clearPlayerFromQueues(player)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	if #queues[modeId] == 1 then
		scheduleFillTimer(modeId)
	end

	broadcastQueue(modeId)
	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	clearPlayerFromQueues(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })

	if modeId and queues[modeId] then
		broadcastQueue(modeId)
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.onArenaFree()
	broadcastAllQueues()
	tryStartAllModes()
end

function MatchmakingService.start()
	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
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
		MatchmakingService.onArenaFree()
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
