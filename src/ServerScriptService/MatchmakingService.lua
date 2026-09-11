local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchState = require(script.Parent.MatchState)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local fillStartedAt = {}
local pendingModes = {}
local onMatchReady
local onQueueUpdate

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function playerName(player)
	return player and player.Name or "?"
end

local function queueNames(modeId)
	local names = {}
	for _, player in queues[modeId] do
		if player.Parent then
			table.insert(names, player.Name)
		end
	end
	return names
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end

	playerMode[player] = nil

	if #queue == 0 then
		fillStartedAt[modeId] = nil
		pendingModes[modeId] = nil
	end
end

local function buildQueuePayload(player, modeId, status)
	local config = getModeConfig(modeId)
	if not config then
		return { inQueue = false }
	end

	local queue = queues[modeId]
	local count = #queue
	local fillSecondsLeft

	if modeId == "ffa" and fillStartedAt[modeId] and config.fillTimeout then
		local elapsed = os.clock() - fillStartedAt[modeId]
		fillSecondsLeft = math.max(0, math.ceil(config.fillTimeout - elapsed))
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = config.label,
		players = queueNames(modeId),
		count = count,
		needed = config.maxPlayers,
		minPlayers = config.minPlayers,
		status = status or "waiting",
		fillSecondsLeft = fillSecondsLeft,
	}
end

local function notifyPlayer(player, payload)
	if onQueueUpdate and player.Parent then
		onQueueUpdate(player, payload)
	end
end

local function notifyQueue(modeId, status)
	for _, player in queues[modeId] do
		notifyPlayer(player, buildQueuePayload(player, modeId, status))
	end
end

local function popMatchPlayers(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local count = math.min(#queue, config.maxPlayers)
	local matchPlayers = {}

	for _ = 1, count do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(matchPlayers, player)
			playerMode[player] = nil
		end
	end

	if #queue == 0 then
		fillStartedAt[modeId] = nil
	end

	pendingModes[modeId] = nil
	return matchPlayers
end

local function tryStartMode(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	if not config or #queue < config.minPlayers then
		return false
	end

	if MatchState.isBusy() then
		pendingModes[modeId] = true
		notifyQueue(modeId, "pending")
		return false
	end

	local matchPlayers = popMatchPlayers(modeId)
	if #matchPlayers < config.minPlayers then
		for _, player in matchPlayers do
			table.insert(queue, player)
			playerMode[player] = modeId
		end
		return false
	end

	notifyQueue(modeId, "starting")

	if onMatchReady then
		onMatchReady(matchPlayers, modeId)
	end

	return true
end

local function evaluateMode(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	if not config or #queue == 0 then
		return
	end

	if #queue >= config.maxPlayers then
		tryStartMode(modeId)
		return
	end

	if #queue >= config.minPlayers then
		if modeId == "ffa" then
			if not fillStartedAt[modeId] then
				fillStartedAt[modeId] = os.clock()
			end

			local elapsed = os.clock() - fillStartedAt[modeId]
			if elapsed >= (config.fillTimeout or 12) then
				tryStartMode(modeId)
			else
				notifyQueue(modeId, MatchState.isBusy() and "pending" or "waiting")
			end
		else
			tryStartMode(modeId)
		end
	end
end

function MatchmakingService.init(handlers)
	onMatchReady = handlers.onMatchReady
	onQueueUpdate = handlers.onQueueUpdate
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.isInQueue(player)
	return playerMode[player] ~= nil
end

function MatchmakingService.joinQueue(player, modeId)
	local config = getModeConfig(modeId)
	if not config then
		return false, "invalid_mode"
	end

	if playerMode[player] == modeId then
		notifyPlayer(player, buildQueuePayload(player, modeId, MatchState.isBusy() and "pending" or "waiting"))
		return true
	end

	removeFromQueue(player)

	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	if modeId == "ffa" and #queues[modeId] >= config.minPlayers and not fillStartedAt[modeId] then
		fillStartedAt[modeId] = os.clock()
	end

	notifyQueue(modeId, MatchState.isBusy() and "pending" or "waiting")
	evaluateMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		notifyPlayer(player, { inQueue = false })
		return
	end

	removeFromQueue(player)
	notifyPlayer(player, { inQueue = false })

	if #queues[modeId] > 0 then
		notifyQueue(modeId, MatchState.isBusy() and "pending" or "waiting")
	end
end

function MatchmakingService.onMatchEnded()
	for modeId in pairs(MatchmakingConfig.MODES) do
		if pendingModes[modeId] or #queues[modeId] >= getModeConfig(modeId).minPlayers then
			evaluateMode(modeId)
		end
	end
end

function MatchmakingService.tick()
	for modeId in pairs(MatchmakingConfig.MODES) do
		if modeId == "ffa" and fillStartedAt[modeId] then
			evaluateMode(modeId)
		end
	end
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
end

function MatchmakingService.getSuggestedMode(playerCount)
	if playerCount >= 3 then
		return "ffa"
	elseif playerCount == 2 then
		return "pvp"
	end
	return "training"
end

return MatchmakingService
