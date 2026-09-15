local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)
local MatchStateService = require(script.Parent.MatchStateService)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local ffaFillDeadline = nil
local started = false

local function getMode(modeId)
	return MatchModes[modeId]
end

local function isValidMode(modeId)
	return getMode(modeId) ~= nil
end

local function removePlayerFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	playerMode[player] = nil

	if modeId == "ffa" and #queues.ffa < MatchModes.ffa.minPlayers then
		ffaFillDeadline = nil
	end
end

local function buildQueuePayload(player, modeId, status)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	return {
		modeId = modeId,
		modeLabel = mode.label,
		queued = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		inQueue = true,
	}
end

local function sendQueueUpdate(player, modeId, status)
	if not player.Parent then
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, status))
end

local function broadcastQueueUpdate(modeId)
	local status = if MatchStateService.isBusy() then "pending" else "waiting"
	for _, player in queues[modeId] do
		sendQueueUpdate(player, modeId, status)
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function clearQueueUI(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local selected = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(selected, player)
			playerMode[player] = nil
			clearQueueUI(player)
		end
	end
	return selected
end

local function launchMatch(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return false
	end

	if MatchStateService.isBusy() then
		return false
	end

	local playerCount = math.min(#queue, mode.maxPlayers)
	local players = popPlayers(modeId, playerCount)
	if #players < mode.minPlayers then
		return false
	end

	if modeId == "ffa" then
		ffaFillDeadline = nil
	end

	for _, player in players do
		HubService.enterArena(player)
	end

	Bindables.MatchReady:Fire(players)
	broadcastAllQueues()
	return true
end

local function tryStartMatches()
	if MatchStateService.isBusy() then
		return
	end

	for _, modeId in { "training", "pvp", "ffa" } do
		local mode = getMode(modeId)
		local queue = queues[modeId]
		if #queue < mode.minPlayers then
			continue
		end

		if modeId == "ffa" then
			if #queue >= mode.maxPlayers then
				launchMatch(modeId)
				return
			end

			if not ffaFillDeadline then
				ffaFillDeadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
			elseif os.clock() >= ffaFillDeadline then
				launchMatch(modeId)
				return
			end
		else
			launchMatch(modeId)
			return
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not isValidMode(modeId) then
		return false, "invalid_mode"
	end

	if playerMode[player] == modeId then
		sendQueueUpdate(player, modeId, if MatchStateService.isBusy() then "pending" else "waiting")
		return true
	end

	if HubService.getPhase(player) == "arena" then
		return false, "in_match"
	end

	removePlayerFromQueue(player)

	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	if modeId == "ffa" and #queues.ffa >= MatchModes.ffa.minPlayers and not ffaFillDeadline then
		ffaFillDeadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
	end

	broadcastQueueUpdate(modeId)
	tryStartMatches()
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	removePlayerFromQueue(player)
	clearQueueUI(player)
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	MatchStateService.onArenaIdle(function()
		broadcastAllQueues()
		tryStartMatches()
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_POLL_INTERVAL)
			tryStartMatches()
		end
	end)

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
