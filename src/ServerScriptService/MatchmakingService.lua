--[[
	MatchmakingService — per-mode queues, fill timers, and MatchReady dispatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local pendingMatches = {}
local initialized = false

local function getQueue(modeId)
	return queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if fillTimers[modeId] then
		local mode = MatchModes.get(modeId)
		if mode and mode.fillTimeout and #queue < mode.minPlayers then
			fillTimers[modeId].cancelled = true
			fillTimers[modeId] = nil
		end
	end
end

local function queuePosition(modeId, player)
	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			return i
		end
	end
	return nil
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local position = queuePosition(modeId, player)
	local timer = fillTimers[modeId]
	local fillTimeLeft

	if timer and not timer.cancelled and timer.deadline then
		fillTimeLeft = math.max(0, math.ceil(timer.deadline - os.clock()))
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		modeDesc = mode.desc,
		position = position,
		total = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = MatchStateService.isArenaBusy(),
		fillTimeLeft = fillTimeLeft,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function takePlayersForMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = math.min(#queue, mode.maxPlayers)
	local matchPlayers = {}

	for _ = 1, count do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(matchPlayers, player)
			playerQueue[player] = nil
		end
	end

	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end

	return matchPlayers
end

local function dispatchMatch(modeId, matchPlayers)
	if #matchPlayers == 0 then
		return
	end

	if MatchStateService.isArenaBusy() then
		table.insert(pendingMatches, {
			modeId = modeId,
			players = matchPlayers,
		})
		for _, player in matchPlayers do
			if player.Parent then
				Remotes.QueueUpdate:FireClient(player, {
					modeId = modeId,
					modeLabel = MatchModes.get(modeId).label,
					pending = true,
					total = 0,
					minPlayers = MatchModes.get(modeId).minPlayers,
					maxPlayers = MatchModes.get(modeId).maxPlayers,
				})
			end
		end
		return
	end

	Bindables.MatchReady:Fire({
		modeId = modeId,
		players = matchPlayers,
	})
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)

	if #queue < mode.minPlayers then
		return
	end

	if mode.maxPlayers > 0 and #queue >= mode.maxPlayers then
		dispatchMatch(modeId, takePlayersForMatch(modeId))
		broadcastQueueUpdate(modeId)
		return
	end

	if not mode.fillTimeout and #queue >= mode.minPlayers then
		dispatchMatch(modeId, takePlayersForMatch(modeId))
		broadcastQueueUpdate(modeId)
	end
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode.fillTimeout then
		return
	end

	if fillTimers[modeId] and not fillTimers[modeId].cancelled then
		return
	end

	local token = { cancelled = false, deadline = os.clock() + mode.fillTimeout }
	fillTimers[modeId] = token

	task.delay(mode.fillTimeout, function()
		if token.cancelled then
			return
		end
		fillTimers[modeId] = nil

		local queue = getQueue(modeId)
		if #queue >= mode.minPlayers then
			dispatchMatch(modeId, takePlayersForMatch(modeId))
			broadcastQueueUpdate(modeId)
		end
	end)
end

local function onQueueChanged(modeId)
	broadcastQueueUpdate(modeId)
	tryStartMatch(modeId)

	local mode = MatchModes.get(modeId)
	if mode.fillTimeout and #getQueue(modeId) >= mode.minPlayers then
		startFillTimer(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false, "invalid_mode"
	end
	if playerQueue[player] then
		return false, "already_queued"
	end

	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId
	onQueueChanged(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	broadcastQueueUpdate(modeId)
	return true
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getQueuedMode(player)
	return playerQueue[player]
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setBusy(false)
	task.defer(function()
		if #pendingMatches > 0 then
			local nextMatch = table.remove(pendingMatches, 1)
			dispatchMatch(nextMatch.modeId, nextMatch.players)
		end
		broadcastAllQueues()
	end)
end

function MatchmakingService.onMatchStarted()
	MatchStateService.setBusy(true)
	broadcastAllQueues()
end

local function processPendingRetries()
	while initialized do
		task.wait(MatchmakingConfig.PENDING_RETRY_INTERVAL)
		if not MatchStateService.isArenaBusy() and #pendingMatches > 0 then
			local nextMatch = table.remove(pendingMatches, 1)
			dispatchMatch(nextMatch.modeId, nextMatch.players)
		end
	end
end

function MatchmakingService.init()
	if initialized then
		return
	end
	initialized = true

	Players.PlayerRemoving:Connect(function(player)
		if playerQueue[player] then
			local modeId = playerQueue[player]
			removeFromQueue(player)
			broadcastQueueUpdate(modeId)
		end

		for i = #pendingMatches, 1, -1 do
			local match = pendingMatches[i]
			for j = #match.players, 1, -1 do
				if match.players[j] == player then
					table.remove(match.players, j)
				end
			end
			if #match.players == 0 then
				table.remove(pendingMatches, i)
			end
		end
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	task.spawn(processPendingRetries)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
