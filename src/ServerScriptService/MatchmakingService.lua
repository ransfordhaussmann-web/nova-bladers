local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {
	training = {},
	pvp = {},
	ffa = {},
}
local playerQueue = {}
local ffaFillToken = 0
local started = false

local function queueSize(modeId)
	return #queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end
	playerQueue[player] = nil
end

local function addToQueue(player, modeId)
	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
end

local function getQueueStatus(modeId)
	local mode = MatchModes.get(modeId)
	local count = queueSize(modeId)
	local status = "waiting"
	if MatchStateService.isArenaBusy() then
		status = "pending"
	elseif count >= mode.minPlayers then
		status = "ready"
	end
	return {
		modeId = modeId,
		modeLabel = mode.label,
		queued = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function broadcastQueueUpdate()
	for player, modeId in playerQueue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, getQueueStatus(modeId))
		end
	end
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(picked, player)
		end
	end
	return picked
end

local function launchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end
	Bindables.MatchReady:Fire(modeId, playerList)
	broadcastQueueUpdate()
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	local count = queueSize(modeId)
	if count < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		if count >= mode.maxPlayers then
			local players = popPlayers(modeId, mode.maxPlayers)
			ffaFillToken += 1
			launchMatch(modeId, players)
			return
		end

		ffaFillToken += 1
		local token = ffaFillToken
		task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
			if token ~= ffaFillToken or MatchStateService.isArenaBusy() then
				return
			end
			if queueSize(modeId) < mode.minPlayers then
				return
			end
			local take = math.min(queueSize(modeId), mode.maxPlayers)
			local players = popPlayers(modeId, take)
			launchMatch(modeId, players)
		end)
		return
	end

	local players = popPlayers(modeId, mode.maxPlayers)
	launchMatch(modeId, players)
end

local function joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end
	if playerQueue[player] == modeId then
		Remotes.QueueUpdate:FireClient(player, getQueueStatus(modeId))
		return
	end

	addToQueue(player, modeId)
	Remotes.QueueUpdate:FireClient(player, getQueueStatus(modeId))
	broadcastQueueUpdate()
	tryStartMatch(modeId)
end

local function leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { status = "idle" })
	broadcastQueueUpdate()
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
		broadcastQueueUpdate()
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			broadcastQueueUpdate()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.ARENA_BUSY_POLL)
			if MatchStateService.isArenaBusy() then
				continue
			end
			for modeId in queues do
				tryStartMatch(modeId)
			end
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

function MatchmakingService.getPlayerQueue(player)
	return playerQueue[player]
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	for modeId in queues do
		tryStartMatch(modeId)
	end
	broadcastQueueUpdate()
end

function MatchmakingService.requeuePlayers(modeId, playerList)
	if not MatchModes.isValid(modeId) then
		return
	end
	for _, player in playerList do
		if player.Parent and not playerQueue[player] then
			table.insert(queues[modeId], player)
			playerQueue[player] = modeId
		end
	end
	broadcastQueueUpdate()
end

return MatchmakingService
