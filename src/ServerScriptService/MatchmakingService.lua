local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local ffaFillToken = 0
local arenaBusy = false
local pendingMatch = nil
local initialized = false

local remotes
local bindables

local function getQueueSize(modeId)
	return #queues[modeId]
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local queue = queues[entry.modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil
end

local function buildQueuePayload(player)
	local entry = playerQueue[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = MatchmakingConfig.getMode(entry.modeId)
	local count = getQueueSize(entry.modeId)
	local status = "waiting"

	if arenaBusy then
		status = "pending"
	elseif count >= mode.minPlayers then
		status = "ready"
	end

	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode.label,
		playersInQueue = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		arenaBusy = arenaBusy,
	}
end

local function broadcastQueueUpdate(modeId)
	local payload = {
		modeId = modeId,
		playersInQueue = getQueueSize(modeId),
		minPlayers = MatchmakingConfig.getMode(modeId).minPlayers,
		maxPlayers = MatchmakingConfig.getMode(modeId).maxPlayers,
		arenaBusy = arenaBusy,
	}

	for player, entry in playerQueue do
		if entry.modeId == modeId and player.Parent then
			remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
		end
	end
end

local function tryStartMatch(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = queues[modeId]
	local count = #queue

	if count < mode.minPlayers then
		return
	end

	if arenaBusy then
		if not pendingMatch or pendingMatch.modeId ~= modeId then
			pendingMatch = {
				modeId = modeId,
				players = {},
			}
			for i = 1, math.min(count, mode.maxPlayers) do
				table.insert(pendingMatch.players, queue[i])
			end
		end
		broadcastQueueUpdate(modeId)
		return
	end

	local matchPlayers = {}
	for i = 1, math.min(count, mode.maxPlayers) do
		table.insert(matchPlayers, queue[i])
	end

	for _, player in matchPlayers do
		removeFromQueue(player)
	end

	pendingMatch = nil
	arenaBusy = true

	for _, player in matchPlayers do
		HubService.leaveHubForArena(player)
	end

	bindables.MatchReady:Fire({
		players = matchPlayers,
		mode = modeId,
	})

	broadcastQueueUpdate(modeId)
end

local function scheduleFfaFill(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode.fillTimeout then
		return
	end

	ffaFillToken += 1
	local token = ffaFillToken

	task.delay(mode.fillTimeout, function()
		if token ~= ffaFillToken then
			return
		end
		if getQueueSize(modeId) >= mode.minPlayers then
			tryStartMatch(modeId)
		end
	end)
end

local function ensureInitialized()
	if initialized then
		return
	end
	initialized = true
	remotes, bindables = RemotesSetup.ensure()

	bindables.MatchStarted.Event:Connect(function()
		arenaBusy = true
	end)

	bindables.MatchEnded.Event:Connect(function()
		arenaBusy = false
		if pendingMatch then
			local modeId = pendingMatch.modeId
			pendingMatch = nil
			tryStartMatch(modeId)
		end
		for modeId in queues do
			broadcastQueueUpdate(modeId)
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	ensureInitialized()
	if not MatchmakingConfig.isValidMode(modeId) then
		modeId = MatchmakingConfig.DEFAULT_MODE
	end

	if HubService.getPhase(player) ~= "hub" then
		return false
	end

	if playerQueue[player] then
		if playerQueue[player].modeId == modeId then
			remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
			return true
		end
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = { modeId = modeId }

	local mode = MatchmakingConfig.getMode(modeId)
	local count = getQueueSize(modeId)

	remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	broadcastQueueUpdate(modeId)

	if modeId == "ffa" and count >= mode.minPlayers then
		scheduleFfaFill(modeId)
	elseif count >= mode.maxPlayers then
		tryStartMatch(modeId)
	elseif count >= mode.minPlayers and modeId ~= "ffa" then
		tryStartMatch(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	ensureInitialized()
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	removeFromQueue(player)

	if modeId == "ffa" then
		ffaFillToken += 1
	end

	if pendingMatch and pendingMatch.modeId == modeId then
		local stillQueued = {}
		for _, pendingPlayer in pendingMatch.players do
			if playerQueue[pendingPlayer] then
				table.insert(stillQueued, pendingPlayer)
			end
		end
		if #stillQueued < MatchmakingConfig.getMode(modeId).minPlayers then
			pendingMatch = nil
		else
			pendingMatch.players = stillQueued
		end
	end

	remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.getRecommendedMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

return MatchmakingService
