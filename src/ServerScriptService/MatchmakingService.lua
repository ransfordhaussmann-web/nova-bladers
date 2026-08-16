--[[
	MatchmakingService — per-mode queues; starts matches when min players reached.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local onMatchReadyCallbacks = {}
local onQueueChanged = nil

local function isValidMode(modeId)
	return MatchmakingConfig.MODES[modeId] ~= nil
end

local function removePlayer(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	playerMode[player] = nil
	local queue = queues[modeId]
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end
end

local function getQueueSnapshot()
	local snapshot = {}
	for modeId, mode in MatchmakingConfig.MODES do
		snapshot[modeId] = {
			count = #queues[modeId],
			min = mode.minPlayers,
			max = mode.maxPlayers,
			label = mode.label,
		}
	end
	return snapshot
end

local function notifyQueueChanged()
	if onQueueChanged then
		onQueueChanged(getQueueSnapshot())
	end
end

local function pullMatchPlayers(modeId)
	local mode = MatchmakingConfig.MODES[modeId]
	local queue = queues[modeId]
	local count = math.min(#queue, mode.maxPlayers)
	local matchPlayers = {}

	for _ = 1, count do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerMode[player] = nil
			table.insert(matchPlayers, player)
		end
	end

	return matchPlayers
end

local function tryStartMatch(modeId)
	local mode = MatchmakingConfig.MODES[modeId]
	if #queues[modeId] < mode.minPlayers then
		return
	end

	local matchPlayers = pullMatchPlayers(modeId)
	if #matchPlayers < mode.minPlayers then
		for _, player in matchPlayers do
			table.insert(queues[modeId], player)
			playerMode[player] = modeId
		end
		return
	end

	notifyQueueChanged()

	if onMatchReadyCallbacks then
		for _, callback in onMatchReadyCallbacks do
			callback(matchPlayers, modeId)
		end
	end
end

function MatchmakingService.setOnMatchReady(callback)
	table.insert(onMatchReadyCallbacks, callback)
end

function MatchmakingService.setOnQueueChanged(callback)
	onQueueChanged = callback
end

function MatchmakingService.getQueueSnapshot()
	return getQueueSnapshot()
end

function MatchmakingService.isQueued(player)
	return playerMode[player] ~= nil
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		return false
	end
	removePlayer(player)
	notifyQueueChanged()
	return true
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		modeId = "training"
	end

	if playerMode[player] == modeId then
		return true
	end

	removePlayer(player)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId
	notifyQueueChanged()
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.playerRemoving(player)
	removePlayer(player)
end

return MatchmakingService
