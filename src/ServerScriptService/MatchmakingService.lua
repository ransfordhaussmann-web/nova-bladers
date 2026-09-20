--[[
	MatchmakingService — per-mode queues, fill timers, and MatchReady dispatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {}
local playerEntry = {}
local pendingMatch = nil
local fillTokens = {}

local function initQueues()
	for _, mode in MatchModes.getAll() do
		queues[mode.id] = { players = {} }
	end
end

local function getQueueCount(modeId)
	return #(queues[modeId] and queues[modeId].players or {})
end

local function removePlayerFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local queue = queues[entry.modeId]
	if queue then
		for i, queued in queue.players do
			if queued == player then
				table.remove(queue.players, i)
				break
			end
		end
	end

	playerEntry[player] = nil
end

local function buildQueuePayload(forPlayer)
	local entry = playerEntry[forPlayer]
	if not entry then
		return { inQueue = false }
	end

	local mode = MatchModes.get(entry.modeId)
	local count = getQueueCount(entry.modeId)
	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode.label,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = entry.status,
		statusLabel = entry.status == "pending"
			and MatchmakingConfig.PENDING_LABEL
			or MatchmakingConfig.WAITING_LABEL,
	}
end

local function broadcastQueueUpdate()
	for player in playerEntry do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
		end
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function takePlayersFromQueue(modeId, amount)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, math.min(amount, #queue.players) do
		table.insert(taken, table.remove(queue.players, 1))
	end
	return taken
end

local function dispatchMatch(modeId, players)
	for _, player in players do
		playerEntry[player] = { modeId = modeId, status = "ready" }
	end
	broadcastQueueUpdate()

	if MatchStateService.isArenaBusy() then
		pendingMatch = { modeId = modeId, players = players }
		for _, player in players do
			if player.Parent then
				playerEntry[player] = { modeId = modeId, status = "pending" }
			end
		end
		broadcastQueueUpdate()
		return
	end

	for _, player in players do
		playerEntry[player] = nil
	end
	broadcastQueueUpdate()

	MatchStateService.setArenaBusy(true)
	Bindables.MatchReady:Fire({
		mode = modeId,
		players = players,
	})
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local count = getQueueCount(modeId)
	if count < mode.minPlayers then
		return
	end

	if count >= mode.maxPlayers then
		cancelFillTimer(modeId)
		local players = takePlayersFromQueue(modeId, mode.maxPlayers)
		dispatchMatch(modeId, players)
		return
	end

	if not mode.fillTimeout and count >= mode.minPlayers then
		cancelFillTimer(modeId)
		local players = takePlayersFromQueue(modeId, mode.minPlayers)
		dispatchMatch(modeId, players)
	end
end

local function scheduleFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode.fillTimeout then
		return
	end

	local count = getQueueCount(modeId)
	if count < mode.minPlayers or count >= mode.maxPlayers then
		return
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		local currentCount = getQueueCount(modeId)
		if currentCount >= mode.minPlayers and currentCount < mode.maxPlayers then
			local players = takePlayersFromQueue(modeId, currentCount)
			dispatchMatch(modeId, players)
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	if playerEntry[player] then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId].players, player)
	playerEntry[player] = { modeId = modeId, status = "waiting" }

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	tryStartMatch(modeId)
	scheduleFillTimer(modeId)
	broadcastQueueUpdate()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerEntry[player] then
		return
	end

	local modeId = playerEntry[player].modeId
	removePlayerFromQueue(player)

	if getQueueCount(modeId) < MatchModes.get(modeId).minPlayers then
		cancelFillTimer(modeId)
	end

	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdate()
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)

	if not pendingMatch then
		return
	end

	local match = pendingMatch
	pendingMatch = nil

	local validPlayers = {}
	for _, player in match.players do
		if player.Parent then
			table.insert(validPlayers, player)
		end
	end

	local mode = MatchModes.get(match.modeId)
	if #validPlayers < mode.minPlayers then
		for _, player in validPlayers do
			MatchmakingService.joinQueue(player, match.modeId)
		end
		return
	end

	MatchStateService.setArenaBusy(true)
	Bindables.MatchReady:Fire({
		mode = match.modeId,
		players = validPlayers,
	})
end

function MatchmakingService.onPlayerRemoving(player)
	if pendingMatch then
		local filtered = {}
		for _, queued in pendingMatch.players do
			if queued ~= player then
				table.insert(filtered, queued)
			end
		end
		pendingMatch.players = filtered
		local mode = MatchModes.get(pendingMatch.modeId)
		if #filtered < mode.minPlayers then
			pendingMatch = nil
		end
	end

	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.init()
	initQueues()

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.onPlayerRemoving(player)
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
