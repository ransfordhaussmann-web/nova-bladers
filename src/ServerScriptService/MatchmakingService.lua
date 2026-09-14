--[[
	MatchmakingService — per-mode queues with FFA fill timeout and arena-pending state.
]]

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

local playerQueue = {}
local queues = {
	training = {},
	pvp = {},
	ffa = {},
}
local ffaFillStartedAt = nil
local ffaFillToken = 0
local pendingMatch = nil

local function getQueueSize(modeId)
	return #queues[modeId]
end

local function isPlayerQueued(player)
	return playerQueue[player] ~= nil
end

local function buildQueuePayload(modeId, status)
	local mode = MatchModes.get(modeId)
	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		queued = getQueueSize(modeId),
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		status = status or "waiting",
	}
end

local function broadcastQueue(modeId)
	local payload = buildQueuePayload(modeId, MatchStateService.isArenaBusy() and "pending" or "waiting")
	for _, player in queues[modeId] do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	if modeId == "ffa" and #queue < MatchModes.ffa.minPlayers then
		ffaFillStartedAt = nil
		ffaFillToken += 1
	end

	broadcastQueue(modeId)
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end
	local count = getQueueSize(modeId)
	if count < mode.minPlayers then
		return false
	end
	if count >= mode.maxPlayers then
		return true
	end
	if modeId == "ffa" and ffaFillStartedAt then
		return os.clock() - ffaFillStartedAt >= MatchmakingConfig.FFA_FILL_TIMEOUT
	end
	return mode.instantStart == true
end

local function takePlayersFromQueue(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local count = math.min(#queue, mode.maxPlayers)
	local matchPlayers = {}

	for _ = 1, count do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(matchPlayers, player)
		end
	end

	if modeId == "ffa" then
		ffaFillStartedAt = nil
		ffaFillToken += 1
	end

	return matchPlayers
end

local function launchMatch(matchPlayers, modeId)
	for _, player in matchPlayers do
		HubService.prepareForMatch(player)
	end
	MatchReady:Fire(matchPlayers, modeId)
end

local function tryStartMatch(modeId)
	if not canStartMode(modeId) then
		return false
	end

	local matchPlayers = takePlayersFromQueue(modeId)
	if #matchPlayers == 0 then
		return false
	end

	if MatchStateService.isArenaBusy() then
		pendingMatch = {
			players = matchPlayers,
			modeId = modeId,
		}
		for _, player in matchPlayers do
			if player.Parent then
				Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, "pending"))
			end
		end
		return true
	end

	launchMatch(matchPlayers, modeId)
	return true
end

local function evaluateQueues()
	for _, modeId in { "training", "pvp", "ffa" } do
		if tryStartMatch(modeId) then
			return
		end
	end
end

local function startFfaFillTimer()
	local mode = MatchModes.ffa
	if getQueueSize("ffa") < mode.minPlayers then
		return
	end
	if ffaFillStartedAt then
		return
	end

	ffaFillStartedAt = os.clock()
	ffaFillToken += 1
	local token = ffaFillToken

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= ffaFillToken then
			return
		end
		tryStartMatch("ffa")
	end)
end

local function joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	if modeId == "ffa" then
		startFfaFillTimer()
	end

	broadcastQueue(modeId)

	if modeId ~= "ffa" or getQueueSize(modeId) >= MatchModes.get(modeId).maxPlayers then
		tryStartMatch(modeId)
	end
end

local function removeFromPending(player)
	if not pendingMatch then
		return false
	end

	for i, queuedPlayer in pendingMatch.players do
		if queuedPlayer == player then
			table.remove(pendingMatch.players, i)
			break
		end
	end

	local modeId = pendingMatch.modeId
	local mode = MatchModes.get(modeId)
	if #pendingMatch.players < mode.minPlayers then
		for _, queuedPlayer in pendingMatch.players do
			table.insert(queues[modeId], queuedPlayer)
			playerQueue[queuedPlayer] = modeId
			if queuedPlayer.Parent then
				Remotes.QueueUpdate:FireClient(queuedPlayer, buildQueuePayload(modeId, "waiting"))
			end
		end
		pendingMatch = nil
	end

	return true
end

local function leaveQueue(player)
	if removeFromPending(player) then
		return
	end
	if not isPlayerQueued(player) then
		return
	end
	removeFromQueue(player)
end

local function flushPendingMatch()
	if not pendingMatch or MatchStateService.isArenaBusy() then
		return
	end

	local match = pendingMatch
	pendingMatch = nil
	launchMatch(match.players, match.modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

function MatchmakingService.start()
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = HubService.getSuggestedModeId()
		end
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		leaveQueue(player)
		if pendingMatch then
			for i, p in pendingMatch.players do
				if p == player then
					table.remove(pendingMatch.players, i)
					break
				end
			end
			if #pendingMatch.players == 0 then
				pendingMatch = nil
			end
		end
	end)

	MatchStateService.onArenaFree(function()
		flushPendingMatch()
		evaluateQueues()
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
