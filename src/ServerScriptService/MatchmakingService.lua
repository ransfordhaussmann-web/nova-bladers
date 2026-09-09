local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(ReplicatedStorage.NovaBladers.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {}
local playerMode = {}
local ffaTimers = {}

for _, modeId in MatchmakingConfig.MODE_ORDER do
	queues[modeId] = {}
end

local handlers = {}

local function isValidMode(modeId)
	return MatchmakingConfig.MODES[modeId] ~= nil
end

local function getQueueSize(modeId)
	return #queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
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

	playerMode[player] = nil
end

local function buildQueuePayload(player, modeId)
	local mode = MatchmakingConfig.MODES[modeId]
	local queue = queues[modeId]
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local pending = MatchStateService.isBusy()
	return {
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queueSize = #queue,
		required = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = pending and "pending" or "waiting",
	}
end

local function broadcastModeQueue(modeId)
	for i, player in queues[modeId] do
		if player.Parent then
			local payload = buildQueuePayload(player, modeId)
			payload.position = i
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function broadcastAllQueues()
	for _, modeId in MatchmakingConfig.MODE_ORDER do
		broadcastModeQueue(modeId)
	end
end

local function cancelFfaTimer(modeId)
	local token = ffaTimers[modeId]
	if token then
		ffaTimers[modeId] = nil
	end
	return token
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerMode[player] = nil
			table.insert(picked, player)
		end
	end
	return picked
end

local function startMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	cancelFfaTimer(modeId)

	for _, player in playerList do
		if handlers.onMatchReady then
			handlers.onMatchReady(player, modeId)
		end
	end

	Bindables.MatchReady:Fire({
		modeId = modeId,
		players = playerList,
	})

	broadcastAllQueues()
end

local function tryStartMode(modeId)
	if MatchStateService.isBusy() then
		broadcastModeQueue(modeId)
		return
	end

	local mode = MatchmakingConfig.MODES[modeId]
	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		if not ffaTimers[modeId] then
			broadcastModeQueue(modeId)
			local token = {}
			ffaTimers[modeId] = token
			task.delay(mode.fillTimeout, function()
				if ffaTimers[modeId] ~= token then
					return
				end
				ffaTimers[modeId] = nil
				if MatchStateService.isBusy() then
					broadcastModeQueue(modeId)
					return
				end
				local count = math.min(#queues[modeId], mode.maxPlayers)
				if count < mode.minPlayers then
					return
				end
				startMatch(modeId, popPlayers(modeId, count))
			end)
		end
		return
	end

	startMatch(modeId, popPlayers(modeId, mode.maxPlayers))
end

function MatchmakingService.tryStartMatches()
	for _, modeId in MatchmakingConfig.MODE_ORDER do
		tryStartMode(modeId)
	end
end

function MatchmakingService.register(newHandlers)
	handlers = newHandlers or {}
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false, "invalid_mode"
	end
	if playerMode[player] then
		if playerMode[player] == modeId then
			return true
		end
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	if handlers.onPlayerQueued then
		handlers.onPlayerQueued(player, modeId)
	end

	local payload = buildQueuePayload(player, modeId)
	Remotes.QueueUpdate:FireClient(player, payload)
	broadcastModeQueue(modeId)

	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	removeFromQueue(player)

	if modeId == "ffa" and #queues[modeId] < MatchmakingConfig.MODES.ffa.minPlayers then
		cancelFfaTimer(modeId)
	end

	if handlers.onPlayerLeftQueue then
		handlers.onPlayerLeftQueue(player)
	end

	Remotes.QueueUpdate:FireClient(player, { status = "left" })
	broadcastModeQueue(modeId)
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.isQueued(player)
	return playerMode[player] ~= nil
end

function MatchmakingService.onMatchEnded()
	cancelFfaTimer("ffa")
	task.defer(MatchmakingService.tryStartMatches)
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

return MatchmakingService
