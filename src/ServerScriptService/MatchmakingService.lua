local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local ffaTimers = {}
local ffaTimerTokens = {}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local callbacks = {
	onQueueUpdate = nil,
	onMatchReady = nil,
	onPlayerEnterArena = nil,
}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function buildQueuePayload(modeId, status)
	local mode = getModeConfig(modeId)
	if not mode then
		return nil
	end

	local count = #queues[modeId]
	local pending = MatchStateService.isArenaBusy()

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status or (pending and "pending" or "waiting"),
		pending = pending,
	}
end

local function broadcastQueueUpdate(modeId)
	if not callbacks.onQueueUpdate then
		return
	end

	local payload = buildQueuePayload(modeId, nil)
	for _, player in queues[modeId] do
		if player.Parent then
			callbacks.onQueueUpdate(player, payload)
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function cancelFfaTimer(modeId)
	ffaTimerTokens[modeId] = (ffaTimerTokens[modeId] or 0) + 1
	ffaTimers[modeId] = nil
end

local function popPlayers(modeId, count)
	local mode = getModeConfig(modeId)
	local popped = {}
	local limit = math.min(count, #queues[modeId], mode.maxPlayers)

	for _ = 1, limit do
		local player = table.remove(queues[modeId], 1)
		if player then
			playerQueue[player] = nil
			table.insert(popped, player)
		end
	end

	return popped
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	local mode = getModeConfig(modeId)
	if not mode then
		return
	end

	local count = #queues[modeId]
	if count < mode.minPlayers then
		return
	end

	if count >= mode.maxPlayers then
		cancelFfaTimer(modeId)
		local players = popPlayers(modeId, mode.maxPlayers)
		if #players > 0 and callbacks.onMatchReady then
			MatchStateService.setArenaBusy(true)
			callbacks.onMatchReady(players, modeId)
			if callbacks.onPlayerEnterArena then
				for _, player in players do
					callbacks.onPlayerEnterArena(player)
				end
			end
		end
		broadcastAllQueues()
		return
	end

	if modeId == "ffa" and mode.fillTimeout then
		if not ffaTimers[modeId] then
			local token = (ffaTimerTokens[modeId] or 0) + 1
			ffaTimerTokens[modeId] = token
			ffaTimers[modeId] = true

			task.delay(mode.fillTimeout, function()
				if ffaTimerTokens[modeId] ~= token then
					return
				end
				ffaTimers[modeId] = nil

				if MatchStateService.isArenaBusy() then
					broadcastQueueUpdate(modeId)
					return
				end

				if #queues[modeId] < mode.minPlayers then
					return
				end

				local players = popPlayers(modeId, #queues[modeId])
				if #players > 0 and callbacks.onMatchReady then
					MatchStateService.setArenaBusy(true)
					callbacks.onMatchReady(players, modeId)
					if callbacks.onPlayerEnterArena then
						for _, player in players do
							callbacks.onPlayerEnterArena(player)
						end
					end
				end
				broadcastAllQueues()
			end)
		end
		broadcastQueueUpdate(modeId)
		return
	end

	if count >= mode.minPlayers then
		local players = popPlayers(modeId, mode.minPlayers)
		if #players > 0 and callbacks.onMatchReady then
			MatchStateService.setArenaBusy(true)
			callbacks.onMatchReady(players, modeId)
			if callbacks.onPlayerEnterArena then
				for _, player in players do
					callbacks.onPlayerEnterArena(player)
				end
			end
		end
		broadcastAllQueues()
	end
end

function MatchmakingService.init(opts)
	callbacks.onQueueUpdate = opts.onQueueUpdate
	callbacks.onMatchReady = opts.onMatchReady
	callbacks.onPlayerEnterArena = opts.onPlayerEnterArena
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = getModeConfig(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	MatchmakingService.leaveQueue(player)

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	if callbacks.onQueueUpdate then
		callbacks.onQueueUpdate(player, buildQueuePayload(modeId, nil))
	end

	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil

	for i, queued in queues[modeId] do
		if queued == player then
			table.remove(queues[modeId], i)
			break
		end
	end

	if modeId == "ffa" and #queues[modeId] < getModeConfig("ffa").minPlayers then
		cancelFfaTimer(modeId)
	end

	if callbacks.onQueueUpdate then
		callbacks.onQueueUpdate(player, {
			modeId = nil,
			status = "left",
		})
	end

	broadcastQueueUpdate(modeId)
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	broadcastAllQueues()

	for modeId in queues do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

return MatchmakingService
