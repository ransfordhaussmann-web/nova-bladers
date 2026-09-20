local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local Bindables

local queues = {}
local playerQueue = {}
local pendingStart = nil
local fillTimers = {}

local function initQueues()
	for _, modeId in MatchModes.all() do
		queues[modeId] = {}
	end
end

local function getQueueCount(modeId)
	local queue = queues[modeId]
	if not queue then
		return 0
	end
	local count = 0
	for _ in queue do
		count += 1
	end
	return count
end

local function getQueueList(modeId)
	local list = {}
	for player in queues[modeId] or {} do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function getPlayerMode(player)
	local entry = playerQueue[player]
	return entry and entry.modeId
end

local function buildStatusText(modeId, position, total, pending)
	local mode = MatchModes.get(modeId)
	if pending then
		return "Arena belegt — du bist als Nächster dran"
	end
	if modeId == "training" then
		return "Starte Training..."
	elseif modeId == "pvp" then
		return string.format("Warte auf Gegner (%d/2)", total)
	elseif modeId == "ffa" then
		return string.format("Warte auf Spieler (%d/%d)", total, mode.maxPlayers)
	end
	return "In Warteschlange..."
end

local function sendQueueUpdate(player)
	local entry = playerQueue[player]
	if not entry or not player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	local mode = MatchModes.get(entry.modeId)
	local list = getQueueList(entry.modeId)
	local position = 1
	for i, p in list do
		if p == player then
			position = i
			break
		end
	end

	Remotes.QueueUpdate:FireClient(player, {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode.label,
		position = position,
		total = #list,
		needed = mode.maxPlayers,
		pending = entry.pending == true,
		statusText = buildStatusText(entry.modeId, position, #list, entry.pending),
	})
end

local function broadcastQueue(modeId)
	for player in queues[modeId] or {} do
		sendQueueUpdate(player)
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function removeFromQueue(player)
	local modeId = getPlayerMode(player)
	if not modeId then
		return
	end

	queues[modeId][player] = nil
	playerQueue[player] = nil

	if getQueueCount(modeId) < MatchModes.get(modeId).minPlayers then
		clearFillTimer(modeId)
	end

	broadcastQueue(modeId)
end

local function canStartNow(modeId)
	local mode = MatchModes.get(modeId)
	local list = getQueueList(modeId)
	local count = #list

	if count < mode.minPlayers then
		return false
	end
	if count >= mode.maxPlayers then
		return true
	end
	if modeId == "training" or modeId == "pvp" then
		return count >= mode.minPlayers
	end
	return fillTimers[modeId] ~= nil
end

local function takePlayersForMatch(modeId)
	local mode = MatchModes.get(modeId)
	local list = getQueueList(modeId)
	table.sort(list, function(a, b)
		return a.UserId < b.UserId
	end)

	local matchPlayers = {}
	for i = 1, math.min(#list, mode.maxPlayers) do
		table.insert(matchPlayers, list[i])
	end

	for _, player in matchPlayers do
		queues[modeId][player] = nil
		playerQueue[player] = nil
	end

	clearFillTimer(modeId)
	broadcastQueue(modeId)

	return matchPlayers
end

local function tryStartMatch(modeId)
	if not canStartNow(modeId) then
		return
	end

	local players = takePlayersForMatch(modeId)
	if #players == 0 then
		return
	end

	if MatchStateService.isArenaBusy() then
		pendingStart = { modeId = modeId, players = players }
		for _, player in players do
			playerQueue[player] = { modeId = modeId, pending = true }
			sendQueueUpdate(player)
		end
		return
	end

	MatchStateService.setArenaBusy(true)
	for _, player in players do
		HubService.enterArena(player)
	end
	Bindables.MatchReady:Fire({
		modeId = modeId,
		players = players,
	})
end

local function scheduleFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if modeId ~= "ffa" or fillTimers[modeId] then
		return
	end
	if getQueueCount(modeId) < mode.minPlayers then
		return
	end

	fillTimers[modeId] = task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		fillTimers[modeId] = nil
		tryStartMatch(modeId)
	end)
end

local function evaluateQueue(modeId)
	if canStartNow(modeId) then
		tryStartMatch(modeId)
		return
	end
	scheduleFillTimer(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end
	if MatchStateService.isArenaBusy() and HubService.getPhase(player) == "arena" then
		return
	end
	if getPlayerMode(player) then
		MatchmakingService.leaveQueue(player)
	end

	queues[modeId][player] = true
	playerQueue[player] = { modeId = modeId, pending = false }

	sendQueueUpdate(player)
	broadcastQueue(modeId)
	evaluateQueue(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not getPlayerMode(player) then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	local wasPending = playerQueue[player] and playerQueue[player].pending
	removeFromQueue(player)

	if wasPending and pendingStart then
		for _, p in pendingStart.players do
			if p == player then
				pendingStart = nil
				break
			end
		end
	end
end

local function onMatchEnded()
	MatchStateService.setArenaBusy(false)

	if pendingStart then
		local payload = pendingStart
		pendingStart = nil

		local validPlayers = {}
		for _, player in payload.players do
			if player.Parent then
				table.insert(validPlayers, player)
			end
		end

		if #validPlayers > 0 then
			MatchStateService.setArenaBusy(true)
			for _, player in validPlayers do
				HubService.enterArena(player)
			end
			Bindables.MatchReady:Fire({
				modeId = payload.modeId,
				players = validPlayers,
			})
			return
		end
	end

	for _, modeId in MatchModes.all() do
		evaluateQueue(modeId)
	end
end

function MatchmakingService.init()
	Remotes, Bindables = RemotesSetup.ensure()
	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(onMatchEnded)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
