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
local pendingMatches = {}
local ffaFillToken = 0
local broadcastUpdate

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end
	playerMode[player] = nil
end

local function buildQueueSnapshot(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	local names = {}
	for _, player in queue do
		if player.Parent then
			table.insert(names, player.DisplayName)
		end
	end

	return {
		modeId = modeId,
		label = mode.label,
		count = #names,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		playerNames = names,
	}
end

local function notifyPlayer(player, payload)
	if broadcastUpdate then
		broadcastUpdate(player, payload)
	end
end

local function notifyQueue(modeId)
	local snapshot = buildQueueSnapshot(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			notifyPlayer(player, {
				status = "queued",
				modeId = modeId,
				queue = snapshot,
				pendingArena = MatchStateService.isArenaBusy(),
			})
		end
	end
end

local function notifyPending(match)
	for _, player in match.players do
		if player.Parent then
			notifyPlayer(player, {
				status = "pending",
				modeId = match.modeId,
				queue = buildQueueSnapshot(match.modeId),
				pendingArena = true,
			})
		end
	end
end

local function launchMatch(modeId, players)
	local valid = {}
	for _, player in players do
		if player.Parent then
			table.insert(valid, player)
		end
	end

	if #valid == 0 then
		return
	end

	local mode = getMode(modeId)
	if #valid < mode.minPlayers then
		for _, player in valid do
			table.insert(queues[modeId], player)
			playerMode[player] = modeId
		end
		notifyQueue(modeId)
		return
	end

	if MatchmakingService.onMatchReady then
		MatchmakingService.onMatchReady(valid, modeId)
	end
end

local function dequeuePlayers(modeId, count)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	local taken = {}
	local limit = math.min(count, #queue, mode.maxPlayers)

	for _ = 1, limit do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerMode[player] = nil
			table.insert(taken, player)
		end
	end

	return taken
end

local function tryStartMode(modeId)
	local mode = getMode(modeId)
	if not mode then
		return
	end

	while #queues[modeId] >= mode.minPlayers do
		local players = dequeuePlayers(modeId, mode.maxPlayers)
		if #players < mode.minPlayers then
			for _, player in players do
				table.insert(queues[modeId], player)
				playerMode[player] = modeId
			end
			break
		end

		if MatchStateService.isArenaBusy() then
			local match = { modeId = modeId, players = players }
			table.insert(pendingMatches, match)
			notifyPending(match)
			break
		end

		launchMatch(modeId, players)

		if modeId ~= "ffa" then
			break
		end
	end

	notifyQueue(modeId)
end

local function scheduleFfaFillCheck()
	ffaFillToken += 1
	local token = ffaFillToken
	local timeout = getMode("ffa").fillTimeout

	task.delay(timeout, function()
		if token ~= ffaFillToken then
			return
		end
		tryStartMode("ffa")
	end)
end

function MatchmakingService.setBroadcastHandler(handler)
	broadcastUpdate = handler
end

function MatchmakingService.joinQueue(player, modeId)
	if not getMode(modeId) then
		return false, "invalid_mode"
	end
	if playerMode[player] == modeId then
		return true
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	if modeId == "ffa" and #queues.ffa == 1 then
		scheduleFfaFillCheck()
	end

	notifyPlayer(player, {
		status = "queued",
		modeId = modeId,
		queue = buildQueueSnapshot(modeId),
		pendingArena = MatchStateService.isArenaBusy(),
	})

	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	removeFromQueue(player)

	for i, match in pendingMatches do
		for j, queued in match.players do
			if queued == player then
				table.remove(match.players, j)
				break
			end
		end
		if #match.players == 0 then
			table.remove(pendingMatches, i)
		end
	end

	notifyPlayer(player, { status = "idle" })
	notifyQueue(modeId)
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.processPending()
	if MatchStateService.isArenaBusy() or #pendingMatches == 0 then
		return
	end

	local match = table.remove(pendingMatches, 1)
	if match and #match.players > 0 then
		launchMatch(match.modeId, match.players)
	end
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

MatchStateService.onArenaFreed(function()
	MatchmakingService.processPending()
end)

return MatchmakingService
