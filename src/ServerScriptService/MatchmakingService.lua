local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {}
local playerQueue = {}
local fillTimers = {}
local started = false

local function getFillTimeout(modeId)
	if modeId == "ffa" then
		return MatchmakingConfig.FFA_FILL_TIMEOUT
	elseif modeId == "pvp" then
		return MatchmakingConfig.PVP_FILL_TIMEOUT
	end
	return nil
end

local function isValidPlayer(player)
	return player and player.Parent == Players
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId] or {}
	local count = #queue
	local pending = MatchStateService.isArenaBusy()
	local status = pending and "pending" or "waiting"

	if mode then
		if count >= mode.maxPlayers then
			status = "full"
		elseif count >= mode.minPlayers and fillTimers[modeId] then
			status = "starting"
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		count = count,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		status = status,
		pending = pending,
		fillSeconds = fillTimers[modeId] and fillTimers[modeId].remaining or nil,
	}
end

local function broadcastQueue(modeId)
	local queue = queues[modeId] or {}
	for _, player in queue do
		if isValidPlayer(player) then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end
end

local function startFillTimer(modeId)
	local timeout = getFillTimeout(modeId)
	if not timeout then
		return
	end

	clearFillTimer(modeId)
	local token = { cancelled = false, remaining = timeout }
	fillTimers[modeId] = token

	task.spawn(function()
		while token.remaining > 0 and not token.cancelled do
			task.wait(1)
			token.remaining -= 1
			broadcastQueue(modeId)
		end
		if not token.cancelled then
			fillTimers[modeId] = nil
			MatchmakingService.tryStartMatch(modeId)
		end
	end)
end

local function removeFromQueue(player, modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end

	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	if playerQueue[player] == modeId then
		playerQueue[player] = nil
	end

	local mode = MatchModes.get(modeId)
	if mode and #queue < mode.minPlayers then
		clearFillTimer(modeId)
	end

	broadcastQueue(modeId)
end

local function removePlayerFromAllQueues(player)
	local modeId = playerQueue[player]
	if modeId then
		removeFromQueue(player, modeId)
	end
end

function MatchmakingService.leaveQueue(player)
	removePlayerFromAllQueues(player)
end

function MatchmakingService.getQueueMode(player)
	return playerQueue[player]
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidPlayer(player) then
		return false, "invalid_player"
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		if playerQueue[player] == modeId then
			return true
		end
		removePlayerFromAllQueues(player)
	end

	local queue = queues[modeId]
	if not queue then
		queue = {}
		queues[modeId] = queue
	end

	if #queue >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerQueue[player] = modeId
	broadcastQueue(modeId)

	if modeId == "training" and #queue >= 1 and not MatchStateService.isArenaBusy() then
		MatchmakingService.tryStartMatch(modeId)
	elseif #queue >= mode.maxPlayers then
		MatchmakingService.tryStartMatch(modeId)
	elseif #queue >= mode.minPlayers then
		if not fillTimers[modeId] then
			startFillTimer(modeId)
		end
	end

	return true
end

function MatchmakingService.tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		broadcastQueue(modeId)
		return
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if not mode or not queue or #queue < mode.minPlayers then
		return
	end

	local matchPlayers = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(matchPlayers, queue[i])
	end

	if #matchPlayers < mode.minPlayers then
		return
	end

	clearFillTimer(modeId)

	for _, player in matchPlayers do
		removeFromQueue(player, modeId)
	end

	MatchStateService.setArenaBusy(true)
	MatchReady:Fire({
		mode = modeId,
		players = matchPlayers,
	})
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	task.defer(function()
		for modeId in queues do
			local mode = MatchModes.get(modeId)
			local queue = queues[modeId]
			if mode and queue and #queue >= mode.minPlayers then
				if modeId == "training" then
					MatchmakingService.tryStartMatch(modeId)
				elseif #queue >= mode.maxPlayers then
					MatchmakingService.tryStartMatch(modeId)
				elseif not fillTimers[modeId] then
					startFillTimer(modeId)
				end
			end
		end
		broadcastAllQueues()
	end)
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removePlayerFromAllQueues(player)
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
