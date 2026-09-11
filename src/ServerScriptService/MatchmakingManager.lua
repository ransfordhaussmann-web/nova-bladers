local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local HubService = require(script.Parent.HubService)
local MatchState = require(script.Parent.MatchState)

local MatchmakingManager = {}

local remotes
local matchReady
local matchEnded

local queues = {}
local playerEntry = {}
local fillTokens = {}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
	fillTokens[modeId] = 0
end

local function getModeLabel(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	return mode and mode.label or modeId
end

local function countQueue(modeId)
	return #queues[modeId]
end

local function buildQueuePayload(player)
	local entry = playerEntry[player]
	if not entry then
		return nil
	end

	local mode = MatchmakingConfig.getMode(entry.modeId)
	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = getModeLabel(entry.modeId),
		status = entry.status,
		playersWaiting = countQueue(entry.modeId),
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillSecondsLeft = entry.fillSecondsLeft,
		arenaBusy = MatchState.isBusy(),
	}
end

local function broadcastQueueUpdate(player)
	local payload = buildQueuePayload(player)
	if payload then
		remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueueUpdates(modeId)
	for _, queuedPlayer in queues[modeId] do
		broadcastQueueUpdate(queuedPlayer)
	end
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerEntry[player] = nil
	remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdates(modeId)
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] += 1
end

local function scheduleFillTimer(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end

	fillTokens[modeId] += 1
	local token = fillTokens[modeId]

	task.spawn(function()
		local remaining = mode.fillTimeout
		while remaining > 0 do
			for _, queuedPlayer in queues[modeId] do
				local entry = playerEntry[queuedPlayer]
				if entry and entry.modeId == modeId then
					entry.fillSecondsLeft = remaining
				end
			end
			broadcastQueueUpdates(modeId)
			task.wait(1)
			remaining -= 1

			if token ~= fillTokens[modeId] then
				return
			end
			if countQueue(modeId) < mode.minPlayers then
				return
			end
			if MatchState.isBusy() then
				return
			end
		end

		if token ~= fillTokens[modeId] then
			return
		end

		MatchmakingManager.tryStartMatch(modeId)
	end)
end

local function setQueueStatus(modeId, status)
	for _, queuedPlayer in queues[modeId] do
		local entry = playerEntry[queuedPlayer]
		if entry then
			entry.status = status
			if status ~= "filling" then
				entry.fillSecondsLeft = nil
			end
		end
	end
end

function MatchmakingManager.tryStartMatch(modeId)
	if MatchState.isBusy() then
		setQueueStatus(modeId, "pending")
		broadcastQueueUpdates(modeId)
		return false
	end

	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return false
	end

	local queue = queues[modeId]
	local count = #queue
	if count < mode.minPlayers then
		return false
	end

	local matchPlayers = {}
	local takeCount = math.min(count, mode.maxPlayers)
	for i = 1, takeCount do
		table.insert(matchPlayers, queue[i])
	end

	cancelFillTimer(modeId)

	for _, matchPlayer in matchPlayers do
		removeFromQueue(matchPlayer)
		HubService.leaveForArena(matchPlayer)
	end

	MatchState.setBusy(true)
	matchReady:Fire(matchPlayers, modeId)
	return true
end

local function evaluateQueue(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return
	end

	local count = countQueue(modeId)
	if count == 0 then
		cancelFillTimer(modeId)
		return
	end

	if MatchState.isBusy() then
		setQueueStatus(modeId, "pending")
		broadcastQueueUpdates(modeId)
		return
	end

	setQueueStatus(modeId, "waiting")

	if count >= mode.maxPlayers then
		MatchmakingManager.tryStartMatch(modeId)
		return
	end

	if count >= mode.minPlayers then
		if mode.fillTimeout <= 0 then
			MatchmakingManager.tryStartMatch(modeId)
		else
			setQueueStatus(modeId, "filling")
			scheduleFillTimer(modeId)
		end
		return
	end

	broadcastQueueUpdates(modeId)
end

function MatchmakingManager.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchmakingConfig.isValidMode(modeId) then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end

	if playerEntry[player] then
		removeFromQueue(player)
	end

	table.insert(queues[modeId], player)
	local status = "waiting"
	if MatchState.isBusy() then
		status = "pending"
	end
	playerEntry[player] = {
		modeId = modeId,
		status = status,
		fillSecondsLeft = nil,
	}

	broadcastQueueUpdate(player)
	evaluateQueue(modeId)
end

function MatchmakingManager.leaveQueue(player)
	if not playerEntry[player] then
		return
	end

	local modeId = playerEntry[player].modeId
	removeFromQueue(player)
	evaluateQueue(modeId)
end

function MatchmakingManager.onMatchEnded()
	MatchState.setBusy(false)

	for modeId in MatchmakingConfig.MODES do
		if countQueue(modeId) > 0 then
			evaluateQueue(modeId)
		end
	end
end

function MatchmakingManager.getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingManager.init(remotesFolder, bindablesFolder)
	if remotes then
		return
	end

	remotes = remotesFolder
	matchReady = bindablesFolder.MatchReady
	matchEnded = bindablesFolder.MatchEnded

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingManager.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingManager.leaveQueue(player)
	end)

	matchEnded.Event:Connect(function()
		MatchmakingManager.onMatchEnded()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingManager.leaveQueue(player)
	end)

	print("[MatchmakingManager] Queue system ready")
end

return MatchmakingManager
