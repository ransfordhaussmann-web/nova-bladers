local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady, MatchEnded

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local fillTokens = {}
local pendingMatch = nil
local handlers = {}

local function getQueueSize(modeId)
	local queue = queues[modeId]
	if not queue then
		return 0
	end
	local count = 0
	for _, player in queue do
		if player.Parent then
			count += 1
		end
	end
	return count
end

local function pruneQueue(modeId)
	local queue = queues[modeId]
	local alive = {}
	for _, player in queue do
		if player.Parent and playerMode[player] == modeId then
			table.insert(alive, player)
		end
	end
	queues[modeId] = alive
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local size = getQueueSize(modeId)
	local status = "waiting"
	if MatchStateService.isArenaOccupied() then
		status = "pending"
	elseif modeId == "ffa" and size >= mode.minPlayers and size < mode.maxPlayers then
		status = "filling"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		queueSize = size,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		arenaBusy = MatchStateService.isArenaOccupied(),
	}
end

local function broadcastQueueUpdate(modeId)
	pruneQueue(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			local payload = buildQueuePayload(player, modeId)
			if payload then
				Remotes.QueueUpdate:FireClient(player, payload)
			end
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or modeId ~= "ffa" then
		return
	end

	cancelFillTimer(modeId)
	local token = fillTokens[modeId] or 0
	fillTokens[modeId] = token

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if fillTokens[modeId] ~= token then
			return
		end
		MatchmakingService.tryStartMatch(modeId)
	end)
end

local function takePlayersFromQueue(modeId, count)
	pruneQueue(modeId)
	local taken = {}
	local remaining = {}

	for _, player in queues[modeId] do
		if #taken < count and player.Parent and playerMode[player] == modeId then
			table.insert(taken, player)
		else
			table.insert(remaining, player)
		end
	end

	queues[modeId] = remaining
	for _, player in taken do
		playerMode[player] = nil
	end

	return taken
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	pruneQueue(modeId)
	local size = getQueueSize(modeId)
	if size < mode.minPlayers then
		return false
	end

	if MatchStateService.isArenaOccupied() then
		pendingMatch = modeId
		broadcastQueueUpdate(modeId)
		return false
	end

	local playerCount = math.min(size, mode.maxPlayers)
	local players = takePlayersFromQueue(modeId, playerCount)
	if #players < mode.minPlayers then
		for _, player in players do
			MatchmakingService.joinQueue(player, modeId)
		end
		return false
	end

	cancelFillTimer(modeId)
	MatchStateService.setArenaOccupied(true)
	pendingMatch = nil

	for _, player in players do
		if handlers.leaveHubForArena then
			handlers.leaveHubForArena(player)
		end
	end

	MatchReady:Fire(modeId, players)
	broadcastAllQueues()
	return true
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.get(modeId) then
		return false
	end
	if handlers.getPhase and handlers.getPhase(player) ~= "hub" then
		return false
	end

	MatchmakingService.leaveQueue(player, false)
	playerMode[player] = modeId
	table.insert(queues[modeId], player)

	local payload = buildQueuePayload(player, modeId)
	if payload then
		Remotes.QueueUpdate:FireClient(player, payload)
	end

	local mode = MatchModes.get(modeId)
	local size = getQueueSize(modeId)

	if size >= mode.maxPlayers then
		MatchmakingService.tryStartMatch(modeId)
	elseif modeId == "ffa" and size >= mode.minPlayers then
		startFillTimer(modeId)
		broadcastQueueUpdate(modeId)
	else
		MatchmakingService.tryStartMatch(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player, broadcast)
	if broadcast == nil then
		broadcast = true
	end

	local modeId = playerMode[player]
	if not modeId then
		return false
	end

	playerMode[player] = nil
	pruneQueue(modeId)

	if modeId == "ffa" then
		local size = getQueueSize(modeId)
		local mode = MatchModes.get(modeId)
		if size < mode.minPlayers then
			cancelFillTimer(modeId)
		end
	end

	if broadcast then
		Remotes.QueueUpdate:FireClient(player, { status = "left" })
		broadcastQueueUpdate(modeId)
	end

	return true
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaOccupied(false)
	MatchStateService.notifyMatchEnded()

	if pendingMatch then
		local modeId = pendingMatch
		pendingMatch = nil
		task.defer(function()
			MatchmakingService.tryStartMatch(modeId)
		end)
	end

	for modeId in queues do
		local mode = MatchModes.get(modeId)
		if mode and getQueueSize(modeId) >= mode.minPlayers then
			if modeId == "ffa" and getQueueSize(modeId) >= mode.minPlayers then
				startFillTimer(modeId)
			else
				task.defer(function()
					MatchmakingService.tryStartMatch(modeId)
				end)
			end
		end
		broadcastQueueUpdate(modeId)
	end
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

function MatchmakingService.init(newHandlers)
	handlers = newHandlers or {}
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	MatchEnded = Bindables.MatchEnded

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
		MatchmakingService.leaveQueue(player, false)
	end)

	MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
