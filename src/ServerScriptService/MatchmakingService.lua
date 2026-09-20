local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchStateService = require(ReplicatedStorage.NovaBladers.MatchStateService)

local MatchmakingService = {}

local remotes
local bindables
local leaveHubForArena

local queues = {}
local playerQueue = {}
local fillTokens = {}
local fillTimerActive = {}

local function initQueues()
	for modeId, mode in pairs(MatchModes) do
		if typeof(mode) == "table" and mode.id then
			queues[modeId] = {}
		end
	end
end

local function isValidPlayer(player)
	return player and player.Parent == Players
end

local function getQueueSize(modeId)
	return #(queues[modeId] or {})
end

local function buildQueueMessage(mode, queueSize, status)
	if status == "pending" then
		return "Arena belegt — du bist als Nächstes dran"
	end

	if mode.id == "training" then
		return "Training startet gleich..."
	end

	if mode.id == "pvp" then
		return string.format("Warte auf Gegner... (%d/%d)", queueSize, mode.maxPlayers)
	end

	return string.format("Warte auf Spieler... (%d/%d)", queueSize, mode.maxPlayers)
end

local function sendQueueUpdate(player, payload)
	if isValidPlayer(player) then
		remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function clearQueueUpdate(player)
	sendQueueUpdate(player, { inQueue = false })
end

local function broadcastModeQueue(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = queues[modeId]
	local queueSize = #queue
	local pending = MatchStateService.isArenaBusy()

	for index, player in queue do
		if isValidPlayer(player) then
			sendQueueUpdate(player, {
				inQueue = true,
				modeId = modeId,
				modeLabel = mode.label,
				position = index,
				queueSize = queueSize,
				required = mode.maxPlayers,
				minPlayers = mode.minPlayers,
				status = pending and "pending" or "waiting",
				message = buildQueueMessage(mode, queueSize, pending and "pending" or "waiting"),
			})
		end
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	fillTimerActive[modeId] = false
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	if queue then
		for i = #queue, 1, -1 do
			if queue[i] == player then
				table.remove(queue, i)
				break
			end
		end
	end

	playerQueue[player] = nil
	clearQueueUpdate(player)
	broadcastModeQueue(modeId)

	if getQueueSize(modeId) < MatchModes.get(modeId).minPlayers then
		cancelFillTimer(modeId)
	end
end

local function takePlayersFromQueue(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	local limit = math.min(count, #queue)

	for _ = 1, limit do
		local player = table.remove(queue, 1)
		if isValidPlayer(player) then
			playerQueue[player] = nil
			clearQueueUpdate(player)
			table.insert(taken, player)
		end
	end

	broadcastModeQueue(modeId)
	return taken
end

local function launchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	MatchStateService.setArenaBusy(true)

	for _, player in playerList do
		sendQueueUpdate(player, {
			inQueue = true,
			modeId = modeId,
			modeLabel = MatchModes.get(modeId).label,
			status = "starting",
			message = "Match startet...",
		})
		if leaveHubForArena then
			leaveHubForArena(player)
		end
	end

	bindables.MatchReady:Fire({
		mode = modeId,
		players = playerList,
	})
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastModeQueue(modeId)
		return
	end

	local queueSize = getQueueSize(modeId)
	if queueSize < mode.minPlayers then
		return
	end

	if mode.id == "training" then
		launchMatch(modeId, takePlayersFromQueue(modeId, 1))
		return
	end

	if mode.id == "pvp" then
		if queueSize >= mode.maxPlayers then
			cancelFillTimer(modeId)
			launchMatch(modeId, takePlayersFromQueue(modeId, mode.maxPlayers))
		end
		return
	end

	if mode.id == "ffa" then
		if queueSize >= mode.maxPlayers then
			cancelFillTimer(modeId)
			launchMatch(modeId, takePlayersFromQueue(modeId, mode.maxPlayers))
			return
		end

		if fillTimerActive[modeId] then
			return
		end

		fillTimerActive[modeId] = true
		local token = (fillTokens[modeId] or 0) + 1
		fillTokens[modeId] = token

		task.delay(mode.fillTimeout or 12, function()
			fillTimerActive[modeId] = false
			if fillTokens[modeId] ~= token then
				return
			end

			if MatchStateService.isArenaBusy() then
				broadcastModeQueue(modeId)
				return
			end

			local size = getQueueSize(modeId)
			if size >= mode.minPlayers then
				launchMatch(modeId, takePlayersFromQueue(modeId, math.min(size, mode.maxPlayers)))
			end
		end)
	end
end

local function tryStartAllQueues()
	for modeId in pairs(queues) do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidPlayer(player) then
		return
	end
	if not MatchModes.isValid(modeId) then
		return
	end

	removeFromQueue(player)

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastModeQueue(modeId)
	tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	tryStartAllQueues()
end

function MatchmakingService.init(opts)
	remotes = opts.remotes
	bindables = opts.bindables
	leaveHubForArena = opts.leaveHubForArena

	initQueues()

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = "training"
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
