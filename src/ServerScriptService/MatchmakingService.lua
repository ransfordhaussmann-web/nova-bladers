local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local Bindables

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local ffaFillToken = 0
local pendingMatch = nil
local started = false

local function getQueue(modeId)
	return queues[modeId]
end

local function countValidPlayers(queue)
	local count = 0
	for _, player in queue do
		if player.Parent and HubService.getPhase(player) == "hub" then
			count += 1
		end
	end
	return count
end

local function buildStatusText(modeConfig, queueCount, status)
	if status == MatchmakingConfig.QUEUE_STATUS.PENDING then
		return "Arena belegt — warte auf freien Slot..."
	end
	if status == MatchmakingConfig.QUEUE_STATUS.STARTING then
		return "Match startet..."
	end
	if queueCount < modeConfig.minPlayers then
		return string.format("Warte auf Spieler (%d/%d)...", queueCount, modeConfig.minPlayers)
	end
	if modeConfig.id == "ffa" and queueCount < modeConfig.maxPlayers then
		return string.format("Spieler gefunden (%d/%d) — Füll-Timer läuft...", queueCount, modeConfig.maxPlayers)
	end
	return string.format("Bereit (%d/%d)", queueCount, modeConfig.maxPlayers)
end

local function sendQueueUpdate(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueue(modeId)
	local modeConfig = MatchmakingConfig.getMode(modeId)
	if not modeConfig then
		return
	end

	local queue = getQueue(modeId)
	local queueCount = countValidPlayers(queue)
	local arenaBusy = GameMatchState.isBusy()
	local status = MatchmakingConfig.QUEUE_STATUS.WAITING

	if pendingMatch and pendingMatch.modeId == modeId then
		status = MatchmakingConfig.QUEUE_STATUS.PENDING
	elseif queueCount >= modeConfig.minPlayers and not arenaBusy then
		status = MatchmakingConfig.QUEUE_STATUS.STARTING
	end

	for _, player in queue do
		if player.Parent and playerMode[player] == modeId then
			sendQueueUpdate(player, {
				inQueue = true,
				mode = modeId,
				modeLabel = modeConfig.label,
				players = queueCount,
				minPlayers = modeConfig.minPlayers,
				maxPlayers = modeConfig.maxPlayers,
				status = status,
				statusText = buildStatusText(modeConfig, queueCount, status),
			})
		end
	end
end

local function clearPlayerFromQueues(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	playerMode[player] = nil
	local queue = getQueue(modeId)
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end

	sendQueueUpdate(player, { inQueue = false })
	broadcastQueue(modeId)
end

local function takePlayersFromQueue(modeId, count)
	local queue = getQueue(modeId)
	local taken = {}
	local remaining = {}

	for _, player in queue do
		if #taken < count and player.Parent and HubService.getPhase(player) == "hub" then
			table.insert(taken, player)
			playerMode[player] = nil
			sendQueueUpdate(player, { inQueue = false })
		else
			table.insert(remaining, player)
		end
	end

	queues[modeId] = remaining
	return taken
end

local function launchMatch(modeId, playerList)
	pendingMatch = nil
	ffaFillToken += 1

	for _, player in playerList do
		if player.Parent then
			HubService.leaveHubForArena(player)
		end
	end

	Bindables.MatchReady:Fire(playerList, modeId)
end

local function tryStartMatch(modeId)
	local modeConfig = MatchmakingConfig.getMode(modeId)
	if not modeConfig then
		return
	end

	local queue = getQueue(modeId)
	local queueCount = countValidPlayers(queue)
	if queueCount < modeConfig.minPlayers then
		return
	end

	if GameMatchState.isBusy() then
		pendingMatch = {
			modeId = modeId,
			playerCount = math.min(queueCount, modeConfig.maxPlayers),
		}
		broadcastQueue(modeId)
		return
	end

	local playerCount = math.min(queueCount, modeConfig.maxPlayers)
	local players = takePlayersFromQueue(modeId, playerCount)
	if #players < modeConfig.minPlayers then
		for _, player in players do
			MatchmakingService.joinQueue(player, modeId)
		end
		return
	end

	launchMatch(modeId, players)
	broadcastQueue(modeId)
end

local function scheduleFfaFill()
	local modeConfig = MatchmakingConfig.MODES.ffa
	ffaFillToken += 1
	local token = ffaFillToken

	task.delay(modeConfig.fillTimeout, function()
		if token ~= ffaFillToken then
			return
		end
		if countValidPlayers(queues.ffa) >= modeConfig.minPlayers then
			tryStartMatch("ffa")
		end
	end)
end

local function onQueueChanged(modeId)
	broadcastQueue(modeId)

	local modeConfig = MatchmakingConfig.getMode(modeId)
	if not modeConfig then
		return
	end

	local queueCount = countValidPlayers(getQueue(modeId))

	if modeId == "training" or modeId == "pvp" then
		if queueCount >= modeConfig.maxPlayers then
			tryStartMatch(modeId)
		end
		return
	end

	if modeId == "ffa" then
		if queueCount >= modeConfig.maxPlayers then
			ffaFillToken += 1
			tryStartMatch("ffa")
		elseif queueCount >= modeConfig.minPlayers then
			scheduleFfaFill()
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchmakingConfig.isValidMode(modeId) then
		return false
	end
	if HubService.getPhase(player) ~= "hub" then
		return false
	end
	if playerMode[player] == modeId then
		return true
	end

	clearPlayerFromQueues(player)

	playerMode[player] = modeId
	table.insert(getQueue(modeId), player)
	onQueueChanged(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		sendQueueUpdate(player, { inQueue = false })
		return
	end

	clearPlayerFromQueues(player)
	onQueueChanged(modeId)
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

local function processPendingMatch()
	if not pendingMatch or GameMatchState.isBusy() then
		return
	end

	local modeId = pendingMatch.modeId
	pendingMatch = nil
	tryStartMatch(modeId)
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.ArenaFree.Event:Connect(function()
		processPendingMatch()
		for modeId, _ in pairs(queues) do
			onQueueChanged(modeId)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
