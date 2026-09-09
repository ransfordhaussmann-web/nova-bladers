local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local queues = {}
local playerEntry = {}
local ffaFillStartedAt = nil
local callbacks = {}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function pruneQueue(modeId)
	local queue = queues[modeId]
	local cleaned = {}
	for _, entry in queue do
		if entry.player.Parent then
			table.insert(cleaned, entry)
		else
			playerEntry[entry.player] = nil
		end
	end
	queues[modeId] = cleaned
end

local function getQueueCount(modeId)
	pruneQueue(modeId)
	return #queues[modeId]
end

local function getPlayerPosition(player, modeId)
	pruneQueue(modeId)
	for index, entry in queues[modeId] do
		if entry.player == player then
			return index
		end
	end
	return nil
end

local function buildUpdatePayload(player, modeId)
	local config = getModeConfig(modeId)
	local count = getQueueCount(modeId)
	local position = getPlayerPosition(player, modeId)
	local status = "queued"

	if MatchStateService.isBusy() then
		status = "pending"
	elseif config.minPlayers == config.maxPlayers and count >= config.minPlayers then
		status = "ready"
	elseif modeId == "ffa" and count >= config.minPlayers then
		if ffaFillStartedAt then
			local elapsed = os.clock() - ffaFillStartedAt
			local remaining = math.max(0, math.ceil(config.fillTimeout - elapsed))
			if remaining <= 0 or count >= config.maxPlayers then
				status = "ready"
			else
				status = "filling"
			end
		else
			status = "filling"
		end
	end

	return {
		modeId = modeId,
		modeLabel = config.label,
		status = status,
		queueCount = count,
		position = position,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		fillRemaining = (modeId == "ffa" and ffaFillStartedAt and count >= config.minPlayers)
			and math.max(0, math.ceil(config.fillTimeout - (os.clock() - ffaFillStartedAt)))
			or nil,
		arenaBusy = MatchStateService.isBusy(),
	}
end

local function broadcastQueue(modeId)
	pruneQueue(modeId)
	for _, entry in queues[modeId] do
		if entry.player.Parent and callbacks.onQueueUpdate then
			callbacks.onQueueUpdate(entry.player, buildUpdatePayload(entry.player, modeId))
		end
	end
end

local function broadcastAllQueues()
	for modeId in MatchmakingConfig.MODES do
		broadcastQueue(modeId)
	end
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return nil
	end

	local modeId = entry.modeId
	playerEntry[player] = nil

	local queue = queues[modeId]
	for index, queued in queue do
		if queued.player == player then
			table.remove(queue, index)
			break
		end
	end

	if modeId == "ffa" and getQueueCount("ffa") < MatchmakingConfig.MODES.ffa.minPlayers then
		ffaFillStartedAt = nil
	end

	broadcastQueue(modeId)
	return modeId
end

local function canStartMode(modeId)
	local config = getModeConfig(modeId)
	local count = getQueueCount(modeId)

	if count < config.minPlayers then
		return false
	end

	if config.minPlayers == config.maxPlayers then
		return count >= config.minPlayers
	end

	if count >= config.maxPlayers then
		return true
	end

	if modeId == "ffa" and ffaFillStartedAt then
		return os.clock() - ffaFillStartedAt >= config.fillTimeout
	end

	return false
end

local function popPlayers(modeId)
	local config = getModeConfig(modeId)
	local count = getQueueCount(modeId)
	local take = math.min(count, config.maxPlayers)
	local selected = {}

	for _ = 1, take do
		local entry = table.remove(queues[modeId], 1)
		if entry then
			playerEntry[entry.player] = nil
			table.insert(selected, entry.player)
		end
	end

	if modeId == "ffa" and getQueueCount("ffa") < config.minPlayers then
		ffaFillStartedAt = nil
	end

	broadcastQueue(modeId)
	return selected
end

local function tryStartMatches()
	if MatchStateService.isBusy() then
		return
	end

	for _, modeId in { "training", "pvp", "ffa" } do
		if canStartMode(modeId) then
			local players = popPlayers(modeId)
			if #players > 0 then
				MatchStateService.setBusy(true)
				for _, player in players do
					if HubService.setArenaPhase then
						HubService.setArenaPhase(player)
					end
				end
				if callbacks.onMatchReady then
					callbacks.onMatchReady(players, modeId)
				end
				return
			end
		end
	end
end

local function maybeStartFfaTimer(modeId)
	if modeId ~= "ffa" then
		return
	end
	local config = getModeConfig("ffa")
	if getQueueCount("ffa") >= config.minPlayers and not ffaFillStartedAt then
		ffaFillStartedAt = os.clock()
	end
end

function MatchmakingService.registerHandlers(handlers)
	callbacks = handlers or {}
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false, "invalid_mode"
	end
	if playerEntry[player] then
		return false, "already_queued"
	end
	if HubService.getPhase(player) == "arena" then
		return false, "in_match"
	end

	table.insert(queues[modeId], {
		player = player,
		joinedAt = os.clock(),
	})
	playerEntry[player] = { modeId = modeId }

	maybeStartFfaTimer(modeId)
	broadcastQueue(modeId)
	tryStartMatches()
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromQueue(player)
	if modeId and callbacks.onQueueUpdate then
		callbacks.onQueueUpdate(player, { status = "left" })
	end
	return modeId ~= nil
end

function MatchmakingService.getQueuedMode(player)
	local entry = playerEntry[player]
	return entry and entry.modeId or nil
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setBusy(false)
	broadcastAllQueues()
	tryStartMatches()
end

function MatchmakingService.onArenaBusyChanged()
	broadcastAllQueues()
	if not MatchStateService.isBusy() then
		tryStartMatches()
	end
end

function MatchmakingService.tick()
	for modeId in MatchmakingConfig.MODES do
		pruneQueue(modeId)
	end

	if not MatchStateService.isBusy() then
		tryStartMatches()
	end

	for modeId in MatchmakingConfig.MODES do
		if getQueueCount(modeId) > 0 then
			broadcastQueue(modeId)
		end
	end
end

function MatchmakingService.removePlayer(player)
	removeFromQueue(player)
end

return MatchmakingService
