local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTokens = {}

local function getQueue(modeId)
	return queues[modeId]
end

local function countValidPlayers(queue)
	local count = 0
	for _, player in queue do
		if player.Parent then
			count += 1
		end
	end
	return count
end

local function collectValidPlayers(queue, maxPlayers)
	local result = {}
	for _, player in queue do
		if player.Parent and #result < maxPlayers then
			table.insert(result, player)
		end
	end
	return result
end

local function clearQueue(modeId)
	queues[modeId] = {}
	fillTokens[modeId] = nil
end

local function buildQueuePayload(modeId, player)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueue(modeId)
	local count = countValidPlayers(queue)
	local status = "waiting"

	if MatchStateService.isArenaBusy() then
		status = "pending"
	elseif mode.maxPlayers > 0 and count >= mode.maxPlayers then
		status = "ready"
	elseif mode.minPlayers > 0 and count >= mode.minPlayers and mode.fillTimeout == 0 then
		status = "ready"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		arenaBusy = MatchStateService.isArenaBusy(),
		inQueue = player ~= nil and playerQueue[player] == modeId,
	}
end

local function broadcastQueueUpdate(modeId)
	local payload = buildQueuePayload(modeId, nil)
	for _, player in getQueue(modeId) do
		if player.Parent then
			payload.inQueue = true
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function removePlayerFromAllQueues(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end
	playerQueue[player] = nil
	broadcastQueueUpdate(modeId)
end

local function leaveHubForQueuedPlayers(playerList)
	for _, player in playerList do
		if HubService.getPhase(player) ~= "arena" then
			HubService.leaveHubForArena(player)
		end
	end
end

local function tryStartMatch(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return false
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdate(modeId)
		return false
	end

	local queue = getQueue(modeId)
	local players = collectValidPlayers(queue, mode.maxPlayers)
	local count = #players

	if count < mode.minPlayers then
		return false
	end

	if count < mode.maxPlayers and fillTokens[modeId] ~= nil then
		return false
	end

	leaveHubForQueuedPlayers(players)
	clearQueue(modeId)
	for _, player in players do
		playerQueue[player] = nil
	end

	MatchReady:Fire(players, modeId)
	return true
end

local function scheduleFillTimeout(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end

		local queue = getQueue(modeId)
		local count = countValidPlayers(queue)
		if count >= mode.minPlayers then
			tryStartMatch(modeId)
		else
			broadcastQueueUpdate(modeId)
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchmakingConfig.isValidMode(modeId) then
		return false
	end

	if HubService.getPhase(player) == "arena" then
		return false
	end

	removePlayerFromAllQueues(player)

	local queue = getQueue(modeId)
	table.insert(queue, player)
	playerQueue[player] = modeId

	local mode = MatchmakingConfig.getMode(modeId)
	local count = countValidPlayers(queue)

	if count == 1 and mode.fillTimeout > 0 then
		scheduleFillTimeout(modeId)
	end

	Remotes.QueueJoin:FireClient(player, buildQueuePayload(modeId, player))
	broadcastQueueUpdate(modeId)

	if count >= mode.maxPlayers or (mode.fillTimeout == 0 and count >= mode.minPlayers) then
		tryStartMatch(modeId)
	elseif MatchStateService.isArenaBusy() then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end
	removePlayerFromAllQueues(player)
	Remotes.QueueLeave:FireClient(player)
	return true
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.init()
	MatchStateService.onArenaFree(function()
		for modeId in queues do
			tryStartMatch(modeId)
		end
		broadcastAllQueues()
	end)

	Players.PlayerRemoving:Connect(function(player)
		removePlayerFromAllQueues(player)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
