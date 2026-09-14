--[[
	MatchmakingService — per-mode queues, fill timers, and MatchReady dispatch.
]]

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
local playerQueue = {}
local fillTokens = {}
local started = false

local function initQueues()
	for _, mode in MatchModes do
		queues[mode.id] = {
			mode = mode,
			players = {},
			fillDeadline = nil,
			fillToken = 0,
		}
	end
end

local function getQueueSize(modeId)
	return #queues[modeId].players
end

local function buildQueuePayload(modeId, player)
	local queue = queues[modeId]
	local mode = queue.mode
	return {
		modeId = modeId,
		modeLabel = mode.label,
		queued = getQueueSize(modeId),
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		inQueue = playerQueue[player] == modeId,
		pendingArena = MatchStateService.isArenaBusy(),
		fillSecondsLeft = nil,
	}
end

local function broadcastQueueUpdate(modeId)
	local payload = buildQueuePayload(modeId, nil)
	for _, player in queues[modeId].players do
		if player.Parent then
			local personal = {
				modeId = payload.modeId,
				modeLabel = payload.modeLabel,
				queued = payload.queued,
				needed = payload.needed,
				maxPlayers = payload.maxPlayers,
				inQueue = true,
				pendingArena = payload.pendingArena,
				fillSecondsLeft = nil,
			}
			if queues[modeId].fillDeadline then
				personal.fillSecondsLeft = math.max(0, math.ceil(queues[modeId].fillDeadline - os.clock()))
			end
			Remotes.QueueUpdate:FireClient(player, personal)
		end
	end
end

local function broadcastPlayerQueueState(player)
	local modeId = playerQueue[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, {
			modeId = nil,
			inQueue = false,
			pendingArena = MatchStateService.isArenaBusy(),
		})
		return
	end
	local payload = buildQueuePayload(modeId, player)
	if queues[modeId].fillDeadline then
		payload.fillSecondsLeft = math.max(0, math.ceil(queues[modeId].fillDeadline - os.clock()))
	end
	Remotes.QueueUpdate:FireClient(player, payload)
end

local function removeFromQueue(player, silent)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, i)
			break
		end
	end
	playerQueue[player] = nil

	if #queue.players == 0 then
		queue.fillDeadline = nil
		queue.fillToken += 1
	end

	if not silent then
		broadcastQueueUpdate(modeId)
		broadcastPlayerQueueState(player)
	end
end

local function takePlayers(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, math.min(count, #queue.players) do
		local player = table.remove(queue.players, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end
	queue.fillDeadline = nil
	queue.fillToken += 1
	broadcastQueueUpdate(modeId)
	return taken
end

local function dispatchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	if MatchStateService.isArenaBusy() then
		for _, player in playerList do
			if not playerQueue[player] then
				table.insert(queues[modeId].players, player)
				playerQueue[player] = modeId
				broadcastPlayerQueueState(player)
			end
		end
		broadcastQueueUpdate(modeId)
		return
	end

	for _, player in playerList do
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		if HubService.getPhase(player) == "hub" then
			HubService.leaveHubForArena(player)
		end
	end

	MatchStateService.setArenaBusy(true)
	MatchReady:Fire(modeId, playerList)
end

local function tryStartQueue(modeId)
	local queue = queues[modeId]
	local mode = queue.mode
	local size = #queue.players

	if size < mode.minPlayers then
		return
	end

	if mode.fillTimeout > 0 and size < mode.maxPlayers then
		if not queue.fillDeadline then
			queue.fillDeadline = os.clock() + mode.fillTimeout
			queue.fillToken += 1
			local token = queue.fillToken
			broadcastQueueUpdate(modeId)

			task.delay(mode.fillTimeout, function()
				if token ~= queue.fillToken or #queue.players < mode.minPlayers then
					return
				end
				local players = takePlayers(modeId, math.min(#queues[modeId].players, mode.maxPlayers))
				dispatchMatch(modeId, players)
			end)
		end
		return
	end

	local players = takePlayers(modeId, math.min(size, mode.maxPlayers))
	dispatchMatch(modeId, players)
end

local function scheduleTrainingSolo(player)
	local modeId = "training"
	local token = (fillTokens[player] or 0) + 1
	fillTokens[player] = token

	task.delay(MatchmakingConfig.TRAINING_SOLO_DELAY, function()
		if fillTokens[player] ~= token or playerQueue[player] ~= modeId then
			return
		end
		if #queues[modeId].players < 1 then
			return
		end
		local players = takePlayers(modeId, 1)
		dispatchMatch(modeId, players)
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "invalid_mode"
	end
	if playerQueue[player] then
		return false, "already_queued"
	end
	if HubService.getPhase(player) ~= "hub" then
		return false, "not_in_hub"
	end

	table.insert(queues[modeId].players, player)
	playerQueue[player] = modeId
	broadcastQueueUpdate(modeId)
	broadcastPlayerQueueState(player)

	if modeId == "training" and #queues[modeId].players >= 1 then
		scheduleTrainingSolo(player)
	else
		tryStartQueue(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end
	fillTokens[player] = (fillTokens[player] or 0) + 1
	removeFromQueue(player)
	return true
end

function MatchmakingService.getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= MatchmakingConfig.RECOMMEND_FFA_AT then
		return "ffa"
	elseif count >= MatchmakingConfig.RECOMMEND_PVP_AT then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.joinRecommended(player)
	return MatchmakingService.joinQueue(player, MatchmakingService.getRecommendedModeId())
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
end

local function processPendingQueues()
	for modeId in queues do
		if #queues[modeId].players >= queues[modeId].mode.minPlayers then
			tryStartQueue(modeId)
		end
	end
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
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getRecommendedModeId()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		fillTokens[player] = nil
		removeFromQueue(player, true)
	end)

	MatchStateService.onArenaFree(processPendingQueues)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
