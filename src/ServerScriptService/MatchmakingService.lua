local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local QueueJoin, QueueLeave, QueueUpdate
local MatchReady

local queues = {}
local playerQueue = {}
local fillGeneration = {}
local fillActive = {}
local pendingMatch = nil
local getRecommendedModeId

for modeId in MatchModes do
	queues[modeId] = {}
end

local function getMode(modeId)
	return MatchModes[modeId]
end

local function isValidMode(modeId)
	return MatchModes[modeId] ~= nil
end

local function countQueue(modeId)
	return #queues[modeId]
end

local function playerInQueue(player)
	return playerQueue[player] ~= nil
end

local function removeFromQueueList(player, modeId)
	local list = queues[modeId]
	for i, queued in list do
		if queued == player then
			table.remove(list, i)
			return true
		end
	end
	return false
end

local function buildQueuePayload(player, modeId, status)
	local mode = getMode(modeId)
	local list = queues[modeId]
	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		status = status or "waiting",
		playersInQueue = #list,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function broadcastModeQueue(modeId)
	local list = queues[modeId]
	local status = pendingMatch and pendingMatch.modeId == modeId and "pending" or "waiting"
	for _, player in list do
		if player.Parent then
			QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, status))
		end
	end
end

local function broadcastPlayerLeft(player)
	QueueUpdate:FireClient(player, { inQueue = false })
end

local function cancelFillTimer(modeId)
	fillGeneration[modeId] = (fillGeneration[modeId] or 0) + 1
	fillActive[modeId] = false
end

local function pullPlayers(modeId, count)
	local list = queues[modeId]
	local pulled = {}
	for _ = 1, math.min(count, #list) do
		local player = table.remove(list, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(pulled, player)
		end
	end
	return pulled
end

local function launchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	if MatchStateService.isArenaBusy() then
		pendingMatch = { modeId = modeId, players = playerList }
		for _, player in playerList do
			if player.Parent then
				QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, "pending"))
			end
		end
		return
	end

	pendingMatch = nil
	for _, player in playerList do
		HubService.leaveHubForArena(player)
	end
	MatchReady:Fire({ mode = modeId, players = playerList })
end

local function tryStartMatch(modeId)
	local mode = getMode(modeId)
	if not mode then
		return
	end

	local queued = countQueue(modeId)
	if queued < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		if queued >= mode.maxPlayers then
			cancelFillTimer(modeId)
			launchMatch(modeId, pullPlayers(modeId, mode.maxPlayers))
			return
		end

		if fillActive[modeId] then
			return
		end

		fillActive[modeId] = true
		local generation = (fillGeneration[modeId] or 0) + 1
		fillGeneration[modeId] = generation
		local timeout = mode.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT

		task.spawn(function()
			for remaining = timeout, 1, -1 do
				if fillGeneration[modeId] ~= generation then
					return
				end
				for _, player in queues[modeId] do
					if player.Parent then
						local payload = buildQueuePayload(player, modeId, "waiting")
						payload.fillSecondsLeft = remaining
						QueueUpdate:FireClient(player, payload)
					end
				end
				task.wait(1)
			end

			if fillGeneration[modeId] ~= generation then
				return
			end
			fillActive[modeId] = false

			local readyCount = countQueue(modeId)
			if readyCount >= mode.minPlayers then
				launchMatch(modeId, pullPlayers(modeId, math.min(readyCount, mode.maxPlayers)))
			end
		end)
		return
	end

	launchMatch(modeId, pullPlayers(modeId, mode.maxPlayers))
end

local function processPendingMatch()
	if not pendingMatch or MatchStateService.isArenaBusy() then
		return
	end

	local match = pendingMatch
	pendingMatch = nil
	launchMatch(match.modeId, match.players)
end

local function removeFromPending(player)
	if not pendingMatch then
		return
	end

	for i, queued in pendingMatch.players do
		if queued == player then
			table.remove(pendingMatch.players, i)
			break
		end
	end

	if #pendingMatch.players == 0 then
		pendingMatch = nil
		return
	end

	local modeId = pendingMatch.modeId
	local mode = getMode(modeId)
	if #pendingMatch.players < mode.minPlayers then
		local remaining = pendingMatch.players
		pendingMatch = nil
		for index, queuedPlayer in remaining do
			table.insert(queues[modeId], index, queuedPlayer)
			playerQueue[queuedPlayer] = modeId
			if queuedPlayer.Parent then
				QueueUpdate:FireClient(queuedPlayer, buildQueuePayload(queuedPlayer, modeId, "waiting"))
			end
		end
		broadcastModeQueue(modeId)
	end
end

local function leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	removeFromQueueList(player, modeId)
	broadcastPlayerLeft(player)

	removeFromPending(player)

	if modeId == "ffa" and countQueue(modeId) < getMode(modeId).minPlayers then
		cancelFillTimer(modeId)
	end

	broadcastModeQueue(modeId)
end

local function joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end
	if playerInQueue(player) and playerQueue[player] == modeId then
		return
	end

	if playerInQueue(player) then
		leaveQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, "waiting"))
	broadcastModeQueue(modeId)
	tryStartMatch(modeId)
end

function MatchmakingService.init(options)
	getRecommendedModeId = options.getRecommendedModeId

	Remotes, Bindables = RemotesSetup.ensure()
	QueueJoin = Remotes.QueueJoin
	QueueLeave = Remotes.QueueLeave
	QueueUpdate = Remotes.QueueUpdate
	MatchReady = Bindables.MatchReady

	MatchStateService.onArenaFree(processPendingMatch)

	if options.hub then
		options.hub.portalPrompt.Triggered:Connect(function(player)
			joinQueue(player, getRecommendedModeId())
		end)

		for _, pad in options.hub.modePads do
			pad.prompt.Triggered:Connect(function(player)
				joinQueue(player, pad.config.id)
			end)
		end
	end

	QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = getRecommendedModeId()
		end
		joinQueue(player, modeId)
	end)

	QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		if playerQueue[player] then
			leaveQueue(player)
		else
			removeFromPending(player)
		end
	end)
end

function MatchmakingService.joinRecommended(player)
	joinQueue(player, getRecommendedModeId())
end

return MatchmakingService
