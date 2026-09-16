local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady

local queues = {}
local queueByPlayer = {}
local pendingByPlayer = {}

local function initQueues()
	for modeId in MatchModes do
		if typeof(MatchModes[modeId]) == "table" and MatchModes[modeId].id then
			queues[modeId] = { players = {}, fillToken = 0 }
		end
	end
end

local function removeFromQueue(player)
	local modeId = queueByPlayer[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	if not queue then
		queueByPlayer[player] = nil
		return
	end

	for i, queued in queue.players do
		if queued == player then
			table.remove(queue.players, i)
			break
		end
	end

	queue.fillToken += 1
	queueByPlayer[player] = nil
end

local function buildQueuePayload(player, modeId, status)
	local mode = MatchModes.get(modeId)
	if not mode then
		return { status = "idle" }
	end

	local queue = queues[modeId]
	local total = queue and #queue.players or 0
	local position = 0

	if queue and status == "queued" then
		for i, queued in queue.players do
			if queued == player then
				position = i
				break
			end
		end
	end

	local message
	if status == "pending" then
		message = "Arena belegt — du startest als Nächstes"
	elseif status == "queued" then
		if modeId == "training" then
			message = "Starte Training..."
		elseif total < mode.minPlayers then
			message = string.format("Warte auf Spieler (%d/%d)", total, mode.minPlayers)
		else
			message = string.format("Fast bereit (%d/%d)", total, mode.maxPlayers)
		end
	else
		message = ""
	end

	return {
		status = status,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		total = total,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		message = message,
	}
end

local function sendQueueUpdate(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function clearPlayerQueueState(player)
	removeFromQueue(player)
	pendingByPlayer[player] = nil
	sendQueueUpdate(player, { status = "idle" })
end

local function broadcastQueueMode(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end

	for _, player in queue.players do
		if player.Parent then
			sendQueueUpdate(player, buildQueuePayload(player, modeId, "queued"))
		end
	end
end

local function leaveHubForArena(player)
	if HubService.getPhase(player) == "arena" then
		return
	end
	HubService.leaveHubForArena(player)
end

local function tryStartMatch(modeId)
	if MatchStateService.isBusy() then
		return false
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if not mode or not queue or #queue.players < mode.minPlayers then
		return false
	end

	local count = math.min(#queue.players, mode.maxPlayers)
	local matched = {}
	for i = 1, count do
		table.insert(matched, queue.players[i])
	end

	for i = 1, count do
		table.remove(queue.players, 1)
	end

	queue.fillToken += 1

	for _, player in matched do
		queueByPlayer[player] = nil
		pendingByPlayer[player] = nil
		sendQueueUpdate(player, { status = "starting", modeId = modeId, modeLabel = mode.label })
		leaveHubForArena(player)
	end

	broadcastQueueMode(modeId)
	MatchReady:Fire(matched, modeId)
	return true
end

local function scheduleFillTimeout(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if not mode or not queue or not mode.fillTimeout then
		return
	end

	queue.fillToken += 1
	local token = queue.fillToken

	task.delay(mode.fillTimeout, function()
		if token ~= queue.fillToken then
			return
		end
		if MatchStateService.isBusy() then
			return
		end
		if #queue.players >= mode.minPlayers then
			tryStartMatch(modeId)
		end
	end)
end

local function evaluateQueue(modeId)
	if MatchStateService.isBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if not mode or not queue then
		return
	end

	if modeId == "training" and #queue.players >= 1 then
		tryStartMatch(modeId)
	elseif modeId == "pvp" and #queue.players >= 2 then
		tryStartMatch(modeId)
	elseif modeId == "ffa" and #queue.players >= mode.maxPlayers then
		tryStartMatch(modeId)
	elseif mode.fillTimeout and #queue.players >= 1 then
		scheduleFillTimeout(modeId)
	end
end

local function processPending()
	if MatchStateService.isBusy() then
		return
	end

	for player, modeId in pendingByPlayer do
		if not player.Parent then
			pendingByPlayer[player] = nil
			continue
		end

		if queueByPlayer[player] then
			pendingByPlayer[player] = nil
			continue
		end

		pendingByPlayer[player] = nil
		MatchmakingService.joinQueue(player, modeId)
		return
	end

	for modeId, queue in queues do
		if #queue.players > 0 then
			evaluateQueue(modeId)
			return
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not player or not player.Parent then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if queueByPlayer[player] == modeId and not pendingByPlayer[player] then
		sendQueueUpdate(player, buildQueuePayload(player, modeId, "queued"))
		return
	end

	removeFromQueue(player)
	pendingByPlayer[player] = nil

	if MatchStateService.isBusy() then
		pendingByPlayer[player] = modeId
		sendQueueUpdate(player, buildQueuePayload(player, modeId, "pending"))
		return
	end

	table.insert(queues[modeId].players, player)
	queueByPlayer[player] = modeId
	sendQueueUpdate(player, buildQueuePayload(player, modeId, "queued"))
	broadcastQueueMode(modeId)
	evaluateQueue(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not player then
		return
	end

	local modeId = queueByPlayer[player] or pendingByPlayer[player]
	removeFromQueue(player)
	pendingByPlayer[player] = nil
	sendQueueUpdate(player, { status = "idle" })

	if modeId then
		broadcastQueueMode(modeId)
	end
end

function MatchmakingService.start()
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchModes.getRecommended(#Players:GetPlayers())
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		clearPlayerQueueState(player)
	end)

	MatchStateService.onArenaFree(function()
		processPending()
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
