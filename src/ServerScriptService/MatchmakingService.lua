local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local GameMatchState = require(ReplicatedStorage.NovaBladers.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local Bindables

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerEntry = {}
local pendingMatch = nil
local ffaFillToken = 0
local started = false

local function getMode(modeId)
	return MatchModes[modeId]
end

local function isValidMode(modeId)
	return getMode(modeId) ~= nil
end

local function removeFromQueueList(queue, player)
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			return true
		end
	end
	return false
end

local function removePlayerFromQueues(player)
	for _, queue in queues do
		removeFromQueueList(queue, player)
	end
	playerEntry[player] = nil
end

local function queueIndex(queue, player)
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			return index
		end
	end
	return nil
end

local function buildQueueMessage(modeId, status, queueSize)
	local mode = getMode(modeId)
	if status == "pending" then
		return "Arena belegt — Match startet gleich..."
	end
	if modeId == "training" then
		return "Training startet..."
	end
	if modeId == "pvp" then
		if queueSize >= mode.minPlayers then
			return "Gegner gefunden!"
		end
		return "Warte auf Gegner (1/2)..."
	end
	if queueSize >= MatchmakingConfig.MAX_FFA_PLAYERS then
		return "Warteschlange voll — Match startet..."
	end
	if queueSize >= mode.minPlayers then
		return string.format("Warte auf Spieler (%d/%d)...", queueSize, MatchmakingConfig.MAX_FFA_PLAYERS)
	end
	return string.format("Warte auf Spieler (%d/%d)...", queueSize, mode.minPlayers)
end

local function sendQueueUpdate(player)
	local entry = playerEntry[player]
	if not entry or not player.Parent then
		return
	end

	local queue = queues[entry.modeId]
	local queueSize = #queue
	local position = queueIndex(queue, player) or queueSize

	Remotes.QueueUpdate:FireClient(player, {
		inQueue = true,
		mode = entry.modeId,
		modeLabel = getMode(entry.modeId).label,
		position = position,
		queueSize = queueSize,
		status = entry.status,
		message = buildQueueMessage(entry.modeId, entry.status, queueSize),
	})
end

local function broadcastQueueUpdates(modeId)
	for player, entry in playerEntry do
		if entry.modeId == modeId and player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function clearQueueUI(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function takePlayersFromQueue(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(taken, player)
		end
	end
	return taken
end

local function markPlayersForMatch(players, modeId, status)
	for _, player in players do
		playerEntry[player] = {
			modeId = modeId,
			status = status,
		}
	end
end

local function clearPlayersFromQueue(players)
	for _, player in players do
		playerEntry[player] = nil
		clearQueueUI(player)
	end
end

local function launchMatch(players, modeId)
	if #players == 0 then
		return
	end

	GameMatchState.setBusy(true)
	clearPlayersFromQueue(players)

	for _, player in players do
		HubService.leaveHubForMatch(player)
	end

	Bindables.MatchReady:Fire({
		players = players,
		mode = modeId,
	})
end

local function tryLaunchMatch(players, modeId)
	if #players == 0 then
		return
	end

	if GameMatchState.isBusy() then
		pendingMatch = {
			players = players,
			mode = modeId,
		}
		markPlayersForMatch(players, modeId, "pending")
		for _, player in players do
			sendQueueUpdate(player)
		end
		return
	end

	launchMatch(players, modeId)
end

local function tryStartMode(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]

	if modeId == "ffa" then
		if #queue < mode.minPlayers then
			return
		end
		if ffaFillToken ~= 0 then
			return
		end

		ffaFillToken += 1
		local token = ffaFillToken
		broadcastQueueUpdates(modeId)

		task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
			if token ~= ffaFillToken then
				return
			end
			ffaFillToken = 0

			local count = math.min(#queues.ffa, MatchmakingConfig.MAX_FFA_PLAYERS)
			if count < mode.minPlayers then
				broadcastQueueUpdates(modeId)
				return
			end

			local players = takePlayersFromQueue(modeId, count)
			tryLaunchMatch(players, modeId)
		end)
		return
	end

	if #queue < mode.minPlayers then
		return
	end

	local players = takePlayersFromQueue(modeId, mode.minPlayers)
	tryLaunchMatch(players, modeId)
end

local function tryStartAllModes()
	for modeId in MatchModes do
		tryStartMode(modeId)
	end
end

local function onArenaFree()
	if pendingMatch then
		local match = pendingMatch
		pendingMatch = nil
		launchMatch(match.players, match.mode)
		return
	end

	tryStartAllModes()
end

function MatchmakingService.getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= MatchmakingConfig.MIN_FFA_PLAYERS then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end
	if GameMatchState.isBusy() and modeId == "training" and playerEntry[player] then
		return
	end

	removePlayerFromQueues(player)

	local queue = queues[modeId]
	table.insert(queue, player)
	playerEntry[player] = {
		modeId = modeId,
		status = "waiting",
	}

	sendQueueUpdate(player)
	broadcastQueueUpdates(modeId)
	tryStartMode(modeId)
end

function MatchmakingService.joinQuickMatch(player)
	MatchmakingService.joinQueue(player, MatchmakingService.getRecommendedModeId())
end

function MatchmakingService.leaveQueue(player)
	if not playerEntry[player] then
		clearQueueUI(player)
		return
	end

	local modeId = playerEntry[player].modeId
	removePlayerFromQueues(player)
	clearQueueUI(player)
	broadcastQueueUpdates(modeId)

	if pendingMatch then
		local pendingModeId = pendingMatch.mode
		local filtered = {}
		for _, queuedPlayer in pendingMatch.players do
			if queuedPlayer ~= player and queuedPlayer.Parent then
				table.insert(filtered, queuedPlayer)
			end
		end

		local mode = getMode(pendingModeId)
		if #filtered == 0 or (mode and #filtered < mode.minPlayers) then
			for _, queuedPlayer in filtered do
				playerEntry[queuedPlayer] = {
					modeId = pendingModeId,
					status = "waiting",
				}
				table.insert(queues[pendingModeId], queuedPlayer)
			end
			pendingMatch = nil
			tryStartMode(pendingModeId)
		else
			pendingMatch.players = filtered
			for _, queuedPlayer in filtered do
				sendQueueUpdate(queuedPlayer)
			end
		end
	end

	if modeId == "ffa" and #queues.ffa < MatchmakingConfig.MIN_FFA_PLAYERS then
		ffaFillToken = 0
	end
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) == "string" then
			MatchmakingService.joinQueue(player, modeId)
		else
			MatchmakingService.joinQuickMatch(player)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.ArenaFree.Event:Connect(onArenaFree)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)

		if pendingMatch then
			local filtered = {}
			for _, queuedPlayer in pendingMatch.players do
				if queuedPlayer ~= player and queuedPlayer.Parent then
					table.insert(filtered, queuedPlayer)
				end
			end
			if #filtered == 0 then
				pendingMatch = nil
			else
				pendingMatch.players = filtered
			end
		end
	end)
end

return MatchmakingService
