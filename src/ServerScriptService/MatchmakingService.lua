local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes
local queues = {
	training = {},
	pvp = {},
	ffa = {},
}
local playerMode = {}
local gatherScheduled = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function indexOf(list, player)
	for i, queued in list do
		if queued == player then
			return i
		end
	end
	return nil
end

local function removeFromList(list, player)
	local idx = indexOf(list, player)
	if idx then
		table.remove(list, idx)
		return true
	end
	return false
end

local function buildUpdatePayload(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local status = MatchmakingConfig.STATUS.WAITING

	if gatherScheduled[modeId] then
		status = MatchmakingConfig.STATUS.GATHERING
	end

	return {
		modeId = modeId,
		modeLabel = config.label,
		queued = #queue,
		needed = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = status,
		inQueue = true,
	}
end

local function ensureRemotes()
	if not Remotes then
		Remotes = RemotesSetup.ensure()
	end
	return Remotes
end

local function broadcastModeUpdate(modeId)
	ensureRemotes()
	local queue = queues[modeId]
	local payload = buildUpdatePayload(modeId)
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function clearClientQueue(player)
	ensureRemotes()
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

function MatchmakingService.init(remotes)
	Remotes = remotes
end

function MatchmakingService.getQueue(modeId)
	return queues[modeId] or {}
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.removePlayers(players)
	for _, player in players do
		local modeId = playerMode[player]
		if modeId then
			removeFromList(queues[modeId], player)
			playerMode[player] = nil
		end
	end
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		clearClientQueue(player)
		return false
	end

	playerMode[player] = nil
	removeFromList(queues[modeId], player)
	clearClientQueue(player)
	broadcastModeUpdate(modeId)
	return true
end

function MatchmakingService.joinQueue(player, modeId)
	ensureRemotes()
	if not isValidMode(modeId) then
		return false
	end
	if playerMode[player] == modeId then
		Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(modeId))
		return true, modeId
	end

	MatchmakingService.leaveQueue(player)

	table.insert(queues[modeId], player)
	playerMode[player] = modeId
	Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(modeId))
	broadcastModeUpdate(modeId)
	return true, modeId
end

function MatchmakingService.markGathering(modeId, active)
	gatherScheduled[modeId] = active or nil
	broadcastModeUpdate(modeId)
end

function MatchmakingService.markPendingArena(players, modeId)
	ensureRemotes()
	local payload = buildUpdatePayload(modeId)
	payload.status = MatchmakingConfig.STATUS.PENDING_ARENA
	for _, player in players do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

function MatchmakingService.popReadyPlayers(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	if #queue < config.minPlayers then
		return nil
	end

	local count = math.min(#queue, config.maxPlayers)
	local ready = {}
	for _ = 1, count do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerMode[player] = nil
			table.insert(ready, player)
		end
	end

	broadcastModeUpdate(modeId)
	return ready
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

return MatchmakingService
