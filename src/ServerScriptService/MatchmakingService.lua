local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, Bindables
local HubService
local queues = {}
local playerQueue = {}
local fillTokens = {}

local function getMode(modeId)
	return MatchModes.get(modeId) or MatchModes.training
end

local function countValidPlayers(playerList)
	local valid = {}
	for _, player in playerList do
		if player.Parent and playerQueue[player] then
			table.insert(valid, player)
		end
	end
	return valid
end

local function buildQueuePayload(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	local players = queue and countValidPlayers(queue.players) or {}
	local pending = MatchStateService.isBusy()
	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = #players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = pending,
		inQueue = false,
		fillSecondsLeft = nil,
	}
end

local function sendQueueUpdate(player, payload)
	if not player.Parent then
		return
	end
	payload.inQueue = playerQueue[player] == payload.modeId
	if payload.inQueue and queues[payload.modeId] and queues[payload.modeId].fillDeadline then
		payload.fillSecondsLeft = math.max(0, math.ceil(queues[payload.modeId].fillDeadline - os.clock()))
	end
	Remotes.QueueUpdate:FireClient(player, payload)
end

local function broadcastQueue(modeId)
	local payload = buildQueuePayload(modeId)
	for _, player in Players:GetPlayers() do
		if playerQueue[player] == modeId or HubService.getPhase(player) == "hub" then
			sendQueueUpdate(player, payload)
		end
	end
end

local function clearFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	if queues[modeId] then
		queues[modeId].fillDeadline = nil
	end
end

local function removeFromQueue(player, silent)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	if not queue then
		return
	end

	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, i)
			break
		end
	end

	if #queue.players == 0 then
		clearFillTimer(modeId)
		queues[modeId] = nil
	end

	if not silent then
		sendQueueUpdate(player, {
			modeId = modeId,
			inQueue = false,
			leftQueue = true,
		})
		broadcastQueue(modeId)
	end
end

local function launchMatch(modeId, playerList)
	for _, player in playerList do
		removeFromQueue(player, true)
	end
	clearFillTimer(modeId)
	queues[modeId] = nil

	MatchStateService.setBusy()
	Bindables.MatchReady:Fire({
		mode = modeId,
		players = playerList,
	})
end

local function tryStartMatch(modeId)
	if MatchStateService.isBusy() then
		broadcastQueue(modeId)
		return
	end

	local queue = queues[modeId]
	if not queue then
		return
	end

	local mode = getMode(modeId)
	local readyPlayers = countValidPlayers(queue.players)
	if #readyPlayers < mode.minPlayers then
		broadcastQueue(modeId)
		return
	end

	if #readyPlayers > mode.maxPlayers then
		local trimmed = {}
		for i = 1, mode.maxPlayers do
			trimmed[i] = readyPlayers[i]
		end
		readyPlayers = trimmed
	end

	launchMatch(modeId, readyPlayers)
end

local function scheduleFillTimer(modeId)
	local mode = getMode(modeId)
	if not mode or mode.id ~= "ffa" or not MatchmakingConfig.FFA_FILL_TIMEOUT then
		return
	end

	local queue = queues[modeId]
	if not queue then
		return
	end

	if #countValidPlayers(queue.players) < mode.minPlayers then
		return
	end

	if queue.fillDeadline then
		return
	end

	queue.fillDeadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.spawn(function()
		while token == fillTokens[modeId] do
			local activeQueue = queues[modeId]
			if not activeQueue or not activeQueue.fillDeadline then
				return
			end

			local remaining = activeQueue.fillDeadline - os.clock()
			if remaining <= 0 then
				tryStartMatch(modeId)
				return
			end

			broadcastQueue(modeId)
			task.wait(1)
		end
	end)
end

local function evaluateQueue(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end

	local readyCount = #countValidPlayers(queue.players)
	if readyCount >= mode.maxPlayers then
		tryStartMatch(modeId)
		return
	end

	if mode.id == "ffa" then
		if readyCount >= mode.minPlayers then
			scheduleFillTimer(modeId)
		end
		return
	end

	if readyCount >= mode.minPlayers then
		tryStartMatch(modeId)
	end
end

local function getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = getRecommendedModeId()
	end

	local mode = getMode(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if HubService.getPhase(player) ~= "hub" then
		return false, "not_in_hub"
	end

	if playerQueue[player] then
		if playerQueue[player] == modeId then
			sendQueueUpdate(player, buildQueuePayload(modeId))
			return true
		end
		removeFromQueue(player, true)
	end

	if not queues[modeId] then
		queues[modeId] = { players = {} }
	end

	table.insert(queues[modeId].players, player)
	playerQueue[player] = modeId

	local payload = buildQueuePayload(modeId)
	payload.inQueue = true
	sendQueueUpdate(player, payload)
	broadcastQueue(modeId)

	evaluateQueue(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	local modeId = playerQueue[player]
	removeFromQueue(player, false)
	if queues[modeId] then
		evaluateQueue(modeId)
	end
end

function MatchmakingService.onArenaFreed()
	MatchStateService.setIdle()
	for modeId in pairs(queues) do
		evaluateQueue(modeId)
	end
end

function MatchmakingService.getPlayerQueue(player)
	return playerQueue[player]
end

function MatchmakingService.start(hubService)
	HubService = hubService
	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
