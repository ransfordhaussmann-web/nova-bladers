local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local Bindables

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTokens = {}

local function getMode(modeId)
	return MatchModes[modeId]
end

local function isPlayerValid(player)
	return player and player.Parent and HubService.getPhase(player) == "hub"
end

local function pruneQueue(modeId)
	local queue = queues[modeId]
	local cleaned = {}
	for _, player in queue do
		if isPlayerValid(player) then
			table.insert(cleaned, player)
		else
			playerQueue[player] = nil
		end
	end
	queues[modeId] = cleaned
end

local function getQueueCount(modeId)
	pruneQueue(modeId)
	return #queues[modeId]
end

local function buildQueuePayload(modeId, player)
	local mode = getMode(modeId)
	local count = getQueueCount(modeId)
	local pending = MatchStateService.isArenaBusy()
	local status = "waiting"

	if pending then
		status = "pending"
	elseif mode and count >= mode.minPlayers then
		status = "ready"
	end

	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		count = count,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		status = status,
		pending = pending,
		inQueue = playerQueue[player] == modeId,
	}
end

local function broadcastQueueUpdate(modeId)
	pruneQueue(modeId)
	for _, player in Players:GetPlayers() do
		if playerQueue[player] == modeId or HubService.getPhase(player) == "hub" then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	if fillTokens[modeId] then
		fillTokens[modeId] = nil
	end

	broadcastQueueUpdate(modeId)
end

local function takePlayersFromQueue(modeId, count)
	pruneQueue(modeId)
	local taken = {}
	local queue = queues[modeId]

	while #taken < count and #queue > 0 do
		local player = table.remove(queue, 1)
		if isPlayerValid(player) then
			table.insert(taken, player)
			playerQueue[player] = nil
		end
	end

	broadcastQueueUpdate(modeId)
	return taken
end

local function startMatch(modeId)
	if MatchStateService.isArenaBusy() then
		return false
	end

	local mode = getMode(modeId)
	if not mode then
		return false
	end

	pruneQueue(modeId)
	local count = #queues[modeId]
	if count < mode.minPlayers then
		return false
	end

	local playerCount = math.min(count, mode.maxPlayers)
	local matched = takePlayersFromQueue(modeId, playerCount)
	if #matched < mode.minPlayers then
		for _, player in matched do
			table.insert(queues[modeId], player)
			playerQueue[player] = modeId
		end
		broadcastQueueUpdate(modeId)
		return false
	end

	fillTokens[modeId] = nil

	for _, player in matched do
		HubService.leaveHubForArena(player)
	end

	Bindables.MatchReady:Fire(matched)
	return true
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = nil
end

local function scheduleFillTimer(modeId)
	local mode = getMode(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end

	local token = {}
	fillTokens[modeId] = token

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		fillTokens[modeId] = nil
		startMatch(modeId)
	end)
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	local mode = getMode(modeId)
	if not mode then
		return
	end

	pruneQueue(modeId)
	local count = #queues[modeId]

	if count >= mode.maxPlayers then
		cancelFillTimer(modeId)
		startMatch(modeId)
		return
	end

	if count < mode.minPlayers then
		cancelFillTimer(modeId)
		broadcastQueueUpdate(modeId)
		return
	end

	if modeId == "ffa" then
		if not fillTokens[modeId] then
			scheduleFillTimer(modeId)
		end
		broadcastQueueUpdate(modeId)
		return
	end

	startMatch(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if not getMode(modeId) then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastQueueUpdate(modeId)
	tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
end

function MatchmakingService.getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= MatchmakingConfig.FFA_MIN_PLAYERS + 1 then
		return "ffa"
	elseif count >= MatchmakingConfig.PVP_PLAYERS then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	task.defer(function()
		for modeId in queues do
			tryStartMatch(modeId)
		end
		broadcastAllQueues()
	end)
end

function MatchmakingService.init(remotes, bindables)
	Remotes = remotes
	Bindables = bindables

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
		removeFromQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
