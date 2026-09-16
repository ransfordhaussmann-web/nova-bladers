local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {}
local pendingQueues = {}
local playerQueue = {}
local fillTimers = {}
local started = false

local function initQueues()
	for _, mode in MatchModes.getAll() do
		queues[mode.id] = {}
		pendingQueues[mode.id] = {}
	end
end

local function cancelFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
	return token
end

local function getQueueCount(modeId)
	return #queues[modeId] + #pendingQueues[modeId]
end

local function buildQueuePayload(player, modeId, status)
	local mode = MatchModes.get(modeId)
	if not mode then
		return { status = "none" }
	end

	local activeCount = #queues[modeId]
	local pendingCount = #pendingQueues[modeId]
	local total = activeCount + pendingCount

	local needed = mode.minPlayers
	if mode.id == "pvp" then
		needed = 2
	elseif mode.id == "training" then
		needed = 1
	end

	local message
	if status == "pending" then
		message = string.format("Arena belegt — %s (%d/%d)", mode.label, total, mode.maxPlayers)
	elseif mode.id == "training" then
		message = "Training startet..."
	elseif mode.id == "pvp" then
		message = string.format("Warte auf Gegner... (%d/2)", total)
	else
		message = string.format("FFA — Warte auf Spieler... (%d/%d)", total, mode.maxPlayers)
	end

	return {
		status = status,
		modeId = mode.id,
		modeLabel = mode.label,
		queued = total,
		needed = needed,
		max = mode.maxPlayers,
		message = message,
	}
end

local function sendQueueUpdate(player)
	local entry = playerQueue[player]
	if not entry then
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, { status = "none" })
		end
		return
	end

	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, entry.modeId, entry.status))
	end
end

local function broadcastModeQueue(modeId)
	for player, entry in playerQueue do
		if entry.modeId == modeId then
			sendQueueUpdate(player)
		end
	end
end

local function removeFromLists(player, modeId)
	local active = queues[modeId]
	for i = #active, 1, -1 do
		if active[i] == player then
			table.remove(active, i)
		end
	end

	local pending = pendingQueues[modeId]
	for i = #pending, 1, -1 do
		if pending[i] == player then
			table.remove(pending, i)
		end
	end
end

local function removePlayerFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	removeFromLists(player, entry.modeId)
	playerQueue[player] = nil
	sendQueueUpdate(player)
end

local function addToQueueList(player, modeId, asPending)
	local list = asPending and pendingQueues[modeId] or queues[modeId]
	table.insert(list, player)
	playerQueue[player] = {
		modeId = modeId,
		status = asPending and "pending" or "waiting",
	}
	sendQueueUpdate(player)
end

local function popMatchPlayers(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local picked = {}
	local function takeFrom(list)
		while #picked < mode.maxPlayers and #list > 0 do
			local player = table.remove(list, 1)
			if player.Parent then
				table.insert(picked, player)
			else
				playerQueue[player] = nil
			end
		end
	end

	takeFrom(queues[modeId])
	if #picked < mode.minPlayers then
		for _, player in picked do
			table.insert(queues[modeId], 1, player)
		end
		return nil
	end

	for _, player in picked do
		playerQueue[player] = nil
		Remotes.QueueUpdate:FireClient(player, { status = "starting", modeId = modeId, modeLabel = mode.label })
	end

	return picked
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local count = #queues[modeId]
	if count < mode.minPlayers then
		return
	end

	if mode.id == "ffa" and count < mode.maxPlayers then
		if not fillTimers[modeId] then
			return
		end
	end

	cancelFillTimer(modeId)

	local players = popMatchPlayers(modeId)
	if not players or #players == 0 then
		return
	end

	MatchStateService.setArenaBusy(true)
	MatchReady:Fire({
		modeId = modeId,
		players = players,
	})
end

local function scheduleFillTimer(modeId)
	if fillTimers[modeId] then
		return
	end

	local token = {}
	fillTimers[modeId] = token

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		tryStartMatch(modeId)
	end)
end

local function evaluateMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local count = #queues[modeId]
	if count == 0 then
		cancelFillTimer(modeId)
		return
	end

	if mode.id == "training" or mode.id == "pvp" then
		if count >= mode.minPlayers then
			tryStartMatch(modeId)
		end
		return
	end

	if count >= mode.maxPlayers then
		tryStartMatch(modeId)
	elseif count >= mode.minPlayers then
		scheduleFillTimer(modeId)
	else
		cancelFillTimer(modeId)
	end
end

local function promotePending(modeId)
	if MatchStateService.isArenaBusy() then
		return
	end

	local pending = pendingQueues[modeId]
	while #pending > 0 do
		local player = table.remove(pending, 1)
		if player.Parent and playerQueue[player] and playerQueue[player].modeId == modeId then
			playerQueue[player].status = "waiting"
			table.insert(queues[modeId], player)
			sendQueueUpdate(player)
		end
	end

	evaluateMode(modeId)
end

function MatchmakingService.onArenaFree()
	MatchStateService.setArenaBusy(false)

	for _, mode in MatchModes.getAll() do
		promotePending(mode.id)
		evaluateMode(mode.id)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if HubService.getPhase(player) == "arena" then
		return
	end

	if typeof(modeId) ~= "string" then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	removePlayerFromQueue(player)

	local asPending = MatchStateService.isArenaBusy()
	addToQueueList(player, modeId, asPending)

	if not asPending then
		evaluateMode(modeId)
	end

	broadcastModeQueue(modeId)
end

function MatchmakingService.leaveQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	removePlayerFromQueue(player)
	evaluateMode(modeId)
	broadcastModeQueue(modeId)
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local entry = playerQueue[player]
		if not entry then
			return
		end
		local modeId = entry.modeId
		removePlayerFromQueue(player)
		evaluateMode(modeId)
		broadcastModeQueue(modeId)
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
