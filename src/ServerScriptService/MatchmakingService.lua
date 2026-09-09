local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local fillTimers = {}
local callbacks = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function queueContains(queue, player)
	for i, p in queue do
		if p == player then
			return i
		end
	end
	return nil
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	local index = queueContains(queue, player)
	if index then
		table.remove(queue, index)
	end
	playerMode[player] = nil
end

local function getQueueStatus(modeId)
	if MatchStateService.isBusy() then
		return "pending"
	end
	local config = getModeConfig(modeId)
	local count = #queues[modeId]
	if modeId == "ffa" and count >= config.minPlayers and fillTimers[modeId] then
		return "filling"
	end
	return "waiting"
end

local function buildUpdate(player, modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	return {
		queued = true,
		modeId = modeId,
		modeLabel = config.label,
		count = #queue,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = getQueueStatus(modeId),
	}
end

local function broadcastQueue(modeId)
	local queue = queues[modeId]
	for _, player in queue do
		if player.Parent and callbacks.onQueueUpdate then
			callbacks.onQueueUpdate(player, buildUpdate(player, modeId))
		end
	end
end

local function clearFillTimer(modeId)
	fillTimers[modeId] = nil
end

local function popPlayers(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local count = math.min(#queue, config.maxPlayers)
	local players = {}
	for _ = 1, count do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(players, player)
			playerMode[player] = nil
			if callbacks.onQueueUpdate then
				callbacks.onQueueUpdate(player, { queued = false })
			end
		end
	end
	clearFillTimer(modeId)
	return players
end

local function tryStartMode(modeId)
	if MatchStateService.isBusy() then
		broadcastQueue(modeId)
		return
	end

	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	if #queue < config.minPlayers then
		return
	end

	if modeId == "ffa" then
		if #queue >= config.maxPlayers then
			clearFillTimer(modeId)
		elseif fillTimers[modeId] then
			return
		else
			fillTimers[modeId] = true
			broadcastQueue(modeId)
			task.delay(config.fillTimeout, function()
				fillTimers[modeId] = nil
				if MatchStateService.isBusy() then
					broadcastQueue(modeId)
					return
				end
				if #queues[modeId] >= config.minPlayers then
					local players = popPlayers(modeId)
					if #players >= config.minPlayers and callbacks.onMatchReady then
						MatchStateService.setBusy(true)
						callbacks.onMatchReady(players, modeId)
					end
				end
			end)
			return
		end
	end

	local players = popPlayers(modeId)
	if #players >= config.minPlayers and callbacks.onMatchReady then
		MatchStateService.setBusy(true)
		callbacks.onMatchReady(players, modeId)
	end
end

function MatchmakingService.register(newCallbacks)
	callbacks = newCallbacks
end

function MatchmakingService.joinQueue(player, modeId)
	if not getModeConfig(modeId) then
		return false
	end
	if playerMode[player] == modeId then
		return true
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	if callbacks.onQueueUpdate then
		callbacks.onQueueUpdate(player, buildUpdate(player, modeId))
	end

	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	removeFromQueue(player)
	if callbacks.onQueueUpdate then
		callbacks.onQueueUpdate(player, { queued = false })
	end

	if modeId == "ffa" and #queues[modeId] < getModeConfig("ffa").minPlayers then
		clearFillTimer(modeId)
	end
	broadcastQueue(modeId)
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setBusy(false)
	for modeId in pairs(MatchmakingConfig.MODES) do
		tryStartMode(modeId)
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

return MatchmakingService
