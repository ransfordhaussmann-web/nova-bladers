local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local arenaBusy = false
local fillTokens = {}
local callbacks = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function queueIndex(modeId, player)
	local list = queues[modeId]
	for index, queuedPlayer in list do
		if queuedPlayer == player then
			return index
		end
	end
	return nil
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return nil
	end

	local index = queueIndex(modeId, player)
	if index then
		table.remove(queues[modeId], index)
	end
	playerMode[player] = nil
	return modeId
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function buildPlayerUpdate(player)
	local modeId = playerMode[player]
	if not modeId then
		return {
			inQueue = false,
		}
	end

	local config = getModeConfig(modeId)
	return {
		inQueue = true,
		modeId = modeId,
		label = config.label,
		count = #queues[modeId],
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = if arenaBusy then "pending" else "searching",
	}
end

local function notifyPlayer(player)
	if callbacks.onQueueUpdate and player.Parent then
		callbacks.onQueueUpdate(player, buildPlayerUpdate(player))
	end
end

local function notifyQueue(modeId)
	for _, player in queues[modeId] do
		notifyPlayer(player)
	end
end

local function canStartMode(modeId, allowTimeout)
	local config = getModeConfig(modeId)
	if not config then
		return false
	end

	local count = #queues[modeId]
	if count == 0 then
		return false
	end
	if count >= config.minPlayers then
		return true
	end
	if allowTimeout and config.fillTimeout and count >= config.minPlayersOnTimeout then
		return true
	end
	return false
end

local function popPlayers(modeId)
	local config = getModeConfig(modeId)
	local count = math.min(#queues[modeId], config.maxPlayers)
	local players = {}

	for _ = 1, count do
		local player = table.remove(queues[modeId], 1)
		if player then
			playerMode[player] = nil
			table.insert(players, player)
		end
	end

	cancelFillTimer(modeId)
	return players
end

local function fireMatchReady(players, modeId)
	if callbacks.onMatchReady then
		callbacks.onMatchReady(players, modeId)
	end
end

local function tryStartMode(modeId, allowTimeout)
	if arenaBusy or not canStartMode(modeId, allowTimeout) then
		return false
	end

	local players = popPlayers(modeId)
	if #players == 0 then
		return false
	end

	arenaBusy = true
	cancelFillTimer(modeId)
	notifyQueue(modeId)
	fireMatchReady(players, modeId)
	return true
end

local function tryStartAnyQueue(allowTimeout)
	for _, modeId in MatchmakingConfig.QUEUE_PRIORITY do
		if tryStartMode(modeId, allowTimeout) then
			return true
		end
	end
	return false
end

local function scheduleFillTimer(modeId)
	local config = getModeConfig(modeId)
	if not config or not config.fillTimeout or #queues[modeId] == 0 then
		return
	end
	if #queues[modeId] >= config.minPlayers then
		return
	end

	cancelFillTimer(modeId)
	local token = fillTokens[modeId] or 0
	fillTokens[modeId] = token

	task.delay(config.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		tryStartMode(modeId, true)
		if not arenaBusy then
			tryStartAnyQueue(true)
		end
	end)
end

function MatchmakingService.register(newCallbacks)
	callbacks = newCallbacks or {}
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	for modeId in queues do
		notifyQueue(modeId)
	end
	if not arenaBusy then
		tryStartAnyQueue(false)
	end
end

function MatchmakingService.getPlayerQueue(player)
	return playerMode[player]
end

function MatchmakingService.joinQueue(player, modeId)
	if not getModeConfig(modeId) then
		return false
	end

	MatchmakingService.leaveQueue(player)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId
	notifyPlayer(player)
	notifyQueue(modeId)

	if tryStartMode(modeId, false) then
		return true
	end

	scheduleFillTimer(modeId)
	if not arenaBusy then
		tryStartAnyQueue(false)
	end
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromQueue(player)
	if not modeId then
		notifyPlayer(player)
		return false
	end

	cancelFillTimer(modeId)
	notifyPlayer(player)
	notifyQueue(modeId)
	return true
end

function MatchmakingService.removePlayer(player)
	local modeId = removeFromQueue(player)
	if modeId then
		notifyQueue(modeId)
	end
end

function MatchmakingService.getRecommendedMode(playerCount)
	return MatchmakingConfig.getRecommendedMode(playerCount)
end

return MatchmakingService
