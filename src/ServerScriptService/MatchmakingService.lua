local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local MatchReady
local MatchEnded

local onPrepareForMatch
local getRecommendedModeId
local getPhase

local queues = {}
local playerToMode = {}
local fillTimers = {}
local pendingLaunch = nil
local initialized = false

local function getMode(modeId)
	return MatchModes[modeId]
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function queueCount(modeId)
	return #ensureQueue(modeId)
end

local function isInQueue(player)
	return playerToMode[player] ~= nil
end

local function buildQueuePayload(player, modeId, status)
	local mode = getMode(modeId)
	if not mode then
		return nil
	end

	local count = queueCount(modeId)
	local payload = {
		modeId = modeId,
		modeLabel = mode.label,
		status = status or "waiting",
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillTimeout = mode.fillTimeout,
	}

	if status == "pending" then
		payload.message = "Arena belegt — warte auf freien Slot"
	elseif count < mode.minPlayers then
		payload.message = string.format("Warte auf Spieler (%d/%d)", count, mode.minPlayers)
	elseif modeId == "ffa" and count < mode.maxPlayers then
		payload.message = string.format("Suche Mitspieler (%d/%d)", count, mode.maxPlayers)
	else
		payload.message = "Match startet gleich..."
	end

	return payload
end

local function sendQueueUpdate(player, modeId, status)
	if not player.Parent then
		return
	end
	local payload = buildQueuePayload(player, modeId, status)
	if payload then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueueUpdate(modeId, status)
	for _, player in ensureQueue(modeId) do
		sendQueueUpdate(player, modeId, status)
	end
end

local function cancelFillTimer(modeId)
	fillTimers[modeId] = nil
end

local function removeFromQueue(player)
	local modeId = playerToMode[player]
	if not modeId then
		return nil
	end

	playerToMode[player] = nil
	local queue = ensureQueue(modeId)
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	if queueCount(modeId) < getMode(modeId).minPlayers then
		cancelFillTimer(modeId)
	end

	broadcastQueueUpdate(modeId, "waiting")
	return modeId
end

local function takePlayers(modeId, count)
	local queue = ensureQueue(modeId)
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerToMode[player] = nil
			table.insert(taken, player)
		end
	end
	return taken
end

local function launchMatch(modeId, players)
	if #players == 0 then
		return
	end

	if MatchStateService.isBusy() then
		pendingLaunch = {
			modeId = modeId,
			players = players,
		}
		for _, player in players do
			sendQueueUpdate(player, modeId, "pending")
		end
		return
	end

	pendingLaunch = nil
	MatchStateService.setBusy()

	for _, player in players do
		if onPrepareForMatch then
			onPrepareForMatch(player)
		end
	end

	MatchReady:Fire(players, modeId)
end

local function tryLaunchMode(modeId)
	local mode = getMode(modeId)
	local count = queueCount(modeId)
	if count < mode.minPlayers then
		return
	end

	if modeId == "training" then
		launchMatch(modeId, takePlayers(modeId, 1))
		return
	end

	if modeId == "pvp" then
		if count >= 2 then
			cancelFillTimer(modeId)
			launchMatch(modeId, takePlayers(modeId, 2))
		end
		return
	end

	if modeId == "ffa" then
		if count >= mode.maxPlayers then
			cancelFillTimer(modeId)
			launchMatch(modeId, takePlayers(modeId, mode.maxPlayers))
			return
		end

		if count >= mode.minPlayers and not fillTimers[modeId] then
			local token = {}
			fillTimers[modeId] = token
			broadcastQueueUpdate(modeId, "filling")

			task.delay(mode.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT, function()
				if fillTimers[modeId] ~= token then
					return
				end
				fillTimers[modeId] = nil
				local currentCount = queueCount(modeId)
				if currentCount >= mode.minPlayers then
					launchMatch(modeId, takePlayers(modeId, currentCount))
				end
			end)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not getMode(modeId) then
		return false, "invalid_mode"
	end
	if getPhase and getPhase(player) == "arena" then
		return false, "in_match"
	end

	if isInQueue(player) then
		if playerToMode[player] == modeId then
			sendQueueUpdate(player, modeId, "waiting")
			return true
		end
		MatchmakingService.leaveQueue(player)
	end

	playerToMode[player] = modeId
	table.insert(ensureQueue(modeId), player)
	sendQueueUpdate(player, modeId, "waiting")
	tryLaunchMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromQueue(player)
	if modeId and pendingLaunch and pendingLaunch.modeId == modeId then
		for index, pendingPlayer in pendingLaunch.players do
			if pendingPlayer == player then
				table.remove(pendingLaunch.players, index)
				break
			end
		end
		if #pendingLaunch.players == 0 then
			pendingLaunch = nil
		end
	end
	Remotes.QueueUpdate:FireClient(player, { status = "idle" })
end

function MatchmakingService.getPlayerMode(player)
	return playerToMode[player]
end

function MatchmakingService.onMatchEnded()
	MatchStateService.clearBusy()

	if pendingLaunch and #pendingLaunch.players > 0 then
		local launch = pendingLaunch
		pendingLaunch = nil
		task.defer(function()
			launchMatch(launch.modeId, launch.players)
		end)
	end
end

function MatchmakingService.init(options)
	if initialized then
		return
	end
	initialized = true

	Remotes = options.remotes
	MatchReady = options.matchReady
	MatchEnded = options.matchEnded
	onPrepareForMatch = options.onPrepareForMatch
	getRecommendedModeId = options.getRecommendedModeId
	getPhase = options.getPhase

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or modeId == "" then
			modeId = getRecommendedModeId and getRecommendedModeId() or "training"
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
