--[[
	MatchmakingService — Queue pro Modus, MatchReady wenn genug Spieler.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerEntry = {}
local pendingMatches = {}
local ffaFillToken = 0
local ffaTimerRunning = false
local started = false

local STATUS = {
	WAITING = "waiting",
	PENDING = "pending",
}

local function getQueue(modeId)
	return queues[modeId]
end

local function countQueue(modeId)
	return #getQueue(modeId)
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local queue = getQueue(entry.modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerEntry[player] = nil
end

local function buildUpdatePayload(player, entry)
	local mode = MatchModes.get(entry.modeId)
	local inQueue = countQueue(entry.modeId)
	local needed = mode.minPlayers

	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode.label,
		playersInQueue = inQueue,
		playersNeeded = needed,
		maxPlayers = mode.maxPlayers,
		status = entry.status,
		statusMessage = entry.statusMessage,
	}
end

local function sendQueueUpdate(player)
	local entry = playerEntry[player]
	if not entry then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player, entry))
end

local function broadcastQueueMode(modeId)
	for player, entry in playerEntry do
		if entry.modeId == modeId and player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function popPlayers(modeId, count)
	local queue = getQueue(modeId)
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(picked, player)
			playerEntry[player] = nil
		end
	end
	broadcastQueueMode(modeId)
	return picked
end

local function canStartMode(mode)
	local count = countQueue(mode.id)
	if count < mode.minPlayers then
		return false, 0
	end
	if mode.id == "ffa" then
		if count >= mode.maxPlayers then
			return true, mode.maxPlayers
		end
		return false, 0
	end
	return true, mode.minPlayers
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local ready, takeCount = canStartMode(mode)
	if not ready or takeCount == 0 then
		return
	end

	local players = popPlayers(modeId, takeCount)
	if #players < mode.minPlayers then
		for _, player in players do
			MatchmakingService.joinQueue(player, modeId)
		end
		return
	end

	if MatchStateService.isArenaBusy() then
		local pending = { players = players, modeId = modeId }
		table.insert(pendingMatches, pending)
		for _, player in players do
			playerEntry[player] = {
				modeId = modeId,
				status = STATUS.PENDING,
				statusMessage = "Arena belegt — warte auf freien Slot...",
				pendingRef = pending,
			}
			sendQueueUpdate(player)
		end
		return
	end

	MatchStateService.setArenaBusy(true)
	MatchReady:Fire(players, modeId)
end

local function resetFfaFillTimer()
	ffaFillToken += 1
	ffaTimerRunning = true
	local token = ffaFillToken
	local mode = MatchModes.ffa

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= ffaFillToken then
			return
		end
		ffaTimerRunning = false
		local count = countQueue("ffa")
		if count >= mode.minPlayers then
			local players = popPlayers("ffa", count)
			if #players >= mode.minPlayers then
				if MatchStateService.isArenaBusy() then
					local pending = { players = players, modeId = "ffa" }
					table.insert(pendingMatches, pending)
					for _, player in players do
						playerEntry[player] = {
							modeId = "ffa",
							status = STATUS.PENDING,
							statusMessage = "Arena belegt — warte auf freien Slot...",
							pendingRef = pending,
						}
						sendQueueUpdate(player)
					end
				else
					MatchStateService.setArenaBusy(true)
					MatchReady:Fire(players, "ffa")
				end
			end
		end
	end)
end

local function onFfaQueueChanged()
	local mode = MatchModes.ffa
	local count = countQueue("ffa")
	if count >= mode.maxPlayers then
		ffaFillToken += 1
		ffaTimerRunning = false
		tryStartMatch("ffa")
	elseif count >= mode.minPlayers and not ffaTimerRunning then
		resetFfaFillTimer()
	elseif count < mode.minPlayers then
		ffaFillToken += 1
		ffaTimerRunning = false
	end
end

local function processPendingMatches()
	if MatchStateService.isArenaBusy() then
		return false
	end

	for i, pending in pendingMatches do
		local allValid = true
		for _, player in pending.players do
			local entry = playerEntry[player]
			if not entry or entry.pendingRef ~= pending or not player.Parent then
				allValid = false
				break
			end
		end
		if allValid then
			table.remove(pendingMatches, i)
			for _, player in pending.players do
				playerEntry[player] = nil
			end
			MatchStateService.setArenaBusy(true)
			MatchReady:Fire(pending.players, pending.modeId)
			return true
		end
	end
	return false
end

local function onArenaFree()
	processPendingMatches()
	for _, mode in MatchModes.all() do
		if mode.id ~= "ffa" then
			tryStartMatch(mode.id)
		else
			onFfaQueueChanged()
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not player.Parent then
		return
	end

	removeFromQueue(player)

	table.insert(getQueue(modeId), player)
	playerEntry[player] = {
		modeId = modeId,
		status = STATUS.WAITING,
		statusMessage = "Suche Mitspieler...",
	}

	sendQueueUpdate(player)
	broadcastQueueMode(modeId)

	if modeId == "ffa" then
		onFfaQueueChanged()
	else
		tryStartMatch(modeId)
	end
end

function MatchmakingService.leaveQueue(player)
	if not playerEntry[player] then
		return
	end

	local modeId = playerEntry[player].modeId
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })

	if modeId == "ffa" and countQueue("ffa") < MatchModes.ffa.minPlayers then
		ffaFillToken += 1
		ffaTimerRunning = false
	end
	broadcastQueueMode(modeId)
end

function MatchmakingService.getPlayerMode(player)
	local entry = playerEntry[player]
	return entry and entry.modeId
end

function MatchmakingService.isInQueue(player)
	return playerEntry[player] ~= nil
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
end

function MatchmakingService.start(handlers)
	if started then
		return
	end
	started = true

	MatchStateService.onArenaFree(onArenaFree)

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		if handlers.onJoinQueue then
			handlers.onJoinQueue(player, modeId)
		else
			MatchmakingService.joinQueue(player, modeId)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local modeId = MatchmakingService.getPlayerMode(player)
		removeFromQueue(player)
		if modeId == "ffa" and countQueue("ffa") < MatchModes.ffa.minPlayers then
			ffaFillToken += 1
			ffaTimerRunning = false
		elseif modeId then
			broadcastQueueMode(modeId)
		end
	end)
end

return MatchmakingService
