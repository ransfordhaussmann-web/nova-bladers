local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes
local Bindables

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillDeadline = {}
local fillTokens = {}
local callbacks = {}

local function getValidPlayers(queue)
	local valid = {}
	for _, player in queue do
		if player.Parent and playerQueue[player] then
			table.insert(valid, player)
		end
	end
	return valid
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local queue = getValidPlayers(queues[modeId])
	local count = #queue
	local arenaBusy = MatchStateService.isArenaBusy()
	local status = "waiting"

	if arenaBusy then
		status = "pending"
	elseif modeId == "ffa" and count >= mode.minPlayers and fillDeadline[modeId] then
		status = "filling"
	elseif count >= mode.maxPlayers then
		status = "starting"
	elseif modeId ~= "ffa" and count >= mode.minPlayers then
		status = "starting"
	end

	local payload = {
		modeId = modeId,
		modeLabel = mode.label,
		playersInQueue = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		inQueue = playerQueue[player] == modeId,
		arenaBusy = arenaBusy,
	}

	if modeId == "ffa" and fillDeadline[modeId] and count >= mode.minPlayers then
		payload.fillTimeoutRemaining = math.max(0, math.ceil(fillDeadline[modeId] - os.clock()))
	end

	return payload
end

local function broadcastQueue(modeId)
	local payloadByPlayer = {}
	for _, player in getValidPlayers(queues[modeId]) do
		payloadByPlayer[player] = buildQueuePayload(modeId, player)
	end

	for player, payload in payloadByPlayer do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function clearFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	fillDeadline[modeId] = nil
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or modeId ~= "ffa" then
		return
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]
	fillDeadline[modeId] = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT

	task.spawn(function()
		while token == fillTokens[modeId] and fillDeadline[modeId] do
			local remaining = fillDeadline[modeId] - os.clock()
			if remaining <= 0 then
				break
			end
			broadcastQueue(modeId)
			task.wait(1)
		end

		if token ~= fillTokens[modeId] then
			return
		end

		fillDeadline[modeId] = nil
		MatchmakingService.tryStartMatch(modeId)
	end)
end

local function addToQueue(player, modeId)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
end

local function removeFromQueue(player, silent)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	local mode = MatchModes.get(modeId)
	if mode and #getValidPlayers(queues[modeId]) < mode.minPlayers then
		clearFillTimer(modeId)
	end

	if not silent then
		broadcastQueue(modeId)
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		end
	end
end

local function popPlayers(modeId, count)
	local queue = getValidPlayers(queues[modeId])
	local selected = {}
	for index = 1, math.min(count, #queue) do
		local player = queue[index]
		table.insert(selected, player)
		removeFromQueue(player, true)
	end
	return selected
end

function MatchmakingService.tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		broadcastQueue(modeId)
		return false
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	local queue = getValidPlayers(queues[modeId])
	local count = #queue
	if count < mode.minPlayers then
		return false
	end

	local startCount = math.min(count, mode.maxPlayers)
	if modeId == "ffa" and count < mode.maxPlayers and fillDeadline[modeId] then
		return false
	end

	local players = popPlayers(modeId, startCount)
	if #players < mode.minPlayers then
		for _, player in players do
			addToQueue(player, modeId)
		end
		broadcastQueue(modeId)
		return false
	end

	clearFillTimer(modeId)
	MatchStateService.setArenaBusy(true)
	broadcastAllQueues()

	if callbacks.onMatchReady then
		callbacks.onMatchReady(players, modeId)
	end

	Bindables.MatchReady:Fire(players, modeId)
	return true
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return false
	end
	if playerQueue[player] == modeId then
		broadcastQueue(modeId)
		return true
	end

	removeFromQueue(player, true)
	addToQueue(player, modeId)

	local mode = MatchModes.get(modeId)
	local count = #getValidPlayers(queues[modeId])
	if modeId == "ffa" and count >= mode.minPlayers and not fillDeadline[modeId] then
		startFillTimer(modeId)
	end

	broadcastQueue(modeId)

	if modeId ~= "ffa" then
		MatchmakingService.tryStartMatch(modeId)
	else
		MatchmakingService.tryStartMatch(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player, false)
end

function MatchmakingService.getRecommendedModeId()
	return MatchModes.getRecommended(#Players:GetPlayers()).id
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	for modeId in queues do
		local mode = MatchModes.get(modeId)
		local count = #getValidPlayers(queues[modeId])
		if modeId == "ffa" and count >= mode.minPlayers and not fillDeadline[modeId] then
			startFillTimer(modeId)
		end
		MatchmakingService.tryStartMatch(modeId)
	end
end

function MatchmakingService.init(handlers)
	callbacks = handlers or {}
	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or modeId == "" then
			modeId = MatchmakingService.getRecommendedModeId()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player, true)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
