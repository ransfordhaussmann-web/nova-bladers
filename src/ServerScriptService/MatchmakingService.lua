local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerQueue = {}
local fillTimers = {}
local heartbeatTask = nil

local function getMode(modeId)
	return MatchModes.get(modeId) or MatchModes.training
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = ensureQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function getQueueStatus(modeId)
	local mode = getMode(modeId)
	local queue = ensureQueue(modeId)
	local count = #queue

	if MatchStateService.isBusy() then
		return "pending"
	end
	if modeId == "ffa" and count >= mode.minPlayers and fillTimers[modeId] then
		return "filling"
	end
	if count >= mode.maxPlayers then
		return "ready"
	end
	if count >= mode.minPlayers then
		return "ready"
	end
	return "waiting"
end

local function buildQueuePayload(modeId, targetPlayer)
	local mode = getMode(modeId)
	local queue = ensureQueue(modeId)
	local status = getQueueStatus(modeId)
	local fillRemaining = nil

	if modeId == "ffa" and fillTimers[modeId] and status == "filling" then
		fillRemaining = MatchmakingConfig.FFA_FILL_TIMEOUT
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillRemaining = fillRemaining,
		inQueue = targetPlayer ~= nil and playerQueue[targetPlayer] == modeId,
	}
end

local function broadcastQueue(modeId)
	local payload = buildQueuePayload(modeId)
	for _, player in ensureQueue(modeId) do
		if player.Parent then
			local personal = buildQueuePayload(modeId, player)
			Remotes.QueueUpdate:FireClient(player, personal)
		end
	end
	return payload
end

local function broadcastAllQueues()
	for modeId, _ in MatchModes.all() do
		if #ensureQueue(modeId) > 0 then
			broadcastQueue(modeId)
		end
	end
end

local function leaveHubForQueuedPlayers(playerList)
	for _, player in playerList do
		if player.Parent and HubService.getPhase(player) == "hub" then
			HubService.leaveHubForArena(player)
		end
	end
end

local function startMatch(modeId, playerList)
	for _, player in playerList do
		removeFromQueue(player)
	end

	leaveHubForQueuedPlayers(playerList)
	MatchStateService.setBusy(true)
	Bindables.MatchReady:Fire({
		mode = modeId,
		players = playerList,
	})
end

local function tryStartMatch(modeId)
	if MatchStateService.isBusy() then
		return
	end

	local mode = getMode(modeId)
	local queue = ensureQueue(modeId)
	local count = #queue

	if count < mode.minPlayers then
		return
	end

	if count >= mode.maxPlayers then
		local matchPlayers = {}
		for i = 1, mode.maxPlayers do
			table.insert(matchPlayers, queue[i])
		end
		startMatch(modeId, matchPlayers)
		return
	end

	if modeId == "ffa" then
		if not fillTimers[modeId] and count >= mode.minPlayers then
			fillTimers[modeId] = task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
				fillTimers[modeId] = nil
				if MatchStateService.isBusy() then
					broadcastQueue(modeId)
					return
				end
				local currentQueue = ensureQueue(modeId)
				if #currentQueue >= mode.minPlayers then
					local matchPlayers = {}
					for _, player in currentQueue do
						table.insert(matchPlayers, player)
					end
					startMatch(modeId, matchPlayers)
				end
			end)
			broadcastQueue(modeId)
		end
		return
	end

	if count >= mode.minPlayers then
		local matchPlayers = {}
		for i = 1, mode.minPlayers do
			table.insert(matchPlayers, queue[i])
		end
		startMatch(modeId, matchPlayers)
	end
end

local function processPendingQueues()
	if MatchStateService.isBusy() then
		return
	end

	for modeId, _ in MatchModes.all() do
		local queue = ensureQueue(modeId)
		if #queue > 0 then
			tryStartMatch(modeId)
			if MatchStateService.isBusy() then
				return
			end
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return false, "Ungültiger Modus"
	end

	if playerQueue[player] == modeId then
		return true
	end

	removeFromQueue(player)
	table.insert(ensureQueue(modeId), player)
	playerQueue[player] = modeId

	broadcastQueue(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueue(modeId)
	return true
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setBusy(false)
	task.defer(processPendingQueues)
	broadcastAllQueues()
end

function MatchmakingService.getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.init()
	Remotes, Bindables = RemotesSetup.ensure()

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

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
		MatchmakingService.leaveQueue(player)
	end)

	if heartbeatTask then
		task.cancel(heartbeatTask)
	end
	heartbeatTask = task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			broadcastAllQueues()
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
