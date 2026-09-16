local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local remotes = nil
local matchReadyBindable = nil
local getPhase = nil
local leaveHubForArena = nil
local started = false

local function countQueue(modeId)
	local list = queues[modeId]
	local n = 0
	for _ in list do
		n += 1
	end
	return n
end

local function getQueuePlayers(modeId)
	local list = {}
	for player in queues[modeId] do
		if player.Parent and getPhase(player) == "hub" then
			table.insert(list, player)
		end
	end
	return list
end

local function resolveAutoMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function buildQueuePayload(player, modeId, status)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local inQueue = countQueue(modeId)
	local needed = mode.minPlayers
	local message

	if status == "pending" then
		message = "Arena belegt — Warte..."
	elseif status == "starting" then
		message = "Match startet..."
	elseif inQueue >= mode.maxPlayers then
		message = "Warteschlange voll"
	else
		message = string.format("%d / %d Spieler", inQueue, needed)
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		playersInQueue = inQueue,
		playersNeeded = needed,
		maxPlayers = mode.maxPlayers,
		status = status or "waiting",
		message = message,
		inQueue = playerQueue[player] == modeId,
	}
end

local function sendQueueUpdate(player, modeId, status)
	if not remotes or not player.Parent then
		return
	end
	local payload = buildQueuePayload(player, modeId, status)
	if payload then
		remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueue(modeId)
	for player, queuedMode in playerQueue do
		if queuedMode == modeId and player.Parent then
			local status = MatchStateService.isArenaBusy() and "pending" or "waiting"
			sendQueueUpdate(player, modeId, status)
		end
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	queues[modeId][player] = nil
	playerQueue[player] = nil

	if modeId == "ffa" then
		local remaining = countQueue("ffa")
		if remaining < MatchModes.get("ffa").minPlayers then
			clearFillTimer("ffa")
		end
	end

	broadcastQueue(modeId)
end

local function takePlayers(modeId, count)
	local available = getQueuePlayers(modeId)
	table.sort(available, function(a, b)
		return a.UserId < b.UserId
	end)

	local picked = {}
	for i = 1, math.min(count, #available) do
		table.insert(picked, available[i])
	end

	for _, player in picked do
		removeFromQueue(player)
	end

	return picked
end

local function launchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	for _, player in playerList do
		sendQueueUpdate(player, modeId, "starting")
		if leaveHubForArena then
			leaveHubForArena(player)
		end
	end

	if matchReadyBindable then
		matchReadyBindable:Fire(playerList, modeId)
	end
end

local function tryStartMode(modeId)
	if MatchStateService.isArenaBusy() then
		broadcastQueue(modeId)
		return false
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	local inQueue = countQueue(modeId)
	if inQueue < mode.minPlayers then
		return false
	end

	if modeId == "ffa" and inQueue < mode.maxPlayers then
		return false
	end

	local players = takePlayers(modeId, mode.maxPlayers)
	if #players >= mode.minPlayers then
		clearFillTimer(modeId)
		launchMatch(modeId, players)
		return true
	end

	return false
end

local function scheduleFfaFill()
	local mode = MatchModes.get("ffa")
	if fillTimers.ffa or countQueue("ffa") < mode.minPlayers then
		return
	end

	fillTimers.ffa = task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		fillTimers.ffa = nil
		if MatchStateService.isArenaBusy() then
			broadcastQueue("ffa")
			return
		end

		local inQueue = countQueue("ffa")
		if inQueue >= mode.minPlayers then
			local players = takePlayers("ffa", math.min(inQueue, mode.maxPlayers))
			if #players >= mode.minPlayers then
				launchMatch("ffa", players)
			end
		end
	end)
end

local function onQueueChanged(modeId)
	broadcastQueue(modeId)

	if MatchStateService.isArenaBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	local inQueue = countQueue(modeId)

	if mode.instantStart and inQueue >= mode.minPlayers then
		tryStartMode(modeId)
		return
	end

	if modeId == "pvp" and inQueue >= mode.maxPlayers then
		tryStartMode(modeId)
		return
	end

	if modeId == "ffa" then
		if inQueue >= mode.maxPlayers then
			clearFillTimer("ffa")
			tryStartMode("ffa")
		elseif inQueue >= mode.minPlayers then
			scheduleFfaFill()
		else
			clearFillTimer("ffa")
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if getPhase(player) ~= "hub" then
		return false, "Nicht in der Lobby"
	end

	local resolved = modeId
	if resolved == "auto" or resolved == nil then
		resolved = resolveAutoMode()
	end

	local mode = MatchModes.get(resolved)
	if not mode then
		return false, "Unbekannter Modus"
	end

	if playerQueue[player] == resolved then
		local status = MatchStateService.isArenaBusy() and "pending" or "waiting"
		sendQueueUpdate(player, resolved, status)
		return true
	end

	if playerQueue[player] then
		removeFromQueue(player)
	end

	queues[resolved][player] = true
	playerQueue[player] = resolved

	local status = MatchStateService.isArenaBusy() and "pending" or "waiting"
	sendQueueUpdate(player, resolved, status)
	onQueueChanged(resolved)

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end
	removeFromQueue(player)
	return true
end

function MatchmakingService.onArenaFreed()
	MatchStateService.setArenaBusy(false)

	for _, modeId in MatchModes.all() do
		broadcastQueue(modeId)
		onQueueChanged(modeId)
	end
end

function MatchmakingService.isPlayerQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.start(options)
	if started then
		return
	end
	started = true

	remotes = options.remotes
	matchReadyBindable = options.matchReadyBindable
	getPhase = options.getPhase
	leaveHubForArena = options.leaveHubForArena

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = "auto"
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
