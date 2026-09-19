local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimerActive = {}
local pendingMatch = nil

local Remotes
local MatchReady

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

local function removeFromQueueList(list, player)
	for index, queuedPlayer in list do
		if queuedPlayer == player then
			table.remove(list, index)
			return true
		end
	end
	return false
end

local function cancelFillTimer(modeId)
	fillTimerActive[modeId] = false
end

local function startFFATimer(modeId)
	if fillTimerActive[modeId] then
		return
	end

	local mode = getMode(modeId)
	if not mode or mode.id ~= "ffa" then
		return
	end

	fillTimerActive[modeId] = true
	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		fillTimerActive[modeId] = false
		if queueCount(modeId) < mode.minPlayers then
			return
		end
		local players = takeQueuedPlayers(modeId, queueCount(modeId))
		tryLaunchMatch(modeId, players)
	end)
end

local function buildQueuePayload(player, modeId, status)
	local mode = getMode(modeId)
	if not mode then
		return { inQueue = false }
	end

	local count = queueCount(modeId)
	local needed = mode.maxPlayers
	local message = "Suche Spieler..."

	if status == "pending" then
		message = "Arena belegt — Warte..."
	elseif status == "starting" then
		message = "Match startet!"
	elseif count >= mode.minPlayers and mode.id == "ffa" and count < mode.maxPlayers then
		message = string.format("Warte auf Spieler (%d/%d)...", count, mode.maxPlayers)
	elseif count < mode.minPlayers then
		message = string.format("Suche Spieler (%d/%d)...", count, mode.minPlayers)
	else
		message = string.format("Bereit (%d/%d)", count, needed)
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		count = count,
		needed = needed,
		minPlayers = mode.minPlayers,
		status = status or "searching",
		message = message,
	}
end

local function sendQueueUpdate(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueue(modeId, status)
	local payload = buildQueuePayload(nil, modeId, status)
	for _, queuedPlayer in ensureQueue(modeId) do
		sendQueueUpdate(queuedPlayer, payload)
	end
end

local function clearPlayerQueueState(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueueList(ensureQueue(modeId), player)
	playerQueue[player] = nil
	cancelFillTimer(modeId)
	sendQueueUpdate(player, { inQueue = false })
	broadcastQueue(modeId)
end

local function takeQueuedPlayers(modeId, count)
	local queue = ensureQueue(modeId)
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end
	broadcastQueue(modeId)
	return taken
end

local function startMatch(modeId, players)
	if #players == 0 then
		return
	end

	for _, player in players do
		sendQueueUpdate(player, buildQueuePayload(player, modeId, "starting"))
	end

	MatchReady:Fire(modeId, players)

	task.delay(0.5, function()
		for _, queuedPlayer in players do
			sendQueueUpdate(queuedPlayer, { inQueue = false })
		end
	end)
end

local function tryLaunchMatch(modeId, players)
	if #players == 0 then
		return
	end

	if MatchStateService.isBusy() then
		pendingMatch = {
			modeId = modeId,
			players = players,
		}
		for _, player in players do
			if player.Parent then
				playerQueue[player] = modeId
				table.insert(ensureQueue(modeId), player)
			end
		end
		broadcastQueue(modeId, "pending")
		return
	end

	startMatch(modeId, players)
end

local function evaluateQueue(modeId)
	local mode = getMode(modeId)
	if not mode then
		return
	end

	local count = queueCount(modeId)
	if count < mode.minPlayers then
		return
	end

	if count >= mode.maxPlayers then
		cancelFillTimer(modeId)
		local players = takeQueuedPlayers(modeId, mode.maxPlayers)
		tryLaunchMatch(modeId, players)
		return
	end

	if mode.id == "training" or mode.id == "pvp" then
		cancelFillTimer(modeId)
		local players = takeQueuedPlayers(modeId, mode.maxPlayers)
		tryLaunchMatch(modeId, players)
		return
	end

	if mode.id == "ffa" and count >= mode.minPlayers and count < mode.maxPlayers then
		startFFATimer(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not getMode(modeId) then
		return
	end

	if playerQueue[player] == modeId then
		sendQueueUpdate(player, buildQueuePayload(player, modeId))
		return
	end

	clearPlayerQueueState(player)
	playerQueue[player] = modeId
	table.insert(ensureQueue(modeId), player)
	sendQueueUpdate(player, buildQueuePayload(player, modeId))
	broadcastQueue(modeId)
	evaluateQueue(modeId)
end

function MatchmakingService.leaveQueue(player)
	clearPlayerQueueState(player)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onArenaFree()
	if pendingMatch and not MatchStateService.isBusy() then
		local match = pendingMatch
		pendingMatch = nil

		local activePlayers = {}
		for _, player in match.players do
			if player.Parent and playerQueue[player] == match.modeId then
				table.insert(activePlayers, player)
			end
		end

		for _, player in activePlayers do
			removeFromQueueList(ensureQueue(match.modeId), player)
			playerQueue[player] = nil
		end
		broadcastQueue(match.modeId)

		local mode = getMode(match.modeId)
		if mode and #activePlayers >= mode.minPlayers then
			local players = activePlayers
			if #players > mode.maxPlayers then
				local trimmed = {}
				for index = 1, mode.maxPlayers do
					trimmed[index] = players[index]
				end
				players = trimmed
				for index = mode.maxPlayers + 1, #activePlayers do
					local leftover = activePlayers[index]
					if leftover.Parent then
						MatchmakingService.joinQueue(leftover, match.modeId)
					end
				end
			end
			startMatch(match.modeId, players)
		end
	end
end

function MatchmakingService.init(getActiveModeId)
	local remotes, bindables = RemotesSetup.ensure()
	Remotes = remotes
	MatchReady = bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = getActiveModeId()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
		if pendingMatch then
			local filtered = {}
			for _, pendingPlayer in pendingMatch.players do
				if pendingPlayer ~= player then
					table.insert(filtered, pendingPlayer)
				end
			end
			pendingMatch.players = filtered
			if #filtered == 0 then
				pendingMatch = nil
			end
		end
	end)

	MatchStateService.onArenaFree(function()
		MatchmakingService.onArenaFree()
	end)
end

return MatchmakingService
