local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerMode = {}
local ffaFillToken = 0
local onQueueChanged

local function initQueues()
	for _, mode in MatchModes.getAll() do
		queues[mode.id] = {}
	end
end

local function getQueueStatus(modeId)
	if MatchStateService.isBusy() then
		return "pending"
	end
	return "waiting"
end

local function buildUpdatePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local position = 0
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			position = index
			break
		end
	end

	return {
		mode = modeId,
		modeLabel = mode.label,
		position = position,
		total = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = getQueueStatus(modeId),
	}
end

local function sendQueueUpdate(player, modeId)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(modeId, player))
	end
end

local function broadcastQueueUpdate(modeId)
	for _, player in queues[modeId] do
		sendQueueUpdate(player, modeId)
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function removeFromQueue(player, modeId)
	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			return true
		end
	end
	return false
end

local function leaveAllQueues(player, notifyLeft)
	local previousMode = playerMode[player]
	playerMode[player] = nil

	local affectedModes = {}
	for modeId in queues do
		if removeFromQueue(player, modeId) then
			table.insert(affectedModes, modeId)
		end
	end

	for _, modeId in affectedModes do
		onQueueChanged(modeId)
	end

	if notifyLeft and previousMode and player.Parent then
		Remotes.QueueUpdate:FireClient(player, {
			mode = nil,
			status = "left",
		})
	end
end

local function takePlayersFromQueue(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player then
			playerMode[player] = nil
			table.insert(taken, player)
		end
	end
	return taken
end

local function startMatch(modeId, playerList)
	MatchStateService.setBusy()

	for _, player in playerList do
		HubService.enterArena(player)
	end

	Bindables.MatchReady:Fire({
		players = playerList,
		mode = modeId,
	})

	broadcastAllQueues()
end

local function canStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return false
	end
	if MatchStateService.isBusy() then
		return false
	end
	return true
end

local function tryStartImmediate(modeId)
	if not canStartMatch(modeId) then
		return false
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]

	if modeId == "ffa" and #queue < mode.maxPlayers then
		return false
	end

	local playersToStart = takePlayersFromQueue(modeId, mode.maxPlayers)
	if #playersToStart < mode.minPlayers then
		for index = #playersToStart, 1, -1 do
			local player = playersToStart[index]
			table.insert(queue, 1, player)
			playerMode[player] = modeId
		end
		return false
	end

	startMatch(modeId, playersToStart)
	return true
end

local function scheduleFfaFill()
	ffaFillToken += 1
	local token = ffaFillToken

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= ffaFillToken then
			return
		end
		if not canStartMatch("ffa") then
			return
		end

		local queue = queues.ffa
		local mode = MatchModes.ffa
		local playersToStart = takePlayersFromQueue("ffa", #queue)
		if #playersToStart >= mode.minPlayers then
			startMatch("ffa", playersToStart)
		else
			for index = #playersToStart, 1, -1 do
				local player = playersToStart[index]
				table.insert(queue, 1, player)
				playerMode[player] = "ffa"
			end
			broadcastQueueUpdate("ffa")
		end
	end)
end

onQueueChanged = function(modeId)
	broadcastQueueUpdate(modeId)

	if modeId == "training" or modeId == "pvp" then
		tryStartImmediate(modeId)
		return
	end

	local mode = MatchModes.ffa
	local queue = queues.ffa
	if #queue >= mode.maxPlayers then
		tryStartImmediate("ffa")
	elseif #queue >= mode.minPlayers then
		scheduleFfaFill()
	else
		ffaFillToken += 1
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false
	end
	if HubService.getPhase(player) == "arena" then
		return false
	end
	if playerMode[player] == modeId then
		sendQueueUpdate(player, modeId)
		return true
	end

	leaveAllQueues(player, false)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId
	onQueueChanged(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	leaveAllQueues(player, true)
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.onArenaFree()
	broadcastAllQueues()

	for _, mode in MatchModes.getAll() do
		if mode.id == "ffa" then
			local queue = queues.ffa
			if #queue >= mode.minPlayers then
				scheduleFfaFill()
			end
		else
			tryStartImmediate(mode.id)
		end
	end
end

function MatchmakingService.init(remotes, bindables)
	Remotes = remotes
	Bindables = bindables
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
		leaveAllQueues(player, false)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)
end

return MatchmakingService
