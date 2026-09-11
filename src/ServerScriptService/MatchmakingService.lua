local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local arenaBusy = false
local ffaFillToken = 0

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function queueIndex(modeId, player)
	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			return i
		end
	end
	return nil
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local index = queueIndex(modeId, player)
	if index then
		table.remove(queues[modeId], index)
	end
	playerQueue[player] = nil
end

local function buildStatusText(modeId, count, status, fillSecondsLeft)
	local mode = getMode(modeId)
	if status == "pending" then
		return "Arena belegt — Warteschlange aktiv"
	end
	if status == "starting" then
		return "Match startet..."
	end
	if modeId == "ffa" and fillSecondsLeft and count >= mode.minPlayers then
		return string.format("FFA startet in %ds (%d/%d)", fillSecondsLeft, count, mode.maxPlayers)
	end
	return string.format("Warte auf Spieler (%d/%d)", count, mode.minPlayers)
end

local function buildQueuePayload(player, modeId, status, fillSecondsLeft)
	local mode = getMode(modeId)
	local count = #queues[modeId]
	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		statusText = buildStatusText(modeId, count, status, fillSecondsLeft),
		fillSecondsLeft = fillSecondsLeft,
		arenaBusy = arenaBusy,
	}
end

local function broadcastModeQueue(modeId, fillSecondsLeft)
	local status = arenaBusy and "pending" or "waiting"
	for _, player in queues[modeId] do
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, status, fillSecondsLeft))
	end
end

local function broadcastAllQueues(fillSecondsLeft)
	for modeId in queues do
		if #queues[modeId] > 0 then
			local secondsLeft = if modeId == "ffa" then fillSecondsLeft else nil
			broadcastModeQueue(modeId, secondsLeft)
		end
	end
end

local function clearClientQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

local function takePlayers(modeId, count)
	local taken = {}
	for _ = 1, count do
		local player = queues[modeId][1]
		if not player then
			break
		end
		table.remove(queues[modeId], 1)
		playerQueue[player] = nil
		table.insert(taken, player)
	end
	return taken
end

local function markStarting(players, modeId)
	for _, player in players do
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, "starting", nil))
	end
end

local function startMatch(modeId, players)
	if #players == 0 then
		return
	end

	arenaBusy = true
	ffaFillToken += 1
	markStarting(players, modeId)

	for _, player in players do
		HubService.transitionToArena(player)
	end

	Bindables.MatchReady:Fire({
		mode = modeId,
		players = players,
	})

	broadcastAllQueues(nil)
end

local function tryStartTraining()
	local mode = getMode("training")
	local queue = queues.training
	if #queue < mode.minPlayers then
		return false
	end

	startMatch("training", takePlayers("training", 1))
	return true
end

local function tryStartPvP()
	local mode = getMode("pvp")
	local queue = queues.pvp
	if #queue < mode.minPlayers then
		return false
	end

	startMatch("pvp", takePlayers("pvp", mode.maxPlayers))
	return true
end

local function tryStartFFA()
	local mode = getMode("ffa")
	local queue = queues.ffa
	if #queue < mode.minPlayers then
		return false
	end

	local count = math.min(#queue, mode.maxPlayers)
	startMatch("ffa", takePlayers("ffa", count))
	return true
end

local function tryStartAnyMatch()
	if arenaBusy then
		return
	end

	for _, modeId in MatchmakingConfig.QUEUE_PRIORITY do
		local started = false
		if modeId == "training" then
			started = tryStartTraining()
		elseif modeId == "pvp" then
			started = tryStartPvP()
		elseif modeId == "ffa" then
			if #queues.ffa >= getMode("ffa").maxPlayers then
				ffaFillToken += 1
				started = tryStartFFA()
			end
		end
		if started then
			return
		end
	end
end

local function scheduleFFAFill()
	local mode = getMode("ffa")
	if #queues.ffa < mode.minPlayers or arenaBusy then
		return
	end

	ffaFillToken += 1
	local token = ffaFillToken

	task.spawn(function()
		for remaining = mode.fillTimeout, 1, -1 do
			if token ~= ffaFillToken or arenaBusy then
				return
			end
			if #queues.ffa < mode.minPlayers then
				return
			end
			if #queues.ffa >= mode.maxPlayers then
				tryStartAnyMatch()
				return
			end

			broadcastModeQueue("ffa", remaining)
			task.wait(1)
		end

		if token ~= ffaFillToken or arenaBusy then
			return
		end
		if #queues.ffa >= mode.minPlayers then
			tryStartFFA()
		end
	end)
end

local function onQueueChanged(modeId)
	broadcastModeQueue(modeId, nil)

	if modeId == "ffa" then
		local mode = getMode("ffa")
		if #queues.ffa >= mode.maxPlayers then
			tryStartAnyMatch()
			return
		end
		if #queues.ffa >= mode.minPlayers then
			scheduleFFAFill()
			return
		end
	end

	tryStartAnyMatch()
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	if not arenaBusy then
		broadcastAllQueues(nil)
		tryStartAnyMatch()
		if #queues.ffa >= getMode("ffa").minPlayers then
			scheduleFFAFill()
		end
	else
		broadcastAllQueues(nil)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not getMode(modeId) then
		return false, "invalid_mode"
	end

	removeFromQueue(player)
	playerQueue[player] = modeId
	table.insert(queues[modeId], player)

	onQueueChanged(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		clearClientQueue(player)
		return
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	clearClientQueue(player)
	broadcastModeQueue(modeId, nil)
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
end

function MatchmakingService.getRecommendedMode(playerCount)
	if playerCount >= 3 then
		return "ffa"
	elseif playerCount == 2 then
		return "pvp"
	end
	return "training"
end

return MatchmakingService
