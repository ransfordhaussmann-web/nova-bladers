local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local pendingMatch = nil
local fillTokens = {}

local Remotes
local MatchReady

local onMatchStart

local function initQueues()
	for _, modeId in MatchModes.ALL do
		queues[modeId] = {}
	end
end

local function getQueueCount(modeId)
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

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local count = getQueueCount(modeId)
	local status = "waiting"
	if pendingMatch and pendingMatch.modeId == modeId then
		status = "pending"
	elseif MatchStateService.isBusy() and count >= mode.minPlayers then
		status = "pending"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		inQueue = playerQueue[player] == modeId,
	}
end

local function broadcastQueueUpdate(modeId)
	for _, player in queues[modeId] or {} do
		if player.Parent then
			local personal = buildQueuePayload(modeId, player)
			if personal then
				Remotes.QueueUpdate:FireClient(player, personal)
			end
		end
	end
end

local function clearFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	if queue then
		for i, p in queue do
			if p == player then
				table.remove(queue, i)
				break
			end
		end
	end

	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdate(modeId)
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	local remaining = {}

	for _, player in queue do
		if player.Parent and #picked < count then
			table.insert(picked, player)
			playerQueue[player] = nil
		else
			table.insert(remaining, player)
		end
	end

	queues[modeId] = remaining
	return picked
end

local function launchMatch(players, modeId)
	pendingMatch = nil
	clearFillTimer(modeId)

	for _, player in players do
		Remotes.QueueUpdate:FireClient(player, { inQueue = false, status = "starting" })
	end

	broadcastQueueUpdate(modeId)

	if onMatchStart then
		onMatchStart(players, modeId)
	end
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local count = getQueueCount(modeId)
	if count < mode.minPlayers then
		return
	end

	if MatchStateService.isBusy() then
		pendingMatch = { modeId = modeId }
		broadcastQueueUpdate(modeId)
		return
	end

	local take = math.min(count, mode.maxPlayers)
	local players = popPlayers(modeId, take)

	if #players < mode.minPlayers then
		for _, player in players do
			table.insert(queues[modeId], player)
			playerQueue[player] = modeId
		end
		return
	end

	launchMatch(players, modeId)
end

local function scheduleFillTimeout(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end

	clearFillTimer(modeId)
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		if getQueueCount(modeId) >= mode.minPlayers then
			tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false
	end

	if playerQueue[player] == modeId then
		return true
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	local mode = MatchModes.get(modeId)
	local payload = buildQueuePayload(modeId, player)
	Remotes.QueueUpdate:FireClient(player, payload)
	broadcastQueueUpdate(modeId)

	if getQueueCount(modeId) >= mode.maxPlayers then
		tryStartMatch(modeId)
	elseif getQueueCount(modeId) >= mode.minPlayers and mode.fillTimeout <= 0 then
		tryStartMatch(modeId)
	elseif getQueueCount(modeId) >= mode.minPlayers then
		scheduleFillTimeout(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	local modeId = playerQueue[player]
	removeFromQueue(player)
	clearFillTimer(modeId)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.init(callbacks)
	Remotes, _ = RemotesSetup.ensure()
	local _, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	onMatchStart = callbacks.onMatchStart

	initQueues()

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
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaFree(function()
		pendingMatch = nil
		for _, modeId in MatchModes.ALL do
			if getQueueCount(modeId) > 0 then
				tryStartMatch(modeId)
			end
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
